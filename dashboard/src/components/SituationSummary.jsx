import React from 'react';
import { BarChart3 } from 'lucide-react';

export default function SituationSummary({ incidents }) {
  const p1 = incidents.filter(i => i.priority === 'P1').length;
  const p2 = incidents.filter(i => i.priority === 'P2').length;
  const p3 = incidents.filter(i => i.priority === 'P3').length;
  const p4 = incidents.filter(i => i.priority === 'P4').length;
  const p5 = incidents.filter(i => i.priority === 'P5').length;
  const total = incidents.length || 1;

  const processing = incidents.filter(i => i.status === 'PROCESSING' || i.status === 'OPEN' || i.status === 'EXECUTING' || i.status === 'IN_PROGRESS').length;
  const complete = incidents.filter(i => i.status === 'PIPELINE_COMPLETE' || i.status === 'RESOLVED' || i.status === 'CLOSED').length;
  const review = incidents.filter(i => i.status === 'MANUAL_REVIEW_REQUIRED').length;

  // Determine overall threat level
  let threatLevel = 'LOW';
  let threatColor = 'var(--emerald)';
  if (p1 >= 3) { threatLevel = 'CRITICAL'; threatColor = 'var(--rose)'; }
  else if (p1 >= 1 || p2 >= 3) { threatLevel = 'HIGH'; threatColor = 'var(--orange)'; }
  else if (p2 >= 1 || p3 >= 2) { threatLevel = 'MODERATE'; threatColor = 'var(--amber)'; }

  // Incident types distribution
  const typeMap = {};
  incidents.forEach(inc => {
    const t = (inc.incident_type || inc.source || 'Unknown').replace(/_/g, ' ');
    typeMap[t] = (typeMap[t] || 0) + 1;
  });

  const sortedTypes = Object.entries(typeMap).sort((a, b) => b[1] - a[1]).slice(0, 5);

  const bars = [
    { label: 'P1', count: p1, cls: 'p1', color: 'var(--rose)' },
    { label: 'P2', count: p2, cls: 'p2', color: 'var(--orange)' },
    { label: 'P3', count: p3, cls: 'p3', color: 'var(--amber)' },
    { label: 'P4', count: p4, cls: 'p4', color: 'var(--blue)' },
    { label: 'P5', count: p5, cls: 'p5', color: 'var(--emerald)' },
  ];

  return (
    <div className="glass-card">
      <div className="glass-card-header">
        <span className="glass-card-title">
          <BarChart3 size={18} style={{ color: 'var(--amber)' }} /> Situation Summary
        </span>
        <span style={{
          fontSize: 10,
          fontWeight: 800,
          color: threatColor,
          textTransform: 'uppercase',
          letterSpacing: 1,
          padding: '3px 10px',
          borderRadius: 4,
          background: `${threatColor}15`,
          border: `1px solid ${threatColor}40`
        }}>
          ⚠ Threat: {threatLevel}
        </span>
      </div>
      <div className="glass-card-body">
        {/* Severity Distribution */}
        <div style={{ marginBottom: 20 }}>
          <div style={{ fontSize: 11, fontWeight: 600, color: 'var(--text-secondary)', marginBottom: 12, textTransform: 'uppercase', letterSpacing: 0.5 }}>
            Severity Distribution
          </div>
          <div className="severity-bars">
            {bars.map(b => (
              <div key={b.label} className="severity-row">
                <span className="severity-label" style={{ color: b.color }}>{b.label}</span>
                <div className="severity-bar-track">
                  <div
                    className={`severity-bar-fill ${b.cls}`}
                    style={{ width: `${(b.count / total) * 100}%` }}
                  />
                </div>
                <span className="severity-count">{b.count}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Pipeline Status */}
        <div style={{ marginBottom: 20 }}>
          <div style={{ fontSize: 11, fontWeight: 600, color: 'var(--text-secondary)', marginBottom: 10, textTransform: 'uppercase', letterSpacing: 0.5 }}>
            Pipeline Status
          </div>
          <div style={{ display: 'flex', gap: 12 }}>
            <div style={{ flex: 1, background: 'var(--bg-surface)', borderRadius: 'var(--radius-sm)', padding: 12, textAlign: 'center' }}>
              <div style={{ fontSize: 20, fontWeight: 800, color: 'var(--blue)', fontFamily: 'Outfit,sans-serif' }}>{processing}</div>
              <div style={{ fontSize: 10, color: 'var(--text-muted)', textTransform: 'uppercase' }}>Processing</div>
            </div>
            <div style={{ flex: 1, background: 'var(--bg-surface)', borderRadius: 'var(--radius-sm)', padding: 12, textAlign: 'center' }}>
              <div style={{ fontSize: 20, fontWeight: 800, color: 'var(--emerald)', fontFamily: 'Outfit,sans-serif' }}>{complete}</div>
              <div style={{ fontSize: 10, color: 'var(--text-muted)', textTransform: 'uppercase' }}>Complete</div>
            </div>
            <div style={{ flex: 1, background: 'var(--bg-surface)', borderRadius: 'var(--radius-sm)', padding: 12, textAlign: 'center' }}>
              <div style={{ fontSize: 20, fontWeight: 800, color: 'var(--rose)', fontFamily: 'Outfit,sans-serif' }}>{review}</div>
              <div style={{ fontSize: 10, color: 'var(--text-muted)', textTransform: 'uppercase' }}>Review Req.</div>
            </div>
          </div>
        </div>

        {/* Top Incident Types */}
        {sortedTypes.length > 0 && (
          <div>
            <div style={{ fontSize: 11, fontWeight: 600, color: 'var(--text-secondary)', marginBottom: 10, textTransform: 'uppercase', letterSpacing: 0.5 }}>
              Top Crisis Types
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
              {sortedTypes.map(([type, count], i) => (
                <div key={i} style={{
                  display: 'flex', justifyContent: 'space-between', alignItems: 'center',
                  padding: '6px 10px', background: 'var(--bg-surface)', borderRadius: 'var(--radius-sm)', fontSize: 12
                }}>
                  <span style={{ color: 'var(--text-secondary)', textTransform: 'capitalize' }}>{type}</span>
                  <span style={{ fontFamily: 'JetBrains Mono, monospace', fontWeight: 700, color: 'var(--text-primary)' }}>{count}</span>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
