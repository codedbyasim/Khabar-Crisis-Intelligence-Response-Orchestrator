import React, { useEffect, useState } from 'react';
import { MapContainer, TileLayer, Marker, Popup, Polyline } from 'react-leaflet';
import L from 'leaflet';
import { useDashboard } from '../../context/DashboardContext';
import './InteractiveMap.css';

// Custom icon colors based on priority
const createPriorityIcon = (priority) => {
  const colors = {
    P1: '#e53935', // Red - Critical
    P2: '#fb8c00', // Orange - High
    P3: '#fdd835', // Yellow - Medium
    P4: '#43a047', // Green - Low
    P5: '#1e88e5', // Blue - Info
  };

  const labels = {
    P1: 'P1',
    P2: 'P2',
    P3: 'P3',
    P4: 'P4',
    P5: 'P5',
  };

  return L.divIcon({
    html: `
      <div style="
        background-color: ${colors[priority] || '#1e88e5'};
        width: 30px;
        height: 30px;
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        border: 3px solid white;
        box-shadow: 0 2px 8px rgba(0,0,0,0.25);
        cursor: pointer;
        font-weight: 800;
        font-size: 10px;
        color: white;
        font-family: 'Inter', sans-serif;
      ">
        ${labels[priority] || '?'}
      </div>
    `,
    className: 'priority-marker',
    iconSize: [30, 30],
    iconAnchor: [15, 15],
    popupAnchor: [0, -15],
  });
};

// Resource icon
const createResourceIcon = (status) => {
  const colors = {
    available: '#43a047',      // Green
    en_route: '#1e88e5',       // Blue
    deployed: '#fb8c00',       // Orange
  };

  const emojis = {
    available: '🟢',
    en_route: '🔵',
    deployed: '🟠',
  };

  return L.divIcon({
    html: `
      <div style="
        background-color: ${colors[status] || '#9E9E9E'};
        width: 26px;
        height: 26px;
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        border: 2px solid white;
        box-shadow: 0 2px 6px rgba(0,0,0,0.2);
        color: white;
        font-size: 12px;
        font-family: 'Inter', sans-serif;
        font-weight: 700;
      ">
        ✚
      </div>
    `,
    className: 'resource-marker',
    iconSize: [26, 26],
    iconAnchor: [13, 13],
    popupAnchor: [0, -13],
  });
};

