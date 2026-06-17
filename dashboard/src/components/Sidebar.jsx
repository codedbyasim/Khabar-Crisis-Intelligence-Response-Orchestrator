import React from 'react';
import {
  LayoutDashboard,
  Map,
  Bot,
  Package,
  ClipboardList,
  Settings
} from 'lucide-react';

const NAV_ITEMS = [
  { id: 'dashboard', label: 'Dashboard', icon: LayoutDashboard },
  { id: 'map', label: 'Crisis Map', icon: Map },
  { id: 'agents', label: 'AI Agents', icon: Bot },
  { id: 'resources', label: 'Resources', icon: Package },
  { id: 'cases', label: 'Case Tracker', icon: ClipboardList },
];

export default function Sidebar({ activeSection, onSectionChange, alertCount }) {
  return (
    <aside className="sidebar">
      <div className="sidebar-logo">
        <div className="sidebar-logo-icon">🚨</div>
        <div className="sidebar-logo-text">
          <h1>KHABAR</h1>
          <p>Command Center</p>
        </div>
      </div>

      <nav className="sidebar-nav">
        {NAV_ITEMS.map(item => {
          const Icon = item.icon;
          return (
            <div
              key={item.id}
              className={`sidebar-item ${activeSection === item.id ? 'active' : ''}`}
              onClick={() => onSectionChange(item.id)}
            >
              <Icon />
              <span>{item.label}</span>
              {item.id === 'alerts' && alertCount > 0 && (
                <span className="sidebar-badge">{alertCount}</span>
              )}
            </div>
          );
        })}
      </nav>

      <div className="sidebar-footer">
        <div
          className="sidebar-item"
          style={{ opacity: 0.5, cursor: 'default' }}
        >
          <Settings />
          <span>Settings</span>
        </div>
      </div>
    </aside>
  );
}
