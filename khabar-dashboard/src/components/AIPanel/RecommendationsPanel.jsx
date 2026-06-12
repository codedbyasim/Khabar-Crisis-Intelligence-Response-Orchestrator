import React from 'react';
import { useDashboard } from '../../context/DashboardContext';
import './RecommendationsPanel.css';

const RecommendationsPanel = () => {
  const { incidents } = useDashboard();

  // Sort incidents by priority (P1 first)
  const priorityOrder = { P1: 1, P2: 2, P3: 3, P4: 4, P5: 5 };
  const sortedIncidents = (incidents || [])
    .filter(inc => inc.priority) // Only incidents with priority
    .sort((a, b) => priorityOrder[a.priority] - priorityOrder[b.priority])
    .slice(0, 5); // Show top 5

  const getPriorityBadgeStyle = (priority) => {
    const styles = {
      P1: { background: '#e53935', label: 'CRITICAL (P1)' },
      P2: { background: '#fb8c00', label: 'HIGH' },
      P3: { background: '#fdd835', label: 'MEDIUM', color: '#333' },
      P4: { background: '#43a047', label: 'LOW' },
      P5: { background: '#1e88e5', label: 'INFO' },
    };
    return styles[priority] || { background: '#9e9e9e', label: 'UNKNOWN' };
  };

  return (
    <div className="recommendations-panel">
      <div className="panel-header">
        <h2>AI Decision Support: Emergency Queue</h2>
      </div>

      <div className="queue-list">
        {sortedIncidents.length === 0 ? (
          <div className="empty-state">
            <p>No active incidents</p>
          </div>
        ) : (
          sortedIncidents.map((incident, idx) => {
            const style = getPriorityBadgeStyle(incident.priority);
            return (
              <div key={incident.incident_id} className="queue-item">
                <div className="item-rank">{idx + 1}</div>
                <div className="item-content">
                  <div>
                    <span
                      className="priority-badge"
                      style={{ backgroundColor: style.background, color: style.color || 'white' }}
                    >
                      {style.label}
                    </span>
                  </div>
                  <p className="item-title">
                    {incident.incident_type || 'Emergency'}, {incident.location?.area || 'Unknown'}
                  </p>
                  <p className="item-meta">
                    Ranked: {incident.timestamp ? new Date(incident.timestamp).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'}) : 'Just now'}
                  </p>
                  <details style={{ marginTop: '8px' }}>
                    <summary style={{ cursor: 'pointer', fontSize: '11px', color: '#1e88e5', fontWeight: '500' }}>View AI Traces</summary>
                    <div style={{
                      marginTop: '6px',
                      maxHeight: '150px',
                      overflowY: 'auto',
                      backgroundColor: '#f1f3f4',
                      padding: '8px',
                      borderRadius: '4px',
                      fontSize: '11px',
                      fontFamily: 'monospace',
                      color: '#444'
                    }}>
                      {incident.traces && incident.traces.length > 0 ? (
                        incident.traces.map((trace, i) => (
                          <div key={i} style={{ marginBottom: '4px', borderBottom: i < incident.traces.length - 1 ? '1px dotted #ccc' : 'none', paddingBottom: '4px' }}>
                            {trace}
                          </div>
                        ))
                      ) : (
                        <div>No traces available yet.</div>
                      )}
                    </div>
                  </details>
                </div>
              </div>
            );
          })
        )}
      </div>

      <div className="ai-status-blocks">
        <div className="status-block">
          <div className="icon" style={{ color: '#fb8c00' }}>🤖</div>
          <span className="label">AI STATUS</span>
        </div>
        <div className="status-block">
          <div className="icon" style={{ color: '#43a047' }}>🟢</div>
          <span className="label">AI STATUS</span>
        </div>
      </div>
    </div>
  );
};

export default RecommendationsPanel;
