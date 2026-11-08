import { useCallback, useEffect, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { deleteProduct, fetchProduct } from '../lib/firestore'
import { useAuth } from '../lib/AuthProvider'
import { formatCurrency, formatDateTime, timestampMillis } from '../lib/format'
import type { Product } from '../types'
import { Badge, ErrorBanner, LoadingScreen } from '../components/ui'
import { ProductImage } from '../components/ProductImage'
import { ConfirmDialog } from '../components/Modal'
import { Icon } from '../components/Icon'
import { useToast } from '../components/Toast'

export function ProductDetailPage() {
  const { id } = useParams()
  const navigate = useNavigate()
  const { user } = useAuth()
  const { notify } = useToast()
  const [product, setProduct] = useState<Product | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [confirming, setConfirming] = useState(false)
  const [deleting, setDeleting] = useState(false)

  const load = useCallback(async () => {
    if (!id) return
    setLoading(true)
    setError(null)
    try {
      setProduct(await fetchProduct(id))
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : 'Could not load the product.')
    } finally {
      setLoading(false)
    }
  }, [id])

  useEffect(() => {
    void load()
  }, [load])

  async function remove() {
    if (!product || !user) return
    setDeleting(true)
    try {
      await deleteProduct(product, { uid: user.uid, email: user.email })
      notify(`"${product.name}" was deleted.`)
      navigate('/products', { replace: true })
    } catch (deleteError) {
      notify(deleteError instanceof Error ? deleteError.message : 'Could not delete the product.', 'error')
      setDeleting(false)
    }
  }

  if (loading) return <LoadingScreen label="Loading product…" />
  if (error) {
    return (
      <div className="page-stack">
        <ErrorBanner message={error} onRetry={load} />
        <Link to="/products" className="button button-ghost">
          <Icon name="arrowLeft" size={16} />
          Back to products
        </Link>
      </div>
    )
  }
  if (!product) {
    return (
      <div className="page-stack">
        <ErrorBanner message="This product no longer exists." />
        <Link to="/products" className="button button-primary">
          <Icon name="arrowLeft" size={16} />
          Back to products
        </Link>
      </div>
    )
  }

  const outOfStock = product.totalStock === 0

  return (
    <div className="page-stack">
      <div className="page-header">
        <div>
          <Link to="/products" className="back-link">
            <Icon name="arrowLeft" size={15} />
            Products
          </Link>
          <h1>{product.name}</h1>
          <div className="detail-meta">
            <Badge value={product.status} />
            <span>{product.category}</span>
            <span>Updated {formatDateTime(product.updatedAt)}</span>
          </div>
        </div>
        <div className="page-actions">
          <Link to={`/products/${product.id}/edit`} className="button button-primary">
            <Icon name="edit" size={16} />
            Edit product
          </Link>
          <button type="button" className="button button-danger-ghost" onClick={() => setConfirming(true)}>
            <Icon name="trash" size={16} />
            Delete
          </button>
        </div>
      </div>

      <div className="detail-grid">
        <section className="panel detail-media">
          <ProductImage
            imageId={product.imageId}
            version={timestampMillis(product.imageUpdatedAt)}
            imageUrl={product.imageUrl}
            alt={product.name}
            iconSize={52}
          />
        </section>

        <div className="detail-side">
          <section className="panel">
            <header className="panel-header">
              <div>
                <p className="eyebrow">Pricing</p>
                <h2>{formatCurrency(product.price)}</h2>
              </div>
            </header>
            <dl className="detail-list">
              <div>
                <dt>Price unit</dt>
                <dd>Integer centavos (PHP)</dd>
              </div>
              <div>
                <dt>Total stock</dt>
                <dd className={outOfStock ? 'stock-zero' : ''}>
                  {outOfStock ? 'Out of stock' : `${product.totalStock} units`}
                </dd>
              </div>
              <div>
                <dt>Created</dt>
                <dd>{formatDateTime(product.createdAt)}</dd>
              </div>
            </dl>
          </section>

          <section className="panel">
            <header className="panel-header">
              <div>
                <p className="eyebrow">Description</p>
                <h2>About this product</h2>
              </div>
            </header>
            <p className="description-copy">
              {product.description || 'No description has been added yet.'}
            </p>
          </section>
        </div>
      </div>

      <section className="panel">
        <header className="panel-header">
          <div>
            <p className="eyebrow">Inventory</p>
            <h2>Stock by size</h2>
          </div>
          <Link to="/inventory" className="text-link">
            Adjust stock <Icon name="chevronRight" size={15} />
          </Link>
        </header>
        {product.sizes.length === 0 ? (
          <p className="muted">No sizes are configured for this product.</p>
        ) : (
          <div className="table-wrap">
            <table className="data-table compact-table">
              <thead>
                <tr>
                  <th>Size</th>
                  <th>Stock</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {product.sizes.map((size) => {
                  const quantity = product.stock[size] ?? 0
                  return (
                    <tr key={size}>
                      <td>
                        <span className="chip">{size}</span>
                      </td>
                      <td className="numeric">{quantity}</td>
                      <td>
                        {quantity === 0 ? (
                          <span className="badge badge-danger">Out of stock</span>
                        ) : quantity <= 3 ? (
                          <span className="badge badge-warning">Low stock</span>
                        ) : (
                          <span className="badge badge-success">In stock</span>
                        )}
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <ConfirmDialog
        open={confirming}
        title="Delete product?"
        description={`"${product.name}" and its stored image will be permanently deleted. This cannot be undone.`}
        confirmLabel="Delete product"
        busy={deleting}
        onCancel={() => setConfirming(false)}
        onConfirm={remove}
      />
    </div>
  )
}
