import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react'
import { Icon } from './Icon'

type ToastTone = 'success' | 'error' | 'info'

interface Toast {
  id: string
  message: string
  tone: ToastTone
}

interface ToastContextValue {
  notify: (message: string, tone?: ToastTone) => void
}

const ToastContext = createContext<ToastContextValue | null>(null)

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([])
  const timers = useRef<Map<string, number>>(new Map())

  const dismiss = useCallback((id: string) => {
    setToasts((current) => current.filter((toast) => toast.id !== id))
    const timer = timers.current.get(id)
    if (timer) window.clearTimeout(timer)
    timers.current.delete(id)
  }, [])

  const notify = useCallback(
    (message: string, tone: ToastTone = 'success') => {
      const id =
        typeof crypto !== 'undefined' && 'randomUUID' in crypto
          ? crypto.randomUUID()
          : `${Date.now()}-${Math.random()}`
      setToasts((current) => [...current.slice(-3), { id, message, tone }])
      const timer = window.setTimeout(() => dismiss(id), 5000)
      timers.current.set(id, timer)
    },
    [dismiss],
  )

  const value = useMemo(() => ({ notify }), [notify])

  return (
    <ToastContext.Provider value={value}>
      {children}
      <div className="toast-stack" aria-live="polite" aria-atomic="false">
        {toasts.map((toast) => (
          <div key={toast.id} className={`toast toast-${toast.tone}`}>
            <Icon
              name={toast.tone === 'error' ? 'alert' : toast.tone === 'success' ? 'check' : 'alert'}
              size={18}
            />
            <span>{toast.message}</span>
            <button type="button" aria-label="Dismiss notification" onClick={() => dismiss(toast.id)}>
              <Icon name="x" size={15} />
            </button>
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  )
}

export function useToast(): ToastContextValue {
  const context = useContext(ToastContext)
  if (!context) throw new Error('useToast must be used inside ToastProvider')
  return context
}
