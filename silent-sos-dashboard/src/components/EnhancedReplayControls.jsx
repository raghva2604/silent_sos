import React, { useMemo, useState } from 'react'
import { exportReplayData, importReplayData, getTimelineStats } from '../utils/replayUtils'

export default function EnhancedReplayControls({
  playing,
  onPlayPause,
  speed,
  onSpeedChange,
  replayState,
  onImportReplay,
}) {
  const [showStats, setShowStats] = useState(false)
  const [showExport, setShowExport] = useState(false)

  const stats = useMemo(() => {
    if (!replayState?.positions) return null
    const positions = replayState.positions
    const duration = positions[positions.length - 1].ts - positions[0].ts
    const distance = Math.random() * 15 // Placeholder
    return {
      duration: Math.floor(duration / 1000),
      distance: distance.toFixed(2),
      points: positions.length,
      avgSpeed: positions.reduce((sum, p) => sum + (p.speed || 0), 0) / positions.length,
    }
  }, [replayState])

  const handleExport = () => {
    const data = exportReplayData(replayState?.userId)
    if (data) {
      const blob = new Blob([data], { type: 'application/json' })
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = `replay_${replayState.userId}_${new Date().getTime()}.json`
      document.body.appendChild(a)
      a.click()
      document.body.removeChild(a)
      URL.revokeObjectURL(url)
    }
  }

  const handleImportFile = (event) => {
    const file = event.target.files?.[0]
    if (!file) return

    const reader = new FileReader()
    reader.onload = (e) => {
      const userId = importReplayData(e.target?.result)
      if (userId && onImportReplay) {
        onImportReplay(userId)
      }
    }
    reader.readAsText(file)
  }

  return (
    <div className="mt-4 rounded-[28px] border border-white/10 bg-slate-900/75 p-4 shadow-[0_24px_80px_rgba(59,130,246,0.14)] backdrop-blur-xl">
      <div className="flex flex-wrap gap-3 items-center">
        <button
          className="px-4 py-2 rounded-2xl bg-sky-500 text-slate-950 font-semibold transition hover:bg-sky-400"
          onClick={onPlayPause}>
          {playing ? '⏸ Pause' : '▶ Play'}
        </button>

        <div className="text-sm text-slate-300">Speed:</div>
        <select
          value={speed}
          onChange={(event) => onSpeedChange(Number(event.target.value))}
          className="rounded-2xl bg-slate-800 px-3 py-2 text-sm text-slate-200 transition hover:bg-slate-700">
          <option value={0.25}>0.25x</option>
          <option value={0.5}>0.5x</option>
          <option value={1}>1x</option>
          <option value={1.5}>1.5x</option>
          <option value={2}>2x</option>
          <option value={4}>4x</option>
        </select>

        <button
          className="ml-auto rounded-2xl bg-slate-800 px-3 py-2 text-sm text-slate-200 transition hover:bg-slate-700"
          onClick={() => setShowStats(!showStats)}>
          {showStats ? '📊 Hide Stats' : '📊 Show Stats'}
        </button>

        <button
          className="rounded-2xl bg-slate-800 px-3 py-2 text-sm text-slate-200 transition hover:bg-slate-700"
          onClick={handleExport}>
          ⬇️ Export
        </button>

        <label className="rounded-2xl bg-slate-800 px-3 py-2 text-sm text-slate-200 transition hover:bg-slate-700 cursor-pointer">
          ⬆️ Import
          <input type="file" accept=".json" onChange={handleImportFile} className="hidden" />
        </label>
      </div>

      {showStats && stats && (
        <div className="mt-4 rounded-3xl bg-slate-800/80 p-4 grid grid-cols-2 gap-3 text-xs text-slate-300 sm:grid-cols-4">
          <div className="rounded-2xl bg-slate-900/70 p-3">
            <div className="text-slate-400">Duration</div>
            <div className="mt-2 text-sm font-semibold text-amber-300">{Math.floor(stats.duration / 60)}m {stats.duration % 60}s</div>
          </div>
          <div className="rounded-2xl bg-slate-900/70 p-3">
            <div className="text-slate-400">Points</div>
            <div className="mt-2 text-sm font-semibold text-emerald-300">{stats.points}</div>
          </div>
          <div className="rounded-2xl bg-slate-900/70 p-3">
            <div className="text-slate-400">Avg Speed</div>
            <div className="mt-2 text-sm font-semibold text-cyan-300">{stats.avgSpeed.toFixed(1)} km/h</div>
          </div>
          <div className="rounded-2xl bg-slate-900/70 p-3">
            <div className="text-slate-400">Distance</div>
            <div className="mt-2 text-sm font-semibold text-violet-300">{stats.distance} km</div>
          </div>
        </div>
      )}
    </div>
  )
}
