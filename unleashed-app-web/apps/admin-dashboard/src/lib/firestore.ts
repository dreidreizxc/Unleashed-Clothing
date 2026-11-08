import {
  Bytes,
  arrayUnion,
  collection,
  doc,
  getDoc,
  getDocs,
  increment,
  limit,
  onSnapshot,
  orderBy,
  query,
  runTransaction,
  serverTimestamp,
  startAfter,
  where,
  writeBatch,
  type DocumentData,
  type Firestore,
  type QueryDocumentSnapshot,
  type Transaction,
  type Unsubscribe,
  type WriteBatch,
} from 'firebase/firestore'
import { requireDb } from '../firebase'
import type {
  Announcement,
  AnnouncementDraft,
  ChatMessage,
  Customer,
  CustomerChat,
  FulfillmentStatus,
  InventoryLog,
  Order,
  OrderItem,
  OrderStatus,
  OrderTimelineEvent,
  PaymentStatus,
  Product,
  ProductCategory,
  ProductDraft,
  ProductReview,
  ProductStatus,
} from '../types'
import { FULFILLMENT_STATUSES, ORDER_STATUSES, PAYMENT_STATUSES } from '../types'
import { prepareProductImage, prepareSizeChartImage } from './images'
import { sizeChartDocId, sizeChartDocIdFromUrl, sizeChartRef } from './sizeChart'
import { timestampMillis, totalStockOf } from './format'
import {
  chatReplyNotification,
  customerChatNotificationId,
  customerOrderNotificationId,
  orderRejectedNotification,
  orderStatusNotification,
  orderStatusTimelineEntry,
} from './customerNotifications'

interface Actor {
  uid: string
  email: string | null
}

function mapStock(value: unknown): Record<string, number> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {}
  const result: Record<string, number> = {}
  for (const [size, quantity] of Object.entries(value as Record<string, unknown>)) {
    result[size] = Math.max(0, Math.trunc(Number(quantity) || 0))
  }
  return result
}

function mapProduct(id: string, data: DocumentData): Product {
  const stock = mapStock(data.stock)
  const sizes = Array.isArray(data.sizes)
    ? data.sizes.map((size) => String(size)).filter(Boolean)
    : Object.keys(stock)
  const category: ProductCategory =
    data.category === 'Cap' || data.category === 'Hoodie' ? data.category : 'T-Shirt'
  const status: ProductStatus =
    data.status === 'active' || data.status === 'inactive' || data.status === 'archived'
      ? data.status
      : 'inactive'

  return {
    id,
    name: String(data.name ?? 'Untitled product'),
    description: String(data.description ?? ''),
    price: Math.max(0, Math.trunc(Number(data.price) || 0)),
    priceUnit: String(data.priceUnit ?? 'centavos'),
    currency: String(data.currency ?? 'PHP'),
    category,
    sizes,
    stock,
    totalStock: Number.isFinite(Number(data.totalStock))
      ? Math.max(0, Math.trunc(Number(data.totalStock)))
      : totalStockOf(stock),
    status,
    imageId: data.imageId ? String(data.imageId) : null,
    imageContentType: data.imageContentType ? String(data.imageContentType) : null,
    imageUpdatedAt: data.imageUpdatedAt ?? null,
    imageUrl: data.imageUrl ? String(data.imageUrl) : null,
    sizeChartUrl: data.sizeChartUrl ? String(data.sizeChartUrl) : null,
    sizeChartContentType: data.sizeChartContentType
      ? String(data.sizeChartContentType)
      : null,
    sizeChartUpdatedAt: data.sizeChartUpdatedAt ?? null,
    createdAt: data.createdAt ?? null,
    updatedAt: data.updatedAt ?? null,
    createdBy: data.createdBy ? String(data.createdBy) : null,
    updatedBy: data.updatedBy ? String(data.updatedBy) : null,
  }
}

function mapOrderItem(item: DocumentData): OrderItem {
  return {
    productId: item.productId ? String(item.productId) : undefined,
    name: item.name ? String(item.name) : undefined,
    size: item.size ? String(item.size) : undefined,
    quantity: Math.max(1, Math.trunc(Number(item.quantity) || 1)),
    price: Math.max(0, Math.trunc(Number(item.price) || 0)),
    subtotal: Number.isFinite(Number(item.subtotal))
      ? Math.max(0, Math.trunc(Number(item.subtotal)))
      : undefined,
    imageId: item.imageId ? String(item.imageId) : null,
    category: item.category ? String(item.category) : undefined,
  }
}

function mapOrderItems(raw: unknown): OrderItem[] {
  if (!Array.isArray(raw)) return []
  return raw
    .filter((item: unknown): item is DocumentData => Boolean(item) && typeof item === 'object')
    .map(mapOrderItem)
}

