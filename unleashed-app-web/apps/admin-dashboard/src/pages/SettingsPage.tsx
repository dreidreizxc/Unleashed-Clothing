import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { authDomain, imageMode, isFirebaseConfigured, projectId } from '../firebase'
import { useAuth } from '../lib/AuthProvider'
import { PageHeader, Spinner } from '../components/ui'
import { Icon } from '../components/Icon'
import { useToast } from '../components/Toast'

export function SettingsPage() {
  const { user, isAdmin, signOut, refreshClaims } = useAuth()
  const { notify } = useToast()
  const navigate = useNavigate()
  const [refreshing, setRefreshing] = useState(false)
  const [signingOut, setSigningOut] = useState(false)

  async function refresh() {
    setRefreshing(true)
    try {
      await refreshClaims()
      notify('Access claims refreshed.', 'info')
    } catch (error) {
      notify(error instanceof Error ? error.message : 'Could not refresh access.', 'error')
    } finally {
      setRefreshing(false)
    }
  }

  async function logout() {
    setSigningOut(true)
    try {
      await signOut()
      navigate('/login', { replace: true })
    } catch (error) {
      notify(error instanceof Error ? error.message : 'Could not sign out.', 'error')
      setSigningOut(false)
    }
  }

  return (
    <div className="page-stack">
      <PageHeader
        eyebrow="Account"
        title="Settings"
        description="Administrator account details and the security model behind this dashboard. Privileges cannot be granted from this page."
      />

      <div className="settings-grid">
        <section className="panel">
          <header className="panel-header">
            <div>
              <p className="eyebrow">Signed in</p>
              <h2>Administrator account</h2>
            </div>
            <span className={`badge ${isAdmin ? 'badge-success' : 'badge-warning'}`}>
              {isAdmin ? 'Admin claim active' : 'Claim not verified'}
            </span>
          </header>
          <dl className="detail-list">
            <div>
              <dt>Email</dt>
              <dd>{user?.email || 'Not available'}</dd>
            </div>
            <div>
              <dt>Display name</dt>
              <dd>{user?.displayName || 'Not set'}</dd>
            </div>
            <div>
              <dt>User ID</dt>
              <dd className="mono-small">{user?.uid || '—'}</dd>
            </div>
            <div>
              <dt>Email verified</dt>
              <dd>{user?.emailVerified ? 'Yes' : 'No'}</dd>
            </div>
            <div>
              <dt>Last sign-in</dt>
              <dd>
                {user?.metadata.lastSignInTime
                  ? new Date(user.metadata.lastSignInTime).toLocaleString('en-PH', {
                      dateStyle: 'medium',
                      timeStyle: 'short',
                    })
                  : '—'}
              </dd>
            </div>
          </dl>
          <div className="inline-actions">
            <button type="button" className="button button-ghost" onClick={refresh} disabled={refreshing}>
              {refreshing ? <Spinner size={16} /> : <Icon name="refresh" size={16} />}
              Refresh claims
            </button>
            <button type="button" className="button button-danger-ghost" onClick={logout} disabled={signingOut}>
              {signingOut ? <Spinner size={16} /> : <Icon name="logout" size={16} />}
              Sign out
            </button>
          </div>
        </section>

        <section className="panel">
          <header className="panel-header">
            <div>
              <p className="eyebrow">Environment</p>
              <h2>Firebase project</h2>
            </div>
          </header>
          <dl className="detail-list">
            <div>
              <dt>Project ID</dt>
              <dd className="mono-small">{projectId || 'Not configured'}</dd>
            </div>
            <div>
              <dt>Auth domain</dt>
              <dd className="mono-small">{authDomain || 'Not configured'}</dd>
            </div>
            <div>
              <dt>Client configured</dt>
              <dd>{isFirebaseConfigured ? 'Yes' : 'No — check .env.local'}</dd>
            </div>
            <div>
              <dt>Image storage</dt>
              <dd>
                {imageMode === 'firestore'
                  ? 'Firestore bytes (Spark plan)'
                  : imageMode}
              </dd>
            </div>
            <div>
              <dt>Cloud Functions</dt>
              <dd>Not used — order requests use Firestore on the Spark plan</dd>
            </div>
          </dl>
          <p className="field-hint">
            Cloud Storage requires the Blaze plan, so product images are optimized in the browser and stored
            in admin-only Firestore documents instead. No billing upgrade is made by this app.
          </p>
          <p className="field-hint">
            Customers submit a provisional order request. An administrator must confirm it here, which
            re-verifies current prices and stock, assigns the official order number, deducts stock, and
            writes the verified totals. Rejecting a request changes no stock.
          </p>
        </section>

        <section className="panel panel-span-2">
          <header className="panel-header">
            <div>
              <p className="eyebrow">Security</p>
              <h2>How administrator access works</h2>
            </div>
            <Icon name="lock" size={20} />
          </header>
          <div className="security-grid">
            <div>
              <strong>1. Firebase Authentication</strong>
              <p>You sign in with email and password. The session is managed by the Firebase Web SDK.</p>
            </div>
            <div>
              <strong>2. Admin custom claim</strong>
              <p>
                The dashboard reads the <code>admin</code> custom claim from the ID token. An email address
                alone never grants access.
              </p>
            </div>
            <div>
              <strong>3. Firestore Security Rules</strong>
              <p>
                Every read and write is checked again by the server using
                <code> request.auth.token.admin == true</code>. Route guards are only a convenience.
              </p>
            </div>
            <div>
              <strong>4. No privilege escalation</strong>
              <p>
                This page cannot grant the admin claim. An authorized operator must run the local
                <code> set-admin-claim.js</code> script with service-account credentials outside the browser.
              </p>
            </div>
          </div>
        </section>

        <section className="panel panel-span-2">
          <header className="panel-header">
            <div>
              <p className="eyebrow">Operations</p>
              <h2>Deployment reminders</h2>
            </div>
          </header>
          <div className="checklist">
            <div>
              <Icon name="check" size={17} />
              <span>Firestore Security Rules must be deployed for the project, not only kept in the repository.</span>
            </div>
            <div>
              <Icon name="check" size={17} />
              <span>Authorized domains must include the host you open (localhost is authorized for development).</span>
            </div>
            <div>
              <Icon name="check" size={17} />
              <span>Product prices are stored as integer centavos (PHP) to match the existing rules and schema.</span>
            </div>
            <div>
              <Icon name="check" size={17} />
              <span>Keep service-account JSON files out of the frontend and out of public repositories.</span>
            </div>
          </div>
        </section>
      </div>
    </div>
  )
}
