#!/usr/bin/env node
/**
 * Demo WebSocket Server for Silent SOS Dashboard
 * Streams sample location updates, alerts, and user info for testing
 */

const WebSocket = require('ws')
const http = require('http')

const PORT = process.env.PORT || 3000

// Simulated users with their properties
const USERS = [
  { id: 'user1', name: 'Alice Johnson', email: 'alice@example.com', phone: '+1-555-0101' },
  { id: 'user2', name: 'Bob Smith', email: 'bob@example.com', phone: '+1-555-0102' },
  { id: 'user3', name: 'Charlie Brown', email: 'charlie@example.com', phone: '+1-555-0103' },
  { id: 'user4', name: 'Diana Prince', email: 'diana@example.com', phone: '+1-555-0104' },
  { id: 'user5', name: 'Ethan Hunt', email: 'ethan@example.com', phone: '+1-555-0105' },
]

// Base locations (cities) for simulation
const BASE_LOCATIONS = [
  { lat: 40.7128, lng: -74.006, name: 'New York' },
  { lat: 34.0522, lng: -118.2437, name: 'Los Angeles' },
  { lat: 41.8781, lng: -87.6298, name: 'Chicago' },
  { lat: 29.7604, lng: -95.3698, name: 'Houston' },
  { lat: 33.7490, lng: -84.388, name: 'Atlanta' },
]

// Simulated walking patterns around base locations
const USER_STATE = new Map(
  USERS.map((user, idx) => [
    user.id,
    {
      lat: BASE_LOCATIONS[idx].lat + (Math.random() - 0.5) * 0.01,
      lng: BASE_LOCATIONS[idx].lng + (Math.random() - 0.5) * 0.01,
      speed: Math.random() * 5,
      direction: Math.random() * 360,
      info: user,
      lastAlertTime: 0,
    },
  ])
)

/**
 * Generate next location for a user (random walk)
 */
function getNextLocation(userId) {
  const state = USER_STATE.get(userId)
  if (!state) return null

  // Random walk with occasional direction changes
  if (Math.random() < 0.05) {
    state.direction = Math.random() * 360
  }

  const speed = 0.0001 + Math.random() * 0.0005
  const radians = (state.direction * Math.PI) / 180
  state.lat += Math.cos(radians) * speed
  state.lng += Math.sin(radians) * speed
  state.speed = Math.random() * 8 + 2 // 2-10 km/h walking speed

  return {
    type: 'location',
    id: userId,
    lat: state.lat,
    lng: state.lng,
    speed: state.speed,
    ts: Date.now(),
  }
}

/**
 * Generate random alert for a user
 */
function generateAlert(userId) {
  const state = USER_STATE.get(userId)
  if (!state || Date.now() - state.lastAlertTime < 30000) return null

  state.lastAlertTime = Date.now()
  const alertTypes = [
    { type: 'fall', severity: 'high', message: 'Fall detected!' },
    { type: 'unusual_motion', severity: 'medium', message: 'Unusual motion pattern' },
    { type: 'stationary_long', severity: 'low', message: 'User stationary for 10+ min' },
    { type: 'high_acceleration', severity: 'medium', message: 'High acceleration detected' },
  ]
  const alert = alertTypes[Math.floor(Math.random() * alertTypes.length)]

  return {
    type: 'alert',
    id: `alert_${userId}_${Date.now()}`,
    userId,
    ...alert,
    ts: Date.now(),
    location: { lat: state.lat, lng: state.lng },
  }
}

/**
 * Broadcast user info to all connected clients
 */
function broadcastUserInfo(ws, userId) {
  const state = USER_STATE.get(userId)
  if (!state) return

  const message = {
    type: 'info',
    id: userId,
    info: state.info,
    ts: Date.now(),
  }

  if (ws) {
    ws.send(JSON.stringify(message))
  }
}

/**
 * Start the test server
 */
function startServer() {
  const server = http.createServer()
  const wss = new WebSocket.Server({ server })

  let streamInterval = null

  wss.on('connection', (ws) => {
    console.log('[WS] Client connected, total clients:', wss.clients.size)

    // Send initial user info to new client
    USERS.forEach((user) => {
      broadcastUserInfo(ws, user.id)
    })

    // Start streaming if not already running
    if (!streamInterval) {
      streamInterval = setInterval(() => {
        const message = {
          // Locations update for all users
          locations: USERS.map((user) => getNextLocation(user.id)).filter(Boolean),
          // Random alerts
          alerts: USERS.filter(() => Math.random() < 0.02)
            .map((user) => generateAlert(user.id))
            .filter(Boolean),
        }

        // Broadcast to all connected clients
        wss.clients.forEach((client) => {
          if (client.readyState === WebSocket.OPEN) {
            // Send individual location updates
            message.locations.forEach((loc) => {
              try {
                client.send(JSON.stringify(loc))
              } catch (error) {
                console.error('Error sending location:', error.message)
              }
            })

            // Send alerts
            message.alerts.forEach((alert) => {
              try {
                client.send(JSON.stringify(alert))
              } catch (error) {
                console.error('Error sending alert:', error.message)
              }
            })
          }
        })
      }, 2000) // Send updates every 2 seconds

      console.log('[WS] Stream started')
    }

    ws.on('message', (data) => {
      try {
        const message = JSON.parse(data)
        console.log('[WS] Received:', message.type)

        // Handle client commands if needed
        if (message.type === 'ping') {
          ws.send(JSON.stringify({ type: 'pong', ts: Date.now() }))
        }
      } catch (error) {
        console.error('Error parsing message:', error.message)
      }
    })

    ws.on('close', () => {
      console.log('[WS] Client disconnected, total clients:', wss.clients.size)
      // Stop streaming if no clients left
      if (wss.clients.size === 0 && streamInterval) {
        clearInterval(streamInterval)
        streamInterval = null
        console.log('[WS] Stream stopped')
      }
    })

    ws.on('error', (error) => {
      console.error('[WS] Error:', error.message)
    })
  })

  server.listen(PORT, () => {
    console.log(`\n📡 Silent SOS Demo Server running on ws://localhost:${PORT}`)
    console.log(`   Simulating ${USERS.length} users with location streaming`)
    console.log(`   Connect dashboard at: http://localhost:5173`)
    console.log(`   Set VITE_WS_URL=ws://localhost:${PORT} environment variable`)
    console.log(`\n⚡ Server ready for WebSocket connections\n`)
  })

  // Graceful shutdown
  process.on('SIGINT', () => {
    console.log('\n\n🛑 Shutting down server...')
    if (streamInterval) clearInterval(streamInterval)
    wss.clients.forEach((ws) => ws.close())
    server.close(() => {
      console.log('✅ Server closed')
      process.exit(0)
    })
  })
}

startServer()