const InteractiveMap = () => {
  const { incidents, resources, deployments } = useDashboard();
  const [lines, setLines] = useState([]);

  // Find the top priority incident for floating tag
  const topIncident = incidents?.find(i => i.priority === 'P1');

  // Generate dispatch lines between resources and incidents
  useEffect(() => {
    const newLines = [];
    deployments?.forEach(dep => {
      if (dep.deployed_location && dep.target_location) {
        newLines.push({
          from: [dep.deployed_location.lat || 33.74, dep.deployed_location.lng || 73.15],
          to: [dep.target_location.lat || 33.74, dep.target_location.lng || 73.15],
          status: dep.status,
        });
      }
    });
    setLines(newLines);
  }, [deployments]);

  return (
    <div className="map-container">
      {/* Floating priority tag */}
      {topIncident && (
        <div className="map-priority-tag">
          <span className="tag p1">P1 URGENT</span>
        </div>
      )}

      <MapContainer
        center={[33.72, 73.06]}
        zoom={13}
        className="leaflet-map"
        style={{ height: '100%', borderRadius: '28px' }}
      >
        <TileLayer
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
          attribution='&copy; <a href="https://www.openstreetmap.org/">OpenStreetMap</a> contributors'
        />

        {/* Dispatch Lines */}
        {lines.map((line, idx) => (
          <Polyline
            key={`line-${idx}`}
            positions={[line.from, line.to]}
            color="#e53935"
            weight={2}
            opacity={0.7}
            dashArray="6, 4"
          />
        ))}

        {/* Incident Markers */}
        {incidents?.map(incident => {
          const lat = incident.lat || incident.location?.lat;
          const lng = incident.lng || incident.location?.lng;
          return lat && lng && (
            <Marker
              key={`incident-${incident.incident_id}`}
              position={[lat, lng]}
              icon={createPriorityIcon(incident.priority)}
            >
              <Popup>
                <div style={{ fontFamily: "'Inter', sans-serif", minWidth: 180 }}>
                  <h4 style={{ margin: '0 0 6px 0', color: '#0d3b3e', fontSize: 14 }}>
                    {incident.priority} — {incident.incident_type}
                  </h4>
                  <p style={{ margin: '3px 0', fontSize: 12, color: '#5f6368' }}>
                    <strong>Area:</strong> {incident.location?.area || 'Unknown'}
                  </p>
                  <p style={{ margin: '3px 0', fontSize: 12, color: '#5f6368' }}>
                    <strong>Confidence:</strong> {((incident.confidence || incident.confidence_score || 0) * 100).toFixed(0)}%
                  </p>
                  <p style={{ margin: '3px 0', fontSize: 12, color: '#5f6368' }}>
                    <strong>Status:</strong> {incident.status}
                  </p>
                  {incident.traces && incident.traces.length > 0 && (
                    <div style={{ marginTop: '10px', paddingTop: '8px', borderTop: '1px solid #eee' }}>
                      <strong style={{ fontSize: 11, color: '#888', textTransform: 'uppercase' }}>AI Reasoning Traces</strong>
                      <div style={{ 
                        marginTop: '4px',
                        maxHeight: '120px', 
                        overflowY: 'auto', 
                        backgroundColor: '#f8f9fa', 
                        padding: '6px', 
                        borderRadius: '4px',
                        fontSize: '10px',
                        color: '#333',
                        fontFamily: 'monospace'
                      }}>
                        {incident.traces.map((trace, i) => (
                          <div key={i} style={{ marginBottom: '4px', paddingBottom: '4px', borderBottom: i < incident.traces.length - 1 ? '1px dotted #ccc' : 'none' }}>
                            {trace}
                          </div>
                        ))}
                      </div>
                    </div>
                  )}
                </div>
              </Popup>
            </Marker>
          );
        })}

        {/* Resource Markers */}
        {resources?.map(resource => (
          resource.location?.lat && resource.location?.lng && (
            <Marker
              key={`resource-${resource.id}`}
              position={[resource.location.lat, resource.location.lng]}
              icon={createResourceIcon(resource.status)}
            >
              <Popup>
                <div style={{ fontFamily: "'Inter', sans-serif", minWidth: 160 }}>
                  <h4 style={{ margin: '0 0 6px 0', color: '#0d3b3e', fontSize: 13 }}>
                    {resource.name}
                  </h4>
                  <p style={{ margin: '3px 0', fontSize: 12, color: '#5f6368' }}>
                    <strong>Type:</strong> {resource.resource_type}
                  </p>
                  <p style={{ margin: '3px 0', fontSize: 12, color: '#5f6368' }}>
                    <strong>Status:</strong> {resource.status}
                  </p>
                  <p style={{ margin: '3px 0', fontSize: 12, color: '#5f6368' }}>
                    <strong>Available:</strong> {resource.quantity_available}
                  </p>
                </div>
              </Popup>
            </Marker>
          )
        ))}
      </MapContainer>

      {/* Map Legend */}
      <div className="map-legend">
        <div className="legend-item">
          <span className="legend-color" style={{ backgroundColor: '#e53935' }}></span>
          <span>P1 Critical</span>
        </div>
        <div className="legend-item">
          <span className="legend-color" style={{ backgroundColor: '#fb8c00' }}></span>
          <span>P2 High</span>
        </div>
        <div className="legend-item">
          <span className="legend-color" style={{ backgroundColor: '#fdd835' }}></span>
          <span>P3 Medium</span>
        </div>
        <div className="legend-item">
          <span className="legend-color" style={{ backgroundColor: '#43a047' }}></span>
          <span>Available</span>
        </div>
        <div className="legend-item">
          <span className="legend-color" style={{ backgroundColor: '#1e88e5' }}></span>
          <span>En Route</span>
        </div>
      </div>
    </div>
  );
};

export default InteractiveMap;
