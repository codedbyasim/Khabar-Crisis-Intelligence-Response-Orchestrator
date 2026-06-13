import React, { useState } from 'react';
import { Package, Plus } from 'lucide-react';

export default function ResourceManager({ resources, resourceSummary, apiBase, onResourceAdded }) {
  const [showForm, setShowForm] = useState(false);
  const [resId, setResId] = useState('');
  const [resName, setResName] = useState('');
  const [resType, setResType] = useState('');
  const [resQty, setResQty] = useState(1);
  const [resLat, setResLat] = useState('');
  const [resLng, setResLng] = useState('');
  const [statusMsg, setStatusMsg] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    setStatusMsg('Registering...');
    try {
      const response = await fetch(`${apiBase}/resources/add`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          resource_id: resId.trim(),
          name: resName.trim(),
          resource_type: resType,
          quantity_available: parseInt(resQty),
          status: 'available',
          location: { lat: parseFloat(resLat), lng: parseFloat(resLng) },
        }),
      });
      const data = await response.json();
      if (data.success) {
        setStatusMsg('✅ Registered!');
        setResId(''); setResName(''); setResType(''); setResQty(1); setResLat(''); setResLng('');
        if (onResourceAdded) onResourceAdded();
        setTimeout(() => { setStatusMsg(''); setShowForm(false); }, 1500);
      } else {
        setStatusMsg(`❌ ${data.error || 'Error'}`);
      }
    } catch {
      setStatusMsg('❌ Connection error');
    }
  };

  // Summary cards
  const summaryCards = resourceSummary ? [
    { emoji: '🚒', name: 'Rescue Teams', count: resourceSummary.rescue_teams?.available || 0, sub: `${resourceSummary.rescue_teams?.en_route || 0} en route` },
    { emoji: '🚑', name: 'Ambulances', count: resourceSummary.ambulances?.available || 0, sub: `${resourceSummary.ambulances?.en_route || 0} dispatched` },
    { emoji: '💧', name: 'Dewatering', count: resourceSummary.dewatering_pumps?.available || 0, sub: 'WASA Depot' },
    { emoji: '🧰', name: 'Medical Kits', count: resourceSummary.medical_kits?.available || 0, sub: 'Central Depot' },
  ] : [];

  return (
    <div className="glass-card">
      <div className="glass-card-header">
        <span className="glass-card-title">
          <Package size={18} style={{ color: 'var(--violet)' }} /> Resource Allocation
        </span>
        <button className="btn-outline" onClick={() => setShowForm(!showForm)}>
          <Plus size={12} style={{ marginRight: 4 }} /> Add Resource
        </button>
      </div>
      <div className="glass-card-body">
        {/* Summary Row */}
        {summaryCards.length > 0 && (
          <div className="res-summary-row">
            {summaryCards.map((c, i) => (
              <div key={i} className="res-mini-card">
                <div className="emoji">{c.emoji}</div>
                <div className="count">{c.count}</div>
                <div className="name">{c.name}</div>
                <div className="sub">{c.sub}</div>
              </div>
            ))}
          </div>
        )}

        {/* Resource Table */}
        {resources.length > 0 ? (
          <div style={{ overflowX: 'auto' }}>
            <table className="resource-table">
              <thead>
                <tr>
                  <th>Resource</th>
                  <th>Type</th>
                  <th>Status</th>
                  <th>Qty</th>
                  <th>Location</th>
                  <th>Assigned Case</th>
                </tr>
              </thead>
              <tbody>
                {resources.map(res => {
                  const st = (res.status || 'available').toLowerCase();
                  const dotClass = st.includes('deploy') ? 'deployed' : st.includes('route') ? 'en-route' : 'available';
                  return (
                    <tr key={res.resource_id}>
                      <td className="res-name-cell">{res.name || res.resource_id}</td>
                      <td style={{ textTransform: 'capitalize' }}>{(res.resource_type || '').replace(/_/g, ' ')}</td>
                      <td>
                        <span className={`status-dot ${dotClass}`}></span>
                        <span style={{ textTransform: 'capitalize' }}>{st}</span>
                      </td>
                      <td style={{ fontFamily: 'JetBrains Mono, monospace', fontWeight: 600 }}>{res.quantity_available || 1}</td>
                      <td style={{ fontSize: 11, color: 'var(--text-muted)' }}>
                        {res.location ? `${parseFloat(res.location.lat).toFixed(3)}, ${parseFloat(res.location.lng).toFixed(3)}` : '—'}
                      </td>
                      <td>
                        {res.assigned_incident ? (
                          <span style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 11, fontWeight: 700, color: 'var(--cyan)' }}>
                            {res.assigned_incident}
                          </span>
                        ) : (
                          <span style={{ color: 'var(--text-muted)' }}>—</span>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="no-data">No resources registered yet.</div>
        )}

        {/* Add Form */}
        {showForm && (
          <div style={{ marginTop: 20, padding: 16, borderRadius: 'var(--radius-md)', border: '1px solid var(--border)', background: 'rgba(255,255,255,0.02)' }}>
            <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--cyan)', marginBottom: 12, textTransform: 'uppercase', letterSpacing: 0.5 }}>
              Register New Resource
            </div>
            <form onSubmit={handleSubmit}>
              <div className="form-grid">
                <input type="text" placeholder="Resource ID (e.g. RES-01)" className="dark-input" value={resId} onChange={e => setResId(e.target.value)} required />
                <input type="text" placeholder="Resource Name" className="dark-input" value={resName} onChange={e => setResName(e.target.value)} required />
              </div>
              <div className="form-grid">
                <select className="dark-select" value={resType} onChange={e => setResType(e.target.value)} required>
                  <option value="" disabled>Select Type</option>
                  <option value="rescue_team">Rescue Team</option>
                  <option value="ambulance">Ambulance</option>
                  <option value="dewatering_pump">Dewatering Pump</option>
                  <option value="fire_truck">Fire Truck</option>
                  <option value="police_unit">Traffic/Police Unit</option>
                </select>
                <input type="number" placeholder="Quantity" className="dark-input" min="1" value={resQty} onChange={e => setResQty(e.target.value)} required />
              </div>
              <div className="form-grid">
                <input type="number" step="any" placeholder="Latitude" className="dark-input" value={resLat} onChange={e => setResLat(e.target.value)} required />
                <input type="number" step="any" placeholder="Longitude" className="dark-input" value={resLng} onChange={e => setResLng(e.target.value)} required />
              </div>
              <button type="submit" className="btn-primary">Register Resource</button>
            </form>
            {statusMsg && (
              <div style={{ marginTop: 10, textAlign: 'center', fontSize: 12, fontWeight: 600, color: 'var(--cyan)' }}>{statusMsg}</div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
