import type { Timestamp } from 'firebase/firestore'

const currencyFormatter = new Intl.NumberFormat('en-PH', {
  style: 'currency',
  currency: 'PHP',
  maximumFractionDigits: 2,
})

const numberFormatter = new Intl.NumberFormat('en-PH')

const dateFormatter = new Intl.DateTimeFormat('en-PH', {
  year: 'numeric',
  month: 'short',
  day: '2-digit',
})

const dateTimeFormatter = new Intl.DateTimeFormat('en-PH', {
  year: 'numeric',
  month: 'short',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
})

/** `price` and order totals are stored as integer centavos. */
export function formatCurrency(centavos: number | null | undefined): string {
  const value = Number.isFinite(centavos) ? Number(centavos) : 0
  return currencyFormatter.format(value / 100)
}

export function formatNumber(value: number | null | undefined): string {
  return numberFormatter.format(Number(value) || 0)
}

export function formatDate(value: Timestamp | null | undefined): string {
  if (!value) return '—'
  try {
    return dateFormatter.format(value.toDate())
  } catch {
    return '—'
  }
}

export function formatDateTime(value: Timestamp | null | undefined): string {
  if (!value) return '—'
  try {
    return dateTimeFormatter.format(value.toDate())
  } catch {
    return '—'
  }
}

export function timestampMillis(value: Timestamp | null | undefined): number | null {
  if (!value) return null
  try {
    return value.toMillis()
  } catch {
    return null
  }
}

export function totalStockOf(stock: Record<string, number> | undefined | null): number {
  if (!stock) return 0
  return Object.values(stock).reduce((sum, quantity) => sum + (Number(quantity) || 0), 0)
}

export function titleCase(value: string | null | undefined): string {
  if (!value) return '—'
  return value
    .replace(/[_-]+/g, ' ')
    .replace(/\b\w/g, (character) => character.toUpperCase())
}

export function orderLabel(order: { orderNumber?: string; id: string }): string {
  return order.orderNumber || `#${order.id.slice(0, 8).toUpperCase()}`
}

export function toDateInputValue(date: Date): string {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

export function initials(value: string | null | undefined): string {
  if (!value) return 'AD'
  return value
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() ?? '')
    .join('')
}
