"""
dashboard_server.py — KHABAR Real-Time Web Dashboard
FR-23: Before/after state | FR-24: P1-P5 queue | FR-25: Agent trace | FR-26: Auto-refresh
Run: python dashboard_server.py  →  http://127.0.0.1:8001
"""
import sys, os
sys.path.append(os.path.join(os.path.dirname(__file__), "agents"))

from fastapi import FastAPI
from fastapi.responses import HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

app = FastAPI(title="KHABAR Dashboard")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

DASHBOARD_HTML = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>KHABAR — Crisis Intelligence Dashboard</title>
<link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700;800&family=JetBrains+Mono:wght@400;600&display=swap" rel="stylesheet">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'Outfit',sans-serif;background:radial-gradient(circle at top right, #0d1b2a, #030712);color:#f8fafc;min-height:100vh}
:root{--teal:#00e5ff;--red:#ff3366;--orange:#ff9f43;--green:#00e676;--blue:#2979ff;--card:rgba(15, 23, 42, 0.6);--border:rgba(255, 255, 255, 0.08);--glass:rgba(255, 255, 255, 0.03)}
header{background:rgba(3, 7, 18, 0.8);backdrop-filter:blur(12px);padding:16px 32px;display:flex;align-items:center;justify-content:space-between;border-bottom:1px solid var(--border);position:sticky;top:0;z-index:100}
.logo{display:flex;align-items:center;gap:16px}
.logo-icon{width:44px;height:44px;background:linear-gradient(135deg,var(--teal),#0077aa);border-radius:12px;display:flex;align-items:center;justify-content:center;font-size:22px;box-shadow:0 8px 16px rgba(0, 229, 255, 0.2)}
.logo h1{font-size:22px;font-weight:800;letter-spacing:1px;background:linear-gradient(to right,#fff,var(--teal));-webkit-background-clip:text;-webkit-text-fill-color:transparent}
.logo p{font-size:12px;color:#94a3b8;margin-top:2px;font-weight:500}
.status-bar{display:flex;align-items:center;gap:20px;background:var(--glass);padding:8px 16px;border-radius:20px;border:1px solid var(--border)}
.live-dot{width:10px;height:10px;background:var(--green);border-radius:50%;animation:pulse 1.5s infinite;box-shadow:0 0 10px var(--green)}
@keyframes pulse{0%,100%{opacity:1;transform:scale(1)}50%{opacity:.5;transform:scale(1.3)}}
.live-text{font-size:13px;color:var(--green);font-weight:700;letter-spacing:1px}
.refresh-info{font-size:12px;color:#cbd5e1}
.main{padding:32px;display:grid;grid-template-columns:1fr 1fr;gap:24px;max-width:1600px;margin:0 auto}
.full-width{grid-column:1/-1}
.card{background:var(--card);backdrop-filter:blur(16px);-webkit-backdrop-filter:blur(16px);border:1px solid var(--border);border-radius:24px;overflow:hidden;box-shadow:0 20px 40px rgba(0,0,0,0.4)}
.card-header{padding:20px 24px;background:linear-gradient(180deg, rgba(255,255,255,0.05) 0%, rgba(255,255,255,0) 100%);border-bottom:1px solid var(--border);display:flex;align-items:center;justify-content:space-between}
.card-title{font-size:15px;font-weight:700;letter-spacing:0.5px;color:#fff;display:flex;align-items:center;gap:10px}
.card-body{padding:24px}
.stat-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:20px;margin-bottom:10px}
.stat-card{background:linear-gradient(135deg, rgba(255,255,255,0.05), rgba(255,255,255,0));border:1px solid var(--border);border-radius:20px;padding:24px;text-align:center;position:relative;overflow:hidden}
.stat-card::before{content:'';position:absolute;top:0;left:0;right:0;height:2px;background:var(--teal);opacity:0.3}
.stat-val{font-size:36px;font-weight:800;margin-bottom:8px;font-family:'JetBrains Mono',monospace}
.stat-label{font-size:12px;color:#94a3b8;text-transform:uppercase;letter-spacing:1px;font-weight:600}
.p1{color:var(--red);text-shadow:0 0 15px rgba(255,51,102,0.4)}.p2{color:var(--orange)}.p3{color:#facc15}.p4{color:var(--blue)}.p5{color:var(--green)}
.priority-badge{display:inline-flex;align-items:center;padding:4px 10px;border-radius:8px;font-size:11px;font-weight:800;letter-spacing:0.5px}
.badge-p1{background:rgba(255,51,102,.15);color:var(--red);border:1px solid rgba(255,51,102,.3)}
.badge-p2{background:rgba(255,159,67,.15);color:var(--orange);border:1px solid rgba(255,159,67,.3)}
.badge-p3{background:rgba(250,204,21,.15);color:#facc15;border:1px solid rgba(250,204,21,.3)}
.badge-p4{background:rgba(41,121,255,.15);color:var(--blue);border:1px solid rgba(41,121,255,.3)}
.badge-p5{background:rgba(0,230,118,.15);color:var(--green);border:1px solid rgba(0,230,118,.3)}
.incident-item{background:rgba(0,0,0,0.2);border:1px solid var(--border);border-radius:16px;padding:16px;margin-bottom:12px;cursor:pointer;transition:all .3s ease}
.incident-item:hover{border-color:var(--teal);transform:translateY(-2px);background:rgba(0,229,255,0.05)}
.incident-item.active-item{border-color:var(--teal);background:linear-gradient(to right, rgba(0,229,255,0.1), transparent);border-left:4px solid var(--teal)}
.inc-header{display:flex;align-items:center;justify-content:space-between;margin-bottom:10px}
.inc-id{font-family:'JetBrains Mono',monospace;font-size:14px;font-weight:700;color:var(--teal)}
.inc-type{font-size:13px;color:#e2e8f0;margin-bottom:8px;text-transform:capitalize;font-weight:600}
.inc-location{font-size:12px;color:#94a3b8;display:flex;align-items:center;gap:6px}
.status-chip{display:inline-flex;align-items:center;gap:5px;padding:4px 12px;border-radius:20px;font-size:11px;font-weight:700;letter-spacing:0.5px;text-transform:uppercase}
.chip-processing{background:rgba(0,229,255,.15);color:var(--teal)}
.chip-complete{background:rgba(0,230,118,.15);color:var(--green)}
.chip-manual{background:rgba(255,51,102,.15);color:var(--red)}
.chip-open{background:rgba(148,163,184,.15);color:#cbd5e1}
.trace-list{max-height:300px;overflow-y:auto;display:flex;flex-direction:column;gap:8px;padding-right:8px}
.trace-item{background:rgba(0,0,0,0.3);border-left:3px solid var(--border);padding:10px 14px;border-radius:0 12px 12px 0;font-size:12px;font-family:'JetBrains Mono',monospace;line-height:1.6;color:#cbd5e1}
.trace-item.trace-detection{border-left-color:var(--blue)}
.trace-item.trace-analysis{border-left-color:#a78bfa}
.trace-item.trace-planning{border-left-color:#34d399}
.trace-item.trace-execution{border-left-color:var(--teal)}
.trace-item.trace-pipeline{border-left-color:var(--green)}
.trace-item.trace-error{border-left-color:var(--red)}
.trace-phase{font-weight:800;margin-right:8px;opacity:0.9}
.before-after{display:grid;grid-template-columns:1fr auto 1fr;gap:20px;align-items:stretch}
.state-box{background:rgba(0,0,0,0.3);border:1px solid var(--border);border-radius:20px;padding:20px}
.state-box h4{font-size:13px;text-transform:uppercase;letter-spacing:1px;font-weight:800;margin-bottom:16px}
.state-box.before h4{color:#94a3b8}
.state-box.after h4{color:var(--green)}
.state-row{display:flex;justify-content:space-between;align-items:center;padding:8px 0;border-bottom:1px dashed rgba(255,255,255,0.1);font-size:13px}
.state-row:last-child{border:none}
.state-key{color:#94a3b8;font-weight:500}.state-val{font-weight:700;color:#f8fafc;font-family:'JetBrains Mono',monospace}
.state-val.changed{color:var(--green);text-shadow:0 0 10px rgba(0,230,118,0.3)}
.arrow-icon{font-size:28px;color:var(--teal);display:flex;align-items:center;animation:bounce-x 2s infinite}
@keyframes bounce-x{0%,100%{transform:translateX(0)}50%{transform:translateX(5px)}}
.resource-grid{display:grid;grid-template-columns:repeat(2,1fr);gap:16px}
.res-item{background:linear-gradient(135deg, rgba(255,255,255,0.05), transparent);border:1px solid var(--border);border-radius:16px;padding:16px;position:relative}
.res-name{font-size:13px;color:#94a3b8;margin-bottom:6px;font-weight:600}
.res-count{font-size:28px;font-weight:800;color:var(--teal);font-family:'JetBrains Mono',monospace}
.res-status{font-size:11px;color:#cbd5e1;margin-top:4px;font-weight:500}
.agent-pipeline{display:flex;align-items:center;gap:8px;padding:24px 0}
.agent-step{flex:1;text-align:center;position:relative}
.agent-circle{width:56px;height:56px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:24px;margin:0 auto 12px;transition:all .4s cubic-bezier(0.4, 0, 0.2, 1);background:rgba(0,0,0,0.4);border:2px solid var(--border)}
.agent-circle.done{background:linear-gradient(135deg,var(--teal),#0077aa);border-color:var(--teal);box-shadow:0 0 20px rgba(0,229,255,.4)}
.agent-circle.active{border-color:var(--teal);animation:pulse-ring 2s infinite}
@keyframes pulse-ring{0%{box-shadow:0 0 0 0 rgba(0,229,255,0.4)}70%{box-shadow:0 0 0 15px rgba(0,229,255,0)}100%{box-shadow:0 0 0 0 rgba(0,229,255,0)}}
.agent-label{font-size:12px;color:#94a3b8;font-weight:600;letter-spacing:0.5px;text-transform:uppercase}
.agent-connector{flex-grow:1;height:2px;background:var(--border);position:relative;top:-14px}
.agent-connector.done{background:var(--teal);box-shadow:0 0 8px var(--teal)}
.empty-state{text-align:center;padding:60px 20px;color:#64748b}
.empty-state .icon{font-size:48px;margin-bottom:16px;opacity:0.5}
.empty-state p{font-size:14px;font-weight:500}
.alert-hist{max-height:220px;overflow-y:auto;display:flex;flex-direction:column;gap:12px}
.alert-item{background:rgba(255,159,67,0.1);border-left:4px solid var(--orange);padding:12px 16px;border-radius:0 12px 12px 0}
.alert-header{display:flex;justify-content:space-between;margin-bottom:6px}
.alert-title{font-size:12px;font-weight:800;color:var(--orange);letter-spacing:0.5px;text-transform:uppercase}
.alert-msg{font-size:13px;color:#f8fafc;line-height:1.5}
::-webkit-scrollbar{width:6px}::-webkit-scrollbar-track{background:transparent}::-webkit-scrollbar-thumb{background:rgba(255,255,255,0.1);border-radius:10px}::-webkit-scrollbar-thumb:hover{background:var(--teal)}
.no-data{color:#64748b;font-size:13px;text-align:center;padding:30px;font-style:italic}
.injector-grid{display:grid;grid-template-columns:repeat(5, 1fr);gap:16px;padding:24px}
.inject-btn{border:none;border-radius:16px;padding:16px;color:#fff;font-weight:700;font-size:12px;cursor:pointer;transition:all 0.3s cubic-bezier(0.4, 0, 0.2, 1);text-align:left;display:flex;flex-direction:column;gap:6px;box-shadow:0 10px 20px rgba(0,0,0,0.2);width:100%;font-family:'Outfit'}
.inject-btn:hover{transform:translateY(-4px);box-shadow:0 15px 30px rgba(0,0,0,0.4)}
.inject-btn .priority{font-size:10px;padding:4px 8px;border-radius:6px;width:max-content;font-weight:800;letter-spacing:1px}
.inject-btn.btn-p1{background:linear-gradient(135deg, #ff3366, #cc0033)}
.inject-btn.btn-p1 .priority{background:rgba(255,255,255,0.25);color:#fff}
.inject-btn.btn-p2{background:linear-gradient(135deg, #ff9f43, #e67e22)}
.inject-btn.btn-p2 .priority{background:rgba(255,255,255,0.25);color:#fff}
.inject-btn.btn-p3{background:linear-gradient(135deg, #facc15, #d4af37);color:#0f172a}
.inject-btn.btn-p3 .priority{background:rgba(0,0,0,0.15);color:#0f172a}
.inject-btn .sc-title{font-size:14px;font-weight:800;margin-top:4px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.inject-btn .sc-desc{font-size:11px;opacity:0.9;font-weight:500;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
</style>
</head>
<body>
<header>
  <div class="logo">
    <div class="logo-icon">🚨</div>
    <div>
      <h1>KHABAR CIRO</h1>
      <p>Crisis Intelligence & Response Orchestrator</p>
    </div>
  </div>
  <div class="status-bar">
    <div class="live-dot"></div>
    <span class="live-text">LIVE</span>
    <span class="refresh-info" id="refresh-timer">Auto-refresh in 5s</span>
  </div>
</header>

<div class="main">
  <!-- Demo Scenarios Quick-Inject -->
  <div class="card full-width">
    <div class="card-header">
      <span class="card-title"><span class="icon">⚡</span> Quick Trigger Demo Scenarios</span>
      <span style="font-size:12px;color:#94a3b8;font-weight:600">1-Click to trigger live 4-agent pipeline</span>
    </div>
    <div class="injector-grid">
      <button class="inject-btn btn-p1" onclick="injectScenario(1)">
        <span class="priority">P1 CRITICAL</span>
        <span class="sc-title">G-10 Flood</span>
        <span class="sc-desc">"Pani bhar gaya hai..."</span>
      </button>
      <button class="inject-btn btn-p1" onclick="injectScenario(2)">
        <span class="priority">P1 CRITICAL</span>
        <span class="sc-title">F-7 Collapse</span>
        <span class="sc-desc">Photo Damage Analysis</span>
      </button>
      <button class="inject-btn btn-p2" onclick="injectScenario(3)">
        <span class="priority">P2 HIGH</span>
        <span class="sc-title">Murree Accident</span>
        <span class="sc-desc">Photo Pile-up Assessment</span>
      </button>
      <button class="inject-btn btn-p2" onclick="injectScenario(4)">
        <span class="priority">P2 HIGH</span>
        <span class="sc-title">Lahore Heatwave</span>
        <span class="sc-desc">Auto Weather Alert 47°C</span>
      </button>
      <button class="inject-btn btn-p3" onclick="injectScenario(5)">
        <span class="priority">P3 STANDARD</span>
        <span class="sc-title">IJP Blockage</span>
        <span class="sc-desc">"Sadak band hai..."</span>
      </button>
    </div>
  </div>

  <!-- Stats Row -->
  <div class="stat-grid full-width" id="stats-row">
    <div class="stat-card"><div class="stat-val p1" id="cnt-p1">—</div><div class="stat-label">P1 Critical</div></div>
    <div class="stat-card"><div class="stat-val p2" id="cnt-p2">—</div><div class="stat-label">P2 High</div></div>
    <div class="stat-card"><div class="stat-val p3" id="cnt-total">—</div><div class="stat-label">Total Incidents</div></div>
    <div class="stat-card"><div class="stat-val" style="color:var(--teal)" id="cnt-alerts">—</div><div class="stat-label">Alerts Broadcasted</div></div>
  </div>

  <!-- Incident Queue -->
  <div class="card">
    <div class="card-header">
      <span class="card-title"><span class="icon">📋</span> Live Incident Queue</span>
      <span id="queue-count" style="font-size:12px;color:#94a3b8;font-weight:600"></span>
    </div>
    <div class="card-body" style="max-height:600px;overflow-y:auto;" id="incident-list">
      <div class="empty-state"><div class="icon">📡</div><p>Listening for incoming signals...</p></div>
    </div>
  </div>

  <!-- Agent Pipeline + Trace -->
  <div class="card">
    <div class="card-header">
      <span class="card-title"><span class="icon">🤖</span> AI Agent Trace Logs</span>
      <span id="selected-inc-id" style="font-size:13px;color:var(--teal);font-family:'JetBrains Mono',monospace;font-weight:700"></span>
    </div>
    <div class="card-body">
      <div class="agent-pipeline" id="agent-pipeline">
        <div class="agent-step"><div class="agent-circle">🔍</div><div class="agent-label">Detection</div></div>
        <div class="agent-connector"></div>
        <div class="agent-step"><div class="agent-circle">📊</div><div class="agent-label">Analysis</div></div>
        <div class="agent-connector"></div>
        <div class="agent-step"><div class="agent-circle">💡</div><div class="agent-label">Planning</div></div>
        <div class="agent-connector"></div>
        <div class="agent-step"><div class="agent-circle">⚡</div><div class="agent-label">Execution</div></div>
      </div>
      <div id="verification-banner"></div>
      <div class="trace-list" id="trace-list">
        <div class="no-data">Select an incident from the queue to view trace logs</div>
      </div>
    </div>
  </div>

  <!-- Before / After State -->
  <div class="card full-width" id="before-after-card" style="display:none">
    <div class="card-header">
      <span class="card-title"><span class="icon">🔄</span> Outcome Simulation: Before vs After</span>
      <span style="font-size:12px;color:var(--green);font-weight:800;letter-spacing:1px;text-transform:uppercase">✅ Simulated</span>
    </div>
    <div class="card-body">
      <div class="before-after" id="before-after-content"></div>
    </div>
  </div>

  <!-- Resources -->
  <div class="card">
    <div class="card-header"><span class="card-title"><span class="icon">🚑</span> Live Resource Inventory</span></div>
    <div class="card-body">
      <div class="resource-grid" id="resource-grid">
        <div class="no-data">Loading resources...</div>
      </div>
    </div>
  </div>

  <!-- Alert History -->
  <div class="card">
    <div class="card-header"><span class="card-title"><span class="icon">📢</span> Public Broadcasts</span></div>
    <div class="card-body">
      <div class="alert-hist" id="alert-hist">
        <div class="no-data">No alerts broadcasted yet</div>
      </div>
    </div>
  </div>
</div>

<script>
const API = 'http://127.0.0.1:8000';
let selectedId = null;
let countdown = 5;
let allIncidents = [];

async function injectScenario(id){
  let payload = {};
  if (id === 1) {
    payload = { text: "G-10 Islamabad mein pani bhar gaya hai, gaariyan doob rahi hain aur log phans gaye hain!", lat: 33.6938, lng: 73.0551 };
  } else if (id === 2) {
    payload = { text: "[PHOTO REPORT] F-7 Markaz Plaza structural collapse. Heavy debris blocking main market and people trapped under debris.", lat: 33.7245, lng: 73.0629 };
  } else if (id === 3) {
    payload = { text: "[PHOTO REPORT] Massive multi-vehicle pile-up accident on Murree Road involving a bus and two cars. Road completely blocked, traffic halted.", lat: 33.6105, lng: 73.0783 };
  } else if (id === 4) {
    payload = { text: "DHA Lahore Heatwave alert issued. Local temperatures rising rapidly to 47 degrees Celsius.", lat: 31.4697, lng: 74.4082 };
  } else if (id === 5) {
    payload = { text: "IJP Road Rawalpindi block hai, road par bada gas pipeline blast ya main pipe toot gayi hai.", lat: 33.6392, lng: 73.0844 };
  }
  
  try {
    const btn = event.currentTarget;
    const oldText = btn.innerHTML;
    btn.innerHTML = `<span class="priority">SENDING...</span><span class="sc-title">Injecting...</span><span class="sc-desc">Running Agent Chain</span>`;
    btn.disabled = true;

    const r = await fetch(`${API}/report/text`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    });
    const d = await r.json();
    
    setTimeout(() => {
      btn.innerHTML = oldText;
      btn.disabled = false;
    }, 1500);

    if (d.success) {
      selectedId = d.incident_id;
      tick();
    }
  } catch(e) {
    console.error("Failed to inject scenario:", e);
    alert("Error triggering scenario. Make sure your api_server is running on http://127.0.0.1:8000");
  }
}

const PHASE_COLORS = {
  DETECTION:'trace-detection', ANALYSIS:'trace-analysis',
  PLANNING:'trace-planning', EXECUTION:'trace-execution',
  PIPELINE_COMPLETE:'trace-pipeline', INGESTION:'trace-ingestion',
  FALLBACK:'trace-error', DETECTION_ERROR:'trace-error',
  ANALYSIS_ERROR:'trace-error', PLANNING_ERROR:'trace-error', EXECUTION_ERROR:'trace-error'
};

function getPriorityBadge(p){
  return `<span class="priority-badge badge-${(p||'p5').toLowerCase()}">${p||'—'}</span>`;
}
function getStatusChip(s){
  const map={'PROCESSING':'chip-processing','PIPELINE_COMPLETE':'chip-complete','MANUAL_REVIEW_REQUIRED':'chip-manual','OPEN':'chip-open'};
  const cls = map[s]||'chip-open';
  return `<span class="status-chip ${cls}">${s||'UNKNOWN'}</span>`;
}

async function fetchIncidents(){
  try{
    const r = await fetch(`${API}/incidents`);
    const d = await r.json();
    allIncidents = d.incidents||[];
    renderQueue(allIncidents);
    updateStats(allIncidents, d.resource_summary);
    renderAlerts(allIncidents);
    if(selectedId){
      const found = allIncidents.find(i=>i.incident_id===selectedId);
      if(found) renderDetail(found);
    }
  }catch(e){ console.error('Fetch incidents failed',e); }
}

async function fetchResources(){
  try{
    const r = await fetch(`${API}/resources`);
    const d = await r.json();
    renderResources(d.summary, d.resources);
  }catch(e){}
}

function updateStats(incidents, resourceSummary){
  const p1 = incidents.filter(i=>i.priority==='P1').length;
  const p2 = incidents.filter(i=>i.priority==='P2').length;
  const totalAlerts = incidents.reduce((sum,i)=>sum+((i.generated_alerts||[]).length),0);
  document.getElementById('cnt-p1').textContent = p1;
  document.getElementById('cnt-p2').textContent = p2;
  document.getElementById('cnt-total').textContent = incidents.length;
  document.getElementById('cnt-alerts').textContent = totalAlerts;
}

function renderAlerts(incidents) {
  const alertHist = document.getElementById('alert-hist');
  const allAlerts = [];
  incidents.forEach(inc => {
    if (inc.generated_alerts && inc.generated_alerts.length > 0) {
      inc.generated_alerts.forEach(alertText => {
        allAlerts.push({ id: inc.incident_id, text: alertText });
      });
    }
  });
  
  if (allAlerts.length === 0) {
    alertHist.innerHTML = '<div class="no-data">No alerts broadcasted yet</div>';
  } else {
    alertHist.innerHTML = allAlerts.map(a => `
      <div class="alert-item">
        <div class="alert-header">
          <span class="alert-title">INCIDENT ${a.id.substring(a.id.length-4)}</span>
        </div>
        <div class="alert-msg">${a.text}</div>
      </div>
    `).join('');
  }
}

function renderQueue(incidents){
  const el = document.getElementById('incident-list');
  document.getElementById('queue-count').textContent = `${incidents.length} incidents`;
  if(!incidents.length){
    el.innerHTML='<div class="empty-state"><div class="icon">📡</div><p>No incidents yet. Waiting for signals...</p></div>';
    return;
  }
  el.innerHTML = incidents.map(inc=>{
    const loc = inc.location ? `${inc.location.area||''} ${inc.location.city||''}`.trim() : (inc.lat ? `${inc.lat?.toFixed(4)},${inc.lng?.toFixed(4)}` : 'Unknown');
    const isActive = inc.incident_id === selectedId;
    return `<div class="incident-item${isActive?' active-item':''}" onclick="selectIncident('${inc.incident_id}')">
      <div class="inc-header">
        <span class="inc-id">${inc.incident_id}</span>
        <div style="display:flex;gap:8px;align-items:center">
          ${getPriorityBadge(inc.priority)}
          ${getStatusChip(inc.status)}
        </div>
      </div>
      <div class="inc-type">🔥 ${(inc.incident_type||inc.source||'Unknown').replace(/_/g,' ')}</div>
      <div class="inc-location">📍 ${loc} ${inc.confidence ? `• Confidence: ${Math.round(inc.confidence*100)}%` : ''}</div>
    </div>`;
  }).join('');
}

function selectIncident(id){
  selectedId = id;
  document.getElementById('selected-inc-id').textContent = id;
  document.querySelectorAll('.incident-item').forEach(el=>el.classList.remove('active-item'));
  event.currentTarget.classList.add('active-item');
  const inc = allIncidents.find(i=>i.incident_id===id);
  if(inc) renderDetail(inc);
}

function renderDetail(inc){
  // Agent pipeline status
  const traces = inc.traces || [];
  const phases = traces.map(t=>{const m=t.match(/\[(.*?)\]/g);return m&&m[1]?m[1].replace(/[\[\]]/g,''):'';});
  const hasDet = phases.some(p=>p==='DETECTION');
  const hasAna = phases.some(p=>p==='ANALYSIS');
  const hasPlan = phases.some(p=>p==='PLANNING');
  const hasExec = phases.some(p=>p==='EXECUTION'||p==='PIPELINE_COMPLETE');
  const isProc = inc.status==='PROCESSING'||phases.some(p=>p.includes('Attempt'));

  const steps = [
    {icon:'🔍',label:'Detection',done:hasDet},
    {icon:'📊',label:'Analysis',done:hasAna},
    {icon:'💡',label:'Planning',done:hasPlan},
    {icon:'⚡',label:'Execution',done:hasExec},
  ];
  document.getElementById('agent-pipeline').innerHTML = steps.map((s,i)=>`
    <div class="agent-step">
      <div class="agent-circle ${s.done?'done':(isProc&&!s.done&&steps[i-1]?.done)?'active':''}">${s.icon}</div>
      <div class="agent-label">${s.label}</div>
    </div>
    ${i<steps.length-1?`<div class="agent-connector ${s.done?'done':''}"></div>`:''}
  `).join('');

  // Verification status banner
  const loc = inc.location || {};
  const isVerified = loc.is_verified !== false && inc.status !== 'REJECTED';
  const vReason = loc.verification_reason || 'Report authenticity successfully verified.';
  document.getElementById('verification-banner').innerHTML = `
    <div style="margin-bottom:16px;padding:12px 16px;border-radius:12px;border:1px solid ${isVerified?'rgba(0,230,118,0.2)':'rgba(255,51,102,0.3)'};background:${isVerified?'rgba(0,230,118,0.05)':'rgba(255,51,102,0.05)'}">
      <div style="font-size:11px;font-weight:800;color:${isVerified?'var(--green)':'var(--red)'};text-transform:uppercase;letter-spacing:1px;display:flex;align-items:center;gap:6px">
        ${isVerified?'🛡️ Verified Crisis Signal':'⚠️ Suspicious / Spam Report Flagged'}
      </div>
      <div style="font-size:12px;color:#cbd5e1;margin-top:4px;line-height:1.4">${vReason}</div>
    </div>
  `;

  // Traces
  const traceEl = document.getElementById('trace-list');
  if(!traces.length){
    traceEl.innerHTML='<div class="no-data">No traces yet</div>';
  }else{
    traceEl.innerHTML = traces.slice().reverse().map(t=>{
      const m = t.match(/\[.*?\] \[(.*?)\] (.*)/);
      const phase = m?m[1]:'SYSTEM';
      const msg = m?m[2]:t;
      const ts = t.match(/\[(.*?)\]/)?.[1]?.split('T')[1]?.split('.')[0]||'';
      const cls = PHASE_COLORS[phase]||'';
      return `<div class="trace-item ${cls}"><span class="trace-phase">[${phase}]</span><span style="color:#64748b;margin-right:8px">${ts}</span>${msg}</div>`;
    }).join('');
    traceEl.scrollTop = 0;
  }

  // Before / After
  const baCard = document.getElementById('before-after-card');
  if(inc.before_state && inc.after_state){
    baCard.style.display='block';
    const b = inc.before_state, a = inc.after_state;
    const diff = inc.state_diff?.changed_keys||[];
    const rows = (obj, isBefore)=> Object.entries({
      'Status': obj.status||'—',
      'Active Units': Object.keys(obj.active_units||{}).length > 0 ? JSON.stringify(obj.active_units).replace(/"/g,'') : '0',
      'Alerts Sent': obj.public_alerts_sent||0,
      'Roads Closed': (obj.closed_roads||[]).length,
      'Tickets': (obj.tickets||[]).length,
    }).map(([k,v])=>`<div class="state-row"><span class="state-key">${k}</span><span class="state-val ${!isBefore&&diff.includes(k.toLowerCase().replace(' ','_'))?'changed':''}">${v}</span></div>`).join('');

    document.getElementById('before-after-content').innerHTML = `
      <div class="state-box before"><h4>⬛ Before Response</h4>${rows(b,true)}</div>
      <div class="arrow-icon">→</div>
      <div class="state-box after"><h4>✅ After Response</h4>${rows(a,false)}</div>`;
  }else{
    baCard.style.display='none';
  }
}

function renderResources(summary, resources){
  const el = document.getElementById('resource-grid');
  if(!summary){el.innerHTML='<div class="no-data">No data</div>';return;}
  el.innerHTML = `
    <div class="res-item"><div class="res-name">🚒 Rescue Teams</div><div class="res-count">${summary.rescue_teams?.available||0}</div><div class="res-status">Available | ${summary.rescue_teams?.en_route||0} en route</div></div>
    <div class="res-item"><div class="res-name">🚑 Ambulances</div><div class="res-count">${summary.ambulances?.available||0}</div><div class="res-status">Available | ${summary.ambulances?.en_route||0} dispatched</div></div>
    <div class="res-item"><div class="res-name">💧 Dewatering Pumps</div><div class="res-count">${summary.dewatering_pumps?.available||0}</div><div class="res-status">WASA Depot</div></div>
    <div class="res-item"><div class="res-name">🧰 Medical Kits</div><div class="res-count">${summary.medical_kits?.available||0}</div><div class="res-status">Central Depot</div></div>`;
}

async function tick(){
  await fetchIncidents();
  await fetchResources();
  countdown = 5;
}

setInterval(()=>{
  countdown--;
  document.getElementById('refresh-timer').textContent = `Auto-refresh in ${countdown}s`;
  if(countdown<=0) tick();
},1000);

tick();
</script>
</body>
</html>"""

@app.get("/", response_class=HTMLResponse)
async def dashboard():
    return HTMLResponse(content=DASHBOARD_HTML)

if __name__ == "__main__":
    print("\n" + "="*55)
    print("  KHABAR Web Dashboard")
    print("  Open: http://127.0.0.1:8001")
    print("="*55 + "\n")
    uvicorn.run(app, host="0.0.0.0", port=8001)
