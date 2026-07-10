import { useCallback, useEffect, useRef, useState } from 'react'

const DEBOUNCE_MS = 50
const MAX_RECONNECT_DELAY = 30000
const DEDUPE_TTL = 30 * 1000

function buildMessageKey(data) {
  if (!data || typeof data !== 'object') return JSON.stringify(data)
  if (data.id != null && data.type && data.ts != null) return `${data.type}:${data.id}:${data.ts}`
  if (data.id != null && data.type) return `${data.type}:${data.id}`
  return JSON.stringify(data)
}

export default function useWebSocket({ url, onMessage }) {
  const wsRef = useRef(null)
  const reconnectRef = useRef(null)
  const retryCountRef = useRef(0)
  const pendingRef = useRef([])
  const debounceTimerRef = useRef(null)
  const dedupeRef = useRef(new Map())
  const onMessageRef = useRef(onMessage)
  const [status, setStatus] = useState('connecting')

  onMessageRef.current = onMessage

  const flushMessages = useCallback(() => {
    debounceTimerRef.current = null
    const batch = pendingRef.current.splice(0)
    if (batch.length === 0) return
    const handler = onMessageRef.current
    batch.forEach((data) => handler && handler(data))
  }, [])

  const enqueueMessage = useCallback((data) => {
    const key = buildMessageKey(data)
    const seen = dedupeRef.current
    const now = Date.now()
    if (seen.has(key) && now - seen.get(key) < DEDUPE_TTL) {
      return
    }
    seen.set(key, now)
    Array.from(seen.entries()).forEach(([k, ts]) => {
      if (now - ts > DEDUPE_TTL) seen.delete(k)
    })
    pendingRef.current.push(data)
    if (!debounceTimerRef.current) {
      debounceTimerRef.current = window.setTimeout(flushMessages, DEBOUNCE_MS)
    }
  }, [flushMessages])

  const connect = useCallback(() => {
    if (!url) return
    try {
      setStatus('connecting')
      const ws = new WebSocket(url)
      wsRef.current = ws

      ws.addEventListener('open', () => {
        console.log('✅ WebSocket Connected', url)
        setStatus('open')
        retryCountRef.current = 0
      })

      ws.addEventListener('message', (event) => {
        console.log('📍 WS Message:', event.data)
        try {
          const data = JSON.parse(event.data)
          enqueueMessage(data)
        } catch (error) {
          console.warn('WS invalid payload', event.data)
        }
      })

      ws.addEventListener('close', () => {
        setStatus('closed')
        const delay = Math.min(2000 * 2 ** retryCountRef.current, MAX_RECONNECT_DELAY)
        retryCountRef.current += 1
        reconnectRef.current = window.setTimeout(connect, delay)
      })

      ws.addEventListener('error', () => {
        setStatus('error')
        ws.close()
      })
    } catch (error) {
      setStatus('error')
      const delay = Math.min(2000 * 2 ** retryCountRef.current, MAX_RECONNECT_DELAY)
      retryCountRef.current += 1
      reconnectRef.current = window.setTimeout(connect, delay)
    }
  }, [url, enqueueMessage])

  useEffect(() => {
    connect()
    return () => {
      if (debounceTimerRef.current) {
        window.clearTimeout(debounceTimerRef.current)
      }
      if (reconnectRef.current) {
        window.clearTimeout(reconnectRef.current)
      }
      if (wsRef.current) {
        wsRef.current.close()
      }
    }
  }, [connect])

  const send = useCallback((payload) => {
    const ws = wsRef.current
    if (ws && ws.readyState === WebSocket.OPEN) {
      try {
        ws.send(JSON.stringify(payload))
      } catch (error) {
        console.warn('WS send failed', error)
      }
    }
  }, [])

  return { send, status }
}
