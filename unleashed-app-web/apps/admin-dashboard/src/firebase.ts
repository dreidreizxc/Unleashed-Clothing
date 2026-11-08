import { getApp, getApps, initializeApp, type FirebaseApp } from 'firebase/app'
import { getAuth, type Auth } from 'firebase/auth'
import { getFirestore, type Firestore } from 'firebase/firestore'

const env = import.meta.env

export const firebaseConfig = {
  apiKey: env.VITE_FIREBASE_API_KEY ?? '',
  authDomain: env.VITE_FIREBASE_AUTH_DOMAIN ?? '',
  projectId: env.VITE_FIREBASE_PROJECT_ID ?? '',
  storageBucket: env.VITE_FIREBASE_STORAGE_BUCKET ?? '',
  messagingSenderId: env.VITE_FIREBASE_MESSAGING_SENDER_ID ?? '',
  appId: env.VITE_FIREBASE_APP_ID ?? '',
  measurementId: env.VITE_FIREBASE_MEASUREMENT_ID ?? '',
}

const requiredKeys: (keyof typeof firebaseConfig)[] = [
  'apiKey',
  'authDomain',
  'projectId',
  'messagingSenderId',
  'appId',
]

export const isFirebaseConfigured = requiredKeys.every((key) => Boolean(firebaseConfig[key]))

let app: FirebaseApp | null = null

if (isFirebaseConfigured) {
  app = getApps().length > 0 ? getApp() : initializeApp(firebaseConfig)
}

export const firebaseApp = app
export const auth: Auth | null = app ? getAuth(app) : null
export const db: Firestore | null = app ? getFirestore(app) : null

export const projectId = firebaseConfig.projectId || 'unleashed-clothing'
export const authDomain = firebaseConfig.authDomain
export const adminEmailHint = env.VITE_ADMIN_EMAIL ?? ''
export const imageMode = env.VITE_PRODUCT_IMAGE_MODE ?? 'firestore'

export function requireAuth(): Auth {
  if (!auth) {
    throw new Error('Firebase Authentication is not configured. Add VITE_FIREBASE_* values to .env.local.')
  }
  return auth
}

export function requireDb(): Firestore {
  if (!db) {
    throw new Error('Cloud Firestore is not configured. Add VITE_FIREBASE_* values to .env.local.')
  }
  return db
}
