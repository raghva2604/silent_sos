import React, { useEffect, useMemo, useRef, useState } from 'react'
import { MapContainer, TileLayer, Marker, Popup, Polyline, useMap, useMapEvent } from 'react-leaflet'
import L from 'leaflet'

const CLUSTER_RADIUS = 60
const SPIDER_DIST = 60

function initials(name) {
  if (!name) return 'U'
  return name
    .split(' ')
    .map((word) => word[0]?.toUpperCase())
    .slice(0, 2)
    .join('')
}

function createAvatarIcon(name, selected) {
  const initialsText = initials(name)
  return L.divIcon({
    className: '',
    html: `<div class="avatar-marker${selected ? ' selected' : ''}">${initialsText}</div>`,
    iconSize: [42, 42],
    iconAnchor: [21, 21],
    popupAnchor: [0, -20],
  })
}

function createClusterIcon(count) {
  return L.divIcon({
    className: '',
    html: `<div class="cluster-marker">${count}</div>`,
    iconSize: [44, 44],
    iconAnchor: [22, 22],
    popupAnchor: [0, -20],
  })
}

function createSpiderIcon(initial) {
  return L.divIcon({
    className: '',
    html: `<div class="spider-marker">${initial}</div>`,
    iconSize: [28, 28],
    iconAnchor: [14, 14],
    popupAnchor: [0, -14],
  })
}

function CenterOnSelect({ selectedPosition }) {
  const map = useMap()
  useEffect(() => {
    if (selectedPosition && map) {
      map.flyTo(selectedPosition, Math.max(map.getZoom(), 8), { duration: 0.9 })
    }
  }, [selectedPosition, map])
  return null
}

function MapEvents({ onMapReady }) {
  const map = useMap()
  useMapEvent('zoomend', () => onMapReady(map))
  useMapEvent('moveend', () => onMapReady(map))
  return null
}

