import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import {
  confirmOrderRequest,
  fetchOrder,
  fetchProducts,
  rejectOrderRequest,
  restockCancelledOrder,
  updateOrder,
  watchOrder,
} from '../lib/firestore'
import { useAuth } from '../lib/AuthProvider'
import { formatCurrency, formatDateTime, orderLabel, titleCase } from '../lib/format'
import type {
  FulfillmentStatus,
  Order,
  OrderItem,
  OrderStatus,
  PaymentStatus,
  Product,
} from '../types'
import { FULFILLMENT_STATUSES, ORDER_STATUSES, PAYMENT_STATUSES } from '../types'
import { Badge, EmptyState, ErrorBanner, LoadingScreen, Spinner } from '../components/ui'
import { ProductImage } from '../components/ProductImage'
import { Icon } from '../components/Icon'
import { Modal } from '../components/Modal'
import { useToast } from '../components/Toast'

/** Statuses an administrator can move an already-reviewed order into. */
const EDITABLE_STATUSES: OrderStatus[] = ORDER_STATUSES.filter(
  (status) => status !== 'pending_confirmation' && status !== 'rejected',
)

function requestedItemsOf(order: Order): OrderItem[] {
  return order.requestedItems?.length ? order.requestedItems : order.items
}

function lineTotal(item: OrderItem): number {
  return (item.price ?? 0) * (item.quantity ?? 0)
}

