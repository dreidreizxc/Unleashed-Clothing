import { Navigate, Outlet, useLocation } from 'react-router-dom'
import { isFirebaseConfigured } from '../firebase'
import { useAuth } from '../lib/AuthProvider'
import { AccessDenied } from './AccessDenied'
import { SetupNotice } from './SetupNotice'
import { LoadingScreen } from './ui'

export function ProtectedRoute() {
  const { user, isAdmin, loading } = useAuth()
  const location = useLocation()

  if (!isFirebaseConfigured) return <SetupNotice />
  if (loading) return <LoadingScreen label="Verifying administrator access…" />
  if (!user) return <Navigate to="/login" replace state={{ from: location.pathname }} />
  if (!isAdmin) return <AccessDenied />
  return <Outlet />
}
