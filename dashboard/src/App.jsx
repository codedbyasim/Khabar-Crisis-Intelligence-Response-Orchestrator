import React, { useState, useEffect, useRef } from 'react';
import {
  Send,
  Clock,
} from 'lucide-react';

import Sidebar from './components/Sidebar';
import StatsGrid from './components/StatsGrid';
import MapWidget from './components/MapWidget';
import AgentPanel from './components/AgentPanel';
import SituationSummary from './components/SituationSummary';
import ResourceManager from './components/ResourceManager';
import AlertsPanel from './components/AlertsPanel';
import CaseTracker from './components/CaseTracker';
import Chatbot from './components/Chatbot';

const API_BASE = window.location.port === '8000'
  ? window.location.origin
  : 'http://127.0.0.1:8000';

const SCENARIOS = [
  {
    id: 1, title: "G-10 Water Logging", desc: "Flooding in sector G-10 Islamabad",
    text: "G-10 Islamabad mein pani bhar gaya hai, gaariyan doob rahi hain aur log phans gaye hain!",
    lat: 33.6938, lng: 73.0551, priority: "P1"
  },
  {
    id: 2, title: "F-7 Plaza Collapse", desc: "Structural damage in F-7 Markaz",
    text: "[PHOTO REPORT] F-7 Markaz Plaza structural collapse. Heavy debris blocking main market and people trapped under debris.",
    lat: 33.7245, lng: 73.0629, priority: "P2"
  },
  {
    id: 3, title: "Murree Road Pile-up", desc: "Multi-vehicle crash blocking traffic",
    text: "[PHOTO REPORT] Massive multi-vehicle pile-up accident on Murree Road involving a bus and two cars. Road completely blocked, traffic halted.",
    lat: 33.6105, lng: 73.0783, priority: "P2"
  },
  {
    id: 4, title: "DHA Heatwave", desc: "Heatwave temperature alert 47°C",
    text: "DHA Lahore Heatwave alert issued. Local temperatures rising rapidly to 47 degrees Celsius.",
    lat: 31.4697, lng: 74.4082, priority: "P3"
  },
  {
    id: 5, title: "IJP Road Pipeline Blast", desc: "Gas pipeline rupture on IJP Road",
    text: "IJP Road Rawalpindi block hai, road par bada gas pipeline blast ya main pipe toot gayi hai.",
    lat: 33.6392, lng: 73.0844, priority: "P1"
  }
];

