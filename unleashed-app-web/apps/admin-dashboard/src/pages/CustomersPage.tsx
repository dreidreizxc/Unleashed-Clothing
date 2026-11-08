import { useCallback, useEffect, useMemo, useState } from 'react'
import { fetchCustomers, fetchOrders } from '../lib/firestore'
import { formatCurrency, formatDate } from '../lib/format'
import type { Customer, Order } from '../types'
import { EmptyState, ErrorBanner, PageHeader, Spinner } from '../components/ui'
import { Icon } from '../components/Icon'

interface CustomerRow extends Customer {
  orderCount: number
  recordedSpend: number
}

export function CustomersPage() {
  const [customers, setCustomers] = useState<Customer[]>([])
  const [orders, setOrders] = useState<Order[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [search, setSearch] = useState('')

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [nextCustomers, nextOrders] = await Promise.all([fetchCustomers(), fetchOrders()])
      setCustomers(nextCustomers)
      setOrders(nextOrders)
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : 'Could not load customers.')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    void load()
  }, [load])

  const rows = useMemo<CustomerRow[]>(() => {
    const byCustomer = new Map<string, { orderCount: number; recordedSpend: number }>()
    for (const order of orders) {
      if (!order.customerId) continue
      const current = byCustomer.get(order.customerId) ?? { orderCount: 0, recordedSpend: 0 }
      if (order.status !== 'pending_confirmation' && order.status !== 'rejected') {
        current.orderCount += 1
      }
      if (
        order.status !== 'pending_confirmation' &&
        order.status !== 'rejected' &&
        order.status !== 'cancelled' &&
        order.status !== 'refunded'
      ) {
        current.recordedSpend += order.total
      }
      byCustomer.set(order.customerId, current)
    }

    return customers.map((customer) => {
      const stats = byCustomer.get(customer.id)
      return {
        ...customer,
        orderCount: stats?.orderCount ?? 0,
        recordedSpend: stats?.recordedSpend ?? 0,
      }
    })
  }, [customers, orders])

  const filtered = useMemo(() => {
    const term = search.trim().toLowerCase()
    if (!term) return rows
    return rows.filter(
      (row) =>
        (row.displayName || '').toLowerCase().includes(term) ||
        (row.email || '').toLowerCase().includes(term) ||
        (row.phone || '').toLowerCase().includes(term) ||
        row.id.toLowerCase().includes(term),
    )
  }, [rows, search])

  return (
    <div className="page-stack">
      <PageHeader
        eyebrow="People"
        title="Customers"
        description="Read-only customer profiles from Firestore. Passwords, tokens, and authentication secrets are never stored or displayed here."
        actions={
          <button type="button" className="button button-ghost" onClick={load} disabled={loading}>
            {loading ? <Spinner size={16} /> : <Icon name="refresh" size={16} />}
            Refresh
          </button>
        }
      />

      {error ? <ErrorBanner message={error} onRetry={load} /> : null}

      <section className="panel">
        <div className="toolbar">
          <label className="search-field">
            <Icon name="search" size={17} />
            <span className="sr-only">Search customers</span>
            <input
              type="search"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Search name, email, phone, or ID…"
            />
          </label>
          <span className="muted">
            {filtered.length} of {rows.length} profiles
          </span>
        </div>

        {loading ? (
          <div className="table-loading">
            <Spinner size={24} label="Loading customers…" />
          </div>
        ) : rows.length === 0 ? (
          <EmptyState
            icon="customers"
            title="No customer profiles yet"
            description="Customer profiles are created by the storefront. No sample customers are shown."
          />
        ) : filtered.length === 0 ? (
          <EmptyState icon="search" title="No matching customers" description="Try a different search term." />
        ) : (
          <div className="table-wrap">
            <table className="data-table customers-table">
              <thead>
                <tr>
                  <th>Customer</th>
                  <th>Contact</th>
                  <th>Orders</th>
                  <th>Recorded spend</th>
                  <th>Joined</th>
                  <th>Role</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((row) => (
                  <tr key={row.id}>
                    <td>
                      <div className="customer-cell">
                        <span className="avatar avatar-small">
                          {(row.displayName || row.email || '?').slice(0, 2).toUpperCase()}
                        </span>
                        <div className="stacked-cell">
                          <span>{row.displayName || 'Unnamed customer'}</span>
                          <span className="muted mono-small">{row.id}</span>
                        </div>
                      </div>
                    </td>
                    <td>
                      <div className="stacked-cell">
                        <span>{row.email || '—'}</span>
                        <span className="muted">{row.phone || 'No phone on file'}</span>
                      </div>
                    </td>
                    <td className="numeric">{row.orderCount}</td>
                    <td className="numeric">{formatCurrency(row.recordedSpend)}</td>
                    <td className="muted">{formatDate(row.createdAt)}</td>
                    <td>{row.role ? <span className="chip">{row.role}</span> : <span className="muted">customer</span>}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        <footer className="table-footer">
          Customer documents live in the <code>users</code> collection. Reads are restricted to the signed-in
          customer or an administrator by Firestore Security Rules.
        </footer>
      </section>
    </div>
  )
}