export function OrderDetailPage() {
  const { id } = useParams()
  const { user } = useAuth()
  const { notify } = useToast()
  const [order, setOrder] = useState<Order | null>(null)
  const [baseline, setBaseline] = useState<Order | null>(null)
  const [products, setProducts] = useState<Product[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const [status, setStatus] = useState<OrderStatus>('pending_confirmation')
  const [paymentStatus, setPaymentStatus] = useState<PaymentStatus>('unpaid')
  const [fulfillmentStatus, setFulfillmentStatus] = useState<FulfillmentStatus>('unfulfilled')
  const [adminNotes, setAdminNotes] = useState('')
  const [cancelReason, setCancelReason] = useState('')
  const [saving, setSaving] = useState(false)
  const [restocking, setRestocking] = useState(false)
  const [reviewAction, setReviewAction] = useState<'confirm' | 'reject' | null>(null)
  const [confirmNote, setConfirmNote] = useState('')
  const [rejectReason, setRejectReason] = useState('')
  const [reviewBusy, setReviewBusy] = useState(false)
  const dirtyRef = useRef(false)

  const applyOrder = useCallback((nextOrder: Order) => {
    setOrder(nextOrder)
    setBaseline(nextOrder)
    setStatus(
      (ORDER_STATUSES.includes(nextOrder.status as OrderStatus)
        ? nextOrder.status
        : 'pending_confirmation') as OrderStatus,
    )
    setPaymentStatus(
      (PAYMENT_STATUSES.includes(nextOrder.paymentStatus as PaymentStatus)
        ? nextOrder.paymentStatus
        : 'unpaid') as PaymentStatus,
    )
    setFulfillmentStatus(
      (FULFILLMENT_STATUSES.includes(nextOrder.fulfillmentStatus as FulfillmentStatus)
        ? nextOrder.fulfillmentStatus
        : 'unfulfilled') as FulfillmentStatus,
    )
    setAdminNotes(nextOrder.adminNotes ?? '')
    setCancelReason(nextOrder.cancelReason ?? '')
  }, [])

  const load = useCallback(async () => {
    if (!id) return
    setLoading(true)
    setError(null)
    try {
      const [nextOrder, nextProducts] = await Promise.all([fetchOrder(id), fetchProducts()])
      setProducts(nextProducts)
      if (nextOrder) {
        applyOrder(nextOrder)
      } else {
        setOrder(null)
      }
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : 'Could not load the order.')
    } finally {
      setLoading(false)
    }
  }, [applyOrder, id])

  useEffect(() => {
    void load()
  }, [load])

  // Live updates keep the timeline and cancellation state current while the
  // page is open. Unsaved form edits are never overwritten by a remote change.
  useEffect(() => {
    if (!id) return
return watchOrder(
  id,
  (nextOrder) => {
    if (!nextOrder) return

    console.log('Live order status:', nextOrder.status)

    if (dirtyRef.current) {
      setOrder(nextOrder)
    } else {
      applyOrder(nextOrder)
    }
    setLoading(false)
  },
  (watchError) => {
    setError((current) => current ?? watchError.message)
  },
)
  }, [applyOrder, id])

  const dirty =
    Boolean(baseline) &&
    (status !== baseline?.status ||
      paymentStatus !== baseline?.paymentStatus ||
      fulfillmentStatus !== (baseline?.fulfillmentStatus ?? 'unfulfilled') ||
      adminNotes.trim() !== (baseline?.adminNotes ?? ''))

  const notesDirty = Boolean(baseline) && adminNotes.trim() !== (baseline?.adminNotes ?? '')

  useEffect(() => {
    dirtyRef.current = dirty
  }, [dirty])

  function resetForm() {
    if (order) applyOrder(order)
  }

  async function save() {
    if (!order || !user) return
    setSaving(true)
    try {
      await updateOrder(
        order,
        {
          status,
          paymentStatus,
          fulfillmentStatus,
          adminNotes,
          cancelReason: status === 'cancelled' ? cancelReason : undefined,
        },
        { uid: user.uid, email: user.email },
      )
      const nextOrder = await fetchOrder(order.id)
      if (nextOrder) applyOrder(nextOrder)
      notify('Order updated.')
    } catch (saveError) {
      notify(saveError instanceof Error ? saveError.message : 'Could not update the order.', 'error')
    } finally {
      setSaving(false)
    }
  }

  async function confirmRequest() {
  if (!order || !user) return

  setReviewBusy(true)

  try {
    const result = await confirmOrderRequest({
      orderId: order.id,
      actor: { uid: user.uid, email: user.email },
      note: confirmNote,
    })

    const [nextOrder, nextProducts] = await Promise.all([
      fetchOrder(order.id),
      fetchProducts(),
    ])

    setProducts(nextProducts)

    if (nextOrder) {
      applyOrder(nextOrder)
      console.log('Confirmed order status:', nextOrder.status)
    }

    setReviewAction(null)
    setConfirmNote('')
    notify(`Order ${result.orderNumber} confirmed. Stock was deducted.`)
  } catch (confirmError) {
    notify(
      confirmError instanceof Error
        ? confirmError.message
        : 'Could not confirm this request.',
      'error',
    )
  } finally {
    setReviewBusy(false)
  }
}

  async function rejectRequest() {
    if (!order || !user) return
    if (!rejectReason.trim()) {
      notify('Give the customer a reason for rejecting this request.', 'error')
      return
    }
    setReviewBusy(true)
    try {
      await rejectOrderRequest({
        orderId: order.id,
        reason: rejectReason,
        actor: { uid: user.uid, email: user.email },
      })
      const nextOrder = await fetchOrder(order.id)
      if (nextOrder) applyOrder(nextOrder)
      setReviewAction(null)
      setRejectReason('')
      notify('Request rejected. No stock was changed.')
    } catch (rejectError) {
      notify(
        rejectError instanceof Error ? rejectError.message : 'Could not reject this request.',
        'error',
      )
    } finally {
      setReviewBusy(false)
    }
  }

  async function restock() {
    if (!order || !user) return
    setRestocking(true)
    try {
      await restockCancelledOrder(order.id, { uid: user.uid, email: user.email })
      const [nextOrder, nextProducts] = await Promise.all([
        fetchOrder(order.id),
        fetchProducts(),
      ])
      setProducts(nextProducts)
      if (nextOrder) applyOrder(nextOrder)
      notify('Stock restored and customer totals adjusted.')
    } catch (restockError) {
      notify(
        restockError instanceof Error ? restockError.message : 'Could not restore stock.',
        'error',
      )
    } finally {
      setRestocking(false)
    }
  }

  const productById = useMemo(() => {
    const map = new Map<string, Product>()
    for (const product of products) map.set(product.id, product)
    return map
  }, [products])

  const review = useMemo(() => {
    if (!order) return null
    const requested = requestedItemsOf(order)
    const requestedSubtotal =
      order.requestedSubtotal ??
      requested.reduce((sum, item) => sum + lineTotal(item), 0)
    const requestedShipping =
      order.requestedShippingFee ?? order.shippingFee ?? 0
    const requestedTotal = order.requestedTotal ?? requestedSubtotal + requestedShipping

    let verifiedSubtotal = 0
    let blocked = false
    const lines = requested.map((item, index) => {
      const product = item.productId ? productById.get(item.productId) : undefined
      const currentPrice = product?.price
      const currentStock = product && item.size ? product.stock[item.size] ?? 0 : 0
      const quantity = item.quantity ?? 0
      const insufficient = !product || currentStock < quantity
      if (insufficient) blocked = true
      verifiedSubtotal += (currentPrice ?? item.price ?? 0) * quantity
      return {
        key: `${item.productId ?? 'item'}-${item.size ?? ''}-${index}`,
        item,
        product,
        currentPrice,
        currentStock,
        quantity,
        insufficient,
        requestedLineTotal: lineTotal(item),
        currentLineTotal: (currentPrice ?? item.price ?? 0) * quantity,
      }
    })

    return {
      requested,
      requestedSubtotal,
      requestedShipping,
      requestedTotal,
      verifiedSubtotal,
      verifiedTotal: verifiedSubtotal + requestedShipping,
      priceChanged: verifiedSubtotal !== requestedSubtotal,
      blocked,
      lines,
    }
  }, [order, productById])

  const stockDeducted = Boolean(order && (order.totalsVerified || order.customerTotalsApplied))

  if (loading) return <LoadingScreen label="Loading order…" />
  if (error) {
    return (
      <div className="page-stack">
        <ErrorBanner message={error} onRetry={load} />
        <Link to="/orders" className="button button-ghost">
          <Icon name="arrowLeft" size={16} />
          Back to orders
        </Link>
      </div>
    )
  }
  if (!order || !review) {
    return (
      <div className="page-stack">
        <ErrorBanner message="This order could not be found. It may have been removed." />
        <Link to="/orders" className="button button-primary">
          <Icon name="arrowLeft" size={16} />
          Back to orders
        </Link>
      </div>
    )
  }

  const isPending = order.status === 'pending_confirmation'
  const isRejected = order.status === 'rejected'
  const showReviewPanel = isPending
  const showStatusForm = !isPending && !isRejected
  // Closed orders stay closed. Legacy `placed` documents still offer the
  // normal pipeline, so prepend their current value when it is not listed.
  const statusOptions: OrderStatus[] =
    order.status === 'cancelled' || order.status === 'refunded'
      ? [status]
      : EDITABLE_STATUSES.includes(status)
        ? EDITABLE_STATUSES
        : [status, ...EDITABLE_STATUSES]
  const itemsTotal = order.items.reduce((sum, item) => sum + lineTotal(item), 0)
  const timeline =
    order.timeline.length > 0
      ? order.timeline
      : [
          {
            status: order.status,
            title: titleCase(order.status),
            note: 'Current status.',
            at: order.createdAt,
          },
        ]

  return (
    <div className="page-stack">
      <div className="page-header">
        <div>
          <Link to="/orders" className="back-link">
            <Icon name="arrowLeft" size={15} />
            Orders
          </Link>
          <h1>{orderLabel(order)}</h1>
          <div className="detail-meta">
            <Badge value={order.status} />
            <Badge value={order.paymentStatus} />
            {order.fulfillmentStatus ? <Badge value={order.fulfillmentStatus} /> : null}
            <span>
              {isPending ? 'Requested' : 'Created'} {formatDateTime(order.createdAt)}
            </span>
            {!order.totalsVerified ? <span className="muted">Totals unverified</span> : null}
          </div>
        </div>
        <div className="page-actions">
          <button type="button" className="button button-ghost" onClick={load} disabled={saving || reviewBusy}>
            <Icon name="refresh" size={16} />
            Refresh
          </button>
          {showStatusForm ? (
            <button
              type="button"
              className="button button-primary"
              onClick={save}
              disabled={saving || !dirty}
            >
              {saving ? <Spinner size={16} /> : <Icon name="check" size={16} />}
              Save changes
            </button>
          ) : null}
        </div>
      </div>

      <div className="order-grid">
        <div className="order-main">
          {showReviewPanel ? (
            <section className="panel">
              <header className="panel-header">
                <div>
                  <p className="eyebrow">Request review</p>
                  <h2>Verify prices and stock</h2>
                </div>
                <span className="muted">Not yet confirmed</span>
              </header>

              <div className="status-callout status-callout-warning">
                <div className="status-callout-heading">
                  <Icon name="alert" size={16} />
                  <strong>This is a provisional request</strong>
                </div>
                <p>
                  The customer&apos;s requested total is not a verified amount. Confirming assigns the
                  next official order number, deducts stock and replaces these totals with current
                  catalogue prices. Rejecting changes no stock.
                </p>
              </div>

              <div className="table-wrap">
                <table className="data-table">
                  <thead>
                    <tr>
                      <th>Product</th>
                      <th>Size</th>
                      <th>Qty</th>
                      <th>Requested price</th>
                      <th>Current price</th>
                      <th>Current stock</th>
                      <th>Verified subtotal</th>
                    </tr>
                  </thead>
                  <tbody>
                    {review.lines.map((line) => (
                      <tr key={line.key}>
                        <td>
                          <div className="product-cell">
                            <ProductImage
                              imageId={line.item.imageId}
                              alt={line.item.name || 'Order item'}
                              className="thumb"
                              iconSize={18}
                            />
                            <div>
                              <span>{line.item.name || 'Unnamed item'}</span>
                              {line.product ? (
                                <span className="muted">
                                  {titleCase(line.product.status)}
                                </span>
                              ) : (
                                <span className="field-error">Product missing</span>
                              )}
                            </div>
                          </div>
                        </td>
                        <td>
                          {line.item.size ? (
                            <span className="chip">{line.item.size}</span>
                          ) : (
                            <span className="muted">—</span>
                          )}
                        </td>
                        <td className="numeric">{line.quantity}</td>
                        <td className="numeric">{formatCurrency(line.item.price)}</td>
                        <td className="numeric">
                          {line.currentPrice === undefined ? (
                            <span className="field-error">—</span>
                          ) : (
                            <span
                              className={
                                line.currentPrice !== line.item.price ? 'price-changed' : undefined
                              }
                            >
                              {formatCurrency(line.currentPrice)}
                            </span>
                          )}
                        </td>
                        <td className="numeric">
                          {line.product ? (
                            <span className={line.insufficient ? 'field-error' : undefined}>
                              {line.currentStock}
                            </span>
                          ) : (
                            <span className="field-error">—</span>
                          )}
                        </td>
                        <td className="numeric">
                          {formatCurrency(line.currentLineTotal)}
                          {line.insufficient ? (
                            <span className="muted table-note">insufficient stock</span>
                          ) : null}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              <footer className="order-totals">
                <div>
                  <span>Requested subtotal</span>
                  <strong>{formatCurrency(review.requestedSubtotal)}</strong>
                </div>
                <div>
                  <span>Verified subtotal at current prices</span>
                  <strong className={review.priceChanged ? 'price-changed' : undefined}>
                    {formatCurrency(review.verifiedSubtotal)}
                  </strong>
                </div>
                <div>
                  <span>Shipping fee</span>
                  <strong>{formatCurrency(review.requestedShipping)}</strong>
                </div>
                <div>
                  <span>Requested total</span>
                  <strong>{formatCurrency(review.requestedTotal)}</strong>
                </div>
                <div>
                  <span>Verified total on confirmation</span>
                  <strong className={review.priceChanged ? 'price-changed' : undefined}>
                    {formatCurrency(review.verifiedTotal)}
                  </strong>
                </div>
              </footer>

              <div className="inline-actions">
                <button
                  type="button"
                  className="button button-primary"
                  onClick={() => setReviewAction('confirm')}
                  disabled={review.blocked || reviewBusy}
                >
                  <Icon name="check" size={16} />
                  Confirm order
                </button>
                <button
                  type="button"
                  className="button button-danger"
                  onClick={() => setReviewAction('reject')}
                  disabled={reviewBusy}
                >
                  <Icon name="x" size={16} />
                  Reject request
                </button>
              </div>
              {review.blocked ? (
                <p className="field-error">
                  One or more lines do not have enough stock at current prices. Reject the request
                  or restock the product first, then refresh.
                </p>
              ) : null}
            </section>
          ) : null}

          {isRejected ? (
            <section className="panel">
              <div className="status-callout status-callout-danger">
                <div className="status-callout-heading">
                  <Icon name="alert" size={16} />
                  <strong>Request rejected</strong>
                </div>
                <p>{order.rejectionReason || 'The store could not confirm this request.'}</p>
                <p className="muted">
                  No stock was deducted and no payment is due. This request is closed.
                </p>
              </div>
            </section>
          ) : null}

          <section className="panel">
            <header className="panel-header">
              <div>
                <p className="eyebrow">Line items</p>
                <h2>{order.totalsVerified ? 'Verified order contents' : 'Requested line items'}</h2>
              </div>
              <span className="muted">{order.items.length} entries</span>
            </header>
            {order.items.length === 0 ? (
              <EmptyState
                icon="orders"
                title="No line items recorded"
                description="This order document has no items array. Totals are still shown for reference."
              />
            ) : (
              <div className="table-wrap">
                <table className="data-table">
                  <thead>
                    <tr>
                      <th>Product</th>
                      <th>Size</th>
                      <th>Qty</th>
                      <th>Unit price</th>
                      <th>Subtotal</th>
                    </tr>
                  </thead>
                  <tbody>
                    {order.items.map((item, index) => (
                      <tr key={`${item.productId ?? 'item'}-${index}`}>
                        <td>
                          <div className="product-cell">
                            <ProductImage
                              imageId={item.imageId}
                              alt={item.name || 'Order item'}
                              className="thumb"
                              iconSize={18}
                            />
                            <div>
                              <span>{item.name || 'Unnamed item'}</span>
                              {item.productId ? (
                                <Link to={`/products/${item.productId}`} className="muted table-link">
                                  View product
                                </Link>
                              ) : null}
                            </div>
                          </div>
                        </td>
                        <td>{item.size ? <span className="chip">{item.size}</span> : <span className="muted">—</span>}</td>
                        <td className="numeric">{item.quantity ?? 0}</td>
                        <td className="numeric">{formatCurrency(item.price)}</td>
                        <td className="numeric">{formatCurrency(lineTotal(item))}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
            <footer className="order-totals">
              {order.requestedTotal !== undefined && order.totalsVerified ? (
                <div>
                  <span>Requested total</span>
                  <strong>{formatCurrency(order.requestedTotal)}</strong>
                </div>
              ) : null}
              <div>
                <span>Sum of line items</span>
                <strong>{formatCurrency(itemsTotal)}</strong>
              </div>
              <div>
                <span>{order.totalsVerified ? 'Verified order total' : 'Requested total'}</span>
                <strong>{formatCurrency(order.total)}</strong>
              </div>
            </footer>
          </section>

          <section className="panel">
            <header className="panel-header">
              <div>
                <p className="eyebrow">Tracking</p>
                <h2>Order timeline</h2>
              </div>
              <span className="muted">{timeline.length} updates</span>
            </header>
            <ol className="order-timeline">
              {timeline.map((event, index) => (
                <li
                  key={`${event.status}-${index}`}
                  className={`timeline-item${index === timeline.length - 1 ? ' is-current' : ''}`}
                >
                  <span className="timeline-dot" aria-hidden="true" />
                  <div className="timeline-body">
                    <div className="timeline-heading">
                      <strong>{event.title || titleCase(event.status)}</strong>
                      <span className="muted">{formatDateTime(event.at)}</span>
                    </div>
                    {event.note ? <p>{event.note}</p> : null}
                  </div>
                </li>
              ))}
            </ol>
          </section>

          <section className="panel">
            <header className="panel-header">
              <div>
                <p className="eyebrow">Notes</p>
                <h2>Administrator notes</h2>
              </div>
              <button
                type="button"
                className="button button-small button-ghost"
                onClick={save}
                disabled={saving || !notesDirty}
              >
                {saving ? <Spinner size={15} /> : <Icon name="check" size={15} />}
                Save notes
              </button>
            </header>
            <label className="field">
              <span className="field-label">Internal notes</span>
              <textarea
                value={adminNotes}
                onChange={(event) => setAdminNotes(event.target.value)}
                rows={5}
                maxLength={2000}
                disabled={saving}
                placeholder="Packing notes, customer follow-ups, courier details…"
              />
              <span className="field-hint">Visible only to administrators. {adminNotes.length} / 2000</span>
            </label>
          </section>
        </div>

        <aside className="order-side">
          <section className="panel">
            <header className="panel-header">
              <div>
                <p className="eyebrow">Customer</p>
                <h2>Recipient</h2>
              </div>
            </header>
            <dl className="detail-list">
              <div>
                <dt>Name</dt>
                <dd>{order.customerName || 'Not recorded'}</dd>
              </div>
              <div>
                <dt>Email</dt>
                <dd>{order.customerEmail || 'Not recorded'}</dd>
              </div>
              <div>
                <dt>Customer ID</dt>
                <dd className="mono-small">{order.customerId || '—'}</dd>
              </div>
              <div>
                <dt>Shipping address</dt>
                <dd>{order.shippingAddress || 'Not recorded'}</dd>
              </div>
              {order.customerNote ? (
                <div>
                  <dt>Customer note</dt>
                  <dd>{order.customerNote}</dd>
                </div>
              ) : null}
            </dl>
          </section>

          {showStatusForm ? (
            <section className="panel">
              <header className="panel-header">
                <div>
                  <p className="eyebrow">Permitted changes</p>
                  <h2>Status</h2>
                </div>
              </header>
              <div className="form-stack">
                <label className="field">
                  <span className="field-label">Order status</span>
                  <select
                    value={status}
                    onChange={(event) => setStatus(event.target.value as OrderStatus)}
                    disabled={saving}
                  >
                    {statusOptions.map((option) => (
                      <option key={option} value={option}>
                        {titleCase(option)}
                      </option>
                    ))}
                  </select>
                </label>
                <label className="field">
                  <span className="field-label">Payment status</span>
                  <select
                    value={paymentStatus}
                    onChange={(event) => setPaymentStatus(event.target.value as PaymentStatus)}
                    disabled={saving}
                  >
                    {PAYMENT_STATUSES.map((option) => (
                      <option key={option} value={option}>
                        {titleCase(option)}
                      </option>
                    ))}
                  </select>
                </label>
                <label className="field">
                  <span className="field-label">Fulfillment status</span>
                  <select
                    value={fulfillmentStatus}
                    onChange={(event) => setFulfillmentStatus(event.target.value as FulfillmentStatus)}
                    disabled={saving}
                  >
                    {FULFILLMENT_STATUSES.map((option) => (
                      <option key={option} value={option}>
                        {titleCase(option)}
                      </option>
                    ))}
                  </select>
                </label>

                {status === 'cancelled' && order.status !== 'cancelled' ? (
                  <div className="status-callout status-callout-warning">
                    <div className="status-callout-heading">
                      <Icon name="alert" size={16} />
                      <strong>Cancelling restores stock</strong>
                    </div>
                    <p>
                      Saving restores every line item to inventory and writes cancelled-order logs.
                      Customer totals are reversed only when they were counted at confirmation.
                    </p>
                    <label className="field">
                      <span className="field-label">Cancellation reason</span>
                      <textarea
                        value={cancelReason}
                        onChange={(event) => setCancelReason(event.target.value)}
                        rows={3}
                        maxLength={500}
                        disabled={saving}
                        placeholder="Why is this order being cancelled?"
                      />
                      <span className="field-hint">Shared with the customer in the notification.</span>
                    </label>
                  </div>
                ) : null}

                {order.status === 'cancelled' && stockDeducted && !order.restockedAt ? (
                  <div className="status-callout status-callout-danger">
                    <div className="status-callout-heading">
                      <Icon name="alert" size={16} />
                      <strong>Stock restoration pending</strong>
                    </div>
                    <p>
                      {order.cancelReason || 'This order was cancelled.'} The items have not been
                      returned to inventory yet.
                    </p>
                    <button
                      type="button"
                      className="button button-danger"
                      onClick={restock}
                      disabled={restocking || saving}
                    >
                      {restocking ? <Spinner size={16} /> : <Icon name="refresh" size={16} />}
                      Restore stock
                    </button>
                  </div>
                ) : null}

                {order.status === 'cancelled' && !stockDeducted ? (
                  <p className="field-hint">
                    This request never deducted stock, so there is nothing to restore.
                  </p>
                ) : null}

                <div className="inline-actions">
                  <button type="button" className="button button-primary" onClick={save} disabled={saving || !dirty}>
                    {saving ? <Spinner size={16} /> : <Icon name="check" size={16} />}
                    Save changes
                  </button>
                  <button type="button" className="button button-ghost" onClick={resetForm} disabled={saving || !dirty}>
                    Reset
                  </button>
                </div>
                <p className="field-hint">
                  Totals, verified line items, official order numbers and customer identity are never
                  changed here. Only the confirmation and cancellation transactions can write them.
                </p>
              </div>
            </section>
          ) : null}

          <section className="panel">
            <header className="panel-header">
              <div>
                <p className="eyebrow">Order metadata</p>
                <h2>Reference</h2>
              </div>
            </header>
            <dl className="detail-list">
              {order.requestReference ? (
                <div>
                  <dt>Customer request reference</dt>
                  <dd className="mono-small">{order.requestReference}</dd>
                </div>
              ) : null}
              <div>
                <dt>Official order number</dt>
                <dd>{order.orderNumber || 'Assigned on confirmation'}</dd>
              </div>
              <div>
                <dt>Payment method</dt>
                <dd>{order.paymentMethod || 'Not recorded'}</dd>
              </div>
              {order.confirmedAt ? (
                <div>
                  <dt>Confirmed</dt>
                  <dd>{formatDateTime(order.confirmedAt)}</dd>
                </div>
              ) : null}
              {order.rejectionReason ? (
                <div>
                  <dt>Rejection reason</dt>
                  <dd>{order.rejectionReason}</dd>
                </div>
              ) : null}
              {order.cancelReason ? (
                <div>
                  <dt>Cancellation reason</dt>
                  <dd>{order.cancelReason}</dd>
                </div>
              ) : null}
              {order.restockedAt ? (
                <div>
                  <dt>Stock restored</dt>
                  <dd>{formatDateTime(order.restockedAt)}</dd>
                </div>
              ) : null}
              <div>
                <dt>Last updated</dt>
                <dd>{formatDateTime(order.updatedAt)}</dd>
              </div>
              <div>
                <dt>Order document</dt>
                <dd className="mono-small">{order.id}</dd>
              </div>
            </dl>
          </section>
        </aside>
      </div>

      <Modal
        open={reviewAction === 'confirm'}
        title="Confirm this request?"
        description="This assigns the official order number and deducts stock immediately."
        onClose={reviewBusy ? () => undefined : () => setReviewAction(null)}
        footer={
          <>
            <button
              type="button"
              className="button button-ghost"
              onClick={() => setReviewAction(null)}
              disabled={reviewBusy}
            >
              Cancel
            </button>
            <button
              type="button"
              className="button button-primary"
              onClick={confirmRequest}
              disabled={reviewBusy || review.blocked}
            >
              {reviewBusy ? <Spinner size={16} /> : <Icon name="check" size={16} />}
              Confirm and deduct stock
            </button>
          </>
        }
      >
        <div className="form-stack">
          <div className="adjust-summary">
            <div>
              <span>Requested total</span>
              <strong>{formatCurrency(review.requestedTotal)}</strong>
            </div>
            <div>
              <span>Verified total</span>
              <strong className={review.priceChanged ? 'price-changed' : undefined}>
                {formatCurrency(review.verifiedTotal)}
              </strong>
            </div>
            <div>
              <span>Items</span>
              <strong>{review.requested.reduce((sum, item) => sum + (item.quantity ?? 0), 0)}</strong>
            </div>
          </div>
          {review.priceChanged ? (
            <p className="field-hint">
              Current catalogue prices differ from the requested prices. The verified total above
              is what the customer will see after confirmation.
            </p>
          ) : null}
          <label className="field">
            <span className="field-label">Timeline note (optional)</span>
            <textarea
              value={confirmNote}
              onChange={(event) => setConfirmNote(event.target.value)}
              rows={3}
              maxLength={500}
              disabled={reviewBusy}
              placeholder="Anything the customer should know about the verified order…"
            />
          </label>
          <p className="field-hint">
            Stock is deducted per size and an inventory log is written in the same transaction. If
            any line has insufficient stock, nothing is changed.
          </p>
        </div>
      </Modal>

      <Modal
        open={reviewAction === 'reject'}
        title="Reject this request?"
        description="No stock is deducted and no payment is due."
        onClose={reviewBusy ? () => undefined : () => setReviewAction(null)}
        footer={
          <>
            <button
              type="button"
              className="button button-ghost"
              onClick={() => setReviewAction(null)}
              disabled={reviewBusy}
            >
              Cancel
            </button>
            <button
              type="button"
              className="button button-danger"
              onClick={rejectRequest}
              disabled={reviewBusy || !rejectReason.trim()}
            >
              {reviewBusy ? <Spinner size={16} /> : <Icon name="x" size={16} />}
              Reject request
            </button>
          </>
        }
      >
        <div className="form-stack">
          <p className="field-hint">
            The customer is notified with this reason and the request becomes read-only. They can
            submit a new request if stock becomes available.
          </p>
          <label className="field">
            <span className="field-label">Reason for rejection</span>
            <textarea
              value={rejectReason}
              onChange={(event) => setRejectReason(event.target.value)}
              rows={4}
              maxLength={500}
              disabled={reviewBusy}
              placeholder="Out of stock, price changed, delivery unavailable…"
            />
            <span className="field-hint">{rejectReason.length} / 500</span>
          </label>
        </div>
      </Modal>
    </div>
  )
}
