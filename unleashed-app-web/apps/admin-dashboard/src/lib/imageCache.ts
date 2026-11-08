import { doc, getDoc, type Bytes } from 'firebase/firestore'
import { requireDb } from '../firebase'

const urlCache = new Map<string, string>()
const pending = new Map<string, Promise<string | null>>()

function cacheKey(imageId: string, version: number | null | undefined): string {
  return `${imageId}:${version ?? 0}`
}

/**
 * Loads an image stored in the Spark-compatible `product_images` collection
 * and returns a temporary object URL. Results are cached for the session.
 */
export async function getProductImageUrl(
  imageId: string,
  version?: number | null,
): Promise<string | null> {
  const key = cacheKey(imageId, version)
  const cached = urlCache.get(key)
  if (cached) return cached

  const existing = pending.get(key)
  if (existing) return existing

  const request = (async () => {
    try {
      const database = requireDb()
      const snapshot = await getDoc(doc(database, 'product_images', imageId))
      if (!snapshot.exists()) return null

      const data = snapshot.data()
      const bytes = data.bytes as Bytes | undefined
      if (!bytes?.toUint8Array) return null

      const contentType = String(data.contentType ?? 'image/jpeg')
      const array = bytes.toUint8Array()
      const blob = new Blob([array as unknown as BlobPart], { type: contentType })
      const url = URL.createObjectURL(blob)
      urlCache.set(key, url)
      return url
    } catch {
      return null
    } finally {
      pending.delete(key)
    }
  })()

  pending.set(key, request)
  return request
}

export function clearProductImageCache(): void {
  for (const url of urlCache.values()) URL.revokeObjectURL(url)
  urlCache.clear()
}
