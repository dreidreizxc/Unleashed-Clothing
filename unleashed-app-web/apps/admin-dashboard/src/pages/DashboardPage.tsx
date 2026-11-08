import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { fetchDashboardData } from '../lib/firestore'
import { formatCurrency, formatDate, formatNumber, titleCase } from '../lib/format'
import type { Order, Product } from '../types'
import { Badge, EmptyState, ErrorBanner, PageHeader, Spinner, StatCard } from '../components/ui'
import { Icon } from '../components/Icon'

const PIPELINE_STATUSES = new Set([
  'confirmed',
  'processing',
  'ready_for_shipment',
  'shipped',
  'out_for_delivery',
])
const SALES_EXCLUDED = new Set(['pending_confirmation', 'rejected', 'cancelled', 'refunded'])

function orderLabel(order: Order): string {
  return order.orderNumber || `#${order.id.slice(0, 8).toUpperCase()}`
}

function orderTotal(order: Order): number {
  return order.totalsVerified ? order.total : order.requestedTotal ?? order.total
}

function isInCurrentMonth(order: Order): boolean {
  if (!order.createdAt) return false
  try {
    const created = order.createdAt.toDate()
    const now = new Date()
    return created.getFullYear() === now.getFullYear() && created.getMonth() === now.getMonth()
  } catch {
    return false
  }
}

