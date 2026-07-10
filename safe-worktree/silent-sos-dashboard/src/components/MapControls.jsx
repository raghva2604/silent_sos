import React from 'react'

/**
 * Map Control Panel
 * Provides controls for map interaction and visualization options
 */
export default function MapControls({ map, showPaths, onTogglePaths, showClusters, onToggleClusters }) {
  const handleZoom = (delta) => {
    if (!map) return
    const zoom = map.getZoom()
    map.setZoom(zoom + delta)
  }

  const handleFitBounds = () => {
    if (!map) return
    // Fit to world bounds
    map.fitWorld()
  }

  const handleCenterMap = () => {
    if (!map) return
    map.setView([20, 0], 4)
  }

  return (
    <div className="rounded-3xl border border-white/10 bg-slate-900/70 p-4 shadow-[0_30px_90px_rgba(34,197,94,0.16)] backdrop-blur-xl transition hover:shadow-[0_44px_120px_rgba(34,197,94,0.22)]">
      <div className="mb-4 flex items-center justify-between gap-3">
        <div>
          <div className="text-sm uppercase tracking-[0.32em] text-slate-400">Map panel</div>
          <div className="text-lg font-semibold text-slate-100">Quick controls</div>
        </div>
        <span className="rounded-full bg-slate-800/90 px-3 py-1 text-xs uppercase tracking-[0.28em] text-slate-300">Fast</span>
      </div>

      <div className="grid gap-3 sm:grid-cols-2">
        <button
          className="rounded-2xl bg-cyan-500/15 px-3 py-3 text-sm text-cyan-200 transition hover:bg-cyan-500/25"
          onClick={() => handleZoom(1)}>
          ➕ Zoom in
        </button>
        <button
          className="rounded-2xl bg-cyan-500/15 px-3 py-3 text-sm text-cyan-200 transition hover:bg-cyan-500/25"
          onClick={() => handleZoom(-1)}>
          ➖ Zoom out
        </button>
        <button
          className="rounded-2xl bg-slate-800/80 px-3 py-3 text-sm text-slate-200 transition hover:bg-slate-700/90"
          onClick={handleCenterMap}>
          🏠 Center map
        </button>
        <button
          className="rounded-2xl bg-slate-800/80 px-3 py-3 text-sm text-slate-200 transition hover:bg-slate-700/90"
          onClick={handleFitBounds}>
          🎯 Fit bounds
        </button>
      </div>

      <div className="mt-4 grid gap-3">
        <button
          className={`rounded-2xl px-3 py-3 text-sm font-semibold transition ${
            showPaths ? 'bg-sky-500 text-slate-950 hover:bg-sky-400' : 'bg-slate-800 text-slate-200 hover:bg-slate-700'
          }`}
          onClick={onTogglePaths}>
          {showPaths ? '✓ Paths enabled' : '○ Paths hidden'}
        </button>
        <button
          className={`rounded-2xl px-3 py-3 text-sm font-semibold transition ${
            showClusters ? 'bg-violet-500 text-slate-950 hover:bg-violet-400' : 'bg-slate-800 text-slate-200 hover:bg-slate-700'
          }`}
          onClick={onToggleClusters}>
          {showClusters ? '✓ Clustering enabled' : '○ Clustering hidden'}
        </button>
      </div>

      <div className="mt-4 border-t border-white/10 pt-4 text-sm text-slate-400 space-y-3">
        <div className="flex items-center gap-2">
          <div className="h-2 w-2 rounded-full bg-emerald-400" />
          <span>Low latency updates</span>
        </div>
        <div className="flex items-center gap-2">
          <div className="h-2 w-2 rounded-full bg-sky-400" />
          <span>Auto cluster & spiderfy</span>
        </div>
        <div className="flex items-center gap-2">
          <div className="h-2 w-2 rounded-full bg-violet-400" />
          <span>Smart map navigation</span>
        </div>
      </div>
    </div>
  )
}
