import { useEffect, useState } from 'react'
import { getProductImageUrl } from '../lib/imageCache'
import { Icon } from './Icon'

export function ProductImage({
  imageId,
  version,
  imageUrl,
  alt,
  className = '',
  iconSize = 28,
}: {
  imageId?: string | null
  version?: number | null
  imageUrl?: string | null
  alt: string
  className?: string
  iconSize?: number
}) {
  const [src, setSrc] = useState<string | null>(imageUrl || null)
  const [loading, setLoading] = useState(Boolean(imageId || imageUrl))

  useEffect(() => {
    let active = true

    if (imageUrl) {
      setSrc(imageUrl)
      setLoading(false)
      return () => {
        active = false
      }
    }

    if (!imageId) {
      setSrc(null)
      setLoading(false)
      return () => {
        active = false
      }
    }

    setLoading(true)
    void getProductImageUrl(imageId, version).then((url) => {
      if (!active) return
      setSrc(url)
      setLoading(false)
    })

    return () => {
      active = false
    }
  }, [imageId, imageUrl, version])

  return (
    <div className={`product-image ${className}`}>
      {loading ? <span className="skeleton product-image-skeleton" /> : null}
      {!loading && src ? (
        <img
          src={src}
          alt={alt}
          loading="lazy"
          onError={() => {
            setSrc(null)
          }}
        />
      ) : null}
      {!loading && !src ? (
        <span className="product-image-placeholder">
          <Icon name="shirt" size={iconSize} />
          <span>No image</span>
        </span>
      ) : null}
    </div>
  )
}
