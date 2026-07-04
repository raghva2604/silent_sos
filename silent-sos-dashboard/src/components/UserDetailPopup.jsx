import React from 'react'

export default function UserDetailPopup({ user, onCenter, onStartReplay, onGenerateAi }) {
  if (!user) return <div className="bg-zinc-900 p-4 rounded-2xl">Select a user to see details</div>

  return (
    <div className="bg-zinc-900 p-4 rounded-2xl">
      <h3 className="text-xl font-semibold">{user.info?.name || 'User'}</h3>
      <div className="mt-2 text-sm text-gray-300">ID: {user.id}</div>
      {user.last && (
        <div className="mt-2 space-y-2 text-sm text-gray-200">
          <div>Last seen: {new Date(user.last.ts).toLocaleString()}</div>
          <div>Latitude: {user.last.lat.toFixed(5)}</div>
          <div>Longitude: {user.last.lng.toFixed(5)}</div>
          <div>Speed: {user.last.speed ?? '—'}</div>
          <div>Battery: {user.last.battery ?? '—'}%</div>
          <div>Status: {user.last.status || '—'}</div>
          <div>Risk: {user.last.riskScore ?? '—'}</div>
          {user.last.network ? <div>Network: {user.last.network}</div> : null}
          {user.last.deviceMotion ? <div>Motion: {user.last.deviceMotion}</div> : null}
        </div>
      )}
      <div className="mt-4 flex flex-wrap gap-2">
        <button className="p-2 bg-green-500 rounded" onClick={() => onCenter && onCenter(user)}>
          Center
        </button>
        <button className="p-2 bg-blue-500 rounded" onClick={() => onStartReplay && onStartReplay(user.id)}>
          Replay
        </button>
        {onGenerateAi ? (
          <button className="p-2 bg-cyan-500 rounded text-slate-950" onClick={() => onGenerateAi && onGenerateAi()}>
            Generate AI
          </button>
        ) : null}
      </div>
    </div>
  )
}
