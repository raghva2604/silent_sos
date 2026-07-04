import React, { useCallback, useEffect, useMemo, useState } from 'react'
import MapPanel from '../components/MapPanel'
import ActiveAlerts from '../components/ActiveAlerts'
import UserDetailPopup from '../components/UserDetailPopup'
import EnhancedReplayControls from '../components/EnhancedReplayControls'
import MapControls from '../components/MapControls'
import ConnectionStats from '../components/ConnectionStats'
import useWebSocket from '../hooks/useWebSocket'
import { saveReplayState, loadReplayState, addEventToHistory } from '../utils/replayUtils'

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL ? import.meta.env.VITE_API_BASE_URL.replace(/\/$/, '') : 'http://localhost:3000'
const WS_URL = import.meta.env.VITE_WS_URL || API_BASE_URL.replace(/^http/, 'ws')
const AI_BASE_URL = import.meta.env.VITE_AI_BASE_URL ? import.meta.env.VITE_AI_BASE_URL.replace(/\/$/, '') : API_BASE_URL

export default function Dashboard() {
  const [users, setUsers] = useState({})
  const [alerts, setAlerts] = useState([])
  const [mapInstance, setMapInstance] = useState(null)
  const [showPaths, setShowPaths] = useState(true)
  const [showClusters, setShowClusters] = useState(true)
  const [selectedUserId, setSelectedUserId] = useState(null)
  const [replayState, setReplayState] = useState(null)
  const [replayPlaying, setReplayPlaying] = useState(false)
  const [replaySpeed, setReplaySpeed] = useState(1)
  const [wsStatus, setWsStatus] = useState('connecting')
  const [aiSummary, setAiSummary] = useState('')
  const [aiLoading, setAiLoading] = useState(false)
  const [aiError, setAiError] = useState('')

  const normalizeLocationBody = useCallback((data) => {
    const userId = String(data.userId ?? data.id ?? 'unknown')
    const lat = Number(data.latitude ?? data.lat)
    const lng = Number(data.longitude ?? data.lng)
    const ts = data.updatedAt ? new Date(data.updatedAt).getTime() : data.ts || Date.now()

    return {
      id: userId,
      lat,
      lng,
      ts,
      speed: data.speed,
      battery: data.battery,
      riskScore: data.riskScore,
      status: data.status,
      fallDetected: data.fallDetected,
      network: data.network,
      deviceMotion: data.deviceMotion,
      backgroundTracking: data.backgroundTracking,
    }
  }, [])

  const handleMessage = useCallback((data) => {
    if (!data || !data.type) return

    // Persist event to history
    addEventToHistory(data)

    if (data.type === 'location') {
      const point = normalizeLocationBody(data)
      if (Number.isNaN(point.lat) || Number.isNaN(point.lng)) return

      const id = point.id
      setUsers((prev) => {
        const current = prev[id] || { id, info: {}, path: [], last: null }
        const path = [...(current.path || []), point].slice(-2000)
        return {
          ...prev,
          [id]: {
            ...current,
            path,
            last: point,
          },
        }
      })
      return
    }

    if (data.type === 'alert') {
      setAlerts((previous) => [{ ...data, id: data.id || data.userId || Date.now() }, ...previous].slice(0, 50))
      return
    }

    if (data.type === 'info') {
      const id = String(data.id)
      setUsers((prev) => ({ ...prev, [id]: { ...(prev[id] || {}), info: data.info } }))
      return
    }
  }, [])

  const { status } = useWebSocket({ url: WS_URL, onMessage: handleMessage })

  useEffect(() => {
    async function loadLatestLocations() {
      try {
        const response = await fetch(`${API_BASE_URL}/latest-location`)
        const json = await response.json()
        if (!response.ok) {
          console.warn('Unable to load latest locations', json)
          return
        }

        const usersById = {}
        json.data.forEach((row) => {
          const id = String(row.user_id || row.userId || row.id || 'unknown')
          const point = {
            id,
            lat: Number(row.latitude ?? row.lat),
            lng: Number(row.longitude ?? row.lng),
            ts: row.created_at ? new Date(row.created_at).getTime() : Date.now(),
            speed: row.speed,
            battery: row.battery,
            riskScore: row.risk_score ?? row.riskScore,
            status: row.status,
            fallDetected: Boolean(row.fall_detected ?? row.fallDetected),
            network: row.network,
            deviceMotion: row.device_motion ?? row.deviceMotion,
            backgroundTracking: Boolean(row.background_tracking ?? row.backgroundTracking),
          }
          usersById[id] = {
            id,
            info: {},
            path: [point],
            last: point,
          }
        })

        setUsers(usersById)
        if (!selectedUserId && Object.keys(usersById).length > 0) {
          setSelectedUserId(Object.keys(usersById)[0])
        }
      } catch (error) {
        console.warn('Failed to fetch latest locations', error)
      }
    }

    loadLatestLocations()
  }, [])

  useEffect(() => {
    setWsStatus(status)
  }, [status])

  useEffect(() => {
    if (!replayState || !replayPlaying) return
    if (replayState.index >= replayState.positions.length - 1) {
      setReplayPlaying(false)
      return
    }

    const timer = window.setInterval(() => {
      setReplayState((current) => {
        if (!current) return current
        const nextIndex = Math.min(current.positions.length - 1, current.index + 1)
        return { ...current, index: nextIndex }
      })
    }, 1000 / replaySpeed)

    return () => window.clearInterval(timer)
  }, [replayPlaying, replaySpeed, replayState])

  const selectedUser = useMemo(() => {
    if (!selectedUserId) return null
    return users[selectedUserId] || null
  }, [selectedUserId, users])

  const selectedReplayPoint = useMemo(() => {
    if (!replayState) return null
    return replayState.positions[replayState.index] || null
  }, [replayState])

  const handleGenerateAiReport = useCallback(async () => {
    if (!selectedUser) {
      setAiError('Select a user before generating an AI report.')
      return
    }

    setAiLoading(true)
    setAiError('')

    const requestUrl = AI_BASE_URL ? `${AI_BASE_URL}/ai/incident-summary` : '/ai/incident-summary'
    const payload = {
      riskScore: selectedUser.last.riskScore,
      status: selectedUser.last.status,
      battery: selectedUser.last.battery,
      speed: selectedUser.last.speed,
      fallDetected: selectedUser.last.fallDetected,
      latitude: selectedUser.last.lat,
      longitude: selectedUser.last.lng,
      time: selectedUser.last.updatedAt || new Date(selectedUser.last.ts).toISOString(),
      network: selectedUser.last.network,
      deviceMotion: selectedUser.last.deviceMotion,
      backgroundTracking: selectedUser.last.backgroundTracking ?? true,
    }

    try {
      const response = await fetch(requestUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
      })

      const data = await response.json()
      if (!response.ok) {
        setAiError(data.error || 'Unable to generate AI summary')
        setAiSummary('')
      } else {
        const summaryText = `${data.summary}${data.recommendation ? '\nRecommendation: ' + data.recommendation : ''}`
        setAiSummary(summaryText)
      }
    } catch (error) {
      setAiError('Unable to contact backend AI service.')
      setAiSummary('')
    } finally {
      setAiLoading(false)
    }
  }, [selectedUser])

  const startReplay = useCallback(
    (userId) => {
      const user = users[userId]
      if (!user?.path || user.path.length === 0) return
      const positions = [...user.path]
      saveReplayState(userId, positions)
      setReplayState({ userId, positions, index: 0 })
      setReplayPlaying(true)
    },
    [users]
  )

  const handleImportReplay = useCallback((userId) => {
    const saved = loadReplayState(userId)
    if (saved) {
      setReplayState({ userId: saved.userId, positions: saved.positions, index: 0 })
      setReplayPlaying(true)
    }
  }, [])

  const seekReplay = useCallback((index) => {
    setReplayState((current) => {
      if (!current) return current
      return { ...current, index }
    })
  }, [])

  const togglePlay = useCallback(() => {
    setReplayPlaying((current) => !current)
  }, [])

  const changeSpeed = useCallback((speed) => {
    setReplaySpeed(speed)
  }, [])

  const handleAlertSelect = useCallback(
    (alert) => {
      if (!alert || alert.userId == null) return
      setSelectedUserId(String(alert.userId))
    },
    [setSelectedUserId]
  )

  return (
    <div className="relative min-h-screen overflow-hidden bg-[#060710] text-white px-4 py-6 sm:px-6 lg:px-8">
      <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_top_left,_rgba(34,197,94,0.16),_transparent_30%),radial-gradient(circle_at_top_right,_rgba(59,130,246,0.12),_transparent_20%),radial-gradient(circle_at_bottom_left,_rgba(168,85,247,0.1),_transparent_25%)]" />
      <div className="relative z-10 space-y-6">
        <div className="flex flex-col gap-4 xl:flex-row xl:items-end xl:justify-between">
          <div className="space-y-3">
            <h1 className="text-4xl md:text-5xl font-semibold tracking-tight text-slate-100">Silent SOS Command Center</h1>
            <p className="max-w-2xl text-sm text-slate-400 sm:text-base">Real-time location tracking, alert monitoring, replay analysis and map intelligence in one futuristic dashboard.</p>
          </div>

          <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
            <div className="rounded-3xl border border-white/10 bg-white/5 p-4 shadow-[0_20px_80px_rgba(14,165,233,0.12)] backdrop-blur-xl transition hover:-translate-y-1">
              <div className="text-xs uppercase tracking-[0.24em] text-slate-400">Devices</div>
              <div className="mt-3 text-3xl font-semibold text-cyan-300">{Object.keys(users).length}</div>
            </div>
            <div className="rounded-3xl border border-white/10 bg-white/5 p-4 shadow-[0_20px_80px_rgba(248,113,113,0.12)] backdrop-blur-xl transition hover:-translate-y-1">
              <div className="text-xs uppercase tracking-[0.24em] text-slate-400">Alerts</div>
              <div className="mt-3 text-3xl font-semibold text-amber-300">{alerts.length}</div>
            </div>
            <div className="rounded-3xl border border-white/10 bg-white/5 p-4 shadow-[0_20px_80px_rgba(59,130,246,0.12)] backdrop-blur-xl transition hover:-translate-y-1">
              <div className="text-xs uppercase tracking-[0.24em] text-slate-400">Replay</div>
              <div className="mt-3 text-3xl font-semibold text-sky-300">{replayState?.userId ?? 'idle'}</div>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-12 gap-6">
          <aside className="col-span-12 xl:col-span-4 space-y-6">
            <div className="rounded-[32px] border border-white/10 bg-slate-950/80 p-5 shadow-[0_40px_120px_rgba(15,23,42,0.35)] backdrop-blur-xl">
              <div className="flex items-center justify-between gap-4 pb-4 border-b border-white/10">
                <div>
                  <div className="text-sm uppercase tracking-[0.32em] text-slate-500">System</div>
                  <div className="text-2xl font-semibold text-slate-100">Live Overview</div>
                </div>
                <div className="flex items-center gap-2 rounded-full bg-cyan-500/15 px-3 py-1 text-xs text-cyan-200">
                  <span className="h-2 w-2 rounded-full bg-cyan-400 animate-pulse" />
                  {wsStatus}
                </div>
              </div>
              <div className="grid gap-3 pt-4">
                <div className="rounded-3xl bg-slate-900/70 p-4 border border-white/5">
                  <div className="text-xs uppercase tracking-[0.28em] text-slate-500">Location stream</div>
                  <div className="mt-2 text-lg font-semibold text-slate-100">{Object.keys(users).length} active trackers</div>
                </div>
                <div className="rounded-3xl bg-slate-900/70 p-4 border border-white/5">
                  <div className="text-xs uppercase tracking-[0.28em] text-slate-500">Alerts queue</div>
                  <div className="mt-2 text-lg font-semibold text-amber-300">{alerts.length} unresolved</div>
                </div>
              </div>
            </div>

            <div className="rounded-[32px] border border-white/10 bg-slate-950/80 p-5 shadow-[0_40px_120px_rgba(15,23,42,0.35)] backdrop-blur-xl">
              <div className="flex items-center justify-between gap-4 pb-4 border-b border-white/10">
                <div>
                  <h2 className="text-xl font-semibold text-slate-100">Controls</h2>
                  <p className="text-sm text-slate-500">Navigation, clustering and path toggles.</p>
                </div>
                <span className="rounded-full border border-white/10 bg-white/5 px-3 py-1 text-xs uppercase tracking-[0.32em] text-slate-300">Live</span>
              </div>

              <MapControls
                map={mapInstance}
                showPaths={showPaths}
                onTogglePaths={() => setShowPaths((s) => !s)}
                showClusters={showClusters}
                onToggleClusters={() => setShowClusters((s) => !s)}
              />
            </div>

            <ActiveAlerts alerts={alerts} onSelectAlert={handleAlertSelect} />

            <ConnectionStats wsStatus={wsStatus} />

            <div className="rounded-[32px] border border-white/10 bg-slate-950/80 p-5 shadow-[0_40px_120px_rgba(15,23,42,0.35)] backdrop-blur-xl">
              <h2 className="text-xl font-semibold text-slate-100 mb-3">Generate AI Report</h2>
              <p className="text-sm text-slate-400 mb-4">Send the latest alert and telemetry to the AI backend for a concise incident summary.</p>
              <button
                type="button"
                onClick={handleGenerateAiReport}
                disabled={aiLoading}
                className="inline-flex items-center justify-center rounded-3xl bg-cyan-500 px-4 py-3 text-sm font-semibold text-slate-950 transition hover:bg-cyan-400 disabled:opacity-50"
              >
                {aiLoading ? 'Generating report...' : 'Generate AI Report'}
              </button>

              {aiError ? (
                <div className="mt-4 rounded-3xl border border-rose-500/20 bg-rose-500/10 p-4 text-sm text-rose-200">
                  {aiError}
                </div>
              ) : null}

              {aiSummary ? (
                <div className="mt-4 rounded-3xl border border-cyan-500/20 bg-cyan-500/10 p-4 text-sm leading-6 text-slate-200">
                  <div className="font-semibold text-slate-100 mb-2">AI Summary</div>
                  <pre className="whitespace-pre-wrap text-sm">{aiSummary}</pre>
                </div>
              ) : null}
            </div>

            <div className="rounded-[32px] border border-white/10 bg-slate-950/80 p-5 shadow-[0_40px_120px_rgba(15,23,42,0.35)] backdrop-blur-xl">
              <h2 className="text-xl font-semibold text-slate-100 mb-3">Selected User</h2>
              <UserDetailPopup
                user={selectedUser ? { ...selectedUser, id: selectedUserId } : null}
                onCenter={() => setSelectedUserId(selectedUserId)}
                onStartReplay={startReplay}
                onGenerateAi={handleGenerateAiReport}
              />
            </div>

            {replayState && (
              <div className="rounded-[32px] border border-white/10 bg-slate-950/80 p-5 shadow-[0_40px_120px_rgba(15,23,42,0.35)] backdrop-blur-xl">
                <div className="flex items-center justify-between mb-4">
                  <div>
                    <h2 className="text-xl font-semibold text-slate-100">Replay Timeline</h2>
                    <div className="text-sm text-slate-500">Move point-by-point through the latest track.</div>
                  </div>
                  <div className="text-sm text-slate-300">{replayState.index + 1}/{replayState.positions.length}</div>
                </div>
                <input
                  type="range"
                  min={0}
                  max={replayState.positions.length - 1}
                  value={replayState.index}
                  onChange={(event) => seekReplay(Number(event.target.value))}
                  className="w-full accent-sky-400 mb-4"
                />
                <EnhancedReplayControls
                  playing={replayPlaying}
                  onPlayPause={togglePlay}
                  speed={replaySpeed}
                  onSpeedChange={changeSpeed}
                  replayState={replayState}
                  onImportReplay={handleImportReplay}
                />
              </div>
            )}
          </aside>

          <main className="col-span-12 xl:col-span-8">
            <div className="rounded-[36px] border border-white/10 bg-slate-950/70 p-4 shadow-[0_40px_120px_rgba(59,130,246,0.16)] backdrop-blur-xl">
              <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
                <div>
                  <div className="text-sm uppercase tracking-[0.32em] text-slate-500">World Map</div>
                  <div className="text-2xl font-semibold text-slate-100">Geo Intelligence</div>
                </div>
                <div className="rounded-full bg-slate-900/80 px-4 py-2 text-xs uppercase tracking-[0.28em] text-slate-300 ring-1 ring-slate-400/10">Realtime visualizer</div>
              </div>
              <MapPanel
                users={users}
                selectedUserId={selectedUserId}
                onSelectUser={setSelectedUserId}
                replayState={replayState}
                showPaths={showPaths}
                showClusters={showClusters}
                onMapCreated={setMapInstance}
              />
            </div>
          </main>
        </div>
      </div>
    </div>
  )
}
