/**
 * Replay persistence and timeline utilities
 * Handles saving/loading replay state and event history
 */

const STORAGE_KEY_PREFIX = 'sos_replay_'
const STORAGE_KEY_HISTORY = 'sos_event_history'
const MAX_HISTORY_SIZE = 500 // Keep last 500 events per user

/**
 * Save replay state to localStorage
 */
export function saveReplayState(userId, positions) {
  try {
    const data = {
      userId,
      positions,
      savedAt: Date.now(),
    }
    sessionStorage.setItem(`${STORAGE_KEY_PREFIX}${userId}`, JSON.stringify(data))
  } catch (error) {
    console.warn('Failed to save replay state:', error)
  }
}

/**
 * Load replay state from localStorage
 */
export function loadReplayState(userId) {
  try {
    const data = sessionStorage.getItem(`${STORAGE_KEY_PREFIX}${userId}`)
    return data ? JSON.parse(data) : null
  } catch (error) {
    console.warn('Failed to load replay state:', error)
    return null
  }
}

/**
 * Clear replay state for a user
 */
export function clearReplayState(userId) {
  try {
    sessionStorage.removeItem(`${STORAGE_KEY_PREFIX}${userId}`)
  } catch (error) {
    console.warn('Failed to clear replay state:', error)
  }
}

/**
 * Save event to history (location, alert, etc)
 */
export function addEventToHistory(event) {
  try {
    const history = loadEventHistory()
    history.push({
      ...event,
      recordedAt: Date.now(),
    })

    // Keep only most recent events and prune by user/type
    const userHistory = {}
    history.forEach((e) => {
      const key = `${e.type}:${e.id}`
      if (!userHistory[key]) userHistory[key] = []
      userHistory[key].push(e)
    })

    // Limit each user/type to MAX_HISTORY_SIZE
    const pruned = []
    Object.values(userHistory).forEach((events) => {
      pruned.push(...events.slice(-MAX_HISTORY_SIZE))
    })

    sessionStorage.setItem(STORAGE_KEY_HISTORY, JSON.stringify(pruned))
  } catch (error) {
    console.warn('Failed to add event to history:', error)
  }
}

/**
 * Load all events from history
 */
export function loadEventHistory() {
  try {
    const data = sessionStorage.getItem(STORAGE_KEY_HISTORY)
    return data ? JSON.parse(data) : []
  } catch (error) {
    console.warn('Failed to load event history:', error)
    return []
  }
}

/**
 * Get timeline statistics (events per minute, peak times, etc)
 */
export function getTimelineStats() {
  const history = loadEventHistory()
  const stats = {
    totalEvents: history.length,
    eventsByType: {},
    eventsPerMinute: {},
    timeRange: { start: null, end: null },
  }

  if (history.length === 0) return stats

  const firstTime = history[0].ts || history[0].recordedAt
  const lastTime = history[history.length - 1].ts || history[history.length - 1].recordedAt
  stats.timeRange = { start: firstTime, end: lastTime }

  // Count by type
  history.forEach((event) => {
    stats.eventsByType[event.type] = (stats.eventsByType[event.type] || 0) + 1
  })

  // Calculate events per minute in 5-min buckets
  const minute = 60 * 1000
  const bucket = 5 * minute
  let currentBucket = firstTime
  while (currentBucket <= lastTime) {
    const key = new Date(currentBucket).toLocaleTimeString()
    const count = history.filter(
      (e) => (e.ts || e.recordedAt) >= currentBucket && (e.ts || e.recordedAt) < currentBucket + bucket
    ).length
    stats.eventsPerMinute[key] = count
    currentBucket += bucket
  }

  return stats
}

/**
 * Export replay data as JSON
 */
export function exportReplayData(userId) {
  const state = loadReplayState(userId)
  if (!state) return null

  const data = {
    userId,
    exportedAt: new Date().toISOString(),
    positions: state.positions,
    duration: state.positions.length > 0 ? state.positions[state.positions.length - 1].ts - state.positions[0].ts : 0,
  }

  return JSON.stringify(data, null, 2)
}

/**
 * Import replay data from JSON
 */
export function importReplayData(jsonString) {
  try {
    const data = JSON.parse(jsonString)
    if (!data.userId || !Array.isArray(data.positions)) {
      throw new Error('Invalid replay data format')
    }
    saveReplayState(data.userId, data.positions)
    return data.userId
  } catch (error) {
    console.error('Failed to import replay data:', error)
    return null
  }
}

/**
 * Get position at specific time
 */
export function getPositionAtTime(positions, targetTime) {
  if (!positions || positions.length === 0) return null

  // Find closest position to target time
  let closest = positions[0]
  let minDiff = Math.abs(positions[0].ts - targetTime)

  for (const pos of positions) {
    const diff = Math.abs(pos.ts - targetTime)
    if (diff < minDiff) {
      minDiff = diff
      closest = pos
    }
  }

  return closest
}

/**
 * Interpolate position between two points
 */
export function interpolatePosition(pos1, pos2, fraction) {
  return {
    lat: pos1.lat + (pos2.lat - pos1.lat) * fraction,
    lng: pos1.lng + (pos2.lng - pos1.lng) * fraction,
    ts: pos1.ts + (pos2.ts - pos1.ts) * fraction,
    speed: pos1.speed + (pos2.speed - pos1.speed) * fraction,
  }
}

/**
 * Calculate distance between two positions (Haversine formula)
 */
export function calculateDistance(pos1, pos2) {
  const R = 6371 // Earth's radius in km
  const dLat = ((pos2.lat - pos1.lat) * Math.PI) / 180
  const dLng = ((pos2.lng - pos1.lng) * Math.PI) / 180
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) + Math.cos((pos1.lat * Math.PI) / 180) * Math.cos((pos2.lat * Math.PI) / 180) * Math.sin(dLng / 2) * Math.sin(dLng / 2)
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  return R * c
}

/**
 * Smooth position history using Kalman-like filter
 */
export function smoothPositions(positions, alpha = 0.3) {
  if (positions.length < 2) return positions

  const smoothed = [positions[0]]
  for (let i = 1; i < positions.length; i++) {
    const prev = smoothed[i - 1]
    const current = positions[i]
    smoothed.push({
      lat: prev.lat + (current.lat - prev.lat) * alpha,
      lng: prev.lng + (current.lng - prev.lng) * alpha,
      ts: current.ts,
      speed: prev.speed + (current.speed - prev.speed) * alpha,
    })
  }
  return smoothed
}
