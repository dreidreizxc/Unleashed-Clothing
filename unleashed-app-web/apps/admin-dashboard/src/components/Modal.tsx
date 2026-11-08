import { useEffect, type ReactNode } from 'react'
import { createPortal } from 'react-dom'
import { Icon } from './Icon'
import { Spinner } from './ui'

export function Modal({
  open,
  title,
  description,
  onClose,
  children,
  footer,
  size = 'medium',
}: {
  open: boolean
  title: string
  description?: string
  onClose: () => void
  children?: ReactNode
  footer?: ReactNode
  size?: 'small' | 'medium' | 'large'
}) {
  useEffect(() => {
    if (!open) return
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') onClose()
    }
    document.addEventListener('keydown', onKeyDown)
    const previousOverflow = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    return () => {
      document.removeEventListener('keydown', onKeyDown)
      document.body.style.overflow = previousOverflow
    }
  }, [open, onClose])

  if (!open) return null

  return createPortal(
    <div className="modal-backdrop" role="presentation" onMouseDown={() => onClose()}>
      <div
        className={`modal modal-${size}`}
        role="dialog"
        aria-modal="true"
        aria-label={title}
        onMouseDown={(event) => event.stopPropagation()}
      >
        <header className="modal-header">
          <div>
            <h2>{title}</h2>
            {description ? <p>{description}</p> : null}
          </div>
          <button type="button" className="icon-button" aria-label="Close dialog" onClick={onClose}>
            <Icon name="x" size={18} />
          </button>
        </header>
        {children ? <div className="modal-body">{children}</div> : null}
        {footer ? <footer className="modal-footer">{footer}</footer> : null}
      </div>
    </div>,
    document.body,
  )
}

export function ConfirmDialog({
  open,
  title,
  description,
  confirmLabel = 'Confirm',
  cancelLabel = 'Cancel',
  tone = 'danger',
  busy = false,
  onCancel,
  onConfirm,
}: {
  open: boolean
  title: string
  description: string
  confirmLabel?: string
  cancelLabel?: string
  tone?: 'danger' | 'primary'
  busy?: boolean
  onCancel: () => void
  onConfirm: () => void
}) {
  return (
    <Modal
      open={open}
      title={title}
      onClose={busy ? () => undefined : onCancel}
      size="small"
      footer={
        <>
          <button type="button" className="button button-ghost" onClick={onCancel} disabled={busy}>
            {cancelLabel}
          </button>
          <button
            type="button"
            className={`button ${tone === 'danger' ? 'button-danger' : 'button-primary'}`}
            onClick={onConfirm}
            disabled={busy}
          >
            {busy ? <Spinner size={16} /> : null}
            {confirmLabel}
          </button>
        </>
      }
    >
      <p className="confirm-copy">{description}</p>
    </Modal>
  )
}