function mapOrder(id: string, data: DocumentData): Order {
  const items = mapOrderItems(data.items)
  const requestedItems = Array.isArray(data.requestedItems)
    ? mapOrderItems(data.requestedItems)
    : undefined

  const timeline: OrderTimelineEvent[] = Array.isArray(data.timeline)
    ? data.timeline
        .filter((entry: unknown): entry is DocumentData => Boolean(entry) && typeof entry === 'object')
        .map((entry: DocumentData) => ({
          status: entry.status ? String(entry.status) : '',
          title: entry.title ? String(entry.title) : 'Order updated',
          note: entry.note ? String(entry.note) : undefined,
          at: entry.at ?? entry.createdAt ?? null,
        }))
    : []

  return {
    id,
    orderNumber: data.orderNumber ? String(data.orderNumber) : undefined,
    customerId: String(data.customerId ?? ''),
    customerName: data.customerName ? String(data.customerName) : undefined,
    customerEmail: data.customerEmail ? String(data.customerEmail) : undefined,
    items,
    requestedItems,
    itemCount: Number.isFinite(Number(data.itemCount))
      ? Math.max(0, Math.trunc(Number(data.itemCount)))
      : items.reduce((sum, item) => sum + (item.quantity ?? 0), 0),
    subtotal: Number.isFinite(Number(data.subtotal))
      ? Math.max(0, Math.trunc(Number(data.subtotal)))
      : undefined,
    shippingFee: Number.isFinite(Number(data.shippingFee))
      ? Math.max(0, Math.trunc(Number(data.shippingFee)))
      : 0,
    total: Math.max(0, Math.trunc(Number(data.total) || 0)),
    requestedSubtotal: Number.isFinite(Number(data.requestedSubtotal))
      ? Math.max(0, Math.trunc(Number(data.requestedSubtotal)))
      : undefined,
    requestedShippingFee: Number.isFinite(Number(data.requestedShippingFee))
      ? Math.max(0, Math.trunc(Number(data.requestedShippingFee)))
      : undefined,
    requestedTotal: Number.isFinite(Number(data.requestedTotal))
      ? Math.max(0, Math.trunc(Number(data.requestedTotal)))
      : undefined,
    totalsVerified: data.totalsVerified === true,
    paymentMethod: data.paymentMethod ? String(data.paymentMethod) : undefined,
    paymentStatus: String(data.paymentStatus ?? 'unpaid'),
    status: String(data.status ?? 'pending_confirmation'),
    fulfillmentStatus: data.fulfillmentStatus ? String(data.fulfillmentStatus) : undefined,
    createdAt: data.createdAt ?? null,
    updatedAt: data.updatedAt ?? null,
    adminNotes: data.adminNotes ? String(data.adminNotes) : null,
    shippingAddress: data.shippingAddress ? String(data.shippingAddress) : null,
    customerNote: data.customerNote ? String(data.customerNote) : null,
    paymentSimulated: data.paymentSimulated === true,
    transactionReference: data.transactionReference ? String(data.transactionReference) : null,
    requestReference: data.requestReference ? String(data.requestReference) : null,
    timeline,
    cancelReason: data.cancelReason ? String(data.cancelReason) : null,
    rejectionReason: data.rejectionReason ? String(data.rejectionReason) : null,
    confirmedAt: data.confirmedAt ?? null,
    confirmedBy: data.confirmedBy ? String(data.confirmedBy) : null,
    rejectedAt: data.rejectedAt ?? null,
    rejectedBy: data.rejectedBy ? String(data.rejectedBy) : null,
    cancelledAt: data.cancelledAt ?? null,
    cancelledBy: data.cancelledBy ? String(data.cancelledBy) : null,
    restockPending: data.restockPending === true,
    restockedAt: data.restockedAt ?? null,
    customerTotalsApplied: data.customerTotalsApplied === true,
  }
}

function mapCustomer(id: string, data: DocumentData): Customer {
  return {
    id,
    email: data.email ? String(data.email) : undefined,
    displayName: data.displayName ? String(data.displayName) : undefined,
    phone: data.phone ? String(data.phone) : undefined,
    totalOrders: Math.max(0, Math.trunc(Number(data.totalOrders) || 0)),
    totalSpent: Math.max(0, Math.trunc(Number(data.totalSpent) || 0)),
    createdAt: data.createdAt ?? null,
    role: data.role ? String(data.role) : undefined,
  }
}

function activityLogData(
  actor: Actor,
  action: string,
  targetType: string,
  targetId: string,
  details: Record<string, unknown> = {},
) {
  return {
    action,
    targetType,
    targetId,
    details,
    adminUid: actor.uid,
    adminEmail: actor.email ?? '',
    createdAt: serverTimestamp(),
  }
}

function logActivity(
  batch: WriteBatch,
  actor: Actor,
  action: string,
  targetType: string,
  targetId: string,
  details: Record<string, unknown> = {},
) {
  const database = requireDb()
  batch.set(
    doc(collection(database, 'admin_activity_logs')),
    activityLogData(actor, action, targetType, targetId, details),
  )
}

export async function fetchProducts(): Promise<Product[]> {
  const database = requireDb()
  const snapshot = await getDocs(query(collection(database, 'products'), limit(500)))
  return snapshot.docs
    .map((entry) => mapProduct(entry.id, entry.data()))
    .sort((a, b) => a.name.localeCompare(b.name))
}

export async function fetchProduct(productId: string): Promise<Product | null> {
  const database = requireDb()
  const snapshot = await getDoc(doc(database, 'products', productId))
  return snapshot.exists() ? mapProduct(snapshot.id, snapshot.data()) : null
}

/** Hard cap for one order listing request, to protect the Spark read quota. */
const MAX_ORDER_PAGE = 100
const MAX_ORDER_ROWS = 400

export interface OrdersPageResult {
  orders: Order[]
  /** Pass this cursor back to fetch the next page. Null when there is no more. */
  cursor: QueryDocumentSnapshot | null
  hasMore: boolean
}

/**
 * Reads one bounded page of orders, newest first. The dashboard never opens an
 * unbounded listener or scans the whole collection: the Spark plan allows
 * roughly 50k reads per day, so every table load has a hard page cap.
 */
export async function fetchOrdersPage(
  options: { pageSize?: number; cursor?: QueryDocumentSnapshot | null } = {},
): Promise<OrdersPageResult> {
  const database = requireDb()
  const pageSize = Math.min(
    MAX_ORDER_PAGE,
    Math.max(1, Math.trunc(options.pageSize ?? 50)),
  )
  const constraints = [orderBy('createdAt', 'desc'), limit(pageSize + 1)] as const
  const ordersQuery = options.cursor
    ? query(collection(database, 'orders'), ...constraints, startAfter(options.cursor))
    : query(collection(database, 'orders'), ...constraints)
  const snapshot = await getDocs(ordersQuery)
  const docs = snapshot.docs.slice(0, pageSize)
  return {
    orders: docs.map((entry) => mapOrder(entry.id, entry.data())),
    cursor: docs.length > 0 ? docs[docs.length - 1] : null,
    hasMore: snapshot.docs.length > pageSize,
  }
}

/**
 * Bounded order read for dashboards and reports. Defaults to the newest 200
 * orders; never returns the whole collection.
 */
export async function fetchOrders(maxRows = 200): Promise<Order[]> {
  const database = requireDb()
  const boundedRows = Math.min(MAX_ORDER_ROWS, Math.max(1, Math.trunc(maxRows)))
  const snapshot = await getDocs(
    query(collection(database, 'orders'), orderBy('createdAt', 'desc'), limit(boundedRows)),
  )
  return snapshot.docs.map((entry) => mapOrder(entry.id, entry.data()))
}

export async function fetchOrder(orderId: string): Promise<Order | null> {
  const database = requireDb()
  const snapshot = await getDoc(doc(database, 'orders', orderId))
  return snapshot.exists() ? mapOrder(snapshot.id, snapshot.data()) : null
}

export async function fetchCustomers(): Promise<Customer[]> {
  const database = requireDb()
  const snapshot = await getDocs(query(collection(database, 'users'), limit(500)))
  return snapshot.docs
    .map((entry) => mapCustomer(entry.id, entry.data()))
    .sort((a, b) => (a.displayName || a.email || '').localeCompare(b.displayName || b.email || ''))
}

