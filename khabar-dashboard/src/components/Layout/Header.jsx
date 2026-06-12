import React from 'react';
import './Header.css';

const Header = ({ apiHealth }) => {
  const isOnline = apiHealth === 'online';

  return (
    <header className="header">
      <div className="header-logo">
        <div>
          <div className="logo-calligraphy">خبر</div>
          <div className="logo-calligraphy-sub">KHABAR</div>
        </div>
        <div className="logo-divider"></div>
        <h1 className="header-title">Crisis Response &amp; Intelligence Dashboard</h1>
      </div>

      <div className="header-right">
        <div className="header-status">
          <span className={`status-dot ${isOnline ? 'online' : 'offline'}`}></span>
          <span className={`status-label ${isOnline ? 'online' : 'offline'}`}>
            {isOnline ? 'SYSTEM LIVE' : 'OFFLINE'}
          </span>
        </div>
      </div>
    </header>
  );
};

export default Header;
