import React, { useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { LayoutDashboard, Radio, MapPin, Database, Settings, LogOut } from 'lucide-react';
import './Sidebar.css';

const Sidebar = () => {
  const location = useLocation();
  const [isOpen, setIsOpen] = useState(true);

  const isActive = (path) => location.pathname === path;

  const scrollTo = (id) => {
    document.getElementById(id)?.scrollIntoView({ behavior: 'smooth' });
  };

  return (
    <aside className={`sidebar ${isOpen ? 'open' : 'collapsed'}`}>
      <nav className="nav-menu">
        <Link
          to="/"
          className={`nav-item ${isActive('/') ? 'active' : ''}`}
        >
          <span className="icon"><LayoutDashboard size={18} /></span>
          <span className="label">Overview</span>
        </Link>

        <a href="#deployments" className="nav-item" onClick={() => scrollTo('deployments-section')}>
          <span className="icon"><Radio size={18} /></span>
          <span className="label">Dispatch Center</span>
        </a>

        <a href="#hotspots" className="nav-item" onClick={() => scrollTo('hotspots-section')}>
          <span className="icon"><MapPin size={18} /></span>
          <span className="label">Spatial Analysis</span>
        </a>

        <a href="#resources" className="nav-item" onClick={() => scrollTo('resources-section')}>
          <span className="icon"><Database size={18} /></span>
          <span className="label">Resources (CRUD)</span>
        </a>

        <div className="nav-separator"></div>

        <div className="nav-bottom">
          <a href="#settings" className="nav-item">
            <span className="icon"><Settings size={18} /></span>
            <span className="label">Settings</span>
          </a>

          <a href="#logout" className="nav-item">
            <span className="icon"><LogOut size={18} /></span>
            <span className="label">Log Out</span>
          </a>
        </div>
      </nav>

      <button className="sidebar-toggle" onClick={() => setIsOpen(!isOpen)}>
        <span>{isOpen ? '❮' : '❯'}</span>
      </button>
    </aside>
  );
};

export default Sidebar;