export async function fetchInventoryLogs(maxRows = 40): Promise<InventoryLog[]> {
  const database = requireDb()
  const rows = Math.min(200, Math.max(1, Math.trunc(maxRows)))
  const snapshot = await getDocs(
    query(
      collection(database, 'inventory_logs'),
      orderBy('createdAt', 'desc'),
      limit(rows),
    ),
  )
  return snapshot.docs.map((entry) => {
    const data = entry.data()
    return {
      id: entry.id,
      productId: String(data.productId ?? ''),
      productName: String(data.productName ?? ''),
      size: String(data.size ?? ''),
      previousQty: Number(data.previousQty) || 0,
      newQty: Number(data.newQty) || 0,
      delta: Number(data.delta) || 0,
      reason: String(data.reason ?? ''),
      adminUid: String(data.adminUid ?? ''),
      adminEmail: String(data.adminEmail ?? ''),
      createdAt: data.createdAt ?? null,
    }
  })
}

/**
 * A size chart document is only deleted when no other product points at the
 * same reference. The current implementation keeps one chart per product, but
 * this guard makes shared or legacy references safe.
 */
async function isSizeChartReferenced(
  database: Firestore,
  sizeChartUrl: string,
  excludeProductId: string,
): Promise<boolean> {
  const snapshot = await getDocs(
    query(
      collection(database, 'products'),
      where('sizeChartUrl', '==', sizeChartUrl),
      limit(2),
    ),
  )
  return snapshot.docs.some((entry) => entry.id !== excludeProductId)
}

export interface SaveProductInput {
  id?: string
  draft: ProductDraft
  existing?: Product | null
  imageFile?: File | null
  removeImage?: boolean
  sizeChartFile?: File | null
  removeSizeChart?: boolean
  actor: Actor
  onStage?: (stage: 'optimizing' | 'saving') => void
}

export async function saveProduct(input: SaveProductInput): Promise<string> {
  const database = requireDb()
  const { id, draft, existing, imageFile, removeImage = false, sizeChartFile, removeSizeChart = false, actor, onStage } = input

  if (!draft.name.trim()) throw new Error('Product name is required.')
  if (!Number.isFinite(draft.price) || draft.price < 0) throw new Error('Price must be zero or greater.')
  if (draft.sizes.length === 0) throw new Error('Choose at least one available size.')
  for (const size of draft.sizes) {
    const quantity = draft.stock[size] ?? 0
    if (!Number.isInteger(quantity) || quantity < 0) {
      throw new Error(`Stock for ${size} must be a whole number zero or greater.`)
    }
  }

  const productRef = id
    ? doc(database, 'products', id)
    : doc(collection(database, 'products'))
  const productId = productRef.id
  const isCreate = !id

  let preparedImage: Awaited<ReturnType<typeof prepareProductImage>> | null = null
  if (imageFile) {
    onStage?.('optimizing')
    preparedImage = await prepareProductImage(imageFile)
  }

  let preparedSizeChart: Awaited<ReturnType<typeof prepareSizeChartImage>> | null = null
  if (sizeChartFile) {
    onStage?.('optimizing')
    preparedSizeChart = await prepareSizeChartImage(sizeChartFile)
  }

  onStage?.('saving')
  const batch = writeBatch(database)
  const now = serverTimestamp()

  const productData: Record<string, unknown> = {
    name: draft.name.trim(),
    description: draft.description.trim(),
    price: Math.round(draft.price),
    priceUnit: 'centavos',
    currency: 'PHP',
    category: draft.category,
    sizes: draft.sizes,
    stock: draft.stock,
    totalStock: totalStockOf(draft.stock),
    status: draft.status,
    updatedAt: now,
    updatedBy: actor.uid,
  }

  if (isCreate) {
    productData.createdAt = now
    productData.createdBy = actor.uid
    productData.imageId = null
    productData.imageContentType = null
    productData.imageUpdatedAt = null
    productData.sizeChartUrl = null
    productData.sizeChartContentType = null
    productData.sizeChartUpdatedAt = null
  }

  if (preparedImage) {
    const imageBytes = new Uint8Array(await preparedImage.blob.arrayBuffer())
    productData.imageId = productId
    productData.imageContentType = preparedImage.contentType
    productData.imageUpdatedAt = now
    batch.set(doc(database, 'product_images', productId), {
      bytes: Bytes.fromUint8Array(imageBytes),
      contentType: preparedImage.contentType,
      width: preparedImage.width,
      height: preparedImage.height,
      size: preparedImage.size,
      updatedAt: now,
      updatedBy: actor.uid,
    })
  } else if (removeImage && existing?.imageId) {
    productData.imageId = null
    productData.imageContentType = null
    productData.imageUpdatedAt = now
    batch.delete(doc(database, 'product_images', existing.imageId))
  }

  if (preparedSizeChart) {
    const chartDocId = sizeChartDocId(productId)
    const chartBytes = new Uint8Array(await preparedSizeChart.blob.arrayBuffer())

    productData.sizeChartUrl = sizeChartRef(productId)
    productData.sizeChartContentType = preparedSizeChart.contentType
    productData.sizeChartUpdatedAt = now

    batch.set(doc(database, 'product_images', chartDocId), {
      kind: 'size_chart',
      productId,
      bytes: Bytes.fromUint8Array(chartBytes),
      contentType: preparedSizeChart.contentType,
      width: preparedSizeChart.width,
      height: preparedSizeChart.height,
      size: preparedSizeChart.size,
      updatedAt: now,
      updatedBy: actor.uid,
    })

    const previousUrl = existing?.sizeChartUrl
    const previousDocId = sizeChartDocIdFromUrl(previousUrl)

    if (
      previousDocId &&
      previousDocId !== chartDocId &&
      previousUrl &&
      !(await isSizeChartReferenced(database, previousUrl, productId))
    ) {
      batch.delete(doc(database, 'product_images', previousDocId))
    }
  } else if (removeSizeChart && existing?.sizeChartUrl) {
    productData.sizeChartUrl = null
    productData.sizeChartContentType = null
    productData.sizeChartUpdatedAt = now

    const previousDocId = sizeChartDocIdFromUrl(existing.sizeChartUrl)

    if (
      previousDocId &&
      !(await isSizeChartReferenced(database, existing.sizeChartUrl, productId))
    ) {
      batch.delete(doc(database, 'product_images', previousDocId))
    }
  }

  if (isCreate) {
    batch.set(productRef, productData)
  } else {
    batch.set(productRef, productData, { merge: true })
  }

  logActivity(
    batch,
    actor,
    isCreate ? 'product_created' : 'product_updated',
    'product',
    productId,
    { name: draft.name.trim(), imageChanged: Boolean(preparedImage || (removeImage && existing?.imageId)), sizeChartChanged: Boolean(preparedSizeChart || (removeSizeChart && existing?.sizeChartUrl)) },
  )

  await batch.commit()
  return productId
}

