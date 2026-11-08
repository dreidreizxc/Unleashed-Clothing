import { useState } from 'react'
import { adminEmailHint } from '../firebase'
import { useAuth } from '../lib/AuthProvider'
import { useToast } from './Toast'
import { Spinner } from './ui'
import { Icon } from './Icon'

export function AccessDenied() {
  const { user, claimsError, refreshClaims, signOut } = useAuth()
  const { notify } = useToast()
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
    } catch (error) {
      notify(error instanceof Error ? error.message : 'Could not sign out.', 'error')
      setSigningOut(false)
    }
  }

  return (
    <div className="auth-shell">
      <div className="auth-card">
        <span className="auth-mark auth-mark-lock">
          <Icon name="lock" size={26} />
        </span>
        <p className="eyebrow">Restricted area</p>
        <h1>Administrator access required</h1>
        <p className="auth-copy">
          You are signed in as <strong>{user?.email ?? 'an unknown account'}</strong>, but this account
          does not have the <code>admin</code> custom claim. The dashboard will not grant access based on
          an email address or a frontend route.
        </p>
        {claimsError ? <p className="field-error">{claimsError}</p> : null}
        <div className="setup-grid">
          <div>
            <span>Signed-in account</span>
            <strong>{user?.email ?? '—'}</strong>
          </div>
          <div>
            <span>Expected admin</span>
            <strong>{adminEmailHint || 'See project setup'}</strong>
          </div>
          <div>
            <span>Authorization</span>
            <strong>Custom claim missing</strong>
          </div>
        </div>
        <div className="code-block">
          <span>An authorized operator should run, from the repository root</span>
          <code>node set-admin-claim.js</code>
        </div>
        <div className="auth-actions">
          <button type="button" className="button button-primary" onClick={refresh} disabled={refreshing}>
            {refreshing ? <Spinner size={16} /> : <Icon name="refresh" size={16} />}
            Refresh access
          </button>
          <button type="button" className="button button-ghost" onClick={logout} disabled={signingOut}>
            {signingOut ? <Spinner size={16} /> : <Icon name="logout" size={16} />}
            Sign out
          </button>
        </div>
        <p className="auth-footnote">
          If the claim was just added, sign out and back in, or use Refresh access. Firestore Security
          Rules still enforce administrator access for every read and write.
        </p>
      </div>
    </div>
  )
}
