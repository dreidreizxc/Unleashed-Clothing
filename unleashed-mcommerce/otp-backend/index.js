require('dotenv').config();

const express = require('express');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const crypto = require('node:crypto');
const path = require('node:path');
const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');

const app = express();

const requiredEnv = [
  'PORT',
  'FIREBASE_PROJECT_ID',
  'FIREBASE_WEB_API_KEY',
  'OTP_HASH_SECRET',
  'RESEND_API_KEY',
  'OTP_FROM_EMAIL',
  'OTP_CODE_TTL_SECONDS',
  'OTP_RESEND_SECONDS',
  'OTP_MAX_ATTEMPTS',
  'OTP_MAX_PER_HOUR',
];

for (const name of requiredEnv) {
  if (!process.env[name]?.trim()) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
}

const serviceAccount = require('./serviceAccountKey.json');

if (serviceAccount.project_id !== process.env.FIREBASE_PROJECT_ID) {
  throw new Error('Firebase service account project does not match configuration.');
}

initializeApp({
  credential: cert(serviceAccount),
  projectId: process.env.FIREBASE_PROJECT_ID,
});

const db = getFirestore();
const auth = getAuth();

const PORT = Number(process.env.PORT);
const OTP_TTL_SECONDS = Number(process.env.OTP_CODE_TTL_SECONDS);
const RESEND_SECONDS = Number(process.env.OTP_RESEND_SECONDS);
const MAX_ATTEMPTS = Number(process.env.OTP_MAX_ATTEMPTS);
const MAX_PER_HOUR = Number(process.env.OTP_MAX_PER_HOUR);
const SESSION_TTL_SECONDS = 7 * 24 * 60 * 60;

class HttpError extends Error {
  constructor(status, message, options = {}) {
    super(message);
    this.name = 'HttpError';
    this.status = status;
    // Only curated messages may cross the API boundary. Unexpected errors stay
    // behind the generic 500 response.
    this.expose = options.expose === true;
  }
}

function redactEmails(value) {
  return String(value).replace(/[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}/g, '[email]');
}

function fromAddress() {
  const raw = String(process.env.OTP_FROM_EMAIL || '');
  const match = raw.match(/<([^>]+)>/);
  return (match ? match[1] : raw).trim().toLowerCase();
}

// Lightweight stage tracing for the OTP routes. Never logs bodies, emails,
// codes, tokens, or headers.
function logStage(req, stage, detail = '') {
  const suffix = detail ? ` (${detail})` : '';
  console.log(`[otp] ${req.method} ${req.path} stage=${stage}${suffix}`);
}

app.disable('x-powered-by');
app.use(helmet());
app.use(express.json({ limit: '10kb' }));

const requestLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 10,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  message: { error: 'Too many login requests. Please try again later.' },
});

const verifyLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  message: { error: 'Too many verification attempts. Please try again later.' },
});

function hashOtp(uid, code) {
  return crypto
    .createHmac('sha256', process.env.OTP_HASH_SECRET)
    .update(`${uid}:${code}`)
    .digest('hex');
}

function safeHashCompare(expected, actual) {
  const expectedBuffer = Buffer.from(expected, 'hex');
  const actualBuffer = Buffer.from(actual, 'hex');

  return expectedBuffer.length === actualBuffer.length
    && crypto.timingSafeEqual(expectedBuffer, actualBuffer);
}

function createOtp() {
  return crypto.randomInt(100000, 1000000).toString();
}

async function authenticatePassword(email, password) {
  const url = new URL(
    'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword'
  );

  url.searchParams.set('key', process.env.FIREBASE_WEB_API_KEY);

  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email,
      password,
      returnSecureToken: true,
    }),
    signal: AbortSignal.timeout(15000),
  });

  const result = await response.json();

  if (!response.ok || !result.idToken || !result.localId) {
    throw new HttpError(401, 'Invalid email or password.');
  }

  const decoded = await auth.verifyIdToken(result.idToken, true);
  const user = await auth.getUser(decoded.uid);

  if (user.disabled || user.uid !== result.localId) {
    throw new HttpError(401, 'Unable to authenticate this account.');
  }

  if (!user.email || user.email.toLowerCase() !== email) {
    throw new HttpError(401, 'Unable to authenticate this account.');
  }


  // Admin dashboard accounts retain their existing authentication flow.
  if (user.customClaims?.admin === true) {
    throw new HttpError(403, 'This login method is for customer accounts.');
  }

  return user;
}