export async function deleteProduct(product: Product, actor: Actor): Promise<void> {
  const database = requireDb()
  const batch = writeBatch(database)
  batch.delete(doc(database, 'products', product.id))
  if (product.imageId) {
    batch.delete(doc(database, 'product_images', product.imageId))
  }

  if (product.sizeChartUrl) {
    const chartDocId = sizeChartDocIdFromUrl(product.sizeChartUrl)

    if (
      chartDocId &&
      !(await isSizeChartReferenced(database, product.sizeChartUrl, product.id))
    ) {
      batch.delete(doc(database, 'product_images', chartDocId))
    }
  }

  logActivity(batch, actor, 'product_deleted', 'product', product.id, { name: product.name })
  await batch.commit()
}

export interface StockAdjustment {
  product: Product
  size: string
  newQty: number
  reason: string
  actor: Actor
}

export async function adjustStock(input: StockAdjustment): Promise<number> {
  const database = requireDb()
  const { product, size, newQty, reason, actor } = input

  if (!Number.isInteger(newQty) || newQty < 0) {
    throw new Error('Stock must be a whole number zero or greater.')
  }
  if (!product.sizes.includes(size)) {
    throw new Error('That size is not configured for this product.')
  }

  return runTransaction(database, async (transaction) => {
    const productRef = doc(database, 'products', product.id)
    const snapshot = await transaction.get(productRef)
    if (!snapshot.exists()) throw new Error('This product no longer exists.')

    const data = snapshot.data()
    const currentStock = mapStock(data.stock)
    const previousQty = currentStock[size] ?? 0
    if (previousQty === newQty) return newQty

    const nextStock = { ...currentStock, [size]: newQty }
    transaction.update(productRef, {
      stock: nextStock,
      totalStock: totalStockOf(nextStock),
      updatedAt: serverTimestamp(),
      updatedBy: actor.uid,
    })

    transaction.set(doc(collection(database, 'inventory_logs')), {
      productId: product.id,
      productName: String(data.name ?? product.name),
      size,
      previousQty,
      newQty,
      delta: newQty - previousQty,
      reason: reason.trim() || 'Manual adjustment',
      adminUid: actor.uid,
      adminEmail: actor.email ?? '',
      createdAt: serverTimestamp(),
    })

    return newQty
  })
}

export interface ConfirmOrderInput {
  orderId: string
  actor: Actor
  /** Overrides the shipping fee the customer requested (integer centavos). */
  shippingFee?: number
  note?: string
}

export interface ConfirmOrderResult {
  orderNumber: string
  total: number
  itemCount: number
}

/**
 * Confirms a pending order request. This is the only path that:
 * * verifies current catalogue prices and per-size stock;
 * * assigns the official `UND-######` order number from `counters/orders`;
 * * deducts stock and writes an inventory log per product size;
 * * replaces the requested totals with verified totals;
 * * counts the order against the customer's totals and notifies them.
 *
 * All reads happen before any write because Firestore transactions require
 * that ordering. If any line has insufficient stock nothing is changed, so
 * two administrators cannot confirm the same stock twice.
 */
