import { adminEmailHint, isFirebaseConfigured, projectId } from '../firebase'

export function SetupNotice() {
  return (
    <div className="auth-shell">
      <div className="auth-card setup-card">
        <span className="auth-mark">UC</span>
        <p className="eyebrow">Unleashed Admin</p>
        <h1>Firebase setup required</h1>
        <p className="auth-copy">
          The dashboard cannot connect because the Firebase web configuration is missing or incomplete.
          Add the public client values to <code>apps/admin-dashboard/.env.local</code> using the
          <code> VITE_FIREBASE_*</code> names, then restart the dev server.
        </p>
        <div className="setup-grid">
          <div>
            <span>Project</span>
            <strong>{projectId || 'Not configured'}</strong>
          </div>
          <div>
            <span>Config status</span>
            <strong>{isFirebaseConfigured ? 'Ready' : 'Missing values'}</strong>
          </div>
          <div>
            <span>Expected admin</span>
            <strong>{adminEmailHint || 'Set VITE_ADMIN_EMAIL'}</strong>
          </div>
        </div>
        <div className="code-block">
          <span>From the repository root</span>
          <code>node set-admin-claim.js</code>
        </div>
        <p className="auth-footnote">
          Administrator access requires a Firebase custom claim named <code>admin</code>. A route guard
          alone is never treated as authorization; Firestore Security Rules enforce the same claim.
        </p>
      </div>
    </div>
  )
}
