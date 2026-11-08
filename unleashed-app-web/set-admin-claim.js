const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const fs = require('fs');
const path = require('path');

// Service account key path
const serviceAccountPath = path.join(__dirname, 'unleashed-clothing-firebase-adminsdk-fbsvc-f694afd9ea.json');

// Load service account credentials
const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));

// Initialize Firebase Admin SDK
const app = initializeApp({
  credential: cert(serviceAccount)
});

const auth = getAuth(app);
const db = getFirestore(app);

// Email to make admin
const ADMIN_EMAIL = 'admin@unleashedclothing.com';

async function setAdminClaim() {
  try {
    // Find user by email
    const user = await auth.getUserByEmail(ADMIN_EMAIL);
    
    console.log(`Found user: ${user.email} (UID: ${user.uid})`);
    
    // Set admin claim without discarding any existing custom claims
    await auth.setCustomUserClaims(user.uid, { ...(user.customClaims || {}), admin: true });
    
    console.log(`✅ Successfully set admin claim for ${ADMIN_EMAIL}`);
    
    // Log the activity
    await db.collection('admin_activity_logs').add({
      action: 'admin_claim_set',
      targetType: 'user',
      targetId: user.uid,
      details: { email: ADMIN_EMAIL, claimedBy: 'setup-script' },
      createdAt: FieldValue.serverTimestamp()
    });
    
    console.log('📝 Activity logged');
    process.exit(0);
    
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

setAdminClaim();
