import { useEffect, useMemo, useState } from 'react'
import type { AdminNotification } from '../types'
import { watchAdminNotifications } from './notifications'

/**
 * Real-time administrator notification feed. Disabled when there is no
 * signed-in administrator so the listener is never started for other roles.
 */
export function useAdminNotifications(enabled = true) {
  const [notifications, setNotifications] = useState<AdminNotification[]>([])
  const [loading, setLoading] = useState(enabled)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!enabled) {
      setNotifications([])
      setLoading(false)
      setError(null)
      return
    }

    setLoading(true)
    const unsubscribe = watchAdminNotifications(
      (next) => {
        setNotifications(next)
        setLoading(false)
        setError(null)
      },
      (watchError) => {
        setError(watchError.message)
        setLoading(false)
      },
    )
    return unsubscribe
  }, [enabled])

  const unreadCount = useMemo(
    () => notifications.reduce((count, notification) => (notification.isRead ? count : count + 1), 0),
    [notifications],
  )

  return { notifications, loading, error, unreadCount }
}
