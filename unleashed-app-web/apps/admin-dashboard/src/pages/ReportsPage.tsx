import { useCallback, useEffect, useMemo, useState } from 'react'
import { fetchOrders } from '../lib/firestore'
import { formatCurrency, formatDateTime, orderLabel, timestampMillis, titleCase, toDateInputValue } from '../lib/format'
import type { Order } from '../types'
import { ORDER_STATUSES } from '../types'
import { Badge, EmptyState, ErrorBanner, PageHeader, Spinner, StatCard } from '../components/ui'
import { Icon } from '../components/Icon'
import { useToast } from '../components/Toast'

const SALES_EXCLUDED = new Set(['pending_confirmation', 'rejected', 'cancelled', 'refunded'])
const REPORT_ORDER_LIMIT = 400

function startOfDay(value: string): number | null {
  if (!value) return null
  const date = new Date(`${value}T00:00:00`)
  return Number.isNaN(date.getTime()) ? null : date.getTime()
}

function endOfDay(value: string): number | null {
  if (!value) return null
  const date = new Date(`${value}T23:59:59.999`)
  return Number.isNaN(date.getTime()) ? null : date.getTime()
}

export function ReportsPage() {
  const { notify } = useToast()
  const initialTo = new Date()
  const initialFrom = new Date()
  initialFrom.setDate(initialFrom.getDate() - 29)

  const [orders, setOrders] = useState<Order[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [from, setFrom] = useState(toDateInputValue(initialFrom))
  const [to, setTo] = useState(toDateInputValue(initialTo))

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      setOrders(await fetchOrders(REPORT_ORDER_LIMIT))
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : 'Could not load report data.')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    void load()
  }, [load])

  const fromMillis = startOfDay(from)
  const toMillis = endOfDay(to)

  const filtered = useMemo(() => {
    return orders.filter((order) => {
      const millis = timestampMillis(order.createdAt)
      if (!fromMillis && !toMillis) return true
      if (millis === null) return false
      if (fromMillis !== null && millis < fromMillis) return false
      if (toMillis !== null && millis > toMillis) return false
      return true
    })
  }, [fromMillis, orders, toMillis])

  const report = useMemo(() => {
    const active = filtered.filter((order) => !SALES_EXCLUDED.has(order.status))
    const recordedSales = active.reduce((sum, order) => sum + order.total, 0)
    const paidSales = active
      .filter((order) => order.paymentStatus === 'paid')
      .reduce((sum, order) => sum + order.total, 0)
    const units = active.reduce(
      (sum, order) => sum + order.items.reduce((itemSum, item) => itemSum + (item.quantity ?? 0), 0),
      0,
    )

    const statusRows = ORDER_STATUSES.map((status) => {
      const matching = filtered.filter((order) => order.status === status)
      return {
        status,
        orders: matching.length,
        revenue: matching
          .filter((order) => !SALES_EXCLUDED.has(order.status))
          .reduce((sum, order) => sum + order.total, 0),
      }
    }).filter((row) => row.orders > 0)

    const productMap = new Map<string, { name: string; size: string; quantity: number; revenue: number }>()
    for (const order of active) {
      for (const item of order.items) {
        const key = `${item.productId ?? item.name ?? 'unknown'}::${item.size ?? ''}`
        const current = productMap.get(key) ?? {
          name: item.name || 'Unnamed item',
          size: item.size || '—',
          quantity: 0,
          revenue: 0,
        }
        current.quantity += item.quantity ?? 0
        current.revenue += (item.price ?? 0) * (item.quantity ?? 0)
        productMap.set(key, current)
      }
    }
    const topProducts = Array.from(productMap.values())
      .sort((a, b) => b.revenue - a.revenue || b.quantity - a.quantity)
      .slice(0, 8)

    const undated = orders.length - filtered.length

    return {
      recordedSales,
      paidSales,
      units,
      activeCount: active.length,
      averageOrder: active.length > 0 ? Math.round(recordedSales / active.length) : 0,
      statusRows,
      topProducts,
      undated,
    }
  }, [filtered, orders.length])

  function allTime() {
    setFrom('')
    setTo('')
  }

  function exportCsv() {
    if (filtered.length === 0) {
      notify('There is nothing to export for this range.', 'info')
      return
    }
    const header = ['Order', 'Date', 'Customer', 'Email', 'Status', 'Payment', 'Fulfillment', 'Total (PHP)']
    const lines = filtered.map((order) => {
      const created = timestampMillis(order.createdAt)
      return [
        orderLabel(order),
        created ? new Date(created).toISOString() : '',
        order.customerName || '',
        order.customerEmail || '',
        order.status,
        order.paymentStatus,
        order.fulfillmentStatus || '',
        (order.total / 100).toFixed(2),
      ]
        .map((value) => `"${String(value).replace(/"/g, '""')}"`)
        .join(',')
    })
    const blob = new Blob([[header.join(','), ...lines].join('\r\n')], { type: 'text/csv;charset=utf-8' })
    const url = URL.createObjectURL(blob)
    const anchor = document.createElement('a')
    anchor.href = url
    anchor.download = `unleashed-orders-${from || 'all'}-${to || 'all'}.csv`
    anchor.click()
    URL.revokeObjectURL(url)
    notify(`Exported ${filtered.length} orders.`)
  }

  const rangeLabel = from || to ? `${from || 'Beginning'} → ${to || 'Today'}` : 'All time'

  return (
    <div className="page-stack">
      <PageHeader
        eyebrow="Insights"
        title="Reports"
        description="Calculated from the most recent 400 Firestore orders. Requested totals are excluded until an administrator confirms them; recorded sales only include confirmed orders, and paid sales only include orders marked paid."
        actions={
          <>
            <button type="button" className="button button-ghost" onClick={load} disabled={loading}>
              {loading ? <Spinner size={16} /> : <Icon name="refresh" size={16} />}
              Refresh
            </button>
            <button type="button" className="button button-primary" onClick={exportCsv} disabled={loading}>
              <Icon name="download" size={16} />
              Export CSV
            </button>
          </>
        }
      />

      {error ? <ErrorBanner message={error} onRetry={load} /> : null}

      <section className="panel report-filters">
        <div className="filter-row">
          <label className="field">
            <span className="field-label">From</span>
            <input type="date" value={from} onChange={(event) => setFrom(event.target.value)} />
          </label>
          <label className="field">
            <span className="field-label">To</span>
            <input
              type="date"
              value={to}
              onChange={(event) => setTo(event.target.value)}
              min={from || undefined}
            />
          </label>
          <div className="filter-actions">
            <button type="button" className="button button-small button-ghost" onClick={allTime}>
              All time
            </button>
            <span className="muted">{filtered.length} orders in range</span>
          </div>
        </div>
        {fromMillis && toMillis && fromMillis > toMillis ? (
          <p className="field-error">The start date is after the end date, so no orders match.</p>
        ) : null}
        {report.undated > 0 ? (
          <p className="field-hint">
            {report.undated} order{report.undated === 1 ? '' : 's'} outside this range
            {orders.some((order) => !order.createdAt) ? ' or without a createdAt timestamp' : ''}.
          </p>
        ) : null}
        <p className="field-hint">
          Reports read at most {REPORT_ORDER_LIMIT} orders per refresh to stay within the Spark
          quota. Older orders beyond that limit are not included.
        </p>
      </section>

      <section className="stat-grid" aria-label="Report summary">
        <StatCard
          label="Recorded sales"
          value={formatCurrency(report.recordedSales)}
          hint={`${report.activeCount} billable orders`}
          icon="reports"
          loading={loading}
        />
        <StatCard
          label="Paid sales"
          value={formatCurrency(report.paidSales)}
          hint="Orders marked paid"
          icon="check"
          loading={loading}
        />
        <StatCard
          label="Units sold"
          value={report.units}
          hint="Across all line items"
          icon="inventory"
          loading={loading}
        />
        <StatCard
          label="Average order"
          value={formatCurrency(report.averageOrder)}
          hint={`Range: ${rangeLabel}`}
          icon="orders"
          loading={loading}
        />
      </section>

      {loading ? (
        <section className="panel">
          <div className="table-loading">
            <Spinner size={24} label="Calculating report…" />
          </div>
        </section>
      ) : orders.length === 0 ? (
        <section className="panel">
          <EmptyState
            icon="reports"
            title="No order data available"
            description="Reports use actual orders from Firestore. Once customers place orders, sales totals and product performance appear here."
          />
        </section>
      ) : filtered.length === 0 ? (
        <section className="panel">
          <EmptyState
            icon="reports"
            title="No orders in this range"
            description="Adjust the date filters or choose All time."
            action={
              <button type="button" className="button button-ghost" onClick={allTime}>
                Show all time
              </button>
            }
          />
        </section>
      ) : (
        <div className="report-grid">
          <section className="panel">
            <header className="panel-header">
              <div>
                <p className="eyebrow">Pipeline</p>
                <h2>Orders by status</h2>
              </div>
            </header>
            <div className="table-wrap">
              <table className="data-table compact-table">
                <thead>
                  <tr>
                    <th>Status</th>
                    <th>Orders</th>
                    <th>Recorded revenue</th>
                  </tr>
                </thead>
                <tbody>
                  {report.statusRows.map((row) => (
                    <tr key={row.status}>
                      <td>
                        <Badge value={row.status} />
                      </td>
                      <td className="numeric">{row.orders}</td>
                      <td className="numeric">
                        {SALES_EXCLUDED.has(row.status)
                          ? row.status === 'pending_confirmation'
                            ? 'Unverified'
                            : 'Excluded'
                          : formatCurrency(row.revenue)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>

          <section className="panel">
            <header className="panel-header">
              <div>
                <p className="eyebrow">Merchandise</p>
                <h2>Top products in range</h2>
              </div>
            </header>
            {report.topProducts.length === 0 ? (
              <EmptyState
                icon="products"
                title="No line items in this range"
                description="Orders in range have no item data to aggregate."
              />
            ) : (
              <div className="table-wrap">
                <table className="data-table compact-table">
                  <thead>
                    <tr>
                      <th>Product</th>
                      <th>Size</th>
                      <th>Units</th>
                      <th>Revenue</th>
                    </tr>
                  </thead>
                  <tbody>
                    {report.topProducts.map((row) => (
                      <tr key={`${row.name}-${row.size}`}>
                        <td>{row.name}</td>
                        <td>
                          <span className="chip">{row.size}</span>
                        </td>
                        <td className="numeric">{row.quantity}</td>
                        <td className="numeric">{formatCurrency(row.revenue)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </section>
        </div>
      )}

      {!loading && filtered.length > 0 ? (
        <section className="panel">
          <header className="panel-header">
            <div>
              <p className="eyebrow">Detail</p>
              <h2>Orders in range</h2>
            </div>
            <span className="muted">{titleCase(from || 'all')} to {titleCase(to || 'today')}</span>
          </header>
          <div className="table-wrap">
            <table className="data-table compact-table">
              <thead>
                <tr>
                  <th>Order</th>
                  <th>Created</th>
                  <th>Customer</th>
                  <th>Status</th>
                  <th>Payment</th>
                  <th>Total</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((order) => (
                  <tr key={order.id}>
                    <td>{orderLabel(order)}</td>
                    <td className="muted">{formatDateTime(order.createdAt)}</td>
                    <td>{order.customerName || order.customerEmail || '—'}</td>
                    <td>
                      <Badge value={order.status} />
                    </td>
                    <td>
                      <Badge value={order.paymentStatus} />
                    </td>
                    <td className="numeric">{formatCurrency(order.total)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      ) : null}
    </div>
  )
}
