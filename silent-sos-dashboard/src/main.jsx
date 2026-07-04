import React from 'react'
import { createRoot } from 'react-dom/client'
import './styles/index.css'
import 'leaflet/dist/leaflet.css'
import App from './App'

const rootEl = document.getElementById('root')

function showErrorInBody(msg) {
  try {
    document.body.innerText = 'App runtime error: ' + msg
  } catch (e) {
    // ignore
  }
}

window.addEventListener('error', (ev) => {
  showErrorInBody(ev && ev.message ? ev.message : String(ev))
})
window.addEventListener('unhandledrejection', (ev) => {
  const msg = ev && ev.reason && ev.reason.message ? ev.reason.message : String(ev.reason)
  showErrorInBody('Unhandled Rejection: ' + msg)
})

if (!rootEl) {
  showErrorInBody('Root element not found')
} else {
  try {
    createRoot(rootEl).render(
      <React.StrictMode>
        <App />
      </React.StrictMode>
    )
  } catch (err) {
    console.error(err)
    showErrorInBody(err && err.message ? err.message : String(err))
  }
}
