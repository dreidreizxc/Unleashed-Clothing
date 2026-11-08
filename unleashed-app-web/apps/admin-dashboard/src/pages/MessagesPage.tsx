import { useCallback, useEffect, useRef, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import {
  fetchChatMessages,
  fetchChats,
  markChatReadByAdmin,
  sendAdminReply,
} from '../lib/firestore'
import { useAuth } from '../lib/AuthProvider'
import { useToast } from '../components/Toast'
import { formatDateTime } from '../lib/format'
import type { ChatMessage, CustomerChat } from '../types'
import { EmptyState, ErrorBanner, PageHeader, Spinner } from '../components/ui'
import { Icon } from '../components/Icon'

export function MessagesPage() {
  const { user } = useAuth()
  const { notify } = useToast()
  const [searchParams, setSearchParams] = useSearchParams()
  const requestedCustomerId = searchParams.get('customerId')

  const [chats, setChats] = useState<CustomerChat[]>([])
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [messages, setMessages] = useState<ChatMessage[]>([])
  const [draft, setDraft] = useState('')
  const [loadingChats, setLoadingChats] = useState(true)
  const [loadingMessages, setLoadingMessages] = useState(false)
  const [sending, setSending] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const threadRef = useRef<HTMLDivElement | null>(null)

  const loadChats = useCallback(async () => {
    setLoadingChats(true)
    setError(null)
    try {
      const next = await fetchChats()
      setChats(next)
      setSelectedId((current) =>
        current && next.some((chat) => chat.customerId === current)
          ? current
          : next[0]?.customerId ?? null,
      )
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : 'Could not load conversations.')
    } finally {
      setLoadingChats(false)
    }
  }, [])

  useEffect(() => {
    void loadChats()
  }, [loadChats])

  // A notification can deep-link to a specific conversation.
  useEffect(() => {
    if (!requestedCustomerId) return
    if (chats.some((chat) => chat.customerId === requestedCustomerId)) {
      setSelectedId(requestedCustomerId)
    }
  }, [chats, requestedCustomerId])

  function selectChat(customerId: string) {
    setSelectedId(customerId)
    if (requestedCustomerId) {
      setSearchParams({}, { replace: true })
    }
  }

  const loadMessages = useCallback(async (customerId: string) => {
    setLoadingMessages(true)
    try {
      const next = await fetchChatMessages(customerId)
      setMessages(next)
      if (next.some((message) => message.senderRole === 'customer' && !message.isRead)) {
        await markChatReadByAdmin(customerId)
        setChats((current) =>
          current.map((chat) =>
            chat.customerId === customerId ? { ...chat, unreadByAdmin: 0 } : chat,
          ),
        )
      }
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : 'Could not load messages.')
    } finally {
      setLoadingMessages(false)
    }
  }, [])

  useEffect(() => {
    if (selectedId) void loadMessages(selectedId)
  }, [selectedId, loadMessages])

  useEffect(() => {
    if (threadRef.current) {
      threadRef.current.scrollTop = threadRef.current.scrollHeight
    }
  }, [messages])

  const selectedChat = chats.find((chat) => chat.customerId === selectedId) ?? null

  async function send() {
    if (!selectedId || !user) return
    const text = draft.trim()
    if (!text) {
      notify('Type a reply before sending.', 'error')
      return
    }
    setSending(true)
    setError(null)
    try {
      await sendAdminReply({
        customerId: selectedId,
        text,
        actor: { uid: user.uid, email: user.email },
      })
      setDraft('')
      await loadMessages(selectedId)
      await loadChats()
      notify('Reply sent to the customer.')
    } catch (sendError) {
      const message = sendError instanceof Error ? sendError.message : 'Could not send the reply.'
      setError(message)
      notify(message, 'error')
    } finally {
      setSending(false)
    }
  }

  return (
    <div className="page-stack">
      <PageHeader
        eyebrow="People"
        title="Messages"
        description="Customer support conversations from the mobile app. Replies are written as the store administrator."
        actions={
          <button type="button" className="button button-ghost" onClick={loadChats} disabled={loadingChats}>
            {loadingChats ? <Spinner size={16} /> : <Icon name="refresh" size={16} />}
            Refresh
          </button>
        }
      />

      {error ? <ErrorBanner message={error} onRetry={loadChats} /> : null}

      {loadingChats ? (
        <section className="panel table-loading">
          <Spinner size={24} label="Loading conversations…" />
        </section>
      ) : chats.length === 0 ? (
        <section className="panel">
          <EmptyState
            icon="messages"
            title="No conversations yet"
            description="Customers can start a conversation from the Profile tab in the mobile app. No sample conversations are shown."
          />
        </section>
      ) : (
        <section className="panel messages-panel">
          <div className="messages-layout">
            <aside className="messages-list" aria-label="Conversations">
              {chats.map((chat) => (
                <button
                  key={chat.customerId}
                  type="button"
                  className={`message-thread-item ${chat.customerId === selectedId ? 'is-active' : ''}`}
                  onClick={() => selectChat(chat.customerId)}
                >
                  <span className="message-thread-top">
                    <strong>{chat.customerName || 'Customer'}</strong>
                    {chat.unreadByAdmin > 0 ? (
                      <span className="message-unread">{chat.unreadByAdmin}</span>
                    ) : null}
                  </span>
                  <span className="message-thread-preview">
                    {chat.lastMessage || 'No messages yet'}
                  </span>
                  <span className="message-thread-time">
                    {chat.lastMessageAt ? formatDateTime(chat.lastMessageAt) : formatDateTime(chat.updatedAt)}
                  </span>
                </button>
              ))}
            </aside>

            <div className="messages-thread">
              <header className="messages-thread-header">
                <div>
                  <strong>{selectedChat?.customerName || 'Customer'}</strong>
                  <span className="muted mono-small">{selectedId}</span>
                </div>
                <span className="chip">{selectedChat?.unreadByCustomer ?? 0} unread for customer</span>
              </header>

              <div className="messages-thread-body" ref={threadRef}>
                {loadingMessages ? (
                  <div className="table-loading">
                    <Spinner size={22} label="Loading messages…" />
                  </div>
                ) : messages.length === 0 ? (
                  <EmptyState
                    icon="messages"
                    title="No messages in this conversation"
                    description="Send the first reply below."
                  />
                ) : (
                  messages.map((message) => (
                    <article
                      key={message.id}
                      className={`message-bubble ${
                        message.senderRole === 'admin' ? 'is-admin' : 'is-customer'
                      }`}
                    >
                      <div className="message-bubble-meta">
                        <span>{message.senderRole === 'admin' ? 'Store' : 'Customer'}</span>
                        <span>{formatDateTime(message.createdAt)}</span>
                      </div>
                      <p>{message.text}</p>
                    </article>
                  ))
                )}
              </div>

              <div className="messages-composer">
                <label className="field field-full">
                  <span className="field-label">Reply as store administrator</span>
                  <textarea
                    value={draft}
                    onChange={(event) => setDraft(event.target.value)}
                    rows={3}
                    maxLength={2000}
                    placeholder="Write a helpful reply…"
                    disabled={sending || !selectedId}
                  />
                  <span className="field-hint">{draft.length} / 2000 characters</span>
                </label>
                <button
                  type="button"
                  className="button button-primary"
                  onClick={send}
                  disabled={sending || !draft.trim() || !selectedId}
                >
                  {sending ? <Spinner size={16} /> : <Icon name="messages" size={16} />}
                  {sending ? 'Sending…' : 'Send reply'}
                </button>
              </div>
            </div>
          </div>
        </section>
      )}
    </div>
  )
}
