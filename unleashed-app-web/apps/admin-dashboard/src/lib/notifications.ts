import {
  collection,
  doc,
  getDocs,
  limit,
  onSnapshot,
  query,
  serverTimestamp,
  updateDoc,
  where,
  writeBatch,
  type DocumentData,
  type Timestamp,
  type Unsubscribe,
} from 'firebase/firestore'
import { requireDb } from '../firebase'
import type { AdminNotification } from '../types'
import { timestampMillis } from './format'

/** Administrator copies of store events use this fixed recipient id. */
export const ADMIN_NOTIFICATION_RECIPIENT = 'admin'

function mapNotification(id: string, data: DocumentData): AdminNotification {
  const customerId = data.customerId ?? data.chatCustomerId ?? null
  return {
    id,
    recipientId: String(data.recipientId ?? ADMIN_NOTIFICATION_RECIPIENT),
    type: String(data.type ?? 'general'),
    title: String(data.title ?? 'Notification'),
    body: String(data.body ?? ''),
        orderId: data.orderId ? String(data.orderId) : null,
    chatId: data.chatId ? String(data.chatId) : customerId ? String(customerId) : null,
    customerId: customerId ? String(customerId) : null,
    reviewId: data.reviewId ? String(data.reviewId) : null,
    productId: data.productId ? String(data.productId) : null,
    rating: typeof data.rating === 'number' ? data.rating : null,
    isRead: data.isRead === true,
    createdAt: (data.createdAt as Timestamp | null | undefined) ?? null,
    readAt: (data.readAt as Timestamp | null | undefined) ?? null,
  }
}

/**
 * Watches the administrator notification feed in real time.
 *
 * Only an equality filter is used so the dashboard does not require a
 * composite Firestore index. Ordering is applied in memory because the feed is
 * small and capped for display.
 */
export function watchAdminNotifications(
  onNext: (notifications: AdminNotification[]) => void,
  onError?: (error: Error) => void,
): Unsubscribe {
  const database = requireDb()
  // Cap the listener so the dashboard cannot stream an unbounded collection on
  // the Spark plan. A single equality filter keeps the query index-free.
  const feed = query(
    collection(database, 'notifications'),
    where('recipientId', '==', ADMIN_NOTIFICATION_RECIPIENT),
    limit(200),
  )

  return onSnapshot(
    feed,
    (snapshot) => {
      const notifications = snapshot.docs.map((entry) => mapNotification(entry.id, entry.data()))
      notifications.sort(
        (a, b) => (timestampMillis(b.createdAt) ?? 0) - (timestampMillis(a.createdAt) ?? 0),
      )
      onNext(notifications)
    },
    (error) => onError?.(error),
  )
}

export async function markAdminNotificationRead(notificationId: string): Promise<void> {
  const database = requireDb()
  await updateDoc(doc(database, 'notifications', notificationId), {
    isRead: true,
    readAt: serverTimestamp(),
  })
}

/** Returns the number of notifications that were updated. */
export async function markAllAdminNotificationsRead(): Promise<number> {
  const database = requireDb()
  // One equality filter only: index merging is not required and the result is
  // filtered in memory, matching the real-time feed query.
  const feed = await getDocs(
    query(
      collection(database, 'notifications'),
      where('recipientId', '==', ADMIN_NOTIFICATION_RECIPIENT),
      limit(200),
    ),
  )
  const unread = feed.docs.filter((entry) => entry.data().isRead !== true)
  if (unread.length === 0) return 0

  const batch = writeBatch(database)
  for (const entry of unread) {
    batch.update(entry.ref, {
      isRead: true,
      readAt: serverTimestamp(),
    })
  }
  await batch.commit()
  return unread.length
}

/** Resolves the screen a notification should open, if any. */
export function notificationLink(notification: AdminNotification): string | null {
  if (notification.type === 'new_review' || notification.reviewId) {
    return '/reviews'
  }

  if (notification.orderId) {
    return `/orders/${encodeURIComponent(notification.orderId)}`
  }

  const customerId = notification.customerId ?? notification.chatId
  if (customerId) {
    return `/messages?customerId=${encodeURIComponent(customerId)}`
  }

  return null
}