export default function App() {
  const [activeSection, setActiveSection] = useState('dashboard');
  const [incidents, setIncidents] = useState([]);
  const [resources, setResources] = useState([]);
  const [resourceSummary, setResourceSummary] = useState(null);
  const [selectedId, setSelectedId] = useState(null);
  const [countdown, setCountdown] = useState(15);
  const [injectingId, setInjectingId] = useState(null);

  // Manual action state
  const [actionType, setActionType] = useState('dispatch');
  const [agency, setAgency] = useState('Rescue 1122');
  const [units, setUnits] = useState(1);
  const [message, setMessage] = useState('');
  const [location, setLocation] = useState('');
  const [newStatus, setNewStatus] = useState('IN_PROGRESS');
  const [actionLoading, setActionLoading] = useState(false);
  const [actionStatus, setActionStatus] = useState('');

  const pollIntervalRef = useRef(null);
  const countdownIntervalRef = useRef(null);

  // Fetch data
  const fetchData = async () => {
    try {
      const incRes = await fetch(`${API_BASE}/incidents`);
      const incData = await incRes.json();
      setIncidents(incData.incidents || []);

      const resRes = await fetch(`${API_BASE}/resources`);
      const resData = await resRes.json();
      setResources(resData.resources || []);
      setResourceSummary(resData.summary || null);
    } catch (err) {
      console.error("Error fetching data:", err);
    }
  };

  useEffect(() => {
    fetchData();
    pollIntervalRef.current = setInterval(() => {
      fetchData();
      setCountdown(15);
    }, 15000);
    countdownIntervalRef.current = setInterval(() => {
      setCountdown(prev => (prev > 1 ? prev - 1 : 15));
    }, 1000);
    return () => {
      clearInterval(pollIntervalRef.current);
      clearInterval(countdownIntervalRef.current);
    };
  }, []);

  const handleSelectIncident = (id) => {
    setSelectedId(id);
    setActionStatus('');
  };

  const handleResourceAdded = () => fetchData();

  const handleInjectScenario = async (sc) => {
    setInjectingId(sc.id);
    try {
      const response = await fetch(`${API_BASE}/report/text`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: sc.text, lat: sc.lat, lng: sc.lng })
      });
      const data = await response.json();
      if (data.success) {
        setSelectedId(data.incident_id);
        fetchData();
      }
    } catch (err) {
      console.error("Scenario injection error:", err);
    } finally {
      setTimeout(() => setInjectingId(null), 1000);
    }
  };

  const handleExecuteAction = async (e) => {
    e.preventDefault();
    if (!selectedId) return;
    setActionLoading(true);
    setActionStatus('Executing...');

    let payload = { incident_id: selectedId, action_type: actionType };
    if (actionType === 'dispatch') { payload.agency = agency; payload.units = parseInt(units); }
    else if (actionType === 'alert') { payload.message = message; payload.location = location || "Rawalpindi/Islamabad"; }
    else if (actionType === 'reroute') { payload.location = location || "Murree Road"; }
    else if (actionType === 'ticket') { payload.agency = agency; payload.message = message; }
    else if (actionType === 'status') { payload.new_status = newStatus; }

    try {
      const response = await fetch(`${API_BASE}/action/execute`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
      const data = await response.json();
      if (data.success) {
        setActionStatus('✅ Action executed successfully!');
        fetchData();
      } else {
        setActionStatus(`❌ Failed: ${data.error || 'Unknown error'}`);
      }
    } catch {
      setActionStatus('❌ Connection error.');
    } finally {
      setActionLoading(false);
    }
  };

  const selectedIncident = incidents.find(inc => inc.incident_id === selectedId);

  const parseTrace = (traceStr) => {
    if (!traceStr) return { phase: 'SYSTEM', time: '', message: '' };
    const match = traceStr.match(/^\[(.*?)\]\s+\[(.*?)\]\s+(.*)$/);
    if (match) {
      const timeFull = match[1];
      const phase = match[2];
      let message = match[3];
      
      // Remove "Affected: ... people" segment if present in the trace logs
      message = message.replace(/\|\s*Affected:\s*~?-?\d+\s*people\s*/gi, '');
      message = message.replace(/Affected:\s*~?-?\d+\s*people\s*\|\s*/gi, '');
      message = message.replace(/Affected:\s*~?-?\d+\s*people\s*/gi, '');

      const time = timeFull.includes('T') ? timeFull.split('T')[1].split('.')[0] : timeFull;
      return { phase, time, message };
    }
    return { phase: 'SYSTEM', time: '', message: traceStr };
  };

  const getAgentSteps = (inc) => {
    if (!inc) return [];
    const traces = inc.traces || [];
    const phases = traces.map(t => {
      const m = t.match(/\[(.*?)\]/g);
      return m && m[1] ? m[1].replace(/[\[\]]/g, '') : '';
    });
    const hasDet = phases.some(p => p === 'DETECTION');
    const hasAna = phases.some(p => p === 'ANALYSIS');
    const hasPlan = phases.some(p => p === 'PLANNING');
    const hasExec = phases.some(p => p === 'EXECUTION' || p === 'PIPELINE_COMPLETE');
    const isProc = inc.status === 'PROCESSING' || phases.some(p => p.includes('Attempt'));

    return [
      { id: 'det', icon: '🔍', label: 'Detection', done: hasDet, active: isProc && !hasDet },
      { id: 'ana', icon: '📊', label: 'Analysis', done: hasAna, active: isProc && hasDet && !hasAna },
      { id: 'pla', icon: '💡', label: 'Planning', done: hasPlan, active: isProc && hasAna && !hasPlan },
      { id: 'exe', icon: '⚡', label: 'Execution', done: hasExec, active: isProc && hasPlan && !hasExec },
    ];
  };

  // Alert count for sidebar badge
  const alertCount = incidents.reduce((sum, i) => sum + (i.generated_alerts?.length || 0), 0);

  // Section titles map
  const sectionTitles = {
    dashboard: 'Command Dashboard',
    map: 'Crisis Map',
    agents: 'AI Agents',
    resources: 'Resource Management',
    alerts: 'Alerts & Warnings',
    cases: 'Case Tracker',
  };

  return (
    <>
      <Sidebar
        activeSection={activeSection}
        onSectionChange={setActiveSection}
        alertCount={alertCount}
      />

      <div className="main-content">
        {/* Top Bar */}
        <div className="top-bar">
          <div className="top-bar-left">
            <span className="top-bar-title">{sectionTitles[activeSection] || 'Dashboard'}</span>
          </div>
          <div className="top-bar-right">
            <div className="live-indicator">
              <div className="live-dot"></div>
              <span className="live-text">LIVE</span>
            </div>
            <span className="refresh-badge">↻ {countdown}s</span>
          </div>
        </div>

        {/* Page Content */}
        <div className="page-content">

          {/* ═══ DASHBOARD VIEW ═══ */}
          {activeSection === 'dashboard' && (
            <>
              <StatsGrid incidents={incidents} resources={resources} resourceSummary={resourceSummary} />
              
              <MapWidget
                incidents={incidents}
                resources={resources}
                selectedId={selectedId}
                onSelectIncident={(id) => { handleSelectIncident(id); setActiveSection('agents'); }}
              />

              <div className="section-grid" style={{ marginTop: 20 }}>
                <SituationSummary incidents={incidents} />
                
                <div className="glass-card">
                  <div className="glass-card-header">
                    <span className="glass-card-title">
                      <Clock size={18} style={{ color: 'var(--cyan)' }} /> Recent Incidents
                    </span>
                    <span style={{ fontSize: 11, color: 'var(--text-muted)' }}>{incidents.length} active</span>
                  </div>
                  <div className="glass-card-body" style={{ maxHeight: 420, overflowY: 'auto' }}>
                    {incidents.length === 0 ? (
                      <div className="empty-state">
                        <div className="icon">📡</div>
                        <p>No active incidents. Waiting for signals...</p>
                      </div>
                    ) : (
                      incidents.slice(0, 8).map(inc => {
                        const loc = inc.location
                          ? `${inc.location.area || ''} ${inc.location.city || ''}`.trim()
                          : (inc.lat ? `${parseFloat(inc.lat).toFixed(4)}, ${parseFloat(inc.lng).toFixed(4)}` : 'Unknown');
                        const isActive = inc.incident_id === selectedId;
                        return (
                          <div
                            key={inc.incident_id}
                            className={`incident-item ${isActive ? 'active-item' : ''}`}
                            onClick={() => { handleSelectIncident(inc.incident_id); setActiveSection('agents'); }}
                          >
                            <div className="inc-header">
                              <span className="inc-id">{inc.incident_id}</span>
                              <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
                                <span className={`priority-badge badge-${(inc.priority || 'P5').toLowerCase()}`}>
                                  {inc.priority || 'P5'}
                                </span>
                                <span className={`status-chip ${
                                  (inc.status === 'PROCESSING' || inc.status === 'EXECUTING' || inc.status === 'IN_PROGRESS') ? 'chip-processing' :
                                  (inc.status === 'PIPELINE_COMPLETE' || inc.status === 'RESOLVED' || inc.status === 'CLOSED') ? 'chip-complete' :
                                  inc.status === 'MANUAL_REVIEW_REQUIRED' ? 'chip-manual' : 'chip-open'
                                }`}>
                                  {inc.status || 'UNKNOWN'}
                                </span>
                              </div>
                            </div>
                            <div className="inc-type">🔥 {(inc.incident_type || inc.source || 'Emergency').replace(/_/g, ' ')}</div>
                            <div className="inc-location">📍 {loc} {inc.confidence ? `• ${Math.round(inc.confidence * 100)}%` : ''}</div>
                          </div>
                        );
                      })
                    )}
                  </div>
                </div>
              </div>
            </>
          )}

          {/* ═══ MAP VIEW ═══ */}
          {activeSection === 'map' && (
            <MapWidget
              incidents={incidents}
              resources={resources}
              selectedId={selectedId}
              onSelectIncident={handleSelectIncident}
            />
          )}

          {/* ═══ AGENTS VIEW ═══ */}
          {activeSection === 'agents' && (
            <div className="section-grid">
              {/* Left: Incident Queue */}
              <div>
                <div className="glass-card" style={{ marginBottom: 20 }}>
                  <div className="glass-card-header">
                    <span className="glass-card-title">
                      <Clock size={18} style={{ color: 'var(--cyan)' }} /> Operations Queue
                    </span>
                    <span style={{ fontSize: 11, color: 'var(--text-muted)' }}>{incidents.length} active</span>
                  </div>
                  <div className="glass-card-body" style={{ maxHeight: 600, overflowY: 'auto' }}>
                    {incidents.length === 0 ? (
                      <div className="empty-state">
                        <div className="icon">📡</div>
                        <p>No active incidents.</p>
                      </div>
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
                            onClick={() => handleSelectIncident(inc.incident_id)}
                          >
                            <div className="inc-header">
                              <span className="inc-id">{inc.incident_id}</span>
                              <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
                                <span className={`priority-badge badge-${(inc.priority || 'P5').toLowerCase()}`}>
                                  {inc.priority || 'P5'}
                                </span>
                                <span className={`status-chip ${
                                  (inc.status === 'PROCESSING' || inc.status === 'EXECUTING' || inc.status === 'IN_PROGRESS') ? 'chip-processing' :
                                  (inc.status === 'PIPELINE_COMPLETE' || inc.status === 'RESOLVED' || inc.status === 'CLOSED') ? 'chip-complete' :
                                  inc.status === 'MANUAL_REVIEW_REQUIRED' ? 'chip-manual' : 'chip-open'
                                }`}>
                                  {inc.status || 'UNKNOWN'}
                                </span>
                              </div>
                            </div>
                            <div className="inc-type">🔥 {(inc.incident_type || inc.source || 'Emergency').replace(/_/g, ' ')}</div>
                            <div className="inc-location">📍 {loc} {inc.confidence ? `• ${Math.round(inc.confidence * 100)}%` : ''}</div>
                          </div>
                        );
                      })
                    )}
                  </div>
                </div>
              </div>

              {/* Right: Agent Panel */}
              <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
                <AgentPanel
                  selectedIncident={selectedIncident}
                  selectedId={selectedId}
                  resources={resources}
                  agentSteps={getAgentSteps(selectedIncident)}
                  actionType={actionType} setActionType={setActionType}
                  agency={agency} setAgency={setAgency}
                  units={units} setUnits={setUnits}
                  message={message} setMessage={setMessage}
                  location={location} setLocation={setLocation}
                  newStatus={newStatus} setNewStatus={setNewStatus}
                  actionLoading={actionLoading}
                  actionStatus={actionStatus}
                  handleExecuteAction={handleExecuteAction}
                  apiBase={API_BASE}
                  parseTrace={parseTrace}
                />
              </div>
            </div>
          )}

          {/* ═══ RESOURCES VIEW ═══ */}
          {activeSection === 'resources' && (
            <ResourceManager
              resources={resources}
              resourceSummary={resourceSummary}
              apiBase={API_BASE}
              onResourceAdded={handleResourceAdded}
            />
          )}

          {/* ═══ ALERTS VIEW ═══ */}
          {activeSection === 'alerts' && (
            <AlertsPanel incidents={incidents} />
          )}

          {/* ═══ CASES VIEW ═══ */}
          {activeSection === 'cases' && (
            <CaseTracker
              incidents={incidents}
              selectedId={selectedId}
              onSelectIncident={(id) => { handleSelectIncident(id); setActiveSection('agents'); }}
            />
          )}

        </div>
      </div>
      <Chatbot apiBase={API_BASE} onActionExecuted={fetchData} />
    </>
  );
}
