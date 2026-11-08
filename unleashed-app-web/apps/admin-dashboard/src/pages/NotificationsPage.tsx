import { useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Icon } from '../components/Icon'
import { NotificationCard } from '../components/NotificationCard'
import { useToast } from '../components/Toast'
import { EmptyState, ErrorBanner, PageHeader, Spinner } from '../components/ui'
import {
  markAdminNotificationRead,
  markAllAdminNotificationsRead,
  notificationLink,
} from '../lib/notifications'
import { useAdminNotifications } from '../lib/useAdminNotifications'
import type { AdminNotification } from '../types'

type NotificationFilter = 'all' | 'unread'

export function NotificationsPage() {
  const { notifications, loading, error, unreadCount } = useAdminNotifications(true)
  const { notify } = useToast()
  const navigate = useNavigate()
  const [filter, setFilter] = useState<NotificationFilter>('all')
  const [markingAll, setMarkingAll] = useState(false)

  const visible = useMemo(
    () => (filter === 'unread' ? notifications.filter((notification) => !notification.isRead) : notifications),
    [filter, notifications],
  )

  async function open(notification: AdminNotification) {
    if (!notification.isRead) {
      try {
        await markAdminNotificationRead(notification.id)
      } catch (markError) {
        notify(
          markError instanceof Error ? markError.message : 'Could not mark that notification as read.',
          'error',
        )
      }
    }
    const target = notificationLink(notification)
    if (target) navigate(target)
  }

  async function markAll() {
    setMarkingAll(true)
    try {
      const count = await markAllAdminNotificationsRead()
      notify(
        count > 0
          ? `${count} notification${count === 1 ? '' : 's'} marked as read.`
          : 'No unread notifications.',
      )
    } catch (markError) {
      notify(
        markError instanceof Error ? markError.message : 'Could not mark notifications as read.',
        'error',
      )
    } finally {
      setMarkingAll(false)
    }
  }

  return (
    <div className="page-stack">
      <PageHeader
        eyebrow="Store"
        title="Notifications"
        description="New orders and customer messages appear here in real time. This feed is visible to administrators only."
        actions={
          <button
            type="button"
            className="button button-ghost"
            onClick={markAll}
            disabled={markingAll || unreadCount === 0}
          >
            {markingAll ? <Spinner size={16} /> : <Icon name="check" size={16} />}
            Mark all read
          </button>
        }
      />

      {error ? <ErrorBanner message={error} /> : null}

      <section className="panel notification-toolbar-panel">
        <div className="notification-toolbar">
          <div className="notification-filters" role="group" aria-label="Filter notifications">
            <button
              type="button"
              className={`button button-small ${filter === 'all' ? 'button-primary' : 'button-ghost'}`}
              onClick={() => setFilter('all')}
              aria-pressed={filter === 'all'}
            >
              All ({notifications.length})
            </button>
            <button
              type="button"
              className={`button button-small ${filter === 'unread' ? 'button-primary' : 'button-ghost'}`}
              onClick={() => setFilter('unread')}
              aria-pressed={filter === 'unread'}
            >
              Unread ({unreadCount})
            </button>
          </div>
          <span className="muted">
            {unreadCount > 0 ? `${unreadCount} unread` : 'Nothing unread'}
          </span>
        </div>
      </section>

      {loading ? (
        <section className="panel table-loading">
          <Spinner size={24} label="Loading notifications…" />
        </section>
      ) : visible.length === 0 ? (
        <section className="panel">
          <EmptyState
            icon="bell"
            title={filter === 'unread' ? 'No unread notifications' : 'No notifications yet'}
            description={
              filter === 'unread'
                ? 'Every notification has been read.'
                : 'New orders and customer messages will appear here as soon as they happen.'
            }
          />
        </section>
      ) : (
        <section className="notification-page-list" aria-label="Notifications">
          {visible.map((notification) => (
            <NotificationCard
              key={notification.id}
              notification={notification}
              onOpen={open}
            />
          ))}
        </section>
      )}
    </div>
  )
}
