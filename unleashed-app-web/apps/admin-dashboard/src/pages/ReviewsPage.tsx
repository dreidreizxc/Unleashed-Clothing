import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { deleteReview, fetchProducts, fetchReviews } from '../lib/firestore'
import { useAuth } from '../lib/AuthProvider'
import { formatDateTime } from '../lib/format'
import type { Product, ProductReview } from '../types'
import { EmptyState, ErrorBanner, PageHeader, Spinner } from '../components/ui'
import { ConfirmDialog } from '../components/Modal'
import { useToast } from '../components/Toast'
import { Icon } from '../components/Icon'

function Stars({ rating }: { rating: number }) {
  const safe = Math.max(0, Math.min(5, rating))
  return (
    <span className="review-stars" aria-label={`${safe} out of 5 stars`}>
      {[1, 2, 3, 4, 5].map((value) => (
        <span key={value} className={value <= safe ? 'is-filled' : ''}>
          <Icon name="star" size={14} />
        </span>
      ))}
    </span>
  )
}

export function ReviewsPage() {
  const { user } = useAuth()
  const { notify } = useToast()
  const [reviews, setReviews] = useState<ProductReview[]>([])
  const [products, setProducts] = useState<Product[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [search, setSearch] = useState('')
  const [rating, setRating] = useState<'all' | '1' | '2' | '3' | '4' | '5'>('all')
  const [deleteTarget, setDeleteTarget] = useState<ProductReview | null>(null)
  const [deleting, setDeleting] = useState(false)

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [nextReviews, nextProducts] = await Promise.all([fetchReviews(), fetchProducts()])
      setReviews(nextReviews)
      setProducts(nextProducts)
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : 'Could not load reviews.')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    void load()
  }, [load])

  const productNames = useMemo(() => {
    const map = new Map<string, string>()
    for (const product of products) map.set(product.id, product.name)
    return map
  }, [products])

  const filtered = useMemo(() => {
    const term = search.trim().toLowerCase()
    return reviews.filter((review) => {
      const productName = productNames.get(review.productId) ?? review.productId
      const matchesTerm =
        !term ||
        productName.toLowerCase().includes(term) ||
        (review.customerName ?? '').toLowerCase().includes(term) ||
        review.text.toLowerCase().includes(term)
      const matchesRating = rating === 'all' || review.rating === Number(rating)
      return matchesTerm && matchesRating
    })
  }, [productNames, rating, reviews, search])

  const average = useMemo(() => {
    if (reviews.length === 0) return 0
    return reviews.reduce((total, review) => total + review.rating, 0) / reviews.length
  }, [reviews])

  async function confirmDelete() {
    if (!deleteTarget || !user) return
    setDeleting(true)
    try {
      await deleteReview(deleteTarget, { uid: user.uid, email: user.email })
      setReviews((current) => current.filter((review) => review.id !== deleteTarget.id))
      notify('Review deleted.')
      setDeleteTarget(null)
    } catch (deleteError) {
      notify(deleteError instanceof Error ? deleteError.message : 'Could not delete the review.', 'error')
    } finally {
      setDeleting(false)
    }
  }

  const hasFilters = Boolean(search.trim()) || rating !== 'all'

  return (
    <div className="page-stack">
      <PageHeader
        eyebrow="People"
        title="Reviews"
        description="Product reviews submitted from delivered orders in the mobile app. Ratings are calculated from real review records only."
        actions={
          <button type="button" className="button button-ghost" onClick={load} disabled={loading}>
            {loading ? <Spinner size={16} /> : <Icon name="refresh" size={16} />}
            Refresh
          </button>
        }
      />

      {error ? <ErrorBanner message={error} onRetry={load} /> : null}

      {!loading && reviews.length > 0 ? (
        <div className="stat-grid">
          <div className="stat-card">
            <div className="stat-top">
              <span className="stat-label">Total reviews</span>
              <span className="stat-icon">
                <Icon name="star" size={18} />
              </span>
            </div>
            <div className="stat-value">{reviews.length}</div>
            <p className="stat-hint">All submitted product reviews</p>
          </div>
          <div className="stat-card">
            <div className="stat-top">
              <span className="stat-label">Average rating</span>
              <span className="stat-icon">
                <Icon name="star" size={18} />
              </span>
            </div>
            <div className="stat-value">{average.toFixed(1)} / 5</div>
            <p className="stat-hint">
              {reviews.filter((review) => review.rating <= 2).length} low ratings (1–2 stars)
            </p>
          </div>
        </div>
      ) : null}

      <section className="panel">
        <div className="toolbar">
          <label className="search-field">
            <Icon name="search" size={17} />
            <span className="sr-only">Search reviews</span>
            <input
              type="search"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Search product, customer, or review text…"
            />
          </label>
          <div className="toolbar-filters">
            <label className="compact-field">
              <span>Rating</span>
              <select value={rating} onChange={(event) => setRating(event.target.value as typeof rating)}>
                <option value="all">All ratings</option>
                <option value="5">5 stars</option>
                <option value="4">4 stars</option>
                <option value="3">3 stars</option>
                <option value="2">2 stars</option>
                <option value="1">1 star</option>
              </select>
            </label>
            {hasFilters ? (
              <button
                type="button"
                className="button button-small button-ghost"
                onClick={() => {
                  setSearch('')
                  setRating('all')
                }}
              >
                Clear filters
              </button>
            ) : null}
          </div>
        </div>

        {loading ? (
          <div className="table-loading">
            <Spinner size={24} label="Loading reviews…" />
          </div>
        ) : reviews.length === 0 ? (
          <EmptyState
            icon="star"
            title="No reviews yet"
            description="Customers can review products after an order is marked delivered. No sample reviews are shown."
          />
        ) : filtered.length === 0 ? (
          <EmptyState
            icon="search"
            title="No matching reviews"
            description="Try a different search term or rating filter."
          />
        ) : (
          <div className="review-list">
            {filtered.map((review) => {
              const productName = productNames.get(review.productId) ?? 'Deleted product'
              return (
                <article key={review.id} className="review-card">
                  <header className="review-card-header">
                    <div>
                      <Stars rating={review.rating} />
                      <Link className="review-product" to={`/products/${review.productId}`}>
                        {productName}
                      </Link>
                    </div>
                    <button
                      type="button"
                      className="button button-small button-danger"
                      onClick={() => setDeleteTarget(review)}
                    >
                      <Icon name="trash" size={15} />
                      Delete
                    </button>
                  </header>
                  {review.text ? <p className="review-text">{review.text}</p> : <p className="review-text muted">No written review.</p>}
                  <footer className="review-meta">
                    <span>{review.customerName || 'Customer'}</span>
                    <span className="mono-small">{review.customerId}</span>
                    {review.orderId ? <span>Order {review.orderId}</span> : null}
                    <span>{formatDateTime(review.createdAt)}</span>
                  </footer>
                </article>
              )
            })}
          </div>
        )}
      </section>

      <ConfirmDialog
        open={deleteTarget !== null}
        title="Delete this review?"
        description={
          deleteTarget
            ? `The ${deleteTarget.rating}-star review for "${
                productNames.get(deleteTarget.productId) ?? 'this product'
              }" will be removed. The customer can submit a new review for the same product later.`
            : ''
        }
        confirmLabel="Delete review"
        busy={deleting}
        onCancel={() => setDeleteTarget(null)}
        onConfirm={confirmDelete}
      />
    </div>
  )
}