export function DashboardPage() {
  const [products, setProducts] = useState<Product[]>([])
  const [orders, setOrders] = useState<Order[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const data = await fetchDashboardData()
      setProducts(data.products)
      setOrders(data.orders)
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : 'Could not load dashboard data.')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    void load()
  }, [load])

  const stats = useMemo(() => {
    const salesOrders = orders.filter((order) => !SALES_EXCLUDED.has(order.status))
    const monthlyOrders = salesOrders.filter(isInCurrentMonth)
    const monthlyIncome = monthlyOrders.reduce((sum, order) => sum + orderTotal(order), 0)
    const itemsSold = salesOrders.reduce(
      (sum, order) =>
        sum + (order.itemCount ?? order.items.reduce((count, item) => count + (item.quantity ?? 0), 0)),
      0,
    )
    const pendingOrders = orders.filter((order) => order.status === 'pending_confirmation').length
    const activeOrders = orders.filter((order) => PIPELINE_STATUSES.has(order.status)).length
    const lowStock = products
      .filter((product) => product.totalStock <= 5)
      .sort((a, b) => a.totalStock - b.totalStock)
      .slice(0, 5)

    return { monthlyIncome, monthlyOrders, itemsSold, pendingOrders, activeOrders, lowStock }
  }, [orders, products])

  const recentOrders = orders.slice(0, 5)
  const activeProducts = products.filter((product) => product.status === 'active').length

  return (
    <div className="page-stack">
      <PageHeader
        eyebrow="Store overview"
        title="Good to see you."
        description="Live figures from Firestore. Requested totals stay unverified until an administrator confirms the request."
        actions={
          <>
            <button type="button" className="button button-ghost" onClick={load} disabled={loading}>
              {loading ? <Spinner size={16} /> : <Icon name="refresh" size={16} />}
              Refresh
            </button>
            <Link to="/products/new" className="button button-primary">
              <Icon name="plus" size={16} />
              Add product
            </Link>
          </>
        }
      />

      {error ? <ErrorBanner message={error} onRetry={load} /> : null}

      <section className="dashboard-hero" aria-label="Store overview">
        <div>
          <p className="eyebrow">RIZAL</p>
          <h2>Control room</h2>
          <p>
            Live Firestore signals only. Confirm pending requests personally before any stock leaves
            the floor.
          </p>
        </div>
        <div className="dashboard-hero-meta">
          <span className="dashboard-hero-date">
            {new Date().toLocaleDateString(undefined, {
              month: 'short',
              day: '2-digit',
              year: 'numeric',
            })}
          </span>
          <span className={`dashboard-hero-status ${error ? 'is-offline' : ''}`}>
            <i aria-hidden="true" />
            {error ? 'Sync interrupted' : 'Firestore connected'}
          </span>
        </div>
      </section>

      <section className="stat-grid" aria-label="Store statistics">
        <StatCard
          label="Total orders"
          value={formatNumber(orders.length)}
          hint={`${formatNumber(stats.activeOrders)} in the active pipeline Â· newest page`}
          icon="orders"
          loading={loading}
        />
        <StatCard
          label="Pending requests"
          value={formatNumber(stats.pendingOrders)}
          hint="Awaiting price and stock verification"
          icon="inventory"
          loading={loading}
        />
        <StatCard
          label="This month's income"
          value={formatCurrency(stats.monthlyIncome)}
          hint={`${formatNumber(stats.monthlyOrders.length)} confirmed orders Â· ${formatNumber(stats.itemsSold)} items sold`}
          icon="reports"
          loading={loading}
        />
        <StatCard
          label="Total products"
          value={formatNumber(products.length)}
          hint={`${formatNumber(activeProducts)} visible in the catalog`}
          icon="products"
          loading={loading}
        />
      </section>

      <div className="dashboard-grid">
        <section className="panel panel-span-2">
          <header className="panel-header">
            <div>
              <p className="eyebrow">Sales</p>
              <h2>Recent requests and orders</h2>
            </div>
            <Link to="/orders" className="text-link">
              View all <Icon name="chevronRight" size={15} />
            </Link>
          </header>

          {loading ? (
            <div className="table-loading">
              <Spinner size={22} label="Loading ordersâ€¦" />
            </div>
          ) : recentOrders.length === 0 ? (
            <EmptyState
              icon="orders"
              title="No orders yet"
              description="Requests will appear here when customers submit them. No placeholder orders are shown."
            />
          ) : (
            <div className="table-wrap">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>Request / order</th>
                    <th>Customer</th>
                    <th>Status</th>
                    <th>Total</th>
                    <th>Date</th>
                  </tr>
                </thead>
                <tbody>
                  {recentOrders.map((order) => (
                    <tr key={order.id}>
                      <td>
                        <Link to={`/orders/${order.id}`} className="table-link">
                          {orderLabel(order)}
                        </Link>
                      </td>
                      <td>{order.customerName || order.customerEmail || 'Customer'}</td>
                      <td>
                        <Badge value={order.status} />
                      </td>
                      <td className="numeric">
                        {formatCurrency(orderTotal(order))}
                        {!order.totalsVerified ? (
                          <span className="muted table-note">requested</span>
                        ) : null}
                      </td>
                      <td className="muted">{formatDate(order.createdAt)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>

        <section className="panel">
          <header className="panel-header">
            <div>
              <p className="eyebrow">Catalog</p>
              <h2>Low stock</h2>
            </div>
            <Link to="/inventory" className="text-link">
              Inventory <Icon name="chevronRight" size={15} />
            </Link>
          </header>

          {loading ? (
            <div className="table-loading">
              <Spinner size={22} label="Checking stockâ€¦" />
            </div>
          ) : stats.lowStock.length === 0 ? (
            <EmptyState
              icon="inventory"
              title={products.length === 0 ? 'No products yet' : 'Stock looks healthy'}
              description={
                products.length === 0
                  ? 'Add your first product to start tracking stock.'
                  : 'No products are at or below five total units.'
              }
              action={
                products.length === 0 ? (
                  <Link to="/products/new" className="button button-small button-primary">
                    <Icon name="plus" size={15} />
                    Add product
                  </Link>
                ) : undefined
              }
            />
          ) : (
            <ul className="low-stock-list">
              {stats.lowStock.map((product) => (
                <li key={product.id}>
                  <div>
                    <Link to={`/products/${product.id}`} className="table-link">
                      {product.name}
                    </Link>
                    <span>{titleCase(product.status)}</span>
                  </div>
                  <span className={`stock-pill ${product.totalStock === 0 ? 'is-out' : ''}`}>
                    {product.totalStock === 0 ? 'Out of stock' : `${product.totalStock} left`}
                  </span>
                </li>
              ))}
            </ul>
          )}
        </section>
      </div>

      {!loading && products.length === 0 && orders.length === 0 ? (
        <section className="panel empty-dashboard">
          <EmptyState
            icon="shirt"
            title="Your storefront is a blank canvas"
            description="Firestore has no products or orders yet. Add a product to start building the catalog."
            action={
              <Link to="/products/new" className="button button-primary">
                <Icon name="plus" size={16} />
                Add your first product
              </Link>
            }
          />
        </section>
      ) : null}
    </div>
  )
}
