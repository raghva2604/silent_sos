import React from 'react'

export default function ReplayControls({ playing, onPlayPause, speed, onSpeedChange }) {
  return (
    <div className="mt-4 bg-black/40 rounded-2xl p-4 border border-white/10">
      <div className="flex flex-wrap gap-3 items-center">
        <button className="px-4 py-2 bg-blue-500 rounded text-white font-semibold" onClick={onPlayPause}>
          {playing ? 'Pause' : 'Play'}
        </button>
        <div className="text-sm text-gray-300">Speed</div>
        <select value={speed} onChange={(event) => onSpeedChange(Number(event.target.value))} className="bg-zinc-900 rounded px-3 py-2 text-sm">
          <option value={0.5}>0.5x</option>
          <option value={1}>1x</option>
          <option value={1.5}>1.5x</option>
          <option value={2}>2x</option>
        </select>
      </div>
    </div>
  )
}
