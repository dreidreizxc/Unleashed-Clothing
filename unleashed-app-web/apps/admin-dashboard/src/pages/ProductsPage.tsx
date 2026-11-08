import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { deleteProduct, fetchProducts } from '../lib/firestore'
import { useAuth } from '../lib/AuthProvider'
import { formatCurrency, formatDateTime, timestampMillis, titleCase } from '../lib/format'
import type { Product, ProductStatus } from '../types'
import { PRODUCT_STATUSES } from '../types'
import { Badge, EmptyState, ErrorBanner, PageHeader, Spinner } from '../components/ui'
import { ProductImage } from '../components/ProductImage'
import { ConfirmDialog } from '../components/Modal'
import { useToast } from '../components/Toast'
import { Icon } from '../components/Icon'

export function ProductsPage() {
  const { user } = useAuth()
  const { notify } = useToast()
  const [products, setProducts] = useState<Product[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [search, setSearch] = useState('')
  const [status, setStatus] = useState<'all' | ProductStatus>('all')
  const [size, setSize] = useState('all')
  const [deleteTarget, setDeleteTarget] = useState<Product | null>(null)
  const [deleting, setDeleting] = useState(false)

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      setProducts(await fetchProducts())
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : 'Could not load products.')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    void load()
  }, [load])

  const allSizes = useMemo(
    () => Array.from(new Set(products.flatMap((product) => product.sizes))).sort(),
    [products],
  )

  const filtered = useMemo(() => {
    const term = search.trim().toLowerCase()
    return products.filter((product) => {
      const matchesTerm =
        !term ||
        product.name.toLowerCase().includes(term) ||
        product.description.toLowerCase().includes(term)
      const matchesStatus = status === 'all' || product.status === status
      const matchesSize = size === 'all' || product.sizes.includes(size)
      return matchesTerm && matchesStatus && matchesSize
    })
  }, [products, search, size, status])

  async function confirmDelete() {
    if (!deleteTarget || !user) return
    setDeleting(true)
    try {
      await deleteProduct(deleteTarget, { uid: user.uid, email: user.email })
      setProducts((current) => current.filter((product) => product.id !== deleteTarget.id))
      notify(`"${deleteTarget.name}" was deleted.`)
      setDeleteTarget(null)
    } catch (deleteError) {
      notify(deleteError instanceof Error ? deleteError.message : 'Could not delete the product.', 'error')
    } finally {
      setDeleting(false)
    }
  }

  const hasFilters = Boolean(search.trim()) || status !== 'all' || size !== 'all'

  return (
    <div className="page-stack">
      <PageHeader
        eyebrow="Catalog"
        title="Products"
        description="Manage T-shirts, caps, and hoodies. Prices are stored as integer centavos to match the existing Firestore schema."
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

      <section className="panel">
        <div className="toolbar">
          <label className="search-field">
            <Icon name="search" size={17} />
            <span className="sr-only">Search products</span>
            <input
              type="search"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Search name or description…"
            />
          </label>
          <div className="toolbar-filters">
            <label className="compact-field">
              <span>Status</span>
              <select value={status} onChange={(event) => setStatus(event.target.value as 'all' | ProductStatus)}>
                <option value="all">All statuses</option>
                {PRODUCT_STATUSES.map((option) => (
                  <option key={option} value={option}>
                    {titleCase(option)}
                  </option>
                ))}
              </select>
            </label>
            <label className="compact-field">
              <span>Size</span>
              <select value={size} onChange={(event) => setSize(event.target.value)}>
                <option value="all">All sizes</option>
                {allSizes.map((option) => (
                  <option key={option} value={option}>
                    {option}
                  </option>
                ))}
              </select>
            </label>
            {hasFilters ? (
              <button
                type="button"
                className="button button-small button-ghost"
                onClick={() => {
                  setSearch('')
                  setStatus('all')
                  setSize('all')
                }}
              >
                Clear filters
              </button>
            ) : null}
          </div>
        </div>

        {loading ? (
          <div className="table-loading">
            <Spinner size={24} label="Loading products…" />
          </div>
        ) : products.length === 0 ? (
          <EmptyState
            icon="products"
            title="No products yet"
            description="Add the first product to the catalog. Images, sizes, and per-size stock are managed in the product form."
            action={
              <Link to="/products/new" className="button button-primary">
                <Icon name="plus" size={16} />
                Add product
              </Link>
            }
          />
        ) : filtered.length === 0 ? (
          <EmptyState
            icon="search"
            title="No matching products"
            description="Try a different search term or clear the filters."
            action={
              <button
                type="button"
                className="button button-ghost"
                onClick={() => {
                  setSearch('')
                  setStatus('all')
                  setSize('all')
                }}
              >
                Clear filters
              </button>
            }
          />
        ) : (
          <>
            <div className="table-wrap">
              <table className="data-table product-table">
                <thead>
                  <tr>
                    <th>Product</th>
                    <th>Price</th>
                    <th>Sizes</th>
                    <th>Stock</th>
                    <th>Status</th>
                    <th>Updated</th>
                    <th className="actions-column">Actions</th>
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
                            <span className="muted">{product.category}</span>
                          </div>
                        </div>
                      </td>
                      <td className="numeric">{formatCurrency(product.price)}</td>
                      <td>
                        <div className="chip-row">
                          {product.sizes.length === 0 ? (
                            <span className="muted">—</span>
                          ) : (
                            product.sizes.map((productSize) => (
                              <span key={productSize} className="chip">
                                {productSize}
                              </span>
                            ))
                          )}
                        </div>
                      </td>
                      <td>
                        <span className={product.totalStock === 0 ? 'stock-zero' : ''}>
                          {product.totalStock} units
                        </span>
                      </td>
                      <td>
                        <Badge value={product.status} />
                      </td>
                      <td className="muted">{formatDateTime(product.updatedAt)}</td>
                      <td>
                        <div className="row-actions">
                          <Link
                            to={`/products/${product.id}`}
                            className="icon-button"
                            aria-label={`View ${product.name}`}
                            title="View product"
                          >
                            <Icon name="eye" size={16} />
                          </Link>
                          <Link
                            to={`/products/${product.id}/edit`}
                            className="icon-button"
                            aria-label={`Edit ${product.name}`}
                            title="Edit product"
                          >
                            <Icon name="edit" size={16} />
                          </Link>
                          <button
                            type="button"
                            className="icon-button icon-button-danger"
                            aria-label={`Delete ${product.name}`}
                            title="Delete product"
                            onClick={() => setDeleteTarget(product)}
                          >
                            <Icon name="trash" size={16} />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <footer className="table-footer">
              Showing {filtered.length} of {products.length} products
            </footer>
          </>
        )}
      </section>

      <ConfirmDialog
        open={Boolean(deleteTarget)}
        title="Delete product?"
        description={
          deleteTarget
            ? `"${deleteTarget.name}" will be removed from the catalog. Its stored image will also be deleted. This cannot be undone.`
            : ''
        }
        confirmLabel="Delete product"
        busy={deleting}
        onCancel={() => setDeleteTarget(null)}
        onConfirm={confirmDelete}
      />
    </div>
  )
}
