import type { Timestamp } from 'firebase/firestore'

/** Product categories supported by the storefront and the mobile app. */
export type ProductStatus = 'active' | 'inactive' | 'archived'

export type ProductCategory = 'T-Shirt' | 'Cap' | 'Hoodie'

export const PRODUCT_CATEGORIES: ProductCategory[] = ['T-Shirt', 'Cap', 'Hoodie']

export const PRODUCT_STATUSES: ProductStatus[] = ['active', 'inactive', 'archived']
export const DEFAULT_SIZES = ['XS', 'S', 'M', 'L', 'XL', 'XXL']

/**
 * `price` is stored as an integer number of centavos (PHP), because the
 * existing Firestore rules require `price` to be an int.
 */
export interface Product {
  id: string
  name: string
  description: string
  price: number
  priceUnit?: string
  currency?: string
  category: ProductCategory
  sizes: string[]
  stock: Record<string, number>
  totalStock: number
  status: ProductStatus
  imageId?: string | null
  imageContentType?: string | null
  imageUpdatedAt?: Timestamp | null
  imageUrl?: string | null
  /** Optional product-specific size chart. Spark fallback: `firestore://...`. */
  sizeChartUrl?: string | null
  sizeChartContentType?: string | null
  sizeChartUpdatedAt?: Timestamp | null
  createdAt?: Timestamp | null
  updatedAt?: Timestamp | null
  createdBy?: string | null
  updatedBy?: string | null
}

export interface ProductImageDoc {
  bytes: import('firebase/firestore').Bytes
  contentType: string
  width: number
  height: number
  size: number
  updatedAt?: Timestamp | null
  updatedBy?: string | null
}

export interface SizeChartDoc {
  kind: 'size_chart'
  productId: string
  bytes: import('firebase/firestore').Bytes
  contentType: string
  width: number
  height: number
  size: number
  updatedAt?: Timestamp | null
  updatedBy?: string | null
}

export interface ProductDraft {
  name: string
  description: string
  price: number
  category: ProductCategory
  sizes: string[]
  stock: Record<string, number>
  status: ProductStatus
}

export interface OrderItem {
  productId?: string
  name?: string
  size?: string
  quantity?: number
  price?: number
  subtotal?: number
  imageId?: string | null
  category?: string
}

export type OrderStatus =
  | 'pending_confirmation'
  | 'confirmed'
  | 'processing'
  | 'ready_for_shipment'
  | 'shipped'
  | 'out_for_delivery'
  | 'delivered'
  | 'rejected'
  | 'cancelled'
  | 'refunded'
  /** Legacy documents created before the order-request model. */
  | 'placed'

export type PaymentStatus = 'unpaid' | 'pending' | 'paid' | 'refunded' | 'failed'
export type FulfillmentStatus = 'unfulfilled' | 'processing' | 'shipped' | 'delivered' | 'cancelled'

export const ORDER_STATUSES: OrderStatus[] = [
  'pending_confirmation',
  'confirmed',
  'processing',
  'ready_for_shipment',
  'shipped',
  'out_for_delivery',
  'delivered',
  'rejected',
  'cancelled',
  'refunded',
]

export const PAYMENT_STATUSES: PaymentStatus[] = ['unpaid', 'pending', 'paid', 'refunded', 'failed']
export const FULFILLMENT_STATUSES: FulfillmentStatus[] = [
  'unfulfilled',
  'processing',
  'shipped',
  'delivered',
  'cancelled',
]

export interface Order {
  id: string
  orderNumber?: string
  customerId: string
  customerName?: string
  customerEmail?: string
  /** Current lines. Verified prices after confirmation. */
  items: OrderItem[]
  /** The customer's original request, kept for verification and diffs. */
  requestedItems?: OrderItem[]
  itemCount?: number
  /** Current totals. Verified after confirmation. */
  subtotal?: number
  shippingFee?: number
  total: number
  requestedSubtotal?: number
  requestedShippingFee?: number
  requestedTotal?: number
  totalsVerified?: boolean
  paymentMethod?: string
  paymentStatus: PaymentStatus | string
  status: OrderStatus | string
  fulfillmentStatus?: FulfillmentStatus | string
  createdAt?: Timestamp | null
  updatedAt?: Timestamp | null
  adminNotes?: string | null
  shippingAddress?: string | null
  customerNote?: string | null
  paymentSimulated?: boolean
  transactionReference?: string | null
  requestReference?: string | null
  timeline: OrderTimelineEvent[]
  cancelReason?: string | null
  rejectionReason?: string | null
  confirmedAt?: Timestamp | null
  confirmedBy?: string | null
  rejectedAt?: Timestamp | null
  rejectedBy?: string | null
  cancelledAt?: Timestamp | null
  cancelledBy?: string | null
  restockPending?: boolean
  restockedAt?: Timestamp | null
  customerTotalsApplied?: boolean
}

export interface OrderTimelineEvent {
  status: string
  title: string
  note?: string
  at?: Timestamp | null
}

export interface Customer {
  id: string
  email?: string
  displayName?: string
  phone?: string
  totalOrders?: number
  totalSpent?: number
  createdAt?: Timestamp | null
  role?: string
}

export interface InventoryLog {
  id?: string
  productId: string
  productName: string
  size: string
  previousQty: number
  newQty: number
  delta: number
  reason: string
  adminUid: string
  adminEmail: string
  createdAt?: Timestamp | null
}

export interface DashboardData {
  products: Product[]
  orders: Order[]
}

export interface ReportRow {
  label: string
  orders: number
  recordedSales: number
  paidSales: number
}

/** Customer <-> store conversation summary at `chats/{customerId}`. */
export interface CustomerChat {
  customerId: string
  customerName: string
  lastMessage: string
  lastSenderRole: string
  unreadByAdmin: number
  unreadByCustomer: number
  lastMessageAt?: Timestamp | null
  updatedAt?: Timestamp | null
}

export interface ChatMessage {
  id: string
  senderId: string
  senderRole: 'customer' | 'admin'
  text: string
  isRead: boolean
  createdAt?: Timestamp | null
}

/** One review per customer per product at `reviews/{productId}_{uid}`. */
export interface ProductReview {
  id: string
  productId: string
  customerId: string
  customerName?: string
  orderId?: string
  rating: number
  text: string
  createdAt?: Timestamp | null
  updatedAt?: Timestamp | null
}

/**
 * Public store announcement at `announcements/{id}`. Active announcements are
 * readable by guests in the mobile app; writes are administrator-only.
 */
export interface Announcement {
  id: string
  title: string
  body: string
  active: boolean
  pinned: boolean
  createdAt?: Timestamp | null
  updatedAt?: Timestamp | null
}

export interface AnnouncementDraft {
  title: string
  body: string
  active: boolean
  pinned: boolean
}

/**
 * Administrator copy of an in-app event at `notifications/{id}`.
 *
 * Mobile and backend writers store administrator notifications with
 * `recipientId: 'admin'`. Customers only ever see notifications addressed to
 * their own UID, so this collection stays administrator-only.
 */
export interface AdminNotification {
  id: string
  recipientId: string
  type: string
  title: string
  body: string
  orderId?: string | null
  chatId?: string | null
  customerId?: string | null
  reviewId?: string | null
  productId?: string | null
  rating?: number | null
  isRead: boolean
  createdAt?: Timestamp | null
  readAt?: Timestamp | null
}
