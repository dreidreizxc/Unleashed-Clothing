import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react'
import {
  getIdTokenResult,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut as firebaseSignOut,
  type User,
} from 'firebase/auth'
import { auth, isFirebaseConfigured, requireAuth } from '../firebase'

interface AuthContextValue {
  user: User | null
  isAdmin: boolean
  loading: boolean
  claimsError: string | null
  signIn: (email: string, password: string) => Promise<void>
  signOut: () => Promise<void>
  refreshClaims: () => Promise<void>
}

const AuthContext = createContext<AuthContextValue | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [isAdmin, setIsAdmin] = useState(false)
  const [loading, setLoading] = useState(isFirebaseConfigured)
  const [claimsError, setClaimsError] = useState<string | null>(null)

  const checkClaims = useCallback(async (nextUser: User) => {
    try {
      const token = await getIdTokenResult(nextUser, true)
      setIsAdmin(token.claims.admin === true)
      setClaimsError(null)
    } catch (error) {
      setIsAdmin(false)
      setClaimsError(error instanceof Error ? error.message : 'Could not verify administrator access.')
    }
  }, [])

  useEffect(() => {
    if (!auth) {
      setLoading(false)
      return
    }

    let active = true
    const unsubscribe = onAuthStateChanged(auth, (nextUser) => {
      if (!active) return
      setUser(nextUser)
      if (!nextUser) {
        setIsAdmin(false)
        setClaimsError(null)
        setLoading(false)
        return
      }
      setLoading(true)
      void checkClaims(nextUser).finally(() => {
        if (active) setLoading(false)
      })
    })

    return () => {
      active = false
      unsubscribe()
    }
  }, [checkClaims])

  const signIn = useCallback(async (email: string, password: string) => {
    await signInWithEmailAndPassword(requireAuth(), email.trim(), password)
  }, [])

  const signOut = useCallback(async () => {
    await firebaseSignOut(requireAuth())
  }, [])

  const refreshClaims = useCallback(async () => {
    if (!user) return
    await checkClaims(user)
  }, [checkClaims, user])

  const value = useMemo<AuthContextValue>(
    () => ({ user, isAdmin, loading, claimsError, signIn, signOut, refreshClaims }),
    [user, isAdmin, loading, claimsError, signIn, signOut, refreshClaims],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth(): AuthContextValue {
  const context = useContext(AuthContext)
  if (!context) throw new Error('useAuth must be used inside AuthProvider')
  return context
}