export async function confirmOrderRequest(input: ConfirmOrderInput): Promise<ConfirmOrderResult> {
  const database = requireDb()
  const orderRef = doc(database, 'orders', input.orderId)
  const counterRef = doc(database, 'counters', 'orders')

  return runTransaction(database, async (transaction) => {
    const orderSnapshot = await transaction.get(orderRef)
    if (!orderSnapshot.exists) throw new Error('This order no longer exists.')
    const current = mapOrder(orderSnapshot.id, orderSnapshot.data() ?? {})
    if (current.status !== 'pending_confirmation') {
      throw new Error('Only a pending request can be confirmed.')
    }

    const requested = current.requestedItems?.length ? current.requestedItems : current.items
    if (requested.length === 0) {
      throw new Error('This request has no line items to confirm.')
    }

    const productIds = Array.from(
      new Set(
        requested
          .map((item) => item.productId)
          .filter((productId): productId is string => Boolean(productId)),
      ),
    )
    if (productIds.length === 0) {
      throw new Error('This request has no product references to verify.')
    }

    const products = new Map<string, DocumentData>()
    for (const productId of productIds) {
      const productSnapshot = await transaction.get(doc(database, 'products', productId))
      if (!productSnapshot.exists()) {
        throw new Error('A product in this request no longer exists. Reject the request instead.')
      }
      products.set(productId, productSnapshot.data() ?? {})
    }

    const counterSnapshot = await transaction.get(counterRef)

    const stockPlans = new Map<
      string,
      { data: DocumentData; stock: Record<string, number>; deducted: Map<string, number> }
    >()
    const verifiedItems: OrderItem[] = []
    let subtotal = 0
    let quantity = 0

    for (const line of requested) {
      const productId = line.productId
      const size = line.size
      const lineQuantity = Math.max(1, Math.trunc(Number(line.quantity) || 0))
      if (!productId || !size) {
        throw new Error('A requested line is missing its product or size.')
      }
      const product = products.get(productId)
      if (!product) throw new Error('A product in this request no longer exists.')

      const price = Number(product.price)
      if (!Number.isInteger(price) || price < 0) {
        throw new Error('A current product price is invalid. Fix it in the catalog first.')
      }

      const plan =
        stockPlans.get(productId) ??
        { data: product, stock: mapStock(product.stock), deducted: new Map<string, number>() }
      const available = plan.stock[size] ?? 0
      const alreadyDeducted = plan.deducted.get(size) ?? 0
      if (available - alreadyDeducted < lineQuantity) {
        const remaining = Math.max(0, available - alreadyDeducted)
        throw new Error(
          remaining <= 0
            ? `${String(product.name ?? 'An item')} (${size}) is out of stock.`
            : `Only ${remaining} of ${String(product.name ?? 'an item')} (${size}) remain.`,
        )
      }
      plan.deducted.set(size, alreadyDeducted + lineQuantity)
      stockPlans.set(productId, plan)

      const lineTotal = price * lineQuantity
      subtotal += lineTotal
      quantity += lineQuantity
      verifiedItems.push({
        productId,
        name: String(product.name ?? line.name ?? 'Product'),
        size,
        price,
        quantity: lineQuantity,
        subtotal: lineTotal,
        imageId: product.imageId ? String(product.imageId) : null,
        category: product.category ? String(product.category) : undefined,
      })
    }

    const requestedShippingFee = Math.max(
      0,
      Math.trunc(Number(current.requestedShippingFee ?? current.shippingFee ?? 0) || 0),
    )
    const shippingFee =
      input.shippingFee === undefined
        ? requestedShippingFee
        : Math.max(0, Math.trunc(input.shippingFee))
    if (!Number.isInteger(shippingFee) || shippingFee < 0) {
      throw new Error('The shipping fee must be a whole number of centavos, zero or greater.')
    }
    const total = subtotal + shippingFee

    const lastNumber = Math.max(0, Math.trunc(Number(counterSnapshot.data()?.lastNumber) || 0))
    const nextNumber = lastNumber + 1
    const orderNumber = `UND-${String(nextNumber).padStart(6, '0')}`
    const confirmedOrder: Order = {
      ...current,
      orderNumber,
      status: 'confirmed',
      items: verifiedItems,
      itemCount: quantity,
      subtotal,
      shippingFee,
      total,
      totalsVerified: true,
      customerTotalsApplied: true,
      paymentStatus: 'unpaid',
    }

    for (const [productId, plan] of stockPlans) {
      const nextStock = { ...plan.stock }
      for (const [size, deducted] of plan.deducted) {
        const previousQty = nextStock[size] ?? 0
        const newQty = Math.max(0, previousQty - deducted)
        nextStock[size] = newQty
        transaction.set(doc(collection(database, 'inventory_logs')), {
          productId,
          productName: String(plan.data.name ?? ''),
          size,
          previousQty,
          newQty,
          delta: newQty - previousQty,
          reason: `Order ${orderNumber} confirmed`,
          orderId: current.id,
          adminUid: input.actor.uid,
          adminEmail: input.actor.email ?? '',
          createdAt: serverTimestamp(),
        })
      }
      transaction.update(doc(database, 'products', productId), {
        stock: nextStock,
        totalStock: totalStockOf(nextStock),
        updatedAt: serverTimestamp(),
        updatedBy: input.actor.uid,
      })
    }

    transaction.set(counterRef, { lastNumber: nextNumber }, { merge: true })
    transaction.update(orderRef, {
      orderNumber,
      items: verifiedItems,
      itemCount: quantity,
      subtotal,
      shippingFee,
      total,
      totalsVerified: true,
      customerTotalsApplied: true,
      status: 'confirmed',
      paymentStatus: 'unpaid',
      confirmedAt: serverTimestamp(),
      confirmedBy: input.actor.uid,
      timeline: arrayUnion(
        orderStatusTimelineEntry('confirmed', input.note?.trim() || undefined),
      ),
      updatedAt: serverTimestamp(),
    })

    if (current.customerId) {
      transaction.set(
        doc(database, 'users', current.customerId),
        {
          totalOrders: increment(1),
          totalSpent: increment(total),
          updatedAt: serverTimestamp(),
        },
        { merge: true },
      )
      transaction.set(
        doc(database, 'notifications', customerOrderNotificationId(current.id, 'confirmed')),
        orderStatusNotification(confirmedOrder, 'confirmed'),
      )
    }

    transaction.set(
      doc(collection(database, 'admin_activity_logs')),
      activityLogData(input.actor, 'order_confirmed', 'order', current.id, {
        orderNumber,
        requestedTotal: current.requestedTotal ?? current.total,
        verifiedTotal: total,
        itemCount: quantity,
      }),
    )

    return { orderNumber, total, itemCount: quantity }
  })
}

export interface RejectOrderInput {
  orderId: string
  reason: string
  actor: Actor
}

/**
 * Rejects a pending request. No stock is deducted and no counter is consumed;
 * the customer receives a deterministic notification with the reason.
 */
export async function rejectOrderRequest(input: RejectOrderInput): Promise<void> {
  const reason = input.reason.trim()
  if (!reason) throw new Error('Give the customer a reason for rejecting this request.')
  if (reason.length > 500) throw new Error('Rejection reasons must be 500 characters or fewer.')

  const database = requireDb()
  const orderRef = doc(database, 'orders', input.orderId)

  await runTransaction(database, async (transaction) => {
    const snapshot = await transaction.get(orderRef)
    if (!snapshot.exists) throw new Error('This order no longer exists.')
    const current = mapOrder(snapshot.id, snapshot.data() ?? {})
    if (current.status !== 'pending_confirmation') {
      throw new Error('Only a pending request can be rejected.')
    }

    transaction.update(orderRef, {
      status: 'rejected',
      rejectionReason: reason,
      rejectedAt: serverTimestamp(),
      rejectedBy: input.actor.uid,
      restockPending: false,
      timeline: arrayUnion(orderStatusTimelineEntry('rejected', reason)),
      updatedAt: serverTimestamp(),
    })

    if (current.customerId) {
      transaction.set(
        doc(database, 'notifications', customerOrderNotificationId(current.id, 'rejected')),
        orderRejectedNotification({ ...current, status: 'rejected', rejectionReason: reason }, reason),
      )
    }

    transaction.set(
      doc(collection(database, 'admin_activity_logs')),
      activityLogData(input.actor, 'order_rejected', 'order', current.id, {
        reason,
        requestedTotal: current.requestedTotal ?? current.total,
      }),
    )
  })
}

export interface OrderChanges {
  status?: OrderStatus
  paymentStatus?: PaymentStatus
  fulfillmentStatus?: FulfillmentStatus
  adminNotes?: string
  cancelReason?: string
  /** Explicitly restore stock for an order that was cancelled by the customer. */
  restock?: boolean
}

/**
 * Restores every line item's quantity to product stock and writes an audit row
 * for each size. All product reads happen before any write because Firestore
 * transactions require that ordering.
 */
