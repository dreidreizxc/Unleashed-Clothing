import { formatDateTime, titleCase } from '../lib/format'
import { notificationLink } from '../lib/notifications'
import type { AdminNotification } from '../types'
import { Icon, type IconName } from './Icon'

function iconFor(type: string): IconName {
    if (type === 'new_review') {
    return 'star'
  }
  if (type === 'new_order' || type === 'order_cancelled' || type.startsWith('order_')) {
    return 'orders'
  }
  if (type === 'chat_message' || type === 'chat_reply') {
    return 'messages'
  }
  return 'bell'
}

export function NotificationCard({
  notification,
  onOpen,
  compact = false,
}: {
  notification: AdminNotification
  onOpen: (notification: AdminNotification) => void
  compact?: boolean
}) {
  const target = notificationLink(notification)
  const unread = !notification.isRead

  return (
    <button
      type="button"
      className={`notification-card ${unread ? 'is-unread' : ''} ${compact ? 'is-compact' : ''}`}
      onClick={() => onOpen(notification)}
      aria-label={`${unread ? 'Unread: ' : ''}${notification.title}`}
    >
      <span className="notification-card-icon">
        <Icon name={iconFor(notification.type)} size={compact ? 15 : 17} />
      </span>
      <span className="notification-card-copy">
        <span className="notification-card-title">{notification.title}</span>
        {notification.body ? (
          <span className="notification-card-body">{notification.body}</span>
        ) : null}
        <span className="notification-card-meta">
          <span>{titleCase(notification.type)}</span>
          <span>{formatDateTime(notification.createdAt)}</span>
        </span>
      </span>
      {unread ? <span className="notification-card-dot" aria-hidden="true" /> : null}
      {target ? (
        <span className="notification-card-arrow" aria-hidden="true">
          <Icon name="chevronRight" size={14} />
        </span>
      ) : null}
    </button>
  )
}
