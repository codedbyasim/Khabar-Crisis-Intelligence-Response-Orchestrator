import React from 'react';
import {
  Bot,
  Activity,
  FileText,
  Shield,
  ShieldAlert,
  ArrowRight,
  CheckCircle
} from 'lucide-react';

const PHASE_CLASS_MAP = {
  DETECTION: 'trace-detection',
  ANALYSIS: 'trace-analysis',
  PLANNING: 'trace-planning',
  EXECUTION: 'trace-execution',
  PIPELINE_COMPLETE: 'trace-pipeline',
  INGESTION: 'trace-ingestion',
  FALLBACK: 'trace-error',
  DETECTION_ERROR: 'trace-error',
  ANALYSIS_ERROR: 'trace-error',
  PLANNING_ERROR: 'trace-error',
  EXECUTION_ERROR: 'trace-error',
  SYSTEM: 'trace-system'
};

export default function AgentPanel({
  selectedIncident,
  selectedId,
  resources = [],
  agentSteps,
  actionType, setActionType,
  agency, setAgency,
  units, setUnits,
  message, setMessage,
  location, setLocation,
  newStatus, setNewStatus,
  actionLoading,
  actionStatus,
  handleExecuteAction,
  apiBase,
  parseTrace
}) {
  if (!selectedIncident) {
    return (
      <div className="glass-card">
        <div className="glass-card-header">
          <span className="glass-card-title">
            <Bot size={18} style={{ color: 'var(--cyan)' }} /> AI Agent Pipeline
          </span>
        </div>
        <div className="glass-card-body">
          <div className="empty-state">
            <div className="icon">🛡️</div>
            <p>Select an incident from the queue to view AI reasoning, agent pipeline status, and coordinator controls.</p>
          </div>
        </div>
      </div>
    );
  }

  const locObj = selectedIncident.location || {};
  const isVerified = locObj.is_verified !== false && selectedIncident.status !== 'REJECTED';
  const vReason = locObj.verification_reason || 'Report authenticity verified by AI analysis.';

  return (
    <>
      {/* Agent Pipeline Card */}
      <div className="glass-card">
        <div className="glass-card-header">
          <span className="glass-card-title">
            <Bot size={18} style={{ color: 'var(--cyan)' }} /> AI Agent Pipeline
          </span>
          <span style={{ fontSize: '12px', fontFamily: 'JetBrains Mono, monospace', fontWeight: 600, color: 'var(--cyan)' }}>
            {selectedId}
          </span>
        </div>
        <div className="glass-card-body">
          {/* Verification Banner */}
          <div className={`verification-banner ${isVerified ? 'verified' : 'suspicious'}`}>
            <div>
              <div className="v-label">
                {isVerified ? <><Shield size={14} /> Verified Crisis Signal</> : <><ShieldAlert size={14} /> Suspicious / Spam Flagged</>}
              </div>
              <div className="v-reason">{vReason}</div>
            </div>
          </div>

          {/* Agent Steps */}
          <div className="agent-pipeline-row">
            {agentSteps.map((step, idx, arr) => (
              <React.Fragment key={step.id}>
                <div className="agent-node">
                  <div className={`agent-icon-circle ${step.done ? 'done' : ''} ${step.active ? 'active' : ''}`}>
                    {step.icon}
                  </div>
                  <div className="agent-node-label">{step.label}</div>
                </div>
                {idx < arr.length - 1 && (
                  <div className={`agent-connector ${step.done ? 'done' : ''}`} />
                )}
              </React.Fragment>
            ))}
          </div>

          {/* Allocated Resources */}
          {(() => {
            const assignedResources = (resources || []).filter(r => r.assigned_incident === selectedId);
            if (assignedResources.length === 0) return null;
            return (
              <div style={{ marginTop: 20, marginBottom: 15, padding: 12, borderRadius: 'var(--radius-md)', border: '1px solid var(--border)', background: 'var(--bg-base)' }}>
                <div style={{ fontSize: '11px', fontWeight: 700, color: 'var(--cyan)', textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 8, display: 'flex', alignItems: 'center', gap: 6 }}>
                  <span>🚑</span> Allocated Incident Resources
                </div>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                  {assignedResources.map(r => (
                    <span key={r.resource_id} style={{ display: 'inline-flex', alignItems: 'center', gap: 6, background: 'var(--cyan-glow)', color: 'var(--cyan)', border: '1px solid rgba(2, 132, 199, 0.2)', padding: '4px 10px', borderRadius: '14px', fontSize: '11px', fontWeight: 600 }}>
                      <span style={{ width: 6, height: 6, background: 'var(--cyan)', borderRadius: '50%' }}></span>
                      {r.name}
                    </span>
                  ))}
                </div>
              </div>
            );
          })()}

          {/* Manual Coordinator Controls */}
          <div className="coord-panel">
            <div className="coord-panel-title">
              ⚡ Manual Coordinator Override
            </div>

            <form onSubmit={handleExecuteAction}>
              <div className="form-grid">
                <div>
                  <select className="dark-select" value={actionType} onChange={e => setActionType(e.target.value)}>
                    <option value="dispatch">Dispatch Rescue Unit</option>
                    <option value="alert">Send Broadcast Alert</option>
                    <option value="reroute">Traffic Reroute (Close Road)</option>
                    <option value="ticket">Create Emergency Ticket</option>
                    <option value="status">Update Case Status</option>
                  </select>
                </div>

                {actionType === 'dispatch' && (
                  <div>
                    <select className="dark-select" value={agency} onChange={e => setAgency(e.target.value)}>
                      <option value="Rescue 1122">Rescue 1122</option>
                      <option value="WASA Rawalpindi">WASA Rawalpindi</option>
                      <option value="Islamabad Traffic Police">Traffic Police</option>
                      <option value="NDMA">NDMA</option>
                    </select>
                  </div>
                )}

                {actionType === 'status' && (
                  <div>
                    <select className="dark-select" value={newStatus} onChange={e => setNewStatus(e.target.value)}>
                      <option value="PROCESSING">PROCESSING</option>
                      <option value="PIPELINE_COMPLETE">PIPELINE_COMPLETE</option>
                      <option value="MANUAL_REVIEW_REQUIRED">MANUAL_REVIEW_REQUIRED</option>
                      <option value="REJECTED">REJECTED / RESOLVED</option>
                    </select>
                  </div>
                )}

                {(actionType === 'alert' || actionType === 'reroute') && (
                  <div>
                    <input type="text" placeholder="Location / Zone name" className="dark-input" value={location} onChange={e => setLocation(e.target.value)} />
                  </div>
                )}

                {actionType === 'ticket' && (
                  <div>
                    <input type="text" placeholder="Target Agency (e.g. WASA)" className="dark-input" value={agency} onChange={e => setAgency(e.target.value)} />
                  </div>
                )}
              </div>

              <div className="form-grid">
                {actionType === 'dispatch' && (
                  <div style={{ gridColumn: 'span 2' }}>
                    <input type="number" placeholder="Number of units" className="dark-input" min="1" value={units} onChange={e => setUnits(e.target.value)} />
                  </div>
                )}
                {(actionType === 'alert' || actionType === 'ticket') && (
                  <div style={{ gridColumn: 'span 2' }}>
                    <input type="text" placeholder={actionType === 'alert' ? 'Public emergency message...' : 'Urgent ticket description...'} className="dark-input" value={message} onChange={e => setMessage(e.target.value)} required />
                  </div>
                )}
              </div>

              <button type="submit" className="btn-primary" disabled={actionLoading}>
                {actionLoading ? 'Executing override...' : '⚡ Send Coordinator Override'}
              </button>
            </form>

            {actionStatus && (
              <div style={{ fontSize: 12, fontWeight: 600, marginTop: 10, color: 'var(--cyan)', textAlign: 'center' }}>
                {actionStatus}
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Case Analysis & Summary */}
      <div className="glass-card">
        <div className="glass-card-header">
          <span className="glass-card-title">
            <FileText size={18} style={{ color: 'var(--cyan)' }} /> Case Analysis & Summary
          </span>
        </div>
        <div className="glass-card-body">
          <div style={{ display: 'flex', flexDirection: 'column', gap: '15px' }}>
            <div style={{ padding: '12px 16px', borderRadius: 'var(--radius-md)', border: '1px solid var(--border)', background: 'var(--bg-base)' }}>
              <div style={{ fontSize: '11px', fontWeight: 700, color: 'var(--cyan)', textTransform: 'uppercase', letterSpacing: '0.5px', marginBottom: '6px' }}>
                English Case Summary
              </div>
              <p style={{ fontSize: '13px', lineHeight: '1.6', color: 'var(--text-light)', margin: 0 }}>
                {selectedIncident.english_summary || (
                  <span style={{ color: 'var(--text-muted)', fontStyle: 'italic' }}>
                    ⌛ Impact analysis pending (waiting for Analysis Agent)...
                  </span>
                )}
              </p>
            </div>

            <div style={{ padding: '12px 16px', borderRadius: 'var(--radius-md)', border: '1px solid var(--border)', background: 'var(--bg-base)' }}>
              <div style={{ fontSize: '11px', fontWeight: 700, color: 'var(--emerald)', textTransform: 'uppercase', letterSpacing: '0.5px', marginBottom: '6px', textAlign: 'right' }}>
                خلاصہ (Urdu Case Summary)
              </div>
              <p dir="rtl" style={{ fontSize: '14px', lineHeight: '1.7', color: 'var(--text-light)', margin: 0, fontFamily: 'Noto Nastaliq Urdu, system-ui', fontWeight: '500' }}>
                {selectedIncident.urdu_summary || (
                  <span style={{ color: 'var(--text-muted)', fontStyle: 'italic', fontSize: '12px' }}>
                    ⌛ تجزیہ زیرِ کار ہے (انتظار فرمائیں)...
                  </span>
                )}
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* AI Trace Console */}
      <div className="glass-card">
        <div className="glass-card-header">
          <span className="glass-card-title">
            <Activity size={18} style={{ color: 'var(--violet)' }} /> Real-Time AI Agent Traces
          </span>
          <a
            href={`${apiBase}/logs/${selectedId}`}
            target="_blank"
            rel="noreferrer"
            className="btn-outline"
          >
            Export Log
          </a>
        </div>
        <div className="glass-card-body">
          <div className="trace-list">
            {(!selectedIncident.traces || selectedIncident.traces.length === 0) ? (
              <div className="no-data">No traces registered yet</div>
            ) : (
              selectedIncident.traces.slice().reverse().map((t, idx) => {
                const { phase, time, message: msg } = parseTrace(t);
                const cls = PHASE_CLASS_MAP[phase] || 'trace-system';
                return (
                  <div key={idx} className={`trace-item ${cls}`}>
                    <span className="trace-phase">[{phase}]</span>
                    <span style={{ color: 'var(--text-dim)', marginRight: 8 }}>{time}</span>
                    <span>{msg}</span>
                  </div>
                );
              })
            )}
          </div>
        </div>
      </div>
    </>
  );
}
