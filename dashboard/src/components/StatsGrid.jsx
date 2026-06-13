import React from 'react';
import {
  AlertTriangle,
  AlertCircle,
  Activity,
  CheckCircle2,
  Truck,
  Megaphone
} from 'lucide-react';

export default function StatsGrid({ incidents, resources, resourceSummary }) {
  const p1Count = incidents.filter(i => i.priority === 'P1').length;
  const p2Count = incidents.filter(i => i.priority === 'P2').length;
  const totalActive = incidents.length;
  
  const solvedCount = incidents.filter(i =>
    i.status === 'PIPELINE_COMPLETE' || i.status === 'REJECTED'
  ).length;

  const deployedResources = resources.filter(r =>
    r.status === 'deployed' || r.status === 'en_route'
  ).length;

  const totalAlerts = incidents.reduce((sum, i) => 
    sum + (i.generated_alerts?.length || 0), 0
  );

  const stats = [
    { label: 'P1 Critical', value: p1Count, accent: 'rose', icon: <AlertTriangle size={16} /> },
    { label: 'P2 High', value: p2Count, accent: 'amber', icon: <AlertCircle size={16} /> },
    { label: 'Total Active', value: totalActive, accent: 'cyan', icon: <Activity size={16} /> },
    { label: 'Cases Resolved', value: solvedCount, accent: 'emerald', icon: <CheckCircle2 size={16} /> },
    { label: 'Resources Out', value: deployedResources, accent: 'violet', icon: <Truck size={16} /> },
    { label: 'Alerts Sent', value: totalAlerts, accent: 'blue', icon: <Megaphone size={16} /> },
  ];

  return (
    <div className="stats-row">
      {stats.map((s, i) => (
        <div key={i} className={`stat-card accent-${s.accent}`}>
          <div className={`stat-icon-box ${s.accent}`}>
            {s.icon}
          </div>
          <div className={`stat-number ${s.accent}`}>{s.value}</div>
          <div className="stat-label">{s.label}</div>
        </div>
      ))}
    </div>
  );
}
