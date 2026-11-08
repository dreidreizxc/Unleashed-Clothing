/**
 * Size charts use the same Spark-compatible storage strategy as product
 * images: the bytes live in an admin-write/public-read Firestore document and
 * the product only stores a lightweight reference in `sizeChartUrl`.
 *
 * Cloud Storage is unavailable on this project's Spark plan, so the reference
 * uses the `firestore://` scheme instead of an HTTPS download URL:
 *
 *   firestore://product_images/sizechart_<productId>
 *
 * The Flutter app understands the same reference format. If this project is
 * later upgraded to Blaze and a Storage bucket is created, `sizeChartUrl` can
 * hold a normal HTTPS URL instead; the readers already support both forms.
 */
export const SIZE_CHART_COLLECTION = 'product_images'
export const SIZE_CHART_DOC_PREFIX = 'sizechart_'

export function sizeChartDocId(productId: string): string {
  return `${SIZE_CHART_DOC_PREFIX}${productId}`
}

export function sizeChartRef(productId: string): string {
  return `firestore://${SIZE_CHART_COLLECTION}/${sizeChartDocId(productId)}`
}

export interface ResolvedSizeChart {
  /** Firestore document id inside `product_images`, when applicable. */
  docId: string | null
  /** Direct HTTPS URL, when the chart is hosted outside Firestore. */
  remoteUrl: string | null
}

export function resolveSizeChartUrl(url?: string | null): ResolvedSizeChart {
  const trimmed = url?.trim()
  if (!trimmed) return { docId: null, remoteUrl: null }

  if (/^https?:\/\//i.test(trimmed)) {
    return { docId: null, remoteUrl: trimmed }
  }

  try {
    const parsed = new URL(trimmed)
    if (parsed.protocol === 'firestore:' && parsed.host === SIZE_CHART_COLLECTION) {
      const docId = decodeURIComponent(
        parsed.pathname.replace(/^\/+/, '').split('/')[0] ?? '',
      ).trim()
      if (docId) return { docId, remoteUrl: null }
    }
  } catch {
    // Fall through to the legacy forms below.
  }

  // Tolerate a bare document path entered by an earlier version of the app.
  const legacy = trimmed.replace(/^\/+/, '')
  if (legacy.startsWith(`${SIZE_CHART_COLLECTION}/`)) {
    const docId = legacy.slice(SIZE_CHART_COLLECTION.length + 1).split('/')[0]?.trim()
    if (docId) return { docId, remoteUrl: null }
  }

  return { docId: null, remoteUrl: null }
}

export function sizeChartDocIdFromUrl(url?: string | null): string | null {
  return resolveSizeChartUrl(url).docId
}
