import type { ReactNode } from 'react'
import { Icon, type IconName } from './Icon'
import { titleCase } from '../lib/format'

export function Spinner({ size = 20, label }: { size?: number; label?: string }) {
  return (
    <span className="spinner-wrap" role="status" aria-live="polite">
      <span className="spinner" style={{ width: size, height: size }} />
      {label ? <span className="spinner-label">{label}</span> : <span className="sr-only">Loading</span>}
    </span>
  )
}

export function LoadingScreen({ label = 'Loading dashboard…' }: { label?: string }) {
  return (
    <div className="loading-screen">
      <div className="loading-mark">UC</div>
      <Spinner size={26} label={label} />
    </div>
  )
}

export function PageHeader({
  eyebrow,
  title,
  description,
  actions,
}: {
  eyebrow?: string
  title: string
  description?: string
  actions?: ReactNode
}) {
  return (
    <header className="page-header">
      <div>
        {eyebrow ? <p className="eyebrow">{eyebrow}</p> : null}
        <h1>{title}</h1>
        {description ? <p className="page-description">{description}</p> : null}
      </div>
      {actions ? <div className="page-actions">{actions}</div> : null}
    </header>
  )
}

export function EmptyState({
  icon = 'products',
  title,
  description,
  action,
}: {
  icon?: IconName
  title: string
  description?: string
  action?: ReactNode
}) {
  return (
    <div className="empty-state">
      <span className="empty-icon">
        <Icon name={icon} size={28} />
      </span>
      <h3>{title}</h3>
      {description ? <p>{description}</p> : null}
      {action ? <div className="empty-action">{action}</div> : null}
    </div>
  )
}

const badgeTone: Record<string, string> = {
  active: 'badge-success',
  paid: 'badge-success',
  delivered: 'badge-success',
  confirmed: 'badge-success',
  inactive: 'badge-muted',
  unfulfilled: 'badge-muted',
  unpaid: 'badge-warning',
  pending_confirmation: 'badge-warning',
  placed: 'badge-warning',
  processing: 'badge-info',
  ready_for_shipment: 'badge-info',
  shipped: 'badge-info',
  out_for_delivery: 'badge-info',
  rejected: 'badge-danger',
  cancelled: 'badge-danger',
  refunded: 'badge-danger',
  archived: 'badge-muted',
}

export function Badge({ value, label }: { value: string; label?: string }) {
  return <span className={`badge ${badgeTone[value] ?? 'badge-muted'}`}>{label ?? titleCase(value)}</span>
}

export function StatCard({
  label,
  value,
  hint,
  icon,
  loading = false,
}: {
  label: string
  value: ReactNode
  hint?: string
  icon: IconName
  loading?: boolean
}) {
  return (
    <div className="stat-card">
      <div className="stat-top">
        <span className="stat-label">{label}</span>
        <span className="stat-icon">
          <Icon name={icon} size={18} />
        </span>
      </div>
      <div className={`stat-value ${loading ? 'is-loading' : ''}`}>
        {loading ? <span className="skeleton skeleton-line" /> : value}
      </div>
      {hint ? <p className="stat-hint">{hint}</p> : null}
    </div>
  )
}

export function ErrorBanner({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <div className="error-banner" role="alert">
      <Icon name="alert" size={18} />
      <span>{message}</span>
      {onRetry ? (
        <button type="button" className="button button-small button-ghost" onClick={onRetry}>
          Try again
        </button>
      ) : null}
    </div>
  )
}

export function FieldError({ children }: { children?: ReactNode }) {
  if (!children) return null
  return <p className="field-error">{children}</p>
}
