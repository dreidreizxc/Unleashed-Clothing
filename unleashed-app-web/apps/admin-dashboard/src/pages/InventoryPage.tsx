import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { adjustStock, fetchInventoryLogs, fetchProducts } from '../lib/firestore'
import { useAuth } from '../lib/AuthProvider'
import { formatDateTime, timestampMillis, totalStockOf } from '../lib/format'
import type { InventoryLog, Product } from '../types'
import { Badge, EmptyState, ErrorBanner, LoadingScreen, PageHeader, Spinner } from '../components/ui'
import { Modal } from '../components/Modal'
import { ProductImage } from '../components/ProductImage'
import { Icon } from '../components/Icon'
import { useToast } from '../components/Toast'

export function InventoryPage() {
  const { user } = useAuth()
  const { notify } = useToast()
  const [products, setProducts] = useState<Product[]>([])
  const [logs, setLogs] = useState<InventoryLog[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [search, setSearch] = useState('')
  const [onlyLow, setOnlyLow] = useState(false)

  const [target, setTarget] = useState<Product | null>(null)
  const [size, setSize] = useState('')
  const [newQty, setNewQty] = useState('0')
  const [reason, setReason] = useState('')
  const [saving, setSaving] = useState(false)
  const [formError, setFormError] = useState<string | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [nextProducts, nextLogs] = await Promise.all([fetchProducts(), fetchInventoryLogs()])
      setProducts(nextProducts)
      setLogs(nextLogs)
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : 'Could not load inventory.')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    void load()
  }, [load])

  const filtered = useMemo(() => {
    const term = search.trim().toLowerCase()
    return products.filter((product) => {
      const matchesTerm = !term || product.name.toLowerCase().includes(term)
      const matchesLow = !onlyLow || product.totalStock <= 5
      return matchesTerm && matchesLow
    })
  }, [onlyLow, products, search])

  function openAdjust(product: Product, selectedSize?: string) {
    const firstSize = selectedSize || product.sizes[0] || ''
    setTarget(product)
    setSize(firstSize)
    setNewQty(String(product.stock[firstSize] ?? 0))
    setReason('')
    setFormError(null)
  }

  function changeSize(nextSize: string) {
    setSize(nextSize)
    if (target) setNewQty(String(target.stock[nextSize] ?? 0))
  }

  async function saveAdjustment() {
    if (!target || !user) return
    const quantity = Number(newQty)
    if (!Number.isInteger(quantity) || quantity < 0) {
      setFormError('Stock must be a whole number zero or greater.')
      return
    }
    if (!size) {
      setFormError('Choose a size to adjust.')
      return
    }

    setSaving(true)
    setFormError(null)
    try {
      await adjustStock({
        product: target,
        size,
        newQty: quantity,
        reason,
        actor: { uid: user.uid, email: user.email },
      })
      setProducts((current) =>
        current.map((product) => {
          if (product.id !== target.id) return product
          const nextStock = { ...product.stock, [size]: quantity }
          return { ...product, stock: nextStock, totalStock: totalStockOf(nextStock) }
        }),
      )
      notify(`Stock for ${target.name} (${size}) updated to ${quantity}.`)
      setTarget(null)
      setLogs(await fetchInventoryLogs())
    } catch (saveError) {
      const message = saveError instanceof Error ? saveError.message : 'Could not update stock.'
      setFormError(message)
      notify(message, 'error')
    } finally {
      setSaving(false)
    }
  }

  if (loading) return <LoadingScreen label="Loading inventory…" />

  const lowCount = products.filter((product) => product.totalStock <= 5).length

  return (
    <div className="page-stack">
      <PageHeader
        eyebrow="Stock control"
        title="Inventory"
        description="Stock is tracked per size. Every adjustment is written in a transaction and recorded in the inventory log."
        actions={
          <button type="button" className="button button-ghost" onClick={load}>
            <Icon name="refresh" size={16} />
            Refresh
          </button>
        }
      />

      {error ? <ErrorBanner message={error} onRetry={load} /> : null}

      <section className="panel">
        <div className="toolbar">
          <label className="search-field">
            <Icon name="search" size={17} />
            <span className="sr-only">Search inventory</span>
            <input
              type="search"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Search products…"
            />
          </label>
          <div className="toolbar-filters">
            <label className="checkbox checkbox-pill">
              <input type="checkbox" checked={onlyLow} onChange={(event) => setOnlyLow(event.target.checked)} />
              <span>Low stock only ({lowCount})</span>
            </label>
          </div>
        </div>

        {products.length === 0 ? (
          <EmptyState
            icon="inventory"
            title="Nothing to stock yet"
            description="Add a product first, then manage its quantities by size here."
            action={
              <Link to="/products/new" className="button button-primary">
                <Icon name="plus" size={16} />
                Add product
              </Link>
            }
          />
        ) : filtered.length === 0 ? (
          <EmptyState icon="search" title="No matching products" description="Try a different search." />
        ) : (
          <div className="table-wrap">
            <table className="data-table inventory-table">
              <thead>
                <tr>
                  <th>Product</th>
                  <th>Stock by size</th>
                  <th>Total</th>
                  <th className="actions-column">Adjust</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((product) => (
                  <tr key={product.id}>
                    <td>
                      <div className="product-cell">
                        <ProductImage
                          imageId={product.imageId}
                          version={timestampMillis(product.imageUpdatedAt)}
                          imageUrl={product.imageUrl}
                          alt={product.name}
                          className="thumb"
                          iconSize={18}
                        />
                        <div>
                          <Link to={`/products/${product.id}`} className="table-link">
                            {product.name}
                          </Link>
                          <span className="muted">
                            {product.sizes.length} {product.sizes.length === 1 ? 'size' : 'sizes'}
                          </span>
                        </div>
                      </div>
                    </td>
                    <td>
                      <div className="stock-size-grid">
                        {product.sizes.map((productSize) => {
                          const quantity = product.stock[productSize] ?? 0
                          return (
                            <button
                              key={productSize}
                              type="button"
                              className={`stock-size ${quantity === 0 ? 'is-out' : quantity <= 3 ? 'is-low' : ''}`}
                              onClick={() => openAdjust(product, productSize)}
                              title={`Adjust ${productSize}`}
                            >
                              <span>{productSize}</span>
                              <strong>{quantity}</strong>
                            </button>
                          )
                        })}
                      </div>
                    </td>
                    <td>
                      <span className={product.totalStock === 0 ? 'stock-zero' : ''}>{product.totalStock}</span>
                    </td>
                    <td>
                      <button
                        type="button"
                        className="button button-small button-ghost"
                        onClick={() => openAdjust(product)}
                        disabled={product.sizes.length === 0}
                      >
                        <Icon name="edit" size={15} />
                        Adjust
                      </button>
                    </td>
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
            <p className="eyebrow">Audit trail</p>
            <h2>Recent stock changes</h2>
          </div>
          <span className="muted">Latest {logs.length}</span>
        </header>
        {logs.length === 0 ? (
          <EmptyState
            icon="inventory"
            title="No stock changes recorded"
            description="Adjustments will appear here with the previous and new quantity."
          />
        ) : (
          <div className="table-wrap">
            <table className="data-table compact-table">
              <thead>
                <tr>
                  <th>When</th>
                  <th>Product</th>
                  <th>Size</th>
                  <th>Change</th>
                  <th>Reason</th>
                  <th>Admin</th>
                </tr>
              </thead>
              <tbody>
                {logs.map((log) => (
                  <tr key={log.id}>
                    <td className="muted">{formatDateTime(log.createdAt)}</td>
                    <td>{log.productName || log.productId}</td>
                    <td>
                      <span className="chip">{log.size}</span>
                    </td>
                    <td>
                      <span className={log.delta >= 0 ? 'delta-up' : 'delta-down'}>
                        {log.delta >= 0 ? '+' : ''}
                        {log.delta} ({log.previousQty} → {log.newQty})
                      </span>
                    </td>
                    <td>{log.reason}</td>
                    <td className="muted">{log.adminEmail || '—'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <Modal
        open={Boolean(target)}
        title={target ? `Adjust stock · ${target.name}` : 'Adjust stock'}
        description="This writes the new quantity and an inventory log entry in one transaction."
        onClose={saving ? () => undefined : () => setTarget(null)}
        footer={
          <>
            <button type="button" className="button button-ghost" onClick={() => setTarget(null)} disabled={saving}>
              Cancel
            </button>
            <button type="button" className="button button-primary" onClick={saveAdjustment} disabled={saving}>
              {saving ? <Spinner size={16} /> : <Icon name="check" size={16} />}
              Save adjustment
            </button>
          </>
        }
      >
        {target ? (
          <div className="form-stack">
            <div className="adjust-summary">
              <div>
                <span>Current total</span>
                <strong>{target.totalStock} units</strong>
              </div>
              <div>
                <span>Product status</span>
                <Badge value={target.status} />
              </div>
            </div>
            <label className="field">
              <span className="field-label">Size</span>
              <select value={size} onChange={(event) => changeSize(event.target.value)} disabled={saving}>
                {target.sizes.map((option) => (
                  <option key={option} value={option}>
                    {option} — current {target.stock[option] ?? 0}
                  </option>
                ))}
              </select>
            </label>
            <label className="field">
              <span className="field-label">New quantity</span>
              <input
                type="number"
                min="0"
                step="1"
                value={newQty}
                onChange={(event) => setNewQty(event.target.value)}
                disabled={saving}
              />
              <span className="field-hint">
                Previous quantity: {target.stock[size] ?? 0}. Negative quantities are not allowed.
              </span>
            </label>
            <label className="field">
              <span className="field-label">Reason</span>
              <input
                type="text"
                value={reason}
                onChange={(event) => setReason(event.target.value)}
                placeholder="Restock, damaged item, stock count…"
                maxLength={200}
                disabled={saving}
              />
            </label>
            {formError ? <p className="field-error">{formError}</p> : null}
          </div>
        ) : null}
      </Modal>
    </div>
  )
}
