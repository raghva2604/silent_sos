// operator-dashboard/src/App.jsx
// React Operator Dashboard for monitoring live SOS events

import React, { useState, useEffect } from 'react';
import { io } from 'socket.io-client';
import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';
import { LatLng } from 'leaflet';
import Lottie from 'lottie-react';
import pulseAnimation from './animations/pulse.json';
import './App.css';

const App = () => {
  const [socket, setSocket] = useState(null);
  const [sosRecords, setSosRecords] = useState([]);
  const [selectedSos, setSelectedSos] = useState(null);
  const [mapCenter, setMapCenter] = useState([37.7749, -122.4194]); // Default: SF
  const [loading, setLoading] = useState(true);
  const [stats, setStats] = useState({ total: 0, unresolved: 0, critical: 0 });

  // Connect to socket.io on mount
  useEffect(() => {
    const BACKEND_URL = process.env.REACT_APP_SERVER_URL || 'http://localhost:4000';
    const newSocket = io(BACKEND_URL, {
      reconnection: true,
      reconnectionDelay: 1000,
      reconnectionDelayMax: 5000,
      reconnectionAttempts: 5,
    });

    newSocket.on('connect', () => {
      console.log('✓ Connected to backend');
      newSocket.emit('join_ops');
    });

    newSocket.on('new_sos', (sosData) => {
      console.log('📍 New SOS:', sosData);
      setSosRecords((prev) => [sosData, ...prev.slice(0, 49)]);
      
      // Update map center if location available
      if (sosData.location?.lat && sosData.location?.lon) {
        setMapCenter([sosData.location.lat, sosData.location.lon]);
      }

      // Notification sound (optional)
      playNotificationSound();
    });

    newSocket.on('sos_ack', (data) => {
      console.log('✓ SOS acknowledged:', data.id);
      setSosRecords((prev) =>
        prev.map((sos) =>
          sos._id === data.id ? { ...sos, resolved: true } : sos
        )
      );
    });

    newSocket.on('disconnect', () => {
      console.log('✗ Disconnected from backend');
    });

    setSocket(newSocket);

    // Fetch initial SOS records
    fetchSosRecords(BACKEND_URL);

    return () => {
      newSocket.close();
    };
  }, []);

  // Update stats when records change
  useEffect(() => {
    const total = sosRecords.length;
    const unresolved = sosRecords.filter((s) => !s.resolved).length;
    const critical = sosRecords.filter((s) => !s.resolved && s.severity === 'critical').length;
    setStats({ total, unresolved, critical });
  }, [sosRecords]);

  const fetchSosRecords = async (backendUrl) => {
    try {
      const response = await fetch(`${backendUrl}/api/sos?limit=50`);
      const data = await response.json();
      if (data.ok) {
        setSosRecords(data.data);
      }
    } catch (err) {
      console.error('Fetch error:', err);
    } finally {
      setLoading(false);
    }
  };

  const playNotificationSound = () => {
    const audio = new Audio('/notification.mp3');
    audio.play().catch(() => {
      console.log('Notification sound blocked');
    });
  };

  const acknowledgeSos = async (sosId) => {
    try {
      const response = await fetch(`${process.env.REACT_APP_SERVER_URL || 'http://localhost:4000'}/api/sos/${sosId}/ack`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
      });
      if (response.ok) {
        socket?.emit('sos_ack_local', { id: sosId });
      }
    } catch (err) {
      console.error('ACK error:', err);
    }
  };

  const formatTime = (timestamp) => {
    return new Date(timestamp).toLocaleString();
  };

  const getSourceIcon = (source) => {
    const icons = {
      manual: '🆘',
      ai: '🤖',
      emergency: '🚨',
      fallback: '📱',
    };
    return icons[source] || '📌';
  };

  const mapMarkers = sosRecords
    .filter((sos) => sos.location?.lat && sos.location?.lon)
    .slice(0, 10);

  return (
    <div className="app-container">
      {/* Header */}
      <header className="header">
        <h1 className="title">🆘 Silent SOS - Operator Dashboard</h1>
        <div className="header-stats">
          <div className="stat-card">
            <span className="stat-label">Total SOS</span>
            <span className="stat-value">{stats.total}</span>
          </div>
          <div className="stat-card alert">
            <span className="stat-label">Unresolved</span>
            <span className="stat-value">{stats.unresolved}</span>
          </div>
          <div className="stat-card critical">
            <span className="stat-label">Critical</span>
            <span className="stat-value">{stats.critical}</span>
          </div>
        </div>
      </header>

      <div className="main-grid">
        {/* Map Panel */}
        <div className="map-panel">
          <h2>📍 Live Map</h2>
          <MapContainer center={mapCenter} zoom={12} style={{ height: '100%' }} scrollWheelZoom={false}>
            <TileLayer
              url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
              attribution='&copy; OpenStreetMap contributors'
            />
            {mapMarkers.map((sos) => (
              <Marker key={sos._id} position={[sos.location.lat, sos.location.lon]}>
                <Popup>
                  <div>
                    <p><strong>User:</strong> {sos.userId}</p>
                    <p><strong>Source:</strong> {sos.source}</p>
                    <p><strong>Time:</strong> {formatTime(sos.timestamp)}</p>
                  </div>
                </Popup>
              </Marker>
            ))}
          </MapContainer>
        </div>

        {/* SOS List Panel */}
        <div className="sos-list-panel">
          <h2>📋 Recent SOS Events</h2>
          {loading ? (
            <div className="loading">Loading events...</div>
          ) : sosRecords.length === 0 ? (
            <div className="empty">No SOS events yet</div>
          ) : (
            <div className="sos-list">
              {sosRecords.map((sos) => (
                <div
                  key={sos._id}
                  className={`sos-card ${sos.resolved ? 'resolved' : 'active'}`}
                  onClick={() => setSelectedSos(sos)}
                >
                  <div className="sos-header">
                    <span className="sos-source">{getSourceIcon(sos.source)} {sos.source}</span>
                    <span className={`sos-status ${sos.resolved ? 'resolved' : 'active'}`}>
                      {sos.resolved ? '✓ Resolved' : '🔴 Active'}
                    </span>
                  </div>
                  <div className="sos-user">User: {sos.userId}</div>
                  <div className="sos-time">{formatTime(sos.timestamp)}</div>
                  {sos.location?.lat && sos.location?.lon && (
                    <div className="sos-location">
                      📍 {sos.location.lat.toFixed(4)}, {sos.location.lon.toFixed(4)}
                    </div>
                  )}
                  {!sos.resolved && (
                    <button
                      className="ack-button"
                      onClick={(e) => {
                        e.stopPropagation();
                        acknowledgeSos(sos._id);
                      }}
                    >
                      Acknowledge
                    </button>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Media Viewer Modal */}
      {selectedSos && (
        <div className="modal-overlay" onClick={() => setSelectedSos(null)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <button className="close-button" onClick={() => setSelectedSos(null)}>✕</button>
            <h3>SOS Details</h3>
            
            <div className="modal-details">
              <p><strong>User ID:</strong> {selectedSos.userId}</p>
              <p><strong>Source:</strong> {selectedSos.source}</p>
              <p><strong>Timestamp:</strong> {formatTime(selectedSos.timestamp)}</p>
              {selectedSos.location && (
                <>
                  <p><strong>Latitude:</strong> {selectedSos.location.lat}</p>
                  <p><strong>Longitude:</strong> {selectedSos.location.lon}</p>
                </>
              )}
              <p><strong>Status:</strong> {selectedSos.resolved ? 'Resolved' : 'Active'}</p>
            </div>

            {selectedSos.media && (
              <div className="media-container">
                {selectedSos.media.frontUrl && (
                  <div className="media-item">
                    <h4>Front Camera</h4>
                    <img src={selectedSos.media.frontUrl} alt="Front" />
                  </div>
                )}
                {selectedSos.media.backUrl && (
                  <div className="media-item">
                    <h4>Back Camera</h4>
                    <img src={selectedSos.media.backUrl} alt="Back" />
                  </div>
                )}
                {selectedSos.media.audioUrl && (
                  <div className="media-item">
                    <h4>Audio Recording</h4>
                    <audio controls src={selectedSos.media.audioUrl} />
                  </div>
                )}
              </div>
            )}

            {!selectedSos.resolved && (
              <button className="ack-button-large" onClick={() => acknowledgeSos(selectedSos._id)}>
                Acknowledge This SOS
              </button>
            )}
          </div>
        </div>
      )}
    </div>
  );
};

export default App;
