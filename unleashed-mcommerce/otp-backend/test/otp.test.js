require('dotenv').config();

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  app,
  errorHandler,
  HttpError,
  hashOtp,
  safeHashCompare,
  createOtp,
  fromAddress,
  sendOtpEmail,
  redactEmails,
} = require('../index');

async function withServer(run) {
  const server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));

  try {
    await run(server.address().port);
  } finally {
    await new Promise((resolve) => {
      server.close(resolve);
      server.closeAllConnections?.();
    });
  }
}

function captureResponse() {
  const captured = {};

  return {
    captured,
    res: {
      headersSent: false,
      status(code) {
        captured.status = code;
        return this;
      },
      json(body) {
        captured.body = body;
        return this;
      },
    },
  };
}

test('unexpected errors return a generic 500 without leaking details', () => {
  const originalError = console.error;
  console.error = () => {};
  const { captured, res } = captureResponse();

  try {
    errorHandler(
      new Error('secret detail for owner@example.com'),
      {},
      res,
      () => {}
    );
  } finally {
    console.error = originalError;
  }

  assert.equal(captured.status, 500);
  assert.deepEqual(captured.body, {
    error: 'An internal server error occurred.',
  });
  assert.doesNotMatch(
    JSON.stringify(captured.body),
    /secret detail|owner@example/
  );
});

test('curated client errors keep their message', () => {
  const { captured, res } = captureResponse();

  errorHandler(
    new HttpError(401, 'Invalid email or password.'),
    {},
    res,
    () => {}
  );

  assert.equal(captured.status, 401);
  assert.deepEqual(captured.body, { error: 'Invalid email or password.' });
});

test('curated delivery errors keep their safe 503 message', () => {
  const originalError = console.error;
  console.error = () => {};
  const { captured, res } = captureResponse();

  try {
    errorHandler(
      new HttpError(503, 'The email service could not be reached.', {
        expose: true,
      }),
      {},
      res,
      () => {}
    );
  } finally {
    console.error = originalError;
  }

  assert.equal(captured.status, 503);
  assert.deepEqual(captured.body, {
    error: 'The email service could not be reached.',
  });
});

test('health endpoint reports ok', async () => {
  await withServer(async (port) => {
    const response = await fetch(`http://127.0.0.1:${port}/health`);
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), { status: 'ok' });
  });
});

test('request-otp rejects a missing password without touching Firebase', async () => {
  await withServer(async (port) => {
    const response = await fetch(
      `http://127.0.0.1:${port}/auth/request-otp`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: 'not-a-real-user@example.com' }),
      }
    );

    assert.equal(response.status, 400);
    assert.deepEqual(await response.json(), {
      error: 'Please provide a valid email and password.',
    });
  });
});

test('request-otp returns a JSON error for malformed JSON', async () => {
  await withServer(async (port) => {
    const response = await fetch(
      `http://127.0.0.1:${port}/auth/request-otp`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: '{"email":',
      }
    );

    assert.equal(response.status, 400);
    const body = await response.json();
    assert.equal(typeof body.error, 'string');
    assert.ok(body.error.length > 0);
  });
});

test('verify-otp rejects a malformed code before any lookup', async () => {
  await withServer(async (port) => {
    const response = await fetch(
      `http://127.0.0.1:${port}/auth/verify-otp`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: 'not-a-real-user@example.com',
          code: '12',
        }),
      }
    );

    assert.equal(response.status, 400);
    assert.deepEqual(await response.json(), {
      error: 'Please provide a valid email and six-digit code.',
    });
  });
});

test('OTP hashing is deterministic and compared safely', () => {
  const first = hashOtp('uid-1', '123456');
  const second = hashOtp('uid-1', '123456');
  const different = hashOtp('uid-1', '654321');

  assert.equal(first, second);
  assert.notEqual(first, different);
  assert.equal(safeHashCompare(first, second), true);
  assert.equal(safeHashCompare(first, different), false);
});

test('createOtp returns a six-digit numeric code', () => {
  for (let index = 0; index < 50; index += 1) {
    assert.match(createOtp(), /^\d{6}$/);
  }
});

test('fromAddress extracts a bare sender address', () => {
  const original = process.env.OTP_FROM_EMAIL;
  process.env.OTP_FROM_EMAIL = 'Unleashed Clothing <noreply@example.com>';

  try {
    assert.equal(fromAddress(), 'noreply@example.com');
  } finally {
    process.env.OTP_FROM_EMAIL = original;
  }
});

test('redactEmails removes addresses from provider messages', () => {
  const redacted = redactEmails(
    'You can only send testing emails to your own email address (owner@example.com).'
  );

  assert.equal(
    redacted,
    'You can only send testing emails to your own email address ([email]).'
  );
});

test('sendOtpEmail maps a provider 403 to a safe, actionable 503', async () => {
  const originalFetch = global.fetch;
  const originalError = console.error;
  console.error = () => {};

  global.fetch = async () => ({
    ok: false,
    status: 403,
    json: async () => ({
      name: 'validation_error',
      message:
        'You can only send testing emails to your own email address (owner@example.com).',
    }),
  });

  try {
    await assert.rejects(
      () => sendOtpEmail('customer@example.com', '123456'),
      (error) => {
        assert.equal(error.status, 503);
        assert.equal(error.expose, true);
        assert.match(error.message, /cannot receive verification codes/i);
        assert.doesNotMatch(error.message, /owner@example\.com/);
        return true;
      }
    );
  } finally {
    global.fetch = originalFetch;
    console.error = originalError;
  }
});

test('sendOtpEmail maps provider throttling and network failures', async () => {
  const originalFetch = global.fetch;
  const originalError = console.error;
  console.error = () => {};

  try {
    global.fetch = async () => ({
      ok: false,
      status: 429,
      json: async () => ({ name: 'rate_limit_exceeded', message: 'slow down' }),
    });

    await assert.rejects(
      () => sendOtpEmail('customer@example.com', '123456'),
      (error) => {
        assert.equal(error.status, 503);
        assert.match(error.message, /too many verification emails/i);
        return true;
      }
    );

    global.fetch = async () => {
      throw new Error('socket hang up');
    };

    await assert.rejects(
      () => sendOtpEmail('customer@example.com', '123456'),
      (error) => {
        assert.equal(error.status, 503);
        assert.match(error.message, /could not be reached/i);
        return true;
      }
    );
  } finally {
    global.fetch = originalFetch;
    console.error = originalError;
  }
});
