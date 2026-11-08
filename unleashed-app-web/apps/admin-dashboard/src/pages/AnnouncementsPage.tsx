import { useCallback, useEffect, useMemo, useState, type FormEvent } from 'react'
import {
  deleteAnnouncement,
  fetchAnnouncements,
  saveAnnouncement,
} from '../lib/firestore'
import { useAuth } from '../lib/AuthProvider'
import { formatDateTime } from '../lib/format'
import type { Announcement, AnnouncementDraft } from '../types'
import { Badge, EmptyState, ErrorBanner, PageHeader, Spinner } from '../components/ui'
import { ConfirmDialog, Modal } from '../components/Modal'
import { Icon } from '../components/Icon'
import { useToast } from '../components/Toast'

const EMPTY_DRAFT: AnnouncementDraft = {
  title: '',
  body: '',
  active: true,
  pinned: false,
}

export function AnnouncementsPage() {
  const { user } = useAuth()
  const { notify } = useToast()
  const [announcements, setAnnouncements] = useState<Announcement[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [search, setSearch] = useState('')
  const [onlyActive, setOnlyActive] = useState(false)

  const [editing, setEditing] = useState<Announcement | null>(null)
  const [formOpen, setFormOpen] = useState(false)
  const [draft, setDraft] = useState<AnnouncementDraft>(EMPTY_DRAFT)
  const [formError, setFormError] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)

  const [deleteTarget, setDeleteTarget] = useState<Announcement | null>(null)
  const [deleting, setDeleting] = useState(false)

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      setAnnouncements(await fetchAnnouncements())
    } catch (loadError) {
      setError(
        loadError instanceof Error
          ? loadError.message
          : 'Could not load announcements.',
      )
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    void load()
  }, [load])

  const filtered = useMemo(() => {
    const term = search.trim().toLowerCase()
    return announcements.filter((announcement) => {
      const matchesTerm =
        !term ||
        announcement.title.toLowerCase().includes(term) ||
        announcement.body.toLowerCase().includes(term)
      const matchesActive = !onlyActive || announcement.active
      return matchesTerm && matchesActive
    })
  }, [announcements, onlyActive, search])

  const activeCount = announcements.filter((announcement) => announcement.active).length

  function openCreate() {
    setEditing(null)
    setDraft(EMPTY_DRAFT)
    setFormError(null)
    setFormOpen(true)
  }

  function openEdit(announcement: Announcement) {
    setEditing(announcement)
    setDraft({
      title: announcement.title,
      body: announcement.body,
      active: announcement.active,
      pinned: announcement.pinned,
    })
    setFormError(null)
    setFormOpen(true)
  }

  function closeForm() {
    if (saving) return
    setFormOpen(false)
    setEditing(null)
    setFormError(null)
  }

  async function submit(event: FormEvent) {
    event.preventDefault()
    if (!user) return

    const title = draft.title.trim()
    const body = draft.body.trim()
    if (!title) {
      setFormError('Announcement title is required.')
      return
    }
    if (!body) {
      setFormError('Announcement message is required.')
      return
    }

    setSaving(true)
    setFormError(null)
    try {
      await saveAnnouncement({
        id: editing?.id,
        draft: { ...draft, title, body },
        actor: { uid: user.uid, email: user.email },
      })
      notify(editing ? 'Announcement updated.' : 'Announcement published.')
      setFormOpen(false)
      setEditing(null)
      await load()
    } catch (saveError) {
      const message =
        saveError instanceof Error
          ? saveError.message
          : 'Could not save the announcement.'
      setFormError(message)
      notify(message, 'error')
    } finally {
      setSaving(false)
    }
  }

  async function confirmDelete() {
    if (!deleteTarget || !user) return
    setDeleting(true)
    try {
      await deleteAnnouncement(deleteTarget, {
        uid: user.uid,
        email: user.email,
      })
      setAnnouncements((current) =>
        current.filter((announcement) => announcement.id !== deleteTarget.id),
      )
      notify('Announcement deleted.')
      setDeleteTarget(null)
    } catch (deleteError) {
      notify(
        deleteError instanceof Error
          ? deleteError.message
          : 'Could not delete the announcement.',
        'error',
      )
    } finally {
      setDeleting(false)
    }
  }

  return (
    <div className="page-stack">
      <PageHeader
        eyebrow="Store"
        title="Announcements"
        description="Public store news shown on the customer home screen. Active announcements are readable by guests; nothing here is private."
        actions={
          <>
            <button type="button" className="button button-ghost" onClick={load} disabled={loading}>
              {loading ? <Spinner size={16} /> : <Icon name="refresh" size={16} />}
              Refresh
            </button>
            <button type="button" className="button button-primary" onClick={openCreate}>
              <Icon name="plus" size={16} />
              New announcement
            </button>
          </>
        }
      />

      {error ? <ErrorBanner message={error} onRetry={load} /> : null}

      <section className="panel">
        <div className="toolbar">
          <label className="search-field">
            <Icon name="search" size={17} />
            <span className="sr-only">Search announcements</span>
            <input
              type="search"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Search announcements…"
            />
          </label>
          <div className="toolbar-filters">
            <label className="checkbox checkbox-pill">
              <input
                type="checkbox"
                checked={onlyActive}
                onChange={(event) => setOnlyActive(event.target.checked)}
              />
              <span>Active only ({activeCount})</span>
            </label>
          </div>
        </div>

        {loading ? (
          <div className="table-loading">
            <Spinner size={24} label="Loading announcements…" />
          </div>
        ) : announcements.length === 0 ? (
          <EmptyState
            icon="messages"
            title="No announcements yet"
            description="Publish store news, restock notices, or delivery updates for guests and customers."
            action={
              <button type="button" className="button button-primary" onClick={openCreate}>
                <Icon name="plus" size={16} />
                New announcement
              </button>
            }
          />
        ) : filtered.length === 0 ? (
          <EmptyState
            icon="search"
            title="No matching announcements"
            description="Try a different search term or clear the active filter."
          />
        ) : (
          <div className="table-wrap">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Announcement</th>
                  <th>Visibility</th>
                  <th>Created</th>
                  <th className="actions-column">Actions</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((announcement) => (
                  <tr key={announcement.id}>
                    <td>
                      <strong>{announcement.title || 'Untitled announcement'}</strong>
                      {announcement.pinned ? (
                        <span className="badge badge-info" style={{ marginLeft: 8 }}>
                          Pinned
                        </span>
                      ) : null}
                      <div className="field-hint">{announcement.body || 'No message'}</div>
                    </td>
                    <td>
                      <Badge
                        value={announcement.active ? 'active' : 'inactive'}
                        label={announcement.active ? 'Public' : 'Hidden'}
                      />
                    </td>
                    <td>{formatDateTime(announcement.createdAt)}</td>
                    <td className="actions-column">
                      <div className="inline-actions">
                        <button
                          type="button"
                          className="button button-small button-ghost"
                          onClick={() => openEdit(announcement)}
                        >
                          <Icon name="edit" size={15} />
                          Edit
                        </button>
                        <button
                          type="button"
                          className="button button-small button-danger"
                          onClick={() => setDeleteTarget(announcement)}
                        >
                          <Icon name="trash" size={15} />
                          Delete
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <Modal
        open={formOpen}
        title={editing ? 'Edit announcement' : 'New announcement'}
        description="This text appears on the mobile home screen when the announcement is active."
        onClose={closeForm}
        size="medium"
        footer={
          <>
            <button type="button" className="button button-ghost" onClick={closeForm} disabled={saving}>
              Cancel
            </button>
            <button
              type="submit"
              form="announcement-form"
              className="button button-primary"
              disabled={saving}
            >
              {saving ? <Spinner size={16} /> : <Icon name="check" size={16} />}
              {editing ? 'Save changes' : 'Publish'}
            </button>
          </>
        }
      >
        <form id="announcement-form" className="form-grid" onSubmit={submit}>
          {formError ? <ErrorBanner message={formError} /> : null}
          <label className="field field-full">
            <span className="field-label">Title</span>
            <input
              type="text"
              value={draft.title}
              onChange={(event) => setDraft((current) => ({ ...current, title: event.target.value }))}
              placeholder="Holiday delivery schedule"
              maxLength={120}
              disabled={saving}
              required
            />
            <span className="field-hint">{draft.title.length} / 120 characters</span>
          </label>
          <label className="field field-full">
            <span className="field-label">Message</span>
            <textarea
              value={draft.body}
              onChange={(event) => setDraft((current) => ({ ...current, body: event.target.value }))}
              placeholder="Orders placed after December 20 will ship in January…"
              rows={5}
              maxLength={1000}
              disabled={saving}
              required
            />
            <span className="field-hint">{draft.body.length} / 1000 characters</span>
          </label>
          <label className="checkbox">
            <input
              type="checkbox"
              checked={draft.active}
              onChange={(event) => setDraft((current) => ({ ...current, active: event.target.checked }))}
              disabled={saving}
            />
            <span>Active — visible to guests and customers</span>
          </label>
          <label className="checkbox">
            <input
              type="checkbox"
              checked={draft.pinned}
              onChange={(event) => setDraft((current) => ({ ...current, pinned: event.target.checked }))}
              disabled={saving}
            />
            <span>Pin to the top of the home screen</span>
          </label>
        </form>
      </Modal>

      <ConfirmDialog
        open={deleteTarget !== null}
        title="Delete this announcement?"
        description={
          deleteTarget
            ? `"${deleteTarget.title}" will be removed from the mobile home screen. This cannot be undone.`
            : ''
        }
        confirmLabel="Delete announcement"
        busy={deleting}
        onCancel={() => setDeleteTarget(null)}
        onConfirm={confirmDelete}
      />
    </div>
  )
}
