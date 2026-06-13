import React from 'react';
import { ClipboardList } from 'lucide-react';

export default function CaseTracker({ incidents, selectedId, onSelectIncident }) {
  const totalCases = incidents.length;
  const openCases = incidents.filter(i => i.status === 'PROCESSING' || i.status === 'OPEN').length;
  const completeCases = incidents.filter(i => i.status === 'PIPELINE_COMPLETE').length;
  const reviewCases = incidents.filter(i => i.status === 'MANUAL_REVIEW_REQUIRED').length;
  const rejectedCases = incidents.filter(i => i.status === 'REJECTED').length;
  const resolvedCases = completeCases + rejectedCases;

  const resolutionRate = totalCases > 0 ? Math.round((resolvedCases / totalCases) * 100) : 0;

  // SVG progress ring
  const radius = 42;
  const circumference = 2 * Math.PI * radius;
  const resolvedOffset = circumference - (resolutionRate / 100) * circumference;
  const openRate = totalCases > 0 ? Math.round((openCases / totalCases) * 100) : 0;
  const openOffset = circumference - (openRate / 100) * circumference;

  const getPriorityBadgeClass = (p) => `priority-badge badge-${(p || 'P5').toLowerCase()}`;
  const getStatusChipClass = (s) => {
    const map = {
      'PROCESSING': 'chip-processing',
      'PIPELINE_COMPLETE': 'chip-complete',
      'MANUAL_REVIEW_REQUIRED': 'chip-manual',
      'OPEN': 'chip-open'
    };
    return `status-chip ${map[s] || 'chip-open'}`;
  };

  return (
    <div className="glass-card">
      <div className="glass-card-header">
        <span className="glass-card-title">
          <ClipboardList size={18} style={{ color: 'var(--emerald)' }} /> Case Tracker
        </span>
        <span style={{ fontSize: 11, fontWeight: 600, color: 'var(--text-muted)' }}>
          {totalCases} total cases
        </span>
      </div>
      <div className="glass-card-body">
        {/* Stats Row */}
        <div className="case-stats-row">
          <div className="case-stat-mini">
            <div className="number" style={{ color: 'var(--blue)' }}>{openCases}</div>
            <div className="label">Processing</div>
          </div>
          <div className="case-stat-mini">
            <div className="number" style={{ color: 'var(--emerald)' }}>{completeCases}</div>
            <div className="label">Complete</div>
          </div>
          <div className="case-stat-mini">
            <div className="number" style={{ color: 'var(--rose)' }}>{reviewCases}</div>
            <div className="label">Review</div>
          </div>
          <div className="case-stat-mini">
            <div className="number" style={{ color: 'var(--text-muted)' }}>{rejectedCases}</div>
            <div className="label">Rejected</div>
          </div>
        </div>

        {/* Progress Rings */}
        <div className="progress-ring-container">
          <div className="progress-ring-wrapper">
            <div style={{ position: 'relative', width: 100, height: 100, margin: '0 auto' }}>
              <svg className="progress-ring" viewBox="0 0 100 100" style={{ width: '100%', height: '100%' }}>
                <circle className="progress-ring-bg" cx="50" cy="50" r={radius} />
                <circle
                  className="progress-ring-fill"
                  cx="50" cy="50" r={radius}
                  stroke="var(--emerald)"
                  strokeDasharray={circumference}
                  strokeDashoffset={resolvedOffset}
                />
              </svg>
              <div className="progress-ring-percent" style={{
                position: 'absolute',
                top: '50%',
                left: '50%',
                transform: 'translate(-50%, -50%)',
                margin: 0,
                fontSize: '15px',
                fontWeight: '800',
                color: 'var(--emerald)'
              }}>
                {resolutionRate}%
              </div>
            </div>
            <div className="progress-ring-label">Resolution Rate</div>
          </div>

          <div className="progress-ring-wrapper">
            <div style={{ position: 'relative', width: 100, height: 100, margin: '0 auto' }}>
              <svg className="progress-ring" viewBox="0 0 100 100" style={{ width: '100%', height: '100%' }}>
                <circle className="progress-ring-bg" cx="50" cy="50" r={radius} />
                <circle
                  className="progress-ring-fill"
                  cx="50" cy="50" r={radius}
                  stroke="var(--blue)"
                  strokeDasharray={circumference}
                  strokeDashoffset={openOffset}
                />
              </svg>
              <div className="progress-ring-percent" style={{
                position: 'absolute',
                top: '50%',
                left: '50%',
                transform: 'translate(-50%, -50%)',
                margin: 0,
                fontSize: '15px',
                fontWeight: '800',
                color: 'var(--blue)'
              }}>
                {openRate}%
              </div>
            </div>
            <div className="progress-ring-label">Active Cases</div>
          </div>
        </div>

        {/* Case List */}
        <div style={{ fontSize: 10, fontWeight: 700, color: 'var(--text-muted)', marginBottom: 10, marginTop: 8, textTransform: 'uppercase', letterSpacing: 0.8 }}>
          All Cases
        </div>
        <div style={{ maxHeight: 320, overflowY: 'auto' }}>
          {incidents.length === 0 ? (
            <div className="no-data">No cases recorded.</div>
          ) : (
            incidents.map(inc => {
              const loc = inc.location
                ? `${inc.location.area || ''} ${inc.location.city || ''}`.trim()
                : (inc.lat ? `${parseFloat(inc.lat).toFixed(4)}, ${parseFloat(inc.lng).toFixed(4)}` : 'Unknown');
              const isActive = inc.incident_id === selectedId;

              return (
                <div
                  key={inc.incident_id}
                  className={`incident-item ${isActive ? 'active-item' : ''}`}
                  onClick={() => onSelectIncident(inc.incident_id)}
                >
                  <div className="inc-header">
                    <span className="inc-id">{inc.incident_id}</span>
                    <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
                      <span className={getPriorityBadgeClass(inc.priority)}>{inc.priority || 'P5'}</span>
                      <span className={getStatusChipClass(inc.status)}>{inc.status || 'UNKNOWN'}</span>
                    </div>
                  </div>
                  <div className="inc-type">🔥 {(inc.incident_type || inc.source || 'Emergency').replace(/_/g, ' ')}</div>
                  <div className="inc-location">
                    📍 {loc} {inc.confidence ? `• ${Math.round(inc.confidence * 100)}%` : ''}
                  </div>
                </div>
              );
            })
          )}
        </div>
      </div>
    </div>
  );
}