async function sendOtpEmail(email, code) {
  let response;

  try {
    response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${process.env.RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: process.env.OTP_FROM_EMAIL,
        to: [email],
        subject: 'Your Unleashed Clothing login verification code',
        text:
          `Your Unleashed Clothing verification code is ${code}. ` +
          `It expires in ${Math.ceil(OTP_TTL_SECONDS / 60)} minutes. ` +
          'If you did not request this code, you can ignore this email.',
        html: `
          <div style="font-family:Arial,sans-serif;max-width:480px;margin:auto;padding:24px;color:#111">
            <h2>Unleashed Clothing</h2>
            <p>Use this code to complete your login:</p>
            <div style="font-size:32px;font-weight:bold;letter-spacing:8px;padding:16px 0">
              ${code}
            </div>
            <p>This code expires in ${Math.ceil(OTP_TTL_SECONDS / 60)} minutes.</p>
            <p>If you did not request this code, ignore this email.</p>
          </div>
        `,
      }),
      signal: AbortSignal.timeout(15000),
    });
  } catch (error) {
    console.error(
      'OTP email request failed:',
      error.name || 'Error',
      redactEmails(error.message)
    );

    throw new HttpError(
      503,
      'The email service could not be reached. Please try again shortly.',
      { expose: true }
    );
  }

  if (response.ok) {
    return;
  }

  const result = await response.json().catch(() => ({}));
  const providerMessage = redactEmails(result.message || '');

  console.error(
    'OTP email rejected:',
    `status=${response.status}`,
    `name=${result.name || 'unknown'}`,
    providerMessage ? `message=${providerMessage}` : ''
  );

  if (response.status === 429) {
    throw new HttpError(
      503,
      'Too many verification emails were requested. Please try again in a few minutes.',
      { expose: true }
    );
  }

  if (response.status === 403) {
    // Resend also returns 403 for its testing-sender restriction. The
    // operator log above keeps the provider detail; the customer gets a
    // safe, actionable message without provider internals.
    throw new HttpError(
      503,
      'This email address cannot receive verification codes yet. Please contact support.',
      { expose: true }
    );
  }

  if (response.status === 401) {
    throw new HttpError(
      503,
      'Email delivery is not configured correctly. Please contact support.',
      { expose: true }
    );
  }

  throw new HttpError(
    503,
    'Unable to send the verification email. Please try again later.',
    { expose: true }
  );
}

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

// Step 1: Validate password and send an OTP.
app.post('/auth/request-otp', requestLimiter, async (req, res, next) => {
  try {
    const email = typeof req.body?.email === 'string'
      ? req.body.email.trim().toLowerCase()
      : '';

    const password = typeof req.body?.password === 'string'
      ? req.body.password
      : '';

    if (
      !email ||
      email.length > 254 ||
      !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ||
      !password ||
      password.length > 4096
    ) {
      throw new HttpError(400, 'Please provide a valid email and password.');
    }

    logStage(req, 'validated');

    const user = await authenticatePassword(email, password);
    const uid = user.uid;
    logStage(req, 'password-verified', `uidSuffix=${uid.slice(-4)}`);
    const code = createOtp();

    const challengeRef = db.collection('otp_challenges').doc(uid);
    const rateLimitRef = db.collection('otp_rate_limits').doc(uid);
    const challengeId = crypto.randomUUID();
    const now = Date.now();

    await db.runTransaction(async (transaction) => {
      const challengeSnapshot = await transaction.get(challengeRef);
      const rateLimitSnapshot = await transaction.get(rateLimitRef);

      const existing = challengeSnapshot.exists
        ? challengeSnapshot.data()
        : {};

      const rateLimit = rateLimitSnapshot.exists
        ? rateLimitSnapshot.data()
        : {};

      const previousSentAt = existing.lastSentAt?.toMillis?.() || 0;

      if (now - previousSentAt < RESEND_SECONDS * 1000) {
        throw new HttpError(
          429,
          'Please wait before requesting another verification code.'
        );
      }

      // Fall back to legacy challenge fields during migration.
      const previousWindow =
        rateLimit.windowStartedAt?.toMillis?.() ||
        existing.windowStartedAt?.toMillis?.() ||
        0;

      const sameHour = now - previousWindow < 60 * 60 * 1000;

      const hourlyCount = sameHour
        ? (rateLimit.hourlyCount ?? existing.hourlyCount ?? 0)
        : 0;

      if (hourlyCount >= MAX_PER_HOUR) {
        throw new HttpError(
          429,
          'You have reached the hourly verification code limit.'
        );
      }

      transaction.set(rateLimitRef, {
        uid,
        windowStartedAt: Timestamp.fromMillis(
          sameHour ? previousWindow : now
        ),
        hourlyCount: hourlyCount + 1,
        updatedAt: FieldValue.serverTimestamp(),
      });

      transaction.set(challengeRef, {
        uid,
        email,
        challengeId,
        codeHash: hashOtp(uid, code),
        attempts: 0,
        expiresAt: Timestamp.fromMillis(
          now + OTP_TTL_SECONDS * 1000
        ),
        lastSentAt: Timestamp.fromMillis(now),
        createdAt: FieldValue.serverTimestamp(),
      });
    });

    logStage(req, 'challenge-created');

    try {
      await sendOtpEmail(email, code);
      logStage(req, 'email-sent');
    } catch (error) {
      logStage(req, 'email-failed');
      console.error('OTP email delivery failed:', redactEmails(error.message));

      // Remove only the challenge belonging to this failed delivery and give
      // back the hourly slot it consumed. A send that never reached the
      // customer must not count against their retry budget.
      await db.runTransaction(async (transaction) => {
        const challengeSnapshot = await transaction.get(challengeRef);
        const rateLimitSnapshot = await transaction.get(rateLimitRef);

        if (
          challengeSnapshot.exists &&
          challengeSnapshot.data().challengeId === challengeId
        ) {
          transaction.delete(challengeRef);

          if (rateLimitSnapshot.exists) {
            const currentCount =
              Number(rateLimitSnapshot.data().hourlyCount) || 0;

            transaction.update(rateLimitRef, {
              hourlyCount: Math.max(0, currentCount - 1),
              updatedAt: FieldValue.serverTimestamp(),
            });
          }
        }
      });

      if (error instanceof HttpError && error.expose) {
        throw error;
      }

      throw new HttpError(
        503,
        'Unable to send the verification email. Please try again later.',
        { expose: true }
      );
    }

    logStage(req, 'completed');
    res.status(200).json({
      message: 'Verification code sent to your email.',
    });
  } catch (error) {
    next(error);
  }
});

