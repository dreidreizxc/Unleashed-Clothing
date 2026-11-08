import { useEffect, useRef, useState } from 'react'
import { ACCEPTED_IMAGE_TYPES, formatFileSize, MAX_INPUT_BYTES, validateImageFile } from '../lib/images'
import { resolveSizeChartUrl } from '../lib/sizeChart'
import { ProductImage } from './ProductImage'

export function SizeChartField({
  sizeChartUrl,
  version,
  selectedFile,
  removeExisting,
  disabled = false,
  onSelect,
  onRemoveExisting,
}: {
  sizeChartUrl?: string | null
  version?: number | null
  selectedFile: File | null
  removeExisting: boolean
  disabled?: boolean
  onSelect: (file: File | null) => void
  onRemoveExisting: (remove: boolean) => void
}) {
  const inputRef = useRef<HTMLInputElement>(null)
  const [previewUrl, setPreviewUrl] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const resolved = resolveSizeChartUrl(sizeChartUrl)
  const hasExistingChart = Boolean(resolved.docId || resolved.remoteUrl)

  useEffect(() => {
    if (!selectedFile) {
      setPreviewUrl(null)
      return
    }

    const url = URL.createObjectURL(selectedFile)
    setPreviewUrl(url)
    return () => URL.revokeObjectURL(url)
  }, [selectedFile])

  function selectFile(file: File | undefined) {
    if (!file || disabled) return

    const validationError = validateImageFile(file)
    if (validationError) {
      setError(validationError)
      if (inputRef.current) inputRef.current.value = ''
      return
    }

    setError(null)
    onRemoveExisting(false)
    onSelect(file)
  }

  return (
    <div className="size-chart-field">
      <p className="field-hint">
        Upload an optional size guide for this product. JPG, PNG, or WebP; up to {formatFileSize(MAX_INPUT_BYTES)}.
        The image is optimized before being stored in Firestore.
      </p>

      {selectedFile && previewUrl ? (
        <div className="size-chart-preview">
          <img
            src={previewUrl}
            alt="Selected size chart preview"
            style={{ display: 'block', width: '100%', maxHeight: 360, objectFit: 'contain' }}
          />
          <p className="field-hint">{selectedFile.name} · {formatFileSize(selectedFile.size)}</p>
        </div>
      ) : hasExistingChart && !removeExisting ? (
        <ProductImage
          imageId={resolved.docId}
          version={version}
          imageUrl={resolved.remoteUrl}
          alt="Current product size chart"
          className="size-chart-preview"
          iconSize={24}
        />
      ) : (
        <p className="field-hint">
          {removeExisting ? 'The current size chart will be removed when you save.' : 'No size chart uploaded.'}
        </p>
      )}

      {error ? <p className="field-error" role="alert">{error}</p> : null}

      <div className="inline-actions">
        <input
          ref={inputRef}
          type="file"
          accept={ACCEPTED_IMAGE_TYPES.join(',')}
          disabled={disabled}
          hidden
          onChange={(event) => {
            selectFile(event.target.files?.[0])
            event.currentTarget.value = ''
          }}
        />

        <button
          type="button"
          className="button-secondary"
          disabled={disabled}
          onClick={() => inputRef.current?.click()}
        >
          {selectedFile || (hasExistingChart && !removeExisting) ? 'Replace size chart' : 'Upload size chart'}
        </button>

        {selectedFile ? (
          <button
            type="button"
            className="button-secondary"
            disabled={disabled}
            onClick={() => {
              onSelect(null)
              setError(null)
            }}
          >
            Cancel replacement
          </button>
        ) : null}

        {hasExistingChart && !removeExisting && !selectedFile ? (
          <button
            type="button"
            className="button-secondary"
            disabled={disabled}
            onClick={() => onRemoveExisting(true)}
          >
            Remove size chart
          </button>
        ) : null}

        {removeExisting ? (
          <button
            type="button"
            className="button-secondary"
            disabled={disabled}
            onClick={() => onRemoveExisting(false)}
          >
            Undo removal
          </button>
        ) : null}
      </div>
    </div>
  )
}
