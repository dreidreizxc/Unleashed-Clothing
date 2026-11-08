export const MAX_INPUT_BYTES = 8 * 1024 * 1024
/** Firestore document limit is 1 MiB; keep images comfortably below it. */
export const MAX_OUTPUT_BYTES = 320 * 1024
export const MAX_IMAGE_DIMENSION = 1200
/**
 * Size charts contain small labels, so they get a larger canvas and a higher
 * byte budget than catalogue thumbnails. They live in their own Firestore
 * document, well below the 1 MiB document limit.
 */
export const MAX_SIZE_CHART_OUTPUT_BYTES = 640 * 1024
export const MAX_SIZE_CHART_DIMENSION = 1800
export const ACCEPTED_IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp']

export interface PreparedImage {
  blob: Blob
  contentType: string
  width: number
  height: number
  size: number
}

export function formatFileSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)} KB`
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
}

export function validateImageFile(file: File): string | null {
  if (!ACCEPTED_IMAGE_TYPES.includes(file.type)) {
    return 'Use a JPG, PNG, or WebP image.'
  }
  if (file.size > MAX_INPUT_BYTES) {
    return `The image is ${formatFileSize(file.size)}. Choose one under ${formatFileSize(MAX_INPUT_BYTES)}.`
  }
  return null
}

async function loadSource(file: File): Promise<{
  source: CanvasImageSource
  width: number
  height: number
  cleanup: () => void
}> {
  if (typeof createImageBitmap === 'function') {
    try {
      const bitmap = await createImageBitmap(file)
      return {
        source: bitmap,
        width: bitmap.width,
        height: bitmap.height,
        cleanup: () => bitmap.close(),
      }
    } catch {
      // Fall through to the HTMLImageElement path.
    }
  }

  const objectUrl = URL.createObjectURL(file)
  try {
    const image = await new Promise<HTMLImageElement>((resolve, reject) => {
      const element = new Image()
      element.onload = () => resolve(element)
      element.onerror = () => reject(new Error('The image could not be read.'))
      element.src = objectUrl
    })
    return {
      source: image,
      width: image.naturalWidth,
      height: image.naturalHeight,
      cleanup: () => URL.revokeObjectURL(objectUrl),
    }
  } catch (error) {
    URL.revokeObjectURL(objectUrl)
    throw error
  }
}

function canvasToBlob(canvas: HTMLCanvasElement, type: string, quality: number): Promise<Blob | null> {
  return new Promise((resolve) => canvas.toBlob(resolve, type, quality))
}

interface PrepareOptions {
  maxOutputBytes: number
  maxDimension: number
  qualitySteps: number[]
}

/**
 * Resizes and re-encodes an image client-side so it can be stored in a
 * Firestore image document on the Spark plan without storing a large base64
 * payload in the product document itself.
 */
async function prepareImage(file: File, options: PrepareOptions): Promise<PreparedImage> {
  const validationError = validateImageFile(file)
  if (validationError) throw new Error(validationError)

  const loaded = await loadSource(file)
  try {
    if (!loaded.width || !loaded.height) {
      throw new Error('The selected image has invalid dimensions.')
    }

    let scale = Math.min(1, options.maxDimension / Math.max(loaded.width, loaded.height))
    let lastBlob: Blob | null = null

    for (let attempt = 0; attempt < 4; attempt += 1) {
      const canvas = document.createElement('canvas')
      canvas.width = Math.max(1, Math.round(loaded.width * scale))
      canvas.height = Math.max(1, Math.round(loaded.height * scale))
      const context = canvas.getContext('2d')
      if (!context) throw new Error('Your browser could not process the image.')

      context.fillStyle = '#ffffff'
      context.fillRect(0, 0, canvas.width, canvas.height)
      context.imageSmoothingEnabled = true
      context.imageSmoothingQuality = 'high'
      context.drawImage(loaded.source, 0, 0, canvas.width, canvas.height)

      for (const quality of options.qualitySteps) {
        let blob = await canvasToBlob(canvas, 'image/webp', quality)
        let contentType = 'image/webp'
        if (!blob || blob.type !== 'image/webp') {
          blob = await canvasToBlob(canvas, 'image/jpeg', quality)
          contentType = 'image/jpeg'
        }
        if (!blob) continue
        lastBlob = blob
        if (blob.size <= options.maxOutputBytes) {
          return {
            blob,
            contentType,
            width: canvas.width,
            height: canvas.height,
            size: blob.size,
          }
        }
      }

      scale *= 0.78
    }

    throw new Error(
      `This image is still ${formatFileSize(lastBlob?.size ?? file.size)} after optimization. ` +
        `Choose an image that can be reduced below ${formatFileSize(options.maxOutputBytes)}.`,
    )
  } finally {
    loaded.cleanup()
  }
}

export function prepareProductImage(file: File): Promise<PreparedImage> {
  return prepareImage(file, {
    maxOutputBytes: MAX_OUTPUT_BYTES,
    maxDimension: MAX_IMAGE_DIMENSION,
    qualitySteps: [0.86, 0.74, 0.62, 0.5, 0.4],
  })
}

export function prepareSizeChartImage(file: File): Promise<PreparedImage> {
  return prepareImage(file, {
    maxOutputBytes: MAX_SIZE_CHART_OUTPUT_BYTES,
    maxDimension: MAX_SIZE_CHART_DIMENSION,
    qualitySteps: [0.92, 0.86, 0.78, 0.68, 0.56, 0.46],
  })
}