// Step 2: Verify the OTP and issue a Firebase custom token.
app.post('/auth/verify-otp', verifyLimiter, async (req, res, next) => {
  try {
    const email = typeof req.body?.email === 'string'
      ? req.body.email.trim().toLowerCase()
      : '';

    const code = typeof req.body?.code === 'string'
      ? req.body.code.trim()
      : '';

    if (
      !email ||
      !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ||
      !/^\d{6}$/.test(code)
    ) {
      throw new HttpError(400, 'Please provide a valid email and six-digit code.');
    }

    logStage(req, 'validated');

    // The email must belong to an existing Firebase account.
    const userRecord = await auth.getUserByEmail(email);

    if (userRecord.disabled || userRecord.customClaims?.admin === true) {
      logStage(req, 'account-rejected');
      throw new HttpError(401, 'Invalid or expired verification code.');
    }

    const uid = userRecord.uid;
    logStage(req, 'account-found', `uidSuffix=${uid.slice(-4)}`);
    const challengeRef = db.collection('otp_challenges').doc(uid);
    const sessionId = crypto.randomUUID();
    const sessionRef = db.collection('otp_sessions').doc(sessionId);

    const result = await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(challengeRef);

      if (!snapshot.exists) {
        return { verified: false };
      }

      const challenge = snapshot.data();
      const now = Date.now();

      if (
        challenge.email !== email ||
        !challenge.expiresAt ||
        challenge.expiresAt.toMillis() <= now ||
        challenge.attempts >= MAX_ATTEMPTS
      ) {
        transaction.delete(challengeRef);
        return { verified: false };
      }

      const submittedHash = hashOtp(uid, code);

      if (!safeHashCompare(challenge.codeHash, submittedHash)) {
        const nextAttempts = challenge.attempts + 1;

        if (nextAttempts >= MAX_ATTEMPTS) {
          transaction.delete(challengeRef);
        } else {
          transaction.update(challengeRef, {
            attempts: nextAttempts,
          });
        }

        return { verified: false };
      }

      const expiresAt = Timestamp.fromMillis(
        now + SESSION_TTL_SECONDS * 1000
      );

      transaction.delete(challengeRef);

      transaction.create(sessionRef, {
        uid,
        active: true,
        expiresAt,
        createdAt: FieldValue.serverTimestamp(),
      });

      return { verified: true };
    });

    if (!result.verified) {
      logStage(req, 'challenge-rejected');
      throw new HttpError(401, 'Invalid or expired verification code.');
    }

    try {
      const customToken = await auth.createCustomToken(uid, {
        session_id: sessionId,
      });

      logStage(req, 'session-created');
      res.status(200).json({
        message: 'Login verified successfully.',
        customToken,
      });
    } catch (error) {
      logStage(req, 'custom-token-failed');
      await sessionRef.update({
        active: false,
        revokedAt: FieldValue.serverTimestamp(),
      }).catch(() => {});

      throw error;
    }
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      return next(new HttpError(401, 'Invalid or expired verification code.'));
    }

    next(error);
  }
});