async function restoreOrderStock(
  transaction: Transaction,
  order: Order,
  actor: Actor,
  reason: string,
): Promise<void> {
  const database = requireDb()
  const additions = new Map<string, Map<string, number>>()

  for (const item of order.items) {
    const productId = item.productId
    const size = item.size
    const quantity = Number(item.quantity) || 0
    if (!productId || !size || quantity <= 0) continue
    const sizes = additions.get(productId) ?? new Map<string, number>()
    sizes.set(size, (sizes.get(size) ?? 0) + quantity)
    additions.set(productId, sizes)
  }

  if (additions.size === 0) return

  const products = new Map<string, DocumentData | null>()
  for (const productId of additions.keys()) {
    const snapshot = await transaction.get(doc(database, 'products', productId))
    products.set(productId, snapshot.exists() ? (snapshot.data() ?? null) : null)
  }

  for (const [productId, sizes] of additions) {
    const product = products.get(productId)
    if (!product) continue

    const stock: Record<string, number> = mapStock(product.stock)

    for (const [size, quantity] of sizes) {
      const previousQty = stock[size] ?? 0
      const newQty = previousQty + quantity
      stock[size] = newQty

      transaction.set(doc(collection(database, 'inventory_logs')), {
        productId,
        productName: String(product.name ?? ''),
        size,
        previousQty,
        newQty,
        delta: quantity,
        reason,
        adminUid: actor.uid,
        adminEmail: actor.email ?? '',
        createdAt: serverTimestamp(),
      })
    }

    transaction.update(doc(database, 'products', productId), {
      stock,
      totalStock: totalStockOf(stock),
      updatedAt: serverTimestamp(),
      updatedBy: actor.uid,
    })
  }
}

export async function updateOrder(
  order: Order,
  changes: OrderChanges,
  actor: Actor,
): Promise<void> {
  if (changes.status !== undefined && !ORDER_STATUSES.includes(changes.status)) {
    throw new Error('Invalid order status.')
  }
  if (
    changes.paymentStatus !== undefined &&
    !PAYMENT_STATUSES.includes(changes.paymentStatus)
  ) {
    throw new Error('Invalid payment status.')
  }
  if (
    changes.fulfillmentStatus !== undefined &&
    !FULFILLMENT_STATUSES.includes(changes.fulfillmentStatus)
  ) {
    throw new Error('Invalid fulfillment status.')
  }

  const database = requireDb()
  const orderRef = doc(database, 'orders', order.id)

  await runTransaction(database, async (transaction) => {
    const snapshot = await transaction.get(orderRef)
    if (!snapshot.exists()) throw new Error('This order no longer exists.')
    const current = mapOrder(snapshot.id, snapshot.data() ?? {})

    const update: Record<string, unknown> = {}
    const changingStatus = changes.status !== undefined && changes.status !== current.status
    const movingToCancelled = changingStatus && changes.status === 'cancelled'
    const explicitRestock = changes.restock === true
    // Only orders confirmed by the trusted admin flow ever had stock deducted.
    // Pending requests and rejected requests must never add stock on cancel.
    const stockDeducted =
      current.totalsVerified === true || current.customerTotalsApplied === true

    if (current.status === 'pending_confirmation') {
      const changesReviewFields =
        changingStatus ||
        (changes.paymentStatus !== undefined &&
          changes.paymentStatus !== current.paymentStatus) ||
        (changes.fulfillmentStatus !== undefined &&
          changes.fulfillmentStatus !== current.fulfillmentStatus) ||
        explicitRestock
      if (changesReviewFields) {
        throw new Error(
          'Review the pending request with Confirm or Reject. Status, payment and stock cannot be changed before then.',
        )
      }
    }

    if (
      changingStatus &&
      (changes.status === 'confirmed' || changes.status === 'rejected')
    ) {
      throw new Error('Use the request review actions to confirm or reject a pending request.')
    }
    if (changingStatus && changes.status === 'pending_confirmation') {
      throw new Error('An order cannot be moved back to pending confirmation.')
    }
    if (
      changingStatus &&
      ['cancelled', 'rejected', 'refunded'].includes(current.status) &&
      changes.status !== current.status
    ) {
      throw new Error('This order is closed and cannot be reopened.')
    }

    if (explicitRestock && current.status !== 'cancelled') {
      throw new Error('Only cancelled orders can be restocked.')
    }
    if (explicitRestock && !stockDeducted) {
      throw new Error('No stock was deducted for this request, so there is nothing to restore.')
    }
    if (explicitRestock && current.restockedAt) {
      throw new Error('Stock has already been restored for this order.')
    }

    // Restock only on a real transition into `cancelled`, or when the
    // administrator explicitly resolves a customer cancellation. Pending
    // requests never deducted stock, and an already restocked order is never
    // restored twice.
    const needsRestock =
      (movingToCancelled && current.status !== 'cancelled') || explicitRestock
    const canRestock = needsRestock && stockDeducted && !current.restockedAt

    const cancelReason =
      changes.cancelReason?.trim() ||
      current.cancelReason ||
      (movingToCancelled ? 'Cancelled by the store.' : null)

    if (changes.status !== undefined) update.status = changes.status
    if (changes.paymentStatus !== undefined) update.paymentStatus = changes.paymentStatus
    if (changes.fulfillmentStatus !== undefined) {
      update.fulfillmentStatus = changes.fulfillmentStatus
    }
    if (changes.adminNotes !== undefined) update.adminNotes = changes.adminNotes.trim()
    if (changes.cancelReason !== undefined || movingToCancelled) {
      update.cancelReason = cancelReason
    }

    if (Object.keys(update).length === 0 && !canRestock) {
      throw new Error('Choose at least one status to update.')
    }

    if (canRestock) {
      await restoreOrderStock(
        transaction,
        current,
        actor,
        `Order ${current.orderNumber || current.id} ${
          movingToCancelled ? 'cancelled' : 'restocked'
        }`,
      )
      update.restockPending = false
      update.restockedAt = serverTimestamp()

      // Only reverse totals that were actually counted (trusted checkout).
      // Client-created requests never touch these counters, so cancelling them
      // must not push the customer's totals negative.
      if (current.customerTotalsApplied && current.customerId) {
        transaction.set(
          doc(database, 'users', current.customerId),
          {
            totalOrders: increment(-1),
            totalSpent: increment(-Math.max(0, current.total)),
            updatedAt: serverTimestamp(),
          },
          { merge: true },
        )
        update.customerTotalsApplied = false
      }
    }

    if (movingToCancelled) {
      // Keep the fulfilment state consistent with the cancelled order.
      update.fulfillmentStatus = 'cancelled'
      update.cancelledAt = serverTimestamp()
      update.cancelledBy = actor.uid
      update.restockPending = stockDeducted && !canRestock && !current.restockedAt
    }

    if (changingStatus && changes.status) {
      update.timeline = arrayUnion(
        orderStatusTimelineEntry(
          changes.status,
          movingToCancelled ? cancelReason ?? undefined : undefined,
        ),
      )

      if (current.customerId) {
        transaction.set(
          doc(database, 'notifications', customerOrderNotificationId(current.id, changes.status)),
          orderStatusNotification(
            {
              ...current,
              status: changes.status,
              cancelReason: movingToCancelled ? cancelReason : current.cancelReason,
            },
            changes.status,
          ),
        )
      }
    }

    update.updatedAt = serverTimestamp()
    transaction.update(orderRef, update)

    transaction.set(
      doc(collection(database, 'admin_activity_logs')),
      activityLogData(actor, 'order_status_updated', 'order', current.id, {
        from: {
          status: current.status,
          paymentStatus: current.paymentStatus,
          fulfillmentStatus: current.fulfillmentStatus,
        },
       to: Object.fromEntries(
  Object.entries(changes).filter(([, value]) => value !== undefined),
),
        restocked: canRestock,
      }),
    )
  })
}

