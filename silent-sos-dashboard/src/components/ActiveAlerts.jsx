import React from 'react'

export default function ActiveAlerts({ alerts = [], onSelectAlert }) {
  return (
    <div className="rounded-[32px] border border-white/10 bg-slate-950/80 p-5 shadow-[0_30px_80px_rgba(248,113,113,0.12)] backdrop-blur-xl">
      <div className="mb-4 flex items-center justify-between gap-3">
        <div>
          <h2 className="text-xl font-semibold text-slate-100">Active Alerts</h2>
          <p className="text-sm text-slate-500">Monitor recent notifications in real time.</p>
        </div>
        <span className="rounded-full bg-amber-500/15 px-3 py-1 text-xs uppercase tracking-[0.32em] text-amber-200">Alert feed</span>
      </div>
      <div className="space-y-3">
        {alerts.length === 0 && <div className="text-sm text-slate-400">No active alerts</div>}
        {alerts.map((a) => (
          <div key={a.id} className="rounded-3xl border border-white/10 bg-slate-900/80 p-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <div className="text-sm font-semibold text-slate-100">{a.type || 'Alert'}</div>
              <div className="text-sm text-slate-400">{a.msg || ''}</div>
            </div>
            <button className="rounded-2xl bg-amber-400 px-4 py-2 text-sm font-semibold text-slate-950 transition hover:bg-amber-300" onClick={() => onSelectAlert && onSelectAlert(a)}>
              View
            </button>
          </div>
        ))}
      </div>
    </div>
  )
}
