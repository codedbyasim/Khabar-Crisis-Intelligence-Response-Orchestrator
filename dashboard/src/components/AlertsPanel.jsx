import React from 'react';
import { Bell } from 'lucide-react';

export default function AlertsPanel({ incidents }) {
  // Collect all alerts from incidents
  const allAlerts = [];
  incidents.forEach(inc => {
    if (inc.generated_alerts && inc.generated_alerts.length > 0) {
      inc.generated_alerts.forEach(alertText => {
        allAlerts.push({
          id: inc.incident_id,
          text: alertText,
          priority: inc.priority || 'P3',
          type: inc.incident_type || inc.source || 'Emergency'
        });
      });
    }
  });

  // Potential escalation warnings (P1 still processing)
  const escalationWarnings = incidents.filter(inc => 
    inc.priority === 'P1' && inc.status === 'PROCESSING'
  );

  return (
    <div className="glass-card">
      <div className="glass-card-header">
        <span className="glass-card-title">
          <Bell size={18} style={{ color: 'var(--amber)' }} /> Alerts & Warnings
        </span>
        <span style={{
          fontSize: 11,
          fontWeight: 700,
          color: allAlerts.length > 0 ? 'var(--amber)' : 'var(--text-muted)',
          fontFamily: 'JetBrains Mono, monospace'
        }}>
          {allAlerts.length} total
        </span>
      </div>
      <div className="glass-card-body">
        {/* Escalation Warnings */}
        {escalationWarnings.length > 0 && (
          <div style={{ marginBottom: 16 }}>
            <div style={{ fontSize: 10, fontWeight: 700, color: 'var(--rose)', marginBottom: 8, textTransform: 'uppercase', letterSpacing: 0.8 }}>
              ⚠ Potential Escalation
            </div>
            {escalationWarnings.map(inc => (
              <div key={inc.incident_id} className="alert-card critical" style={{ marginBottom: 6 }}>
                <div className="alert-card-header">
                  <span className="alert-card-id">🔴 {inc.incident_id.substring(inc.incident_id.length - 6)}</span>
                  <span className="alert-card-time">P1 STILL PROCESSING</span>
                </div>
                <div className="alert-card-msg">
                  Critical incident "{(inc.incident_type || 'Emergency').replace(/_/g, ' ')}" is still being processed. Immediate manual review recommended.
                </div>
              </div>
            ))}
          </div>
        )}

        {/* Broadcast Alerts */}
        <div style={{ fontSize: 10, fontWeight: 700, color: 'var(--text-muted)', marginBottom: 8, textTransform: 'uppercase', letterSpacing: 0.8 }}>
          📢 Broadcast History
        </div>
        <div className="alert-feed">
          {allAlerts.length === 0 ? (
            <div className="no-data">No alerts broadcasted yet.</div>
          ) : (
            allAlerts.map((a, idx) => (
              <div key={idx} className={`alert-card ${a.priority === 'P1' ? 'critical' : ''}`}>
                <div className="alert-card-header">
                  <span className="alert-card-id">
                    INC-{a.id.substring(a.id.length - 4)}
                  </span>
                  <span className="alert-card-time" style={{ textTransform: 'capitalize' }}>
                    {a.type.replace(/_/g, ' ')}
                  </span>
                </div>
                <div className="alert-card-msg">{a.text}</div>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
}