export default function MapPanel({ users, selectedUserId, onSelectUser, replayState, showPaths = true, showClusters = true, onMapCreated }) {
  const [map, setMap] = useState(null)
  const [spiderState, setSpiderState] = useState(null)
  const centerPosition = useMemo(() => {
    if (selectedUserId && users[selectedUserId] && users[selectedUserId].last) {
      return [users[selectedUserId].last.lat, users[selectedUserId].last.lng]
    }
    return [20, 0]
  }, [selectedUserId, users])

  const markers = useMemo(() => {
    return Object.entries(users)
      .filter(([, u]) => u?.last)
      .map(([id, u]) => ({
        id,
        name: u.info?.name || id,
        last: u.last,
        latlng: L.latLng(u.last.lat, u.last.lng),
      }))
  }, [users])

  const { clusters, singles } = useMemo(() => {
    if (!map || markers.length === 0) return { clusters: [], singles: markers }
    const used = new Set()
    const points = markers.map((marker) => ({ ...marker, point: map.latLngToLayerPoint(marker.latlng) }))
    const clusters = []
    const singles = []

    for (const marker of points) {
      if (used.has(marker.id)) continue
      const group = [marker]
      for (const other of points) {
        if (other.id === marker.id || used.has(other.id)) continue
        if (marker.point.distanceTo(other.point) < CLUSTER_RADIUS) {
          group.push(other)
        }
      }
      if (group.length > 1) {
        group.forEach((item) => used.add(item.id))
        const centerPoint = group.reduce((sum, item) => sum.add(item.point), L.point(0, 0)).divideBy(group.length)
        clusters.push({
          markers: group,
          centerLatLng: map.layerPointToLatLng(centerPoint),
          count: group.length,
        })
      } else {
        singles.push(marker)
      }
    }
    return { clusters, singles }
  }, [map, markers])

  useEffect(() => {
    if (!map) return
    if (!selectedUserId) {
      setSpiderState(null)
      return
    }
    const selected = users[selectedUserId]
    if (!selected?.last) return
    setSpiderState(null)
  }, [selectedUserId, users, map])

  function showSpider(cluster) {
    if (!map) return
    const spiderMarkers = cluster.markers.map((marker, index) => {
      const angle = (2 * Math.PI * index) / cluster.markers.length
      const point = map.latLngToLayerPoint(cluster.centerLatLng)
      const offset = L.point(Math.cos(angle) * SPIDER_DIST, Math.sin(angle) * SPIDER_DIST)
      return {
        ...marker,
        spiderLatLng: map.layerPointToLatLng(point.add(offset)),
      }
    })
    setSpiderState({ cluster, spiderMarkers })
  }

  const selectedPosition = useMemo(() => {
    if (!selectedUserId) return null
    const selected = users[selectedUserId]
    return selected?.last ? [selected.last.lat, selected.last.lng] : null
  }, [selectedUserId, users])

  return (
    <MapContainer
      center={centerPosition}
      zoom={4}
      zoomControl={false}
      className="rounded-[28px] overflow-hidden"
      style={{ height: '80vh', width: '100%' }}
      whenCreated={(mapInstance) => {
        setMap(mapInstance)
        if (onMapCreated) onMapCreated(mapInstance)
      }}>
        <TileLayer url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />
        <MapEvents onMapReady={() => setSpiderState(null)} />
        {singles.map((marker) => (
          <Marker
            key={marker.id}
            position={marker.latlng}
            icon={createAvatarIcon(marker.name, marker.id === selectedUserId)}
            eventHandlers={{ click: () => onSelectUser(marker.id) }}>
            <Popup>
              <div style={{ minWidth: 160 }}>
                <strong>{marker.name}</strong>
                <div>Last: {new Date(marker.last.ts).toLocaleTimeString()}</div>
              </div>
            </Popup>
          </Marker>
        ))}
          {showClusters &&
          clusters.map((cluster) => (
            <Marker
              key={`cluster-${cluster.centerLatLng.lat}-${cluster.centerLatLng.lng}-${cluster.count}`}
              position={cluster.centerLatLng}
              icon={createClusterIcon(cluster.count)}
              eventHandlers={{ click: () => showSpider(cluster) }}>
              <Popup>
                <div className="text-black text-sm">
                  <strong>{cluster.count} users</strong>
                  <div>Click to spiderfy</div>
                </div>
              </Popup>
            </Marker>
          ))}
        {spiderState?.spiderMarkers.map((marker) => (
          <React.Fragment key={`spider-${marker.id}`}>
            <Polyline positions={[marker.latlng, marker.spiderLatLng]} pathOptions={{ color: 'white', dashArray: '4 6' }} />
            <Marker
              position={marker.spiderLatLng}
              icon={createSpiderIcon(initials(marker.name))}
              eventHandlers={{ click: () => onSelectUser(marker.id) }}>
              <Popup>
                <div style={{ minWidth: 140 }}>
                  <strong>{marker.name}</strong>
                  <div>{marker.last.lat.toFixed(5)}, {marker.last.lng.toFixed(5)}</div>
                </div>
              </Popup>
            </Marker>
          </React.Fragment>
        ))}
        {showPaths &&
          Object.entries(users).map(([id, user]) => {
            if (!user.path || user.path.length < 2) return null
            const coords = user.path.map((p) => [p.lat, p.lng])
            return <Polyline key={`path-${id}`} positions={coords} pathOptions={{ color: 'rgba(16, 185, 129, 0.6)' }} />
          })}
        {replayState?.positions?.length > 0 && (
          <Marker
            key="replay-marker"
            position={[replayState.positions[replayState.index].lat, replayState.positions[replayState.index].lng]}
            icon={createClusterIcon(1)}>
            <Popup>Replay: {new Date(replayState.positions[replayState.index].ts).toLocaleTimeString()}</Popup>
          </Marker>
        )}
        <CenterOnSelect selectedPosition={selectedPosition} />
      </MapContainer>
  )
}
