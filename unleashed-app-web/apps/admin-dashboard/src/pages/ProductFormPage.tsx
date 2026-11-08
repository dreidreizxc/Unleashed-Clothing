import { useEffect, useMemo, useState, type FormEvent } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { fetchProduct, saveProduct } from '../lib/firestore'
import { useAuth } from '../lib/AuthProvider'
import { timestampMillis, titleCase } from '../lib/format'
import type { Product, ProductCategory, ProductDraft, ProductStatus } from '../types'
import { DEFAULT_SIZES, PRODUCT_CATEGORIES } from '../types'
import { ErrorBanner, LoadingScreen, PageHeader, Spinner } from '../components/ui'
import { ImageField } from '../components/ImageField'
import { SizeChartField } from '../components/SizeChartField'
import { Icon } from '../components/Icon'
import { useToast } from '../components/Toast'

const CREATE_STATUSES: ProductStatus[] = ['active', 'inactive']
const EDIT_STATUSES: ProductStatus[] = ['active', 'inactive', 'archived']

export function ProductFormPage({ mode }: { mode: 'create' | 'edit' }) {
  const { id } = useParams()
  const navigate = useNavigate()
  const { user } = useAuth()
  const { notify } = useToast()

  const [existing, setExisting] = useState<Product | null>(null)
  const [loading, setLoading] = useState(mode === 'edit')
  const [loadError, setLoadError] = useState<string | null>(null)
  const [notFound, setNotFound] = useState(false)

  const [name, setName] = useState('')
  const [description, setDescription] = useState('')
  const [priceInput, setPriceInput] = useState('0.00')
  const [category, setCategory] = useState<ProductCategory>('T-Shirt')
  const [status, setStatus] = useState<ProductStatus>('active')
  const [selectedSizes, setSelectedSizes] = useState<string[]>(['S', 'M', 'L', 'XL'])
  const [extraSizes, setExtraSizes] = useState<string[]>([])
  const [stockInputs, setStockInputs] = useState<Record<string, string>>({
    S: '0',
    M: '0',
    L: '0',
    XL: '0',
  })
  const [customSize, setCustomSize] = useState('')

  const [imageFile, setImageFile] = useState<File | null>(null)
  const [removeImage, setRemoveImage] = useState(false)
  const [sizeChartFile, setSizeChartFile] = useState<File | null>(null)
  const [removeSizeChart, setRemoveSizeChart] = useState(false)
  const [saving, setSaving] = useState(false)
  const [saveStage, setSaveStage] = useState<'optimizing' | 'saving' | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (mode !== 'edit' || !id) return
    let active = true
    setLoading(true)
    setLoadError(null)
    setNotFound(false)
    void fetchProduct(id)
      .then((product) => {
        if (!active) return
        if (!product) {
          setNotFound(true)
          return
        }
        setExisting(product)
        setName(product.name)
        setDescription(product.description)
        setPriceInput((product.price / 100).toFixed(2))
        setCategory(product.category)
        setStatus(product.status)
        setSelectedSizes(product.sizes)
        setExtraSizes(product.sizes.filter((size) => !DEFAULT_SIZES.includes(size)))
        const nextStock: Record<string, string> = {}
        for (const size of product.sizes) {
          nextStock[size] = String(product.stock[size] ?? 0)
        }
        setStockInputs(nextStock)
      })
      .catch((loadFailure) => {
        if (active) {
          setLoadError(loadFailure instanceof Error ? loadFailure.message : 'Could not load the product.')
        }
      })
      .finally(() => {
        if (active) setLoading(false)
      })
    return () => {
      active = false
    }
  }, [id, mode])

    const availableSizes = useMemo(() => {
    const defaultSizes = category === 'Cap' ? ['One Size'] : DEFAULT_SIZES

    const categoryExtras = extraSizes.filter((size) =>
      category === 'Cap' ? size === 'One Size' : size !== 'One Size',
    )

    const categorySelected = selectedSizes.filter((size) =>
      category === 'Cap' ? size === 'One Size' : size !== 'One Size',
    )

    return Array.from(
      new Set([...defaultSizes, ...categoryExtras, ...categorySelected]),
    ).sort((a, b) => {
      const order = defaultSizes.indexOf(a)
      const otherOrder = defaultSizes.indexOf(b)

      if (order !== -1 && otherOrder !== -1) return order - otherOrder
      if (order !== -1) return -1
      if (otherOrder !== -1) return 1
      return a.localeCompare(b)
    })
  }, [category, extraSizes, selectedSizes])

      function handleCategoryChange(nextCategory: ProductCategory) {
    setCategory(nextCategory)

    if (nextCategory === 'Cap') {
      setSelectedSizes(['One Size'])
      setExtraSizes((current) =>
        current.includes('One Size') ? current : [...current, 'One Size'],
      )
      setStockInputs((current) => ({
        ...current,
        'One Size': current['One Size'] ?? '0',
      }))
      return
    }

    setSelectedSizes((current) => {
      const clothingSizes = current.filter((size) => size !== 'One Size')
      return clothingSizes.length > 0
        ? clothingSizes
        : ['S', 'M', 'L', 'XL']
    })

    setExtraSizes((current) =>
      current.filter((size) => size !== 'One Size'),
    )

    setStockInputs((current) => ({
      ...current,
      S: current.S ?? '0',
      M: current.M ?? '0',
      L: current.L ?? '0',
      XL: current.XL ?? '0',
    }))
  }

  function toggleSize(size: string) {
    setSelectedSizes((current) =>
      current.includes(size)
        ? current.filter((entry) => entry !== size)
        : [...current, size],
    )

    setStockInputs((current) => ({
      ...current,
      [size]: current[size] ?? '0',
    }))
  }

  function addCustomSize() {
    const size = customSize.trim().toUpperCase()

    if (!size) return

    if (!/^[A-Z0-9-]{1,8}$/.test(size)) {
      setError('Custom sizes can use up to 8 letters, numbers, or hyphens.')
      return
    }

    setExtraSizes((current) =>
      current.includes(size) ? current : [...current, size],
    )

    setSelectedSizes((current) =>
      current.includes(size) ? current : [...current, size],
    )

    setStockInputs((current) => ({
      ...current,
      [size]: current[size] ?? '0',
    }))

    setCustomSize('')
    setError(null)
  }

  async function submit(event: FormEvent) {
    event.preventDefault()
    if (!user) return
    setError(null)

    const trimmedName = name.trim()
    if (!trimmedName) {
      setError('Product name is required.')
      return
    }
    if (trimmedName.length > 120) {
      setError('Product name must be 120 characters or fewer.')
      return
    }
    if (description.length > 4000) {
      setError('Description must be 4,000 characters or fewer.')
      return
    }
    const priceNumber = Number.parseFloat(priceInput)
    if (!Number.isFinite(priceNumber) || priceNumber < 0) {
      setError('Enter a valid price zero or greater.')
      return
    }
    if (selectedSizes.length === 0) {
      setError('Choose at least one available size.')
      return
    }

    const stock: Record<string, number> = {}
    for (const size of selectedSizes) {
      const raw = stockInputs[size] ?? '0'
      const quantity = Number(raw)
      if (!Number.isInteger(quantity) || quantity < 0) {
        setError(`Stock for ${size} must be a whole number zero or greater.`)
        return
      }
      stock[size] = quantity
    }

    const draft: ProductDraft = {
      name: trimmedName,
      description: description.trim(),
      price: Math.round(priceNumber * 100),
      category,
      sizes: selectedSizes,
      stock,
      status,
    }

    setSaving(true)
    setSaveStage(null)
    try {
      const productId = await saveProduct({
        id: mode === 'edit' ? id : undefined,
        draft,
        existing,
        imageFile,
        removeImage,
        sizeChartFile,
        removeSizeChart,
        actor: { uid: user.uid, email: user.email },
        onStage: setSaveStage,
      })
      notify(mode === 'create' ? 'Product created successfully.' : 'Product updated successfully.')
      navigate(`/products/${productId}`, { replace: true })
    } catch (saveError) {
      const message = saveError instanceof Error ? saveError.message : 'Could not save the product.'
      setError(message)
      notify(message, 'error')
    } finally {
      setSaving(false)
      setSaveStage(null)
    }
  }

  if (loading) return <LoadingScreen label="Loading productâ€¦" />
  if (mode === 'edit' && notFound) {
    return (
      <div className="page-stack">
        <ErrorBanner message="This product could not be found. It may have been deleted." />
        <Link to="/products" className="button button-primary">
          <Icon name="arrowLeft" size={16} />
          Back to products
        </Link>
      </div>
    )
  }

  return (
    <div className="page-stack">
      <PageHeader
        eyebrow={mode === 'create' ? 'New product' : 'Edit product'}
        title={mode === 'create' ? 'Add product' : `Edit ${existing?.name ?? 'product'}`}
        description="Manage T-shirts, caps, and hoodies. Prices are entered in pesos and stored as integer centavos."
        actions={
          <Link to={mode === 'edit' && id ? `/products/${id}` : '/products'} className="button button-ghost">
            <Icon name="arrowLeft" size={16} />
            Cancel
          </Link>
        }
      />

      {loadError ? <ErrorBanner message={loadError} /> : null}
      {error ? <ErrorBanner message={error} /> : null}

      <form className="form-layout" onSubmit={submit}>
        <div className="form-main">
          <section className="panel form-panel">
            <header className="panel-header">
              <div>
                <p className="eyebrow">Details</p>
                <h2>Product information</h2>
              </div>
            </header>
            <div className="form-grid">
              <label className="field field-full">
                <span className="field-label">Product name</span>
                <input
                  type="text"
                  value={name}
                  onChange={(event) => setName(event.target.value)}
                  placeholder="Unleashed Classic Tee"
                  maxLength={120}
                  disabled={saving}
                  required
                />
              </label>
              <label className="field field-full">
                <span className="field-label">Description</span>
                <textarea
                  value={description}
                  onChange={(event) => setDescription(event.target.value)}
                  placeholder="Fabric, fit, print details, care instructionsâ€¦"
                  rows={5}
                  maxLength={4000}
                  disabled={saving}
                />
                <span className="field-hint">{description.length} / 4000 characters</span>
              </label>
              <label className="field">
                <span className="field-label">Price (PHP)</span>
                <input
                  type="number"
                  min="0"
                  step="0.01"
                  value={priceInput}
                  onChange={(event) => setPriceInput(event.target.value)}
                  disabled={saving}
                  required
                />
                <span className="field-hint">Displayed as â‚±{Number(priceInput || 0).toFixed(2)}</span>
              </label>
              <label className="field">
                <span className="field-label">Category</span>
                <select
                  value={category}
                  onChange={(event) =>
  handleCategoryChange(event.target.value as ProductCategory)
}
                  disabled={saving}
                >
                  {PRODUCT_CATEGORIES.map((option) => (
                    <option key={option} value={option}>
                      {option}
                    </option>
                  ))}
                </select>
                <span className="field-hint">Used by the mobile category filter.</span>
              </label>
              <label className="field">
                <span className="field-label">Visibility</span>
                <select
                  value={status}
                  onChange={(event) => setStatus(event.target.value as ProductStatus)}
                  disabled={saving}
                >
                  {(mode === 'create' ? CREATE_STATUSES : EDIT_STATUSES).map((option) => (
                    <option key={option} value={option}>
                      {titleCase(option)}
                    </option>
                  ))}
                </select>
                <span className="field-hint">
                  {status === 'active'
                    ? 'Visible to customers in the catalog.'
                    : status === 'archived'
                      ? 'Hidden and kept for historical orders.'
                      : 'Hidden from the storefront.'}
                </span>
              </label>
            </div>
          </section>

          <section className="panel form-panel">
            <header className="panel-header">
              <div>
                <p className="eyebrow">Variants</p>
                <h2>Sizes and stock</h2>
              </div>
            </header>
            <p className="field-hint">
              Select the sizes sold for this product and enter the current quantity for each size.
            </p>
            <div className="size-grid">
              {availableSizes.map((size) => {
                const selected = selectedSizes.includes(size)
                return (
                  <div key={size} className={`size-row ${selected ? 'is-selected' : ''}`}>
                    <label className="checkbox">
                      <input
                        type="checkbox"
                        checked={selected}
                        onChange={() => toggleSize(size)}
                        disabled={saving}
                      />
                      <span className="size-name">{size}</span>
                    </label>
                    <label className="stock-input">
                      <span className="sr-only">Stock for {size}</span>
                      <input
                        type="number"
                        min="0"
                        step="1"
                        value={stockInputs[size] ?? '0'}
                        onChange={(event) =>
                          setStockInputs((current) => ({ ...current, [size]: event.target.value }))
                        }
                        disabled={!selected || saving}
                      />
                    </label>
                  </div>
                )
              })}
                       {category !== 'Cap' && (
              <div className="custom-size-row">
                <input
                  type="text"
                  value={customSize}
                  onChange={(event) => setCustomSize(event.target.value)}
                  placeholder="Add custom size (e.g. 3XL)"
                  maxLength={8}
                  disabled={saving}
                  onKeyDown={(event) => {
                    if (event.key === 'Enter') {
                      event.preventDefault()
                      addCustomSize()
                    }
                  }}
                />
                <button
                  type="button"
                  className="button button-small button-ghost"
                  onClick={addCustomSize}
                  disabled={saving}
                >
                  <Icon name="plus" size={15} />
                  Add size
                </button>
              </div>
            )}
            </div>
          </section>
        </div>

        <aside className="form-side">
          <section className="panel form-panel">
            <header className="panel-header">
              <div>
                <p className="eyebrow">Media</p>
                <h2>Product image</h2>
              </div>
            </header>
            <ImageField
              imageId={existing?.imageId}
              imageVersion={timestampMillis(existing?.imageUpdatedAt)}
              imageUrl={existing?.imageUrl}
              hasExistingImage={Boolean(existing?.imageId || existing?.imageUrl)}
              selectedFile={imageFile}
              removeExisting={removeImage}
              disabled={saving}
              onSelect={(file) => {
                setImageFile(file)
                if (file) setRemoveImage(false)
              }}
              onRemoveExisting={setRemoveImage}
            />
              <div className="form-divider" />
              <h3>Size chart</h3>
              <SizeChartField
                sizeChartUrl={existing?.sizeChartUrl}
                version={timestampMillis(existing?.sizeChartUpdatedAt)}
                selectedFile={sizeChartFile}
                removeExisting={removeSizeChart}
                disabled={saving}
                onSelect={setSizeChartFile}
                onRemoveExisting={setRemoveSizeChart}
              />
          </section>

          <section className="panel form-panel sticky-panel">
            <header className="panel-header">
              <div>
                <p className="eyebrow">Publish</p>
                <h2>Save changes</h2>
              </div>
            </header>
            <p className="field-hint">
              Saving writes the product and image atomically. If either write fails, neither is saved and
              the existing image is preserved.
            </p>
            {saveStage ? (
              <div className="save-progress">
                <Spinner size={16} />
                {saveStage === 'optimizing' ? 'Optimizing imageâ€¦' : 'Saving product and imageâ€¦'}
              </div>
            ) : null}
            <div className="form-actions">
              <button type="submit" className="button button-primary button-block" disabled={saving}>
                {saving ? <Spinner size={17} /> : <Icon name="check" size={17} />}
                {saving ? 'Savingâ€¦' : mode === 'create' ? 'Create product' : 'Save changes'}
              </button>
              <Link to={mode === 'edit' && id ? `/products/${id}` : '/products'} className="button button-ghost button-block">
                Cancel
              </Link>
            </div>
            {mode === 'edit' ? (
              <p className="field-hint">
                Leave the image unchanged to keep the current one. Selecting a replacement is atomic with
                the product update.
              </p>
            ) : null}
          </section>
        </aside>
      </form>
    </div>
  )
}

