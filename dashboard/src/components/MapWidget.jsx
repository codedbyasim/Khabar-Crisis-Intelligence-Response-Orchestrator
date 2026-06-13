import React, { useEffect, useRef, useState } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';

export default function MapWidget({ incidents, resources, selectedId, onSelectIncident }) {
  const mapContainerRef = useRef(null);
  const mapRef = useRef(null);
  const incidentMarkersRef = useRef({});
  const resourceMarkersRef = useRef({});
  const hotspotCirclesRef = useRef([]);
  const [isMapReady, setIsMapReady] = useState(false);

  // Initialize Leaflet Map with light tiles
  useEffect(() => {
    if (!mapRef.current && mapContainerRef.current) {
      const map = L.map(mapContainerRef.current, {
        zoomControl: true,
        attributionControl: true
      }).setView([33.65, 73.06], 12);

      // Light premium tile layer (CartoDB Positron)
      L.tileLayer('https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png', {
        maxZoom: 19,
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OSM</a> &copy; <a href="https://carto.com/attributions">CARTO</a>'
      }).addTo(map);

      mapRef.current = map;
      setIsMapReady(true);
    }

    return () => {
      if (mapRef.current) {
        mapRef.current.remove();
        mapRef.current = null;
        setIsMapReady(false);
      }
    };
  }, []);

  // Update Markers & Hotspots
  useEffect(() => {
    const map = mapRef.current;
    if (!map || !isMapReady) return;

    // Clear previous hotspots
    hotspotCirclesRef.current.forEach(c => map.removeLayer(c));
    hotspotCirclesRef.current = [];

    const coordinatesMap = {};

    // Render Incidents
    incidents.forEach(inc => {
      let lat = inc.lat;
      let lng = inc.lng;
      
      // Fallback for active in-memory incidents where lat/lng reside in the location dictionary
      if (!lat && inc.location) {
        lat = inc.location.latitude || inc.location.lat;
      }
      if (!lng && inc.location) {
        lng = inc.location.longitude || inc.location.lng;
      }

      if (lat && lng) {
        const parsedLat = parseFloat(lat);
        const parsedLng = parseFloat(lng);
        const key = `${parsedLat.toFixed(3)},${parsedLng.toFixed(3)}`;
        coordinatesMap[key] = (coordinatesMap[key] || 0) + 1;

        const id = inc.incident_id;
        const type = inc.incident_type || inc.source || 'Emergency';
        const priority = inc.priority || 'P3';
        const status = inc.status || 'PROCESSING';

        let markerColor = '#f59e0b';
        if (priority === 'P1') markerColor = '#f43f5e';
        else if (priority === 'P2') markerColor = '#f97316';
        else if (priority === 'P5') markerColor = '#10b981';

        const markerHtml = `<div style="
          background: ${markerColor};
          width: 14px; height: 14px;
          border-radius: 50%;
          border: 2px solid rgba(255,255,255,0.8);
          box-shadow: 0 0 12px ${markerColor}, 0 0 24px ${markerColor}40;
        "></div>`;

        const customIcon = L.divIcon({
          html: markerHtml,
          className: 'custom-div-icon',
          iconSize: [14, 14],
          iconAnchor: [7, 7]
        });

        if (incidentMarkersRef.current[id]) {
          incidentMarkersRef.current[id].setLatLng([parsedLat, parsedLng]);
        } else {
          const marker = L.marker([parsedLat, parsedLng], { icon: customIcon })
            .bindPopup(`
              <div style="font-family:Inter,sans-serif;min-width:180px;color:#0f172a;">
                <div style="font-size:10px;color:#475569;margin-bottom:6px;font-weight:600;letter-spacing:0.5px;">INCIDENT</div>
                <div style="font-size:12px;font-weight:700;color:#0f172a;margin-bottom:4px;">${type.replace(/_/g, ' ')}</div>
                <div style="font-size:11px;color:#64748b;margin-bottom:2px;">ID: ${id}</div>
                <div style="display:flex;gap:6px;margin-top:8px;">
                  <span style="background:${markerColor}20;color:${markerColor};padding:2px 6px;border-radius:3px;font-size:10px;font-weight:700;">${priority}</span>
                  <span style="background:rgba(0,0,0,0.05);color:#475569;padding:2px 6px;border-radius:3px;font-size:10px;">${status}</span>
                </div>
              </div>
            `)
            .addTo(map);

          marker.on('click', () => {
            if (onSelectIncident) onSelectIncident(id);
          });

          incidentMarkersRef.current[id] = marker;
        }
      }
    });

    // Clean removed incidents
    const currentIncIds = new Set(incidents.map(i => i.incident_id));
    for (let id in incidentMarkersRef.current) {
      if (!currentIncIds.has(id)) {
        map.removeLayer(incidentMarkersRef.current[id]);
        delete incidentMarkersRef.current[id];
      }
    }

    // Render Resources
    resources.forEach(res => {
      let lat = null;
      let lng = null;
      if (res.location) {
        lat = res.location.lat || res.location.latitude;
        lng = res.location.lng || res.location.longitude;
      }
      if (!lat || !lng) {
        lat = res.lat;
        lng = res.lng;
      }

      if (lat && lng) {
        const parsedLat = parseFloat(lat);
        const parsedLng = parseFloat(lng);
        const id = res.resource_id;
        const type = (res.resource_type || res.type || 'resource').toLowerCase();
        const status = res.status || 'available';

        let resColor = '#0284c7';
        if (type.includes('pump')) resColor = '#ea580c';
        if (type.includes('team') || type.includes('crew') || type.includes('unit')) resColor = '#7c3aed';

        const markerHtml = `<div style="
          background: ${resColor};
          width: 10px; height: 10px;
          transform: rotate(45deg);
          border: 2px solid rgba(255,255,255,0.7);
          box-shadow: 0 0 8px ${resColor};
        "></div>`;

        const customIcon = L.divIcon({
          html: markerHtml,
          className: 'custom-div-icon',
          iconSize: [10, 10],
          iconAnchor: [5, 5]
        });

        if (resourceMarkersRef.current[id]) {
          resourceMarkersRef.current[id].setLatLng([parsedLat, parsedLng]);
        } else {
          const marker = L.marker([parsedLat, parsedLng], { icon: customIcon })
            .bindPopup(`
              <div style="font-family:Inter,sans-serif;color:#0f172a;">
                <div style="font-size:10px;color:${resColor};margin-bottom:4px;font-weight:700;">RESOURCE</div>
                <div style="font-size:12px;font-weight:600;color:#0f172a;">${res.name || id}</div>
                <div style="font-size:11px;color:#475569;">${type.replace(/_/g,' ')} · ${status}</div>
              </div>
            `)
            .addTo(map);
          resourceMarkersRef.current[id] = marker;
        }
      }
    });

    // Clean removed resources
    const currentResIds = new Set(resources.map(r => r.resource_id));
    for (let id in resourceMarkersRef.current) {
      if (!currentResIds.has(id)) {
        map.removeLayer(resourceMarkersRef.current[id]);
        delete resourceMarkersRef.current[id];
      }
    }

    // Hotspot zones
    for (let coordKey in coordinatesMap) {
      const count = coordinatesMap[coordKey];
      const [parsedLat, parsedLng] = coordKey.split(',').map(Number);
      const radius = 300 + (count * 200);
      const opacity = 0.12 + (count * 0.08);

      const circle = L.circle([parsedLat, parsedLng], {
        color: '#e11d48',
        fillColor: '#e11d48',
        fillOpacity: opacity,
        radius: radius,
        weight: 1,
        dashArray: '6, 4'
      }).addTo(map);

      circle.bindTooltip(`⚠ ${count} Active Incident(s)`, {
        permanent: false,
        sticky: true,
        className: 'leaflet-tooltip'
      });
      hotspotCirclesRef.current.push(circle);
    }
  }, [incidents, resources, isMapReady]);

  // Zoom on selection
  useEffect(() => {
    const map = mapRef.current;
    if (!map || !selectedId || !isMapReady) return;

    const selectedMarker = incidentMarkersRef.current[selectedId];
    if (selectedMarker) {
      selectedMarker.openPopup();
      map.setView(selectedMarker.getLatLng(), 14, { animate: true });
    }
  }, [selectedId, isMapReady]);

  return (
    <div className="glass-card full-span">
      <div className="glass-card-header">
        <span className="glass-card-title" style={{ color: 'var(--cyan)' }}>
          🗺️ Interactive Crisis Map — Islamabad & Rawalpindi
        </span>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <span style={{ fontSize: '10px', color: 'var(--rose)', fontWeight: 700, display: 'flex', alignItems: 'center', gap: 4 }}>
            <span style={{ width: 6, height: 6, background: 'var(--rose)', borderRadius: '50%', display: 'inline-block', animation: 'pulse-live 2s infinite' }}></span>
            HOTSPOTS ACTIVE
          </span>
        </div>
      </div>
      <div className="glass-card-body" style={{ padding: 0 }}>
        <div
          ref={mapContainerRef}
          className="map-container"
        />
      </div>
    </div>
  );
}
