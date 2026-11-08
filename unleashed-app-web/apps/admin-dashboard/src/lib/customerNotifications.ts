import { serverTimestamp, Timestamp } from 'firebase/firestore'
import type { Order, OrderStatus } from '../types'

/**
 * Customer-facing copy for every order status. The stage 1 customer app shows
 * these titles in its own notification feed, so keep the wording customer-safe
 * and never mention administrator tooling.
 */
export const ORDER_STATUS_TITLES: Record<string, string> = {
  pending_confirmation: 'Request received',
  confirmed: 'Order confirmed',
  processing: 'Preparing your order',
  ready_for_shipment: 'Ready for shipment',
  shipped: 'Order shipped',
  out_for_delivery: 'Out for delivery',
  delivered: 'Order delivered',
  rejected: 'Request rejected',
  cancelled: 'Order cancelled',
  refunded: 'Order refunded',
  // Legacy status from documents created before the order-request model.
  placed: 'Order placed',
}

/** Customer-facing explanation stored on each tracking timeline entry. */
export const ORDER_STATUS_NOTES: Record<string, string> = {
  pending_confirmation:
    'The store is verifying current prices and stock for your request.',
  confirmed: 'Your order has been confirmed with verified prices and totals.',
  processing: 'Your order is being prepared.',
  ready_for_shipment: 'Your order is packed and ready for shipment.',
  shipped: 'Your order has been handed to the courier.',
  out_for_delivery: 'Your order is out for delivery.',
  delivered: 'Your order has been delivered.',
  rejected:
    'The store could not confirm this request. No stock was deducted and no payment is due.',
  cancelled: 'Order cancelled.',
  refunded: 'Payment has been refunded.',
  placed: 'Order received by the store.',
}

/**
 * Deterministic ids prevent duplicate customer alerts if a write is retried or
 * the same status transition is attempted twice.
 */
export function customerOrderNotificationId(orderId: string, status: string): string {
  return `customer_order_${orderId}_${status}`
}

export function customerChatNotificationId(messageId: string): string {
  return `customer_chat_${messageId}`
}

export function orderLabel(order: Pick<Order, 'id' | 'orderNumber'>): string {
  return order.orderNumber || `#${order.id.slice(0, 8).toUpperCase()}`
}

/**
 * Builds one timestamped entry for the shared `orders/{id}.timeline` array.
 *
 * Firestore does not accept server-timestamp sentinels inside arrays, so this
 * uses a client `Timestamp.now()`. The entry is committed atomically with the
 * status change, and the customer reads it in real time.
 */
export function orderStatusTimelineEntry(status: string, note?: string) {
  const title = ORDER_STATUS_TITLES[status] ?? 'Order updated'
  const detail = note?.trim() || ORDER_STATUS_NOTES[status] || ''
  return {
    status,
    title,
    ...(detail ? { note: detail } : {}),
    at: Timestamp.now(),
  }
}

function money(centavos: number): string {
  return `₱${(Math.max(0, centavos) / 100).toFixed(2)}`
}

/** Builds the Firestore payload for a customer order-status alert. */
export function orderStatusNotification(order: Order, status: OrderStatus | string) {
  const title = ORDER_STATUS_TITLES[status] ?? 'Order updated'
  const body =
    status === 'confirmed'
      ? `Order ${orderLabel(order)} confirmed. Verified total ${money(order.total)}.`
      : `Order ${orderLabel(order)}: ${title}.`
  return {
    recipientId: order.customerId,
    type: `order_${status}`,
    title,
    body,
    orderId: order.id,
    isRead: false,
    createdAt: serverTimestamp(),
  }
}

/** Builds the Firestore payload for a rejected request. */
export function orderRejectedNotification(order: Order, reason: string) {
  return {
    recipientId: order.customerId,
    type: 'order_rejected',
    title: 'Request rejected',
    body: `Request ${orderLabel(order)} could not be confirmed. ${reason}`.slice(0, 480),
    orderId: order.id,
    isRead: false,
    createdAt: serverTimestamp(),
  }
}

/** Builds the Firestore payload for a customer chat-reply alert. */
export function chatReplyNotification(customerId: string, messageId: string, text: string) {
  return {
    recipientId: customerId,
    type: 'chat_reply',
    title: 'Unleashed Clothing replied',
    body: text.slice(0, 140),
    customerId,
    chatId: customerId,
    isRead: false,
    messageId,
    createdAt: serverTimestamp(),
  }
}