/**
 * Resolves a customer cancellation that did not restore stock automatically.
 * Restores stock, writes inventory logs, and reverses the customer's order
 * totals when confirmation had counted them.
 */
export async function restockCancelledOrder(
  orderId: string,
  actor: Actor,
): Promise<void> {
  const database = requireDb()
  const orderRef = doc(database, 'orders', orderId)

  await runTransaction(database, async (transaction) => {
    const snapshot = await transaction.get(orderRef)
    if (!snapshot.exists()) throw new Error('This order no longer exists.')
    const current = mapOrder(snapshot.id, snapshot.data() ?? {})

    if (current.status !== 'cancelled') {
      throw new Error('Only cancelled orders can be restocked.')
    }
    if (current.restockedAt) {
      throw new Error('Stock has already been restored for this order.')
    }
    // Pending requests never reserved or deducted stock. Restoring them would
    // create inventory out of thin air.
    if (current.totalsVerified !== true && current.customerTotalsApplied !== true) {
      throw new Error('No stock was deducted for this request, so there is nothing to restore.')
    }

    await restoreOrderStock(
      transaction,
      current,
      actor,
      `Order ${current.orderNumber || current.id} restocked`,
    )

    const update: Record<string, unknown> = {
      restockPending: false,
      restockedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }

    if (current.customerTotalsApplied && current.customerId) {
      transaction.set(
        doc(database, 'users', current.customerId),
        {
          totalOrders: increment(-1),
          totalSpent: increment(-Math.max(0, current.total)),
          updatedAt: serverTimestamp(),
        },
        { merge: true },
      )
      update.customerTotalsApplied = false
    }

    transaction.update(orderRef, update)

    transaction.set(
      doc(collection(database, 'admin_activity_logs')),
      activityLogData(actor, 'order_restocked', 'order', current.id, {
        previousStatus: current.status,
      }),
    )
  })
}

/**
 * Subscribes to one order document. The admin detail page uses this to reflect
 * customer cancellations and status changes without a manual refresh.
 */
export function watchOrder(
  orderId: string,
  onChange: (order: Order | null) => void,
  onError?: (error: Error) => void,
): Unsubscribe {
  const database = requireDb()
  return onSnapshot(
    doc(database, 'orders', orderId),
    (snapshot) => {
      const nextOrder = snapshot.exists()
        ? mapOrder(snapshot.id, snapshot.data())
        : null

      console.log('Order snapshot:', {
        status: nextOrder?.status,
        fromCache: snapshot.metadata.fromCache,
        hasPendingWrites: snapshot.metadata.hasPendingWrites,
      })

      onChange(nextOrder)
    },
    (error) => {
      onError?.(error instanceof Error ? error : new Error('Could not watch this order.'))
    },
  )
}

export async function fetchDashboardData(): Promise<{ products: Product[]; orders: Order[] }> {
  const [products, orders] = await Promise.all([fetchProducts(), fetchOrders()])
  return { products, orders }
}

// ---------------------------------------------------------------------------
// Customer messaging
// ---------------------------------------------------------------------------

function mapChat(id: string, data: DocumentData): CustomerChat {
  return {
    customerId: String(data.customerId ?? id),
    customerName: String(data.customerName ?? 'Customer'),
    lastMessage: String(data.lastMessage ?? ''),
    lastSenderRole: String(data.lastSenderRole ?? 'customer'),
    unreadByAdmin: Math.max(0, Math.trunc(Number(data.unreadByAdmin) || 0)),
    unreadByCustomer: Math.max(0, Math.trunc(Number(data.unreadByCustomer) || 0)),
    lastMessageAt: data.lastMessageAt ?? null,
    updatedAt: data.updatedAt ?? null,
  }
}

function mapChatMessage(id: string, data: DocumentData): ChatMessage {
  return {
    id,
    senderId: String(data.senderId ?? ''),
    senderRole: data.senderRole === 'admin' ? 'admin' : 'customer',
    text: String(data.text ?? ''),
    isRead: data.isRead === true,
    createdAt: data.createdAt ?? null,
  }
}

export async function fetchChats(): Promise<CustomerChat[]> {
  const database = requireDb()
  const snapshot = await getDocs(
    query(
      collection(database, 'chats'),
      orderBy('lastMessageAt', 'desc'),
      limit(100),
    ),
  )
  return snapshot.docs.map((entry) => mapChat(entry.id, entry.data()))
}

export async function fetchChatMessages(customerId: string): Promise<ChatMessage[]> {
  const database = requireDb()
  const snapshot = await getDocs(
    query(
      collection(database, 'chats', customerId, 'messages'),
      orderBy('createdAt', 'desc'),
      limit(200),
    ),
  )
  return snapshot.docs
    .map((entry) => mapChatMessage(entry.id, entry.data()))
    .sort((a, b) => (timestampMillis(a.createdAt) ?? 0) - (timestampMillis(b.createdAt) ?? 0))
}

export async function markChatReadByAdmin(customerId: string): Promise<void> {
  const database = requireDb()
  const messages = await getDocs(
    query(
      collection(database, 'chats', customerId, 'messages'),
      orderBy('createdAt', 'desc'),
      limit(500),
    ),
  )
  const unread = messages.docs.filter((entry) => {
    const data = entry.data()
    return data.senderRole === 'customer' && data.isRead !== true
  })
  if (unread.length === 0) return
  const batch = writeBatch(database)
  for (const entry of unread) {
    batch.update(entry.ref, { isRead: true })
  }
  batch.update(doc(database, 'chats', customerId), {
    unreadByAdmin: 0,
    updatedAt: serverTimestamp(),
  })
  await batch.commit()
}

