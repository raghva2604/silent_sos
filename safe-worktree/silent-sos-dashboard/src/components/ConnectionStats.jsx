import React, { useEffect, useState } from 'react'

/**
 * WebSocket Connection Stats Monitor
 * Displays metrics about the WebSocket connection including:
 * - Messages received/sent
 * - Debounce efficiency
 * - Deduplication rate
 * - Reconnection attempts
 * - Connection uptime
 */

export default function ConnectionStats({ wsStatus }) {
  const [stats, setStats] = useState({
    messagesReceived: 0,
    messagesSent: 0,
    dedupRate: 0,
    debounceEfficiency: 0,
    reconnectAttempts: 0,
    uptime: 0,
    bytesReceived: 0,
  })

  const [connectedTime, setConnectedTime] = useState(null)

  useEffect(() => {
    if (wsStatus === 'open') {
      setConnectedTime(Date.now())
    }
  }, [wsStatus])

  useEffect(() => {
    const interval = setInterval(() => {
      if (connectedTime) {
        const uptime = Math.floor((Date.now() - connectedTime) / 1000)
        setStats((prev) => ({ ...prev, uptime }))
      }
    }, 1000)

    return () => clearInterval(interval)
  }, [connectedTime])

  const getStatusColor = () => {
    switch (wsStatus) {
      case 'open':
        return 'text-green-400'
      case 'connecting':
        return 'text-yellow-400'
      case 'closed':
        return 'text-gray-400'
      case 'error':
        return 'text-red-400'
      default:
        return 'text-gray-400'
    }
  }

  const getStatusIcon = () => {
    switch (wsStatus) {
      case 'open':
        return '🟢'
      case 'connecting':
        return '🟡'
      case 'closed':
        return '⚪'
      case 'error':
        return '🔴'
      default:
        return '⚪'
    }
  }

  const formatUptime = (seconds) => {
    const hours = Math.floor(seconds / 3600)
    const minutes = Math.floor((seconds % 3600) / 60)
    const secs = seconds % 60
    if (hours > 0) return `${hours}h ${minutes}m`
    if (minutes > 0) return `${minutes}m ${secs}s`
    return `${secs}s`
  }

  return (
    <div className="rounded-[32px] border border-white/10 bg-slate-950/80 p-5 shadow-[0_30px_80px_rgba(59,130,246,0.16)] backdrop-blur-xl">
      <div className="flex items-center justify-between gap-3 pb-4 border-b border-white/10 mb-4">
        <div>
          <h3 className="text-lg font-semibold text-slate-100">Connection Status</h3>
          <p className="text-sm text-slate-500">WebSocket metrics and health indicators.</p>
        </div>
        <div className={`flex items-center gap-2 rounded-full px-3 py-1 text-xs font-semibold ${getStatusColor()} bg-white/5`}> 
          <span className="h-2 w-2 rounded-full bg-current animate-pulse" />
          {getStatusIcon()} {wsStatus}
        </div>
      </div>

      <div className="grid grid-cols-2 gap-3 text-sm">
        <div className="rounded-3xl bg-slate-900/80 p-4">
          <div className="text-slate-400">Uptime</div>
          <div className="mt-2 text-lg font-semibold text-cyan-300">{formatUptime(stats.uptime)}</div>
        </div>

        <div className="rounded-3xl bg-slate-900/80 p-4">
          <div className="text-slate-400">Messages Received</div>
          <div className="mt-2 text-lg font-semibold text-emerald-300">{stats.messagesReceived}</div>
        </div>

        <div className="rounded-3xl bg-slate-900/80 p-4">
          <div className="text-slate-400">Dedup Rate</div>
          <div className="mt-2 text-lg font-semibold text-amber-300">{stats.dedupRate}%</div>
        </div>

        <div className="rounded-3xl bg-slate-900/80 p-4">
          <div className="text-slate-400">Debounce Saved</div>
          <div className="mt-2 text-lg font-semibold text-violet-300">{stats.debounceEfficiency}%</div>
        </div>
      </div>

      <div className="mt-4 rounded-3xl bg-black/20 p-4 border border-white/10 text-xs text-slate-400 space-y-2">
        <div>✓ Exponential backoff active</div>
        <div>✓ Deduplication active</div>
        <div>✓ 50ms debounce threshold</div>
        <div>✓ Auto reconnect supported</div>
      </div>
    </div>
  )
}
