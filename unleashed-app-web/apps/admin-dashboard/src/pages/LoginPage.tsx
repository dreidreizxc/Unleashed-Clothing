import { useState, type FormEvent } from 'react'
import { Navigate, useLocation, useNavigate } from 'react-router-dom'
import { isFirebaseConfigured, projectId } from '../firebase'
import { useAuth } from '../lib/AuthProvider'
import { AccessDenied } from '../components/AccessDenied'
import { SetupNotice } from '../components/SetupNotice'
import { Icon } from '../components/Icon'
import { Spinner } from '../components/ui'
import { useToast } from '../components/Toast'

function authErrorMessage(error: unknown): string {
  const code = (error as { code?: string })?.code ?? ''
  switch (code) {
    case 'auth/invalid-credential':
    case 'auth/wrong-password':
    case 'auth/user-not-found':
      return 'Incorrect email or password.'
    case 'auth/invalid-email':
      return 'Enter a valid email address.'
    case 'auth/too-many-requests':
      return 'Too many attempts. Wait a moment and try again.'
    case 'auth/network-request-failed':
      return 'Network error. Check your connection and try again.'
    case 'auth/unauthorized-domain':
      return 'This domain is not authorized in Firebase Auth. Open the dashboard at http://localhost:5173.'
    case 'auth/operation-not-allowed':
      return 'Email/password sign-in is not enabled for this Firebase project.'
    case 'auth/invalid-api-key':
      return 'The Firebase API key is invalid. Check .env.local.'
    default:
      return error instanceof Error ? error.message : 'Sign-in failed. Please try again.'
  }
}

export function LoginPage() {
  const { user, isAdmin, loading, signIn } = useAuth()
  const { notify } = useToast()
  const location = useLocation()
  const navigate = useNavigate()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  if (!isFirebaseConfigured) return <SetupNotice />
  if (loading) {
    return (
      <div className="auth-shell">
        <div className="auth-card auth-card-loading">
          <Spinner size={26} label="Checking your session…" />
        </div>
      </div>
    )
  }
  if (user && !isAdmin) return <AccessDenied />
  if (user && isAdmin) {
    const from = (location.state as { from?: string } | null)?.from
    return <Navigate to={from && from !== '/login' ? from : '/'} replace />
  }

  async function submit(event: FormEvent) {
    event.preventDefault()
    setError(null)
    if (!email.trim() || !password) {
      setError('Enter your administrator email and password.')
      return
    }
    setBusy(true)
    try {
      await signIn(email, password)
      notify('Signed in successfully.')
      navigate('/', { replace: true })
    } catch (signInError) {
      setError(authErrorMessage(signInError))
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="login-shell">
      <section className="login-brand">
        <div className="brand brand-large">
          <span className="brand-mark brand-mark-large">U</span>
          <div>
            <strong>UNLEASHED</strong>
            <span>M-Commerce Control Room</span>
          </div>
        </div>
        <div className="login-brand-copy">
          <p className="eyebrow">Administrator access</p>
          <h1>Run the store from one calm, focused place.</h1>
          <p>
            Manage the product catalog, stock, orders, and customer records. Every action is checked
            against your Firebase administrator claim and enforced by Firestore Security Rules.
          </p>
        </div>
        <ul className="login-features">
          <li>
            <Icon name="products" size={18} />
            Product and image management
          </li>
          <li>
            <Icon name="inventory" size={18} />
            Stock adjustments with an audit trail
          </li>
          <li>
            <Icon name="reports" size={18} />
            Sales reporting from real order data
          </li>
        </ul>
        <div className="login-brand-foot">
          <span>Firebase project</span>
          <strong>{projectId || 'Not configured'}</strong>
        </div>
      </section>

      <section className="login-panel">
        <div className="login-form-wrap">
          <span className="auth-mark">UC</span>
          <p className="eyebrow">Welcome back</p>
          <h2>Sign in to the dashboard</h2>
          <p className="login-subtitle">
            Use the Firebase account that has the <code>admin</code> custom claim.
          </p>

          <form className="form-stack" onSubmit={submit}>
            <label className="field">
              <span className="field-label">Email address</span>
              <input
                type="email"
                autoComplete="email"
                value={email}
                onChange={(event) => setEmail(event.target.value)}
                disabled={busy}
                required
              />
            </label>
            <label className="field">
              <span className="field-label">Password</span>
              <input
                type="password"
                autoComplete="current-password"
                value={password}
                onChange={(event) => setPassword(event.target.value)}

                disabled={busy}
                required
              />
            </label>

            {error ? (
              <div className="error-banner" role="alert">
                <Icon name="alert" size={18} />
                <span>{error}</span>
              </div>
            ) : null}

            <button type="submit" className="button button-primary button-block" disabled={busy}>
              {busy ? <Spinner size={17} /> : <Icon name="lock" size={17} />}
              {busy ? 'Signing in…' : 'Sign in'}
            </button>
          </form>

          <p className="auth-footnote">
            Administrator access is not granted by email address. If your account has no claim, an
            authorized operator must run <code>node set-admin-claim.js</code> from the repository root.
          </p>
        </div>
      </section>
    </div>
  )
}