export async function sendAdminReply(input: {
  customerId: string
  text: string
  actor: Actor
}): Promise<void> {
  const database = requireDb()
  const { customerId, actor } = input
  const text = input.text.trim()
  if (!customerId) throw new Error('Choose a customer conversation first.')
  if (!text) throw new Error('Type a reply before sending.')
  if (text.length > 2000) throw new Error('Replies must be 2,000 characters or fewer.')

  const chatRef = doc(database, 'chats', customerId)
  await runTransaction(database, async (transaction) => {
    const chatSnapshot = await transaction.get(chatRef)
    const chatData = chatSnapshot.data() ?? {}
    const messageRef = doc(collection(database, 'chats', customerId, 'messages'))
    transaction.set(messageRef, {
      senderId: actor.uid,
      senderRole: 'admin',
      text,
      isRead: false,
      createdAt: serverTimestamp(),
    })
    transaction.set(
      chatRef,
      {
        customerId,
        customerName: String(chatData.customerName ?? 'Customer'),
        lastMessage: text,
        lastMessageAt: serverTimestamp(),
        lastSenderRole: 'admin',
        unreadByAdmin: 0,
        unreadByCustomer: Math.max(0, Math.trunc(Number(chatData.unreadByCustomer) || 0)) + 1,
        createdAt: chatData.createdAt ?? serverTimestamp(),
        updatedAt: serverTimestamp(),
      },
      { merge: true },
    )

    // The customer is alerted in the same transaction as the reply. If either
    // write fails, neither is committed. The deterministic id prevents
    // duplicate alerts on retries.
    transaction.set(
      doc(database, 'notifications', customerChatNotificationId(messageRef.id)),
      chatReplyNotification(customerId, messageRef.id, text),
    )

    transaction.set(doc(collection(database, 'admin_activity_logs')), {
      action: 'admin_reply_sent',
      targetType: 'chat',
      targetId: customerId,
      details: { preview: text.slice(0, 120) },
      adminUid: actor.uid,
      adminEmail: actor.email ?? '',
      createdAt: serverTimestamp(),
    })
  })
}

// ---------------------------------------------------------------------------
// Product reviews
// ---------------------------------------------------------------------------

function mapReview(id: string, data: DocumentData): ProductReview {
  return {
    id,
    productId: String(data.productId ?? ''),
    customerId: String(data.customerId ?? ''),
    customerName: data.customerName ? String(data.customerName) : undefined,
    orderId: data.orderId ? String(data.orderId) : undefined,
    rating: Math.min(5, Math.max(0, Math.trunc(Number(data.rating) || 0))),
    text: String(data.text ?? ''),
    createdAt: data.createdAt ?? null,
    updatedAt: data.updatedAt ?? null,
  }
}

export async function fetchReviews(): Promise<ProductReview[]> {
  const database = requireDb()
  const snapshot = await getDocs(
    query(collection(database, 'reviews'), orderBy('createdAt', 'desc'), limit(300)),
  )
  return snapshot.docs.map((entry) => mapReview(entry.id, entry.data()))
}

export async function deleteReview(review: ProductReview, actor: Actor): Promise<void> {
  const database = requireDb()
  const batch = writeBatch(database)
  batch.delete(doc(database, 'reviews', review.id))
  logActivity(batch, actor, 'review_deleted', 'review', review.id, {
    productId: review.productId,
    customerId: review.customerId,
    rating: review.rating,
  })
  await batch.commit()
}

// ---------------------------------------------------------------------------
// Public store announcements
// ---------------------------------------------------------------------------

function mapAnnouncement(id: string, data: DocumentData): Announcement {
  return {
    id,
    title: String(data.title ?? '').trim(),
    body: String(data.body ?? data.message ?? '').trim(),
    active: data.active !== false,
    pinned: data.pinned === true,
    createdAt: data.createdAt ?? null,
    updatedAt: data.updatedAt ?? null,
  }
}

export async function fetchAnnouncements(): Promise<Announcement[]> {
  const database = requireDb()
  const snapshot = await getDocs(query(collection(database, 'announcements'), limit(200)))
  return snapshot.docs
    .map((entry) => mapAnnouncement(entry.id, entry.data()))
    .sort((a, b) => {
      if (a.pinned !== b.pinned) return a.pinned ? -1 : 1
      return (timestampMillis(b.createdAt) ?? 0) - (timestampMillis(a.createdAt) ?? 0)
    })
}

export interface SaveAnnouncementInput {
  id?: string
  draft: AnnouncementDraft
  actor: Actor
}

export async function saveAnnouncement(input: SaveAnnouncementInput): Promise<string> {
  const database = requireDb()
  const { id, draft, actor } = input
  const title = draft.title.trim()
  const body = draft.body.trim()

  if (!title) throw new Error('Announcement title is required.')
  if (title.length > 120) throw new Error('Titles must be 120 characters or fewer.')
  if (!body) throw new Error('Announcement message is required.')
  if (body.length > 1000) throw new Error('Messages must be 1,000 characters or fewer.')

  const announcementRef = id
    ? doc(database, 'announcements', id)
    : doc(collection(database, 'announcements'))
  const isCreate = !id
  const now = serverTimestamp()

  const data: Record<string, unknown> = {
    title,
    body,
    active: draft.active,
    pinned: draft.pinned,
    updatedAt: now,
    updatedBy: actor.uid,
  }
  if (isCreate) {
    data.createdAt = now
    data.createdBy = actor.uid
  }

  const batch = writeBatch(database)
  if (isCreate) {
    batch.set(announcementRef, data)
  } else {
    batch.set(announcementRef, data, { merge: true })
  }
  logActivity(
    batch,
    actor,
    isCreate ? 'announcement_created' : 'announcement_updated',
    'announcement',
    announcementRef.id,
    { title, active: draft.active, pinned: draft.pinned },
  )
  await batch.commit()
  return announcementRef.id
}

export async function deleteAnnouncement(announcement: Announcement, actor: Actor): Promise<void> {
  const database = requireDb()
  const batch = writeBatch(database)
  batch.delete(doc(database, 'announcements', announcement.id))
  logActivity(batch, actor, 'announcement_deleted', 'announcement', announcement.id, {
    title: announcement.title,
  })
  await batch.commit()
}
