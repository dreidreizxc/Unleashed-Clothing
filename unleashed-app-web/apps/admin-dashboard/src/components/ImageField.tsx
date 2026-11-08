import { useEffect, useRef, useState, type DragEvent } from 'react'
import { ACCEPTED_IMAGE_TYPES, MAX_INPUT_BYTES, formatFileSize, validateImageFile } from '../lib/images'
import { Icon } from './Icon'
import { ProductImage } from './ProductImage'

export function ImageField({
  imageId,
  imageVersion,
  imageUrl,
  hasExistingImage,
  selectedFile,
  removeExisting,
  disabled = false,
  label = 'Product image',
  hint = `JPG, PNG, or WebP. Up to ${formatFileSize(MAX_INPUT_BYTES)}; optimized to under 320 KB for Firestore. Images are stored in an admin-only Firestore collection because Cloud Storage is unavailable on the Spark plan.`,
  selectedAlt = 'Selected product preview',
  existingAlt = 'Current product image',
  onSelect,
  onRemoveExisting,
}: {
  imageId?: string | null
  imageVersion?: number | null
  imageUrl?: string | null
  hasExistingImage: boolean
  selectedFile: File | null
  removeExisting: boolean
  disabled?: boolean
  label?: string
  hint?: string
  selectedAlt?: string
  existingAlt?: string
  onSelect: (file: File | null) => void
  onRemoveExisting: (remove: boolean) => void
}) {
  const inputRef = useRef<HTMLInputElement>(null)
  const [previewUrl, setPreviewUrl] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [dragging, setDragging] = useState(false)

  useEffect(() => {
    if (!selectedFile) {
      setPreviewUrl(null)
      return
    }
    const url = URL.createObjectURL(selectedFile)
    setPreviewUrl(url)
    return () => URL.revokeObjectURL(url)
  }, [selectedFile])

  function selectFile(file: File | undefined | null) {
    if (!file || disabled) return
    const validationError = validateImageFile(file)
    if (validationError) {
      setError(validationError)
      return
    }
    setError(null)
    onRemoveExisting(false)
    onSelect(file)
  }

  function handleDrop(event: DragEvent<HTMLDivElement>) {
    event.preventDefault()
    setDragging(false)
    selectFile(event.dataTransfer.files?.[0])
  }

  function cancelSelection() {
    setError(null)
    onSelect(null)
    if (inputRef.current) inputRef.current.value = ''
  }

  function removeImage() {
    setError(null)
    onSelect(null)
    onRemoveExisting(true)
    if (inputRef.current) inputRef.current.value = ''
  }

  return (
    <div className="image-field">
      <div className="image-field-copy">
        <span className="field-label">{label}</span>
        <p className="field-hint">{hint}</p>
      </div>

      {selectedFile && previewUrl ? (
        <div className="image-preview-panel">
          <img src={previewUrl} alt={selectedAlt} />
          <div className="image-preview-meta">
            <strong>{selectedFile.name}</strong>
            <span>{formatFileSize(selectedFile.size)} • ready to optimize on save</span>
            <div className="inline-actions">
              <button type="button" className="button button-small button-ghost" onClick={() => inputRef.current?.click()} disabled={disabled}>
                Replace
              </button>
              <button type="button" className="button button-small button-ghost" onClick={cancelSelection} disabled={disabled}>
                Cancel selection
              </button>
            </div>
          </div>
        </div>
      ) : hasExistingImage && !removeExisting ? (
        <div className="image-preview-panel">
          <ProductImage
            imageId={imageId}
            version={imageVersion}
            imageUrl={imageUrl}
            alt={existingAlt}
            iconSize={34}
          />
          <div className="image-preview-meta">
            <strong>Current image</strong>
            <span>Leave unchanged to keep this image.</span>
            <div className="inline-actions">
              <button type="button" className="button button-small button-ghost" onClick={() => inputRef.current?.click()} disabled={disabled}>
                Replace image
              </button>
              <button type="button" className="button button-small button-danger-ghost" onClick={removeImage} disabled={disabled}>
                Remove image
              </button>
            </div>
          </div>
        </div>
      ) : (
        <div
          className={`upload-dropzone ${dragging ? 'is-dragging' : ''} ${disabled ? 'is-disabled' : ''}`}
          onDragOver={(event) => {
            event.preventDefault()
            if (!disabled) setDragging(true)
          }}
          onDragLeave={() => setDragging(false)}
          onDrop={handleDrop}
          onClick={() => !disabled && inputRef.current?.click()}
          onKeyDown={(event) => {
            if (!disabled && (event.key === 'Enter' || event.key === ' ')) inputRef.current?.click()
          }}
          role="button"
          tabIndex={disabled ? -1 : 0}
        >
          <span className="upload-icon">
            <Icon name={removeExisting ? 'image' : 'upload'} size={26} />
          </span>
          <strong>{removeExisting ? 'Image will be removed on save' : 'Drop an image here or browse'}</strong>
          <span>
            {removeExisting
              ? 'Choose a new image or undo the removal.'
              : 'Square images work best. The image is previewed before saving.'}
          </span>
          {removeExisting ? (
            <button
              type="button"
              className="button button-small button-ghost"
              onClick={(event) => {
                event.stopPropagation()
                onRemoveExisting(false)
              }}
              disabled={disabled}
            >
              Undo removal
            </button>
          ) : null}
        </div>
      )}

      <input
        ref={inputRef}
        type="file"
        accept={ACCEPTED_IMAGE_TYPES.join(',')}
        className="sr-only"
        disabled={disabled}
        onChange={(event) => {
          selectFile(event.target.files?.[0])
          event.target.value = ''
        }}
      />

      {error ? <p className="field-error">{error}</p> : null}
    </div>
  )
}
