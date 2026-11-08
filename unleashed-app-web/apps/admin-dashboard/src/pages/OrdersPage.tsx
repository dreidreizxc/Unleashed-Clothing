import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { fetchOrdersPage } from '../lib/firestore'
import { formatCurrency, formatDate, orderLabel, titleCase } from '../lib/format'
import type { Order } from '../types'
import { ORDER_STATUSES, PAYMENT_STATUSES } from '../types'
import type { QueryDocumentSnapshot } from 'firebase/firestore'
import { Badge, EmptyState, ErrorBanner, PageHeader, Spinner, StatCard } from '../components/ui'
import { Icon } from '../components/Icon'

const PAGE_SIZE = 50
const SALES_EXCLUDED = new Set(['pending_confirmation', 'rejected', 'cancelled', 'refunded'])

function orderTotal(order: Order): number {
  return order.totalsVerified ? order.total : order.requestedTotal ?? order.total
}

export function OrdersPage() {
  const [orders, setOrders] = useState<Order[]>([])
  const [cursor, setCursor] = useState<QueryDocumentSnapshot | null>(null)
  const [hasMore, setHasMore] = useState(false)
  const [loading, setLoading] = useState(true)
  const [loadingMore, setLoadingMore] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [search, setSearch] = useState('')
  const [status, setStatus] = useState('all')
  const [payment, setPayment] = useState('all')

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const page = await fetchOrdersPage({ pageSize: PAGE_SIZE })
      setOrders(page.orders)
      setCursor(page.cursor)
      setHasMore(page.hasMore)
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : 'Could not load orders.')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    void load()
  }, [load])

  async function loadMore() {
    if (!cursor || loadingMore) return
    setLoadingMore(true)
    setError(null)
    try {
      const page = await fetchOrdersPage({ pageSize: PAGE_SIZE, cursor })
      setOrders((current) => {
        const seen = new Set(current.map((order) => order.id))
        return [...current, ...page.orders.filter((order) => !seen.has(order.id))]
      })
      setCursor(page.cursor)
      setHasMore(page.hasMore)
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : 'Could not load more orders.')
    } finally {
      setLoadingMore(false)
    }
  }

  const summary = useMemo(() => {
    const salesOrders = orders.filter((order) => !SALES_EXCLUDED.has(order.status))
    return {
      pending: orders.filter((order) => order.status === 'pending_confirmation').length,
      confirmed: orders.filter(
        (order) =>
          order.status === 'confirmed' ||
          order.status === 'processing' ||
          order.status === 'ready_for_shipment' ||
          order.status === 'shipped' ||
          order.status === 'out_for_delivery',
      ).length,
      paid: orders.filter((order) => order.paymentStatus === 'paid').length,
      recorded: salesOrders.reduce((sum, order) => sum + orderTotal(order), 0),
    }
  }, [orders])

  const filtered = useMemo(() => {
    const term = search.trim().toLowerCase()
    return orders.filter((order) => {
      const matchesTerm =
        !term ||
        orderLabel(order).toLowerCase().includes(term) ||
        (order.customerName || '').toLowerCase().includes(term) ||
        (order.customerEmail || '').toLowerCase().includes(term) ||
        order.customerId.toLowerCase().includes(term)
      const matchesStatus = status === 'all' || order.status === status
      const matchesPayment = payment === 'all' || order.paymentStatus === payment
      return matchesTerm && matchesStatus && matchesPayment
    })
  }, [orders, payment, search, status])

  const hasFilters = Boolean(search.trim()) || status !== 'all' || payment !== 'all'

  function clearFilters() {
    setSearch('')
    setStatus('all')
    setPayment('all')
  }

  return (
    <div className="page-stack">
      <PageHeader
        eyebrow="Sales"
        title="Orders"
        description="Requests stay provisional until an administrator verifies prices and stock. Only confirmed orders have verified totals and deducted stock."
        actions={
          <button type="button" className="button button-ghost" onClick={load} disabled={loading}>
            {loading ? <Spinner size={16} /> : <Icon name="refresh" size={16} />}
            Refresh
          </button>
        }
      />

      {error ? <ErrorBanner message={error} onRetry={load} /> : null}

      <section className="stat-grid" aria-label="Order summary">
        <StatCard
          label="Loaded orders"
          value={orders.length}
          icon="orders"
          loading={loading}
          hint={hasMore ? 'Newest page — load more below' : 'All orders loaded'}
        />
        <StatCard
          label="Pending requests"
          value={summary.pending}
          icon="inventory"
          loading={loading}
          hint="Need price and stock verification"
        />
        <StatCard
          label="Active orders"
          value={summary.confirmed}
          icon="check"
          loading={loading}
          hint="Confirmed through out for delivery"
        />
        <StatCard
          label="Recorded sales"
          value={formatCurrency(summary.recorded)}
          icon="reports"
          loading={loading}
          hint={`${summary.paid} marked paid · excludes pending, rejected, cancelled`}
        />
      </section>

      <section className="panel">
        <div className="toolbar">
          <label className="search-field">
            <Icon name="search" size={17} />
            <span className="sr-only">Search orders</span>
            <input
              type="search"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Search request, order, customer, or ID…"
            />
          </label>
          <div className="toolbar-filters">
            <label className="compact-field">
              <span>Status</span>
              <select value={status} onChange={(event) => setStatus(event.target.value)}>
                <option value="all">All statuses</option>
                {ORDER_STATUSES.map((option) => (
                  <option key={option} value={option}>
                    {titleCase(option)}
                  </option>
                ))}
              </select>
            </label>
            <label className="compact-field">
              <span>Payment</span>
              <select value={payment} onChange={(event) => setPayment(event.target.value)}>
                <option value="all">All payments</option>
                {PAYMENT_STATUSES.map((option) => (
                  <option key={option} value={option}>
                    {titleCase(option)}
                  </option>
                ))}
              </select>
            </label>
            {hasFilters ? (
              <button type="button" className="button button-small button-ghost" onClick={clearFilters}>
                Clear filters
              </button>
            ) : null}
          </div>
        </div>

        {loading ? (
          <div className="table-loading">
            <Spinner size={24} label="Loading orders…" />
          </div>
        ) : orders.length === 0 ? (
          <EmptyState
            icon="orders"
            title="No orders yet"
            description="Requests submitted by customers will appear here. No sample orders are shown."
            action={
              <Link to="/products" className="button button-ghost">
                <Icon name="products" size={16} />
                Review the catalog
              </Link>
            }
          />
        ) : filtered.length === 0 ? (
          <EmptyState
            icon="search"
            title="No matching orders"
            description="Try a different search term or clear the filters."
            action={
              <button type="button" className="button button-ghost" onClick={clearFilters}>
                Clear filters
              </button>
            }
          />
        ) : (
          <>
            <div className="table-wrap">
              <table className="data-table orders-table">
                <thead>
                  <tr>
                    <th>Request / order</th>
                    <th>Customer</th>
                    <th>Date</th>
                    <th>Items</th>
                    <th>Total</th>
                    <th>Payment</th>
                    <th>Fulfillment</th>
                    <th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  {filtered.map((order) => {
                    const itemCount =
                      order.itemCount ??
                      order.items.reduce((sum, item) => sum + (item.quantity ?? 0), 0)
                    return (
                      <tr key={order.id}>
                        <td>
                          <Link to={`/orders/${order.id}`} className="table-link">
                            {orderLabel(order)}
                          </Link>
                          {!order.totalsVerified ? (
                            <span className="muted table-note">Requested</span>
                          ) : null}
                        </td>
                        <td>
                          <div className="stacked-cell">
                            <span>{order.customerName || 'Customer'}</span>
                            <span className="muted">{order.customerEmail || order.customerId}</span>
                          </div>
                        </td>
                        <td className="muted">{formatDate(order.createdAt)}</td>
                        <td className="numeric">{itemCount}</td>
                        <td className="numeric">
                          {formatCurrency(orderTotal(order))}
                          {!order.totalsVerified ? (
                            <span className="muted table-note">unverified</span>
                          ) : null}
                        </td>
                        <td>
                          <Badge value={order.paymentStatus} />
                        </td>
                        <td>
                          {order.fulfillmentStatus ? (
                            <Badge value={order.fulfillmentStatus} />
                          ) : (
                            <span className="muted">—</span>
                          )}
                        </td>
                        <td>
                          <Badge value={order.status} />
                        </td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
            <footer className="table-footer">
              <span>
                Showing {filtered.length} of {orders.length} loaded orders
              </span>
              {hasMore ? (
                <button
                  type="button"
                  className="button button-small button-ghost"
                  onClick={loadMore}
                  disabled={loadingMore}
                >
                  {loadingMore ? <Spinner size={15} /> : <Icon name="chevronRight" size={15} />}
                  Load more
                </button>
              ) : null}
            </footer>
          </>
        )}
      </section>
    </div>
  )
}