// Step 3: Invalidate the current server-managed session on logout.
app.post('/auth/logout', async (req, res, next) => {
  try {
    const authorization = req.headers.authorization || '';
    const match = authorization.match(/^Bearer (.+)$/i);

    if (!match) {
      throw new HttpError(401, 'Authentication token is required.');
    }

    const decoded = await auth.verifyIdToken(match[1], true);
    const sessionId = decoded.session_id;
    logStage(req, 'token-verified', `uidSuffix=${String(decoded.uid).slice(-4)}`);

    if (typeof sessionId === 'string' && sessionId.length > 0) {
      const sessionRef = db.collection('otp_sessions').doc(sessionId);

      await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(sessionRef);

        if (snapshot.exists && snapshot.data().uid === decoded.uid) {
          transaction.update(sessionRef, {
            active: false,
            revokedAt: FieldValue.serverTimestamp(),
          });
        }
      });

      logStage(req, 'session-revoked');
    }

    res.status(200).json({ message: 'Session invalidated.' });
  } catch (error) {
    next(error);
  }
});

function errorHandler(error, req, res, next) {
  if (res.headersSent) {
    return next(error);
  }

  const status =
    Number.isInteger(error.status) && error.status >= 400
      ? error.status
      : 500;

  const isCurated =
    status < 500
      ? error instanceof HttpError || error.expose === true
      : error instanceof HttpError && error.expose === true;

  if (status >= 500) {
    console.error('OTP backend error:', {
      status,
      name: error.name || 'Error',
      message: redactEmails(error.message || ''),
      stack: process.env.NODE_ENV === 'production' ? undefined : error.stack,
    });
  }

  res.status(status).json({
    error: isCurated
      ? error.message
      : 'An internal server error occurred.',
  });
}

app.use(errorHandler);

function warnAboutEmailSender() {
  const sender = fromAddress();
  const domain = sender.includes('@') ? sender.split('@')[1] : 'unknown';

  if (domain === 'resend.dev') {
    console.warn(
      'OTP email sender uses the Resend test address. Only the Resend ' +
        'account owner can receive verification codes until a verified ' +
        'domain is configured.'
    );
  }

  if (!process.env.RESEND_API_KEY || process.env.RESEND_API_KEY.length < 10) {
    console.warn('RESEND_API_KEY does not look configured.');
  }

  return domain;
}

async function checkEmailProvider() {
  try {
    const response = await fetch('https://api.resend.com/domains', {
      headers: { Authorization: `Bearer ${process.env.RESEND_API_KEY}` },
      signal: AbortSignal.timeout(8000),
    });

    if (!response.ok) {
      console.warn(
        `Resend credential check failed with HTTP ${response.status}. ` +
          'Email delivery will fail until this is fixed.'
      );
      return;
    }

    console.log('Resend credential check: ok');
  } catch (error) {
    console.warn(
      'Resend credential check could not reach the provider:',
      error.name || 'Error'
    );
  }
}

if (require.main === module) {
  const senderDomain = warnAboutEmailSender();

  // Make crashes and forced restarts visible in redirected logs. Without
  // these handlers a crash (or an external kill) looks like a silent
  // "connection reset" in the Flutter app.
  process.on('unhandledRejection', (reason) => {
    console.error(
      'OTP backend unhandled rejection:',
      redactEmails(reason?.message || String(reason))
    );
  });

  process.on('uncaughtException', (error) => {
    console.error(
      'OTP backend uncaught exception:',
      redactEmails(error?.message || String(error))
    );
    if (error?.stack) console.error(error.stack);
    process.exitCode = 1;
  });

  for (const signal of ['SIGINT', 'SIGTERM']) {
    process.on(signal, () => {
      console.log(`OTP backend received ${signal}; shutting down.`);
      process.exit(0);
    });
  }

  app.listen(PORT, '0.0.0.0', () => {
    console.log(`OTP backend listening on port ${PORT}`);
    console.log(`OTP email sender domain: ${senderDomain}`);
    // Non-blocking: surface a stale or invalid key at startup instead of
    // letting every login fail with a generic server error.
    void checkEmailProvider();
  });
}

module.exports = {
  app,
  errorHandler,
  HttpError,
  hashOtp,
  safeHashCompare,
  createOtp,
  fromAddress,
  sendOtpEmail,
  redactEmails,
};



