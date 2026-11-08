import { useEffect, useRef, useState } from 'react'
import { Link, NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom'
import { useAuth } from '../lib/AuthProvider'
import { initials } from '../lib/format'
import {
  markAdminNotificationRead,
  markAllAdminNotificationsRead,
  notificationLink,
} from '../lib/notifications'
import { useAdminNotifications } from '../lib/useAdminNotifications'
import type { AdminNotification } from '../types'
import { NotificationCard } from './NotificationCard'
import { ErrorBanner, Spinner } from './ui'
import { useToast } from './Toast'
import { Icon, type IconName } from './Icon'

interface NavItem {
  to: string
  label: string
  icon: IconName
  end?: boolean
}

const storeNav: NavItem[] = [
  { to: '/', label: 'Overview', icon: 'dashboard', end: true },
  { to: '/products', label: 'Products', icon: 'products' },
  { to: '/inventory', label: 'Inventory', icon: 'inventory' },
  { to: '/orders', label: 'Orders', icon: 'orders' },
  { to: '/customers', label: 'Customers', icon: 'customers' },
  { to: '/messages', label: 'Messages', icon: 'messages' },
  { to: '/notifications', label: 'Notifications', icon: 'bell' },
  { to: '/reviews', label: 'Reviews', icon: 'star' },
  { to: '/announcements', label: 'Announcements', icon: 'messages' },
]

const systemNav: NavItem[] = [
  { to: '/reports', label: 'Reports', icon: 'reports' },
  { to: '/settings', label: 'Settings', icon: 'settings' },
]

function pageMeta(pathname: string): { eyebrow: string; title: string } {
  if (pathname === '/') return { eyebrow: 'UNLEASHED', title: 'Overview' }
  if (pathname === '/products/new') return { eyebrow: 'Catalog', title: 'Add product' }
  if (/^\/products\/[^/]+\/edit$/.test(pathname)) return { eyebrow: 'Catalog', title: 'Edit product' }
  if (/^\/products\/[^/]+$/.test(pathname)) return { eyebrow: 'Catalog', title: 'Product details' }
  if (pathname === '/products') return { eyebrow: 'Catalog', title: 'Products' }
  if (pathname === '/inventory') return { eyebrow: 'Stock control', title: 'Inventory' }
  if (/^\/orders\/[^/]+$/.test(pathname)) return { eyebrow: 'Sales', title: 'Order details' }
  if (pathname === '/orders') return { eyebrow: 'Sales', title: 'Orders' }
  if (pathname === '/customers') return { eyebrow: 'People', title: 'Customers' }
  if (pathname === '/messages') return { eyebrow: 'People', title: 'Messages' }
  if (pathname === '/notifications') return { eyebrow: 'Store', title: 'Notifications' }
  if (pathname === '/reviews') return { eyebrow: 'People', title: 'Reviews' }
  if (pathname === '/announcements') return { eyebrow: 'Store', title: 'Announcements' }
  if (pathname === '/reports') return { eyebrow: 'Insights', title: 'Reports' }
  if (pathname === '/settings') return { eyebrow: 'Account', title: 'Settings' }
  return { eyebrow: 'UNLEASHED', title: 'Admin' }
}

export function Layout() {
  const { user, signOut, isAdmin } = useAuth()
  const { notify } = useToast()
  const location = useLocation()
  const navigate = useNavigate()
  const [mobileOpen, setMobileOpen] = useState(false)
  const [signingOut, setSigningOut] = useState(false)
  const [notificationsOpen, setNotificationsOpen] = useState(false)
  const [markingAll, setMarkingAll] = useState(false)
  const notificationsRef = useRef<HTMLDivElement | null>(null)
  const { notifications, loading: notificationsLoading, error: notificationsError, unreadCount } =
    useAdminNotifications(Boolean(user && isAdmin))
  const meta = pageMeta(location.pathname)

  useEffect(() => {
    setMobileOpen(false)
    setNotificationsOpen(false)
  }, [location.pathname])

  useEffect(() => {
    if (!notificationsOpen) return

    function closeOnOutsideClick(event: MouseEvent) {
      if (!notificationsRef.current?.contains(event.target as Node)) {
        setNotificationsOpen(false)
      }
    }

    document.addEventListener('mousedown', closeOnOutsideClick)
    return () => document.removeEventListener('mousedown', closeOnOutsideClick)
  }, [notificationsOpen])

  async function openNotification(notification: AdminNotification) {
    setNotificationsOpen(false)
    if (!notification.isRead) {
      try {
        await markAdminNotificationRead(notification.id)
      } catch (error) {
        notify(
          error instanceof Error ? error.message : 'Could not mark that notification as read.',
          'error',
        )
      }
    }
    const target = notificationLink(notification)
    if (target) navigate(target)
  }

  async function markAllRead() {
    setMarkingAll(true)
    try {
      const count = await markAllAdminNotificationsRead()
      notify(
        count > 0
          ? `${count} notification${count === 1 ? '' : 's'} marked as read.`
          : 'No unread notifications.',
      )
    } catch (error) {
      notify(
        error instanceof Error ? error.message : 'Could not mark notifications as read.',
        'error',
      )
    } finally {
      setMarkingAll(false)
    }
  }

  async function logout() {
    setSigningOut(true)
    try {
      await signOut()
      navigate('/login', { replace: true })
    } catch (error) {
      notify(error instanceof Error ? error.message : 'Could not sign out.', 'error')
      setSigningOut(false)
    }
  }

  function renderNav(items: NavItem[]) {
    return items.map((item) => (
      <NavLink
        key={item.to}
        to={item.to}
        end={item.end}
        className={({ isActive }) => `nav-link ${isActive ? 'is-active' : ''}`}
      >
        <Icon name={item.icon} size={19} />
        <span>{item.label}</span>
      </NavLink>
    ))
  }

  return (
    <div className="app-shell">
      <button
        type="button"
        className={`sidebar-scrim ${mobileOpen ? 'is-visible' : ''}`}
        aria-label="Close navigation"
        onClick={() => setMobileOpen(false)}
      />
      <aside className={`sidebar ${mobileOpen ? 'is-open' : ''}`}>
        <div className="brand">
          <span className="brand-mark">U</span>
          <div>
            <strong>UNLEASHED</strong>
            <span>Admin console</span>
          </div>
          <button
            type="button"
            className="icon-button sidebar-close"
            aria-label="Close navigation"
            onClick={() => setMobileOpen(false)}
          >
            <Icon name="x" size={18} />
          </button>
        </div>

        <nav className="sidebar-nav" aria-label="Main navigation">
          <span className="nav-label">Store</span>
          {renderNav(storeNav)}
          <span className="nav-label">System</span>
          {renderNav(systemNav)}
        </nav>

        <div className="sidebar-account">
          <span className="avatar">{initials(user?.displayName || user?.email)}</span>
          <div className="sidebar-account-copy">
            <strong>{user?.displayName || 'Administrator'}</strong>
            <span>{user?.email}</span>
          </div>
          <button
            type="button"
            className="icon-button"
            aria-label="Sign out"
            title="Sign out"
            onClick={logout}
            disabled={signingOut}
          >
            <Icon name="logout" size={17} />
          </button>
        </div>
      </aside>

      <div className="main-shell">
        <header className="topbar">
          <button
            type="button"
            className="icon-button mobile-menu"
            aria-label="Open navigation"
            onClick={() => setMobileOpen(true)}
          >
            <Icon name="menu" size={20} />
          </button>
          <div className="topbar-title">
            <span>{meta.eyebrow}</span>
            <strong>{meta.title}</strong>
          </div>
          <div className="topbar-actions">
            <div className="notification-bell-wrap" ref={notificationsRef}>
              <button
                type="button"
                className={`icon-button notification-bell ${notificationsOpen ? 'is-active' : ''}`}
                aria-label={
                  unreadCount > 0
                    ? `Notifications, ${unreadCount} unread`
                    : 'Notifications'
                }
                aria-haspopup="dialog"
                aria-expanded={notificationsOpen}
                onClick={() => setNotificationsOpen((open) => !open)}
              >
                <Icon name="bell" size={18} />
                {unreadCount > 0 ? (
                  <span className="notification-badge">
                    {unreadCount > 99 ? '99+' : unreadCount}
                  </span>
                ) : null}
              </button>

              {notificationsOpen ? (
                <div className="notifications-popover" role="dialog" aria-label="Notifications">
                  <div className="notifications-popover-head">
                    <div>
                      <strong>Notifications</strong>
                      <span>{unreadCount > 0 ? `${unreadCount} unread` : 'All caught up'}</span>
                    </div>
                    <button
                      type="button"
                      className="button button-small button-ghost"
                      onClick={markAllRead}
                      disabled={markingAll || unreadCount === 0}
                    >
                      {markingAll ? <Spinner size={14} /> : <Icon name="check" size={14} />}
                      Mark all read
                    </button>
                  </div>

                  <div className="notifications-popover-list">
                    {notificationsLoading ? (
                      <div className="notifications-popover-state">
                        <Spinner size={20} label="Loading notifications…" />
                      </div>
                    ) : notificationsError ? (
                      <div className="notifications-popover-state">
                        <ErrorBanner message={notificationsError} />
                      </div>
                    ) : notifications.length === 0 ? (
                      <p className="notifications-popover-empty">
                        New orders and customer messages will appear here.
                      </p>
                    ) : (
                      notifications
                        .slice(0, 8)
                        .map((notification) => (
                          <NotificationCard
                            key={notification.id}
                            notification={notification}
                            onOpen={openNotification}
                            compact
                          />
                        ))
                    )}
                  </div>

                  <div className="notifications-popover-foot">
                    <Link
                      to="/notifications"
                      className="button button-small button-ghost"
                      onClick={() => setNotificationsOpen(false)}
                    >
                      View all notifications
                      <Icon name="chevronRight" size={14} />
                    </Link>
                  </div>
                </div>
              ) : null}
            </div>

            <span className="topbar-account">
              <Icon name="user" size={15} />
              {user?.email}
            </span>            <button type="button" className="button button-small button-ghost" onClick={logout} disabled={signingOut}>
              <Icon name="logout" size={15} />
              Sign out
            </button>
          </div>
        </header>

        <main className="main-content">
          <Outlet />
        </main>
      </div>
    </div>
  )
}
