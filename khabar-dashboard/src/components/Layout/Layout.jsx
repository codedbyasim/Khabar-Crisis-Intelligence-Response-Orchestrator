import React, { useEffect } from 'react';
import Header from './Header';
import Sidebar from './Sidebar';
import { useDashboard } from '../../context/DashboardContext';
import { usePolling } from '../../hooks/usePolling';
import './Layout.css';

const Layout = ({ children }) => {
  const { apiHealth, checkApiHealth, pollIncidents, pollResources, pollDeployments, pollHotspots } = useDashboard();

  // Check API health on mount
  useEffect(() => {
    checkApiHealth();
  }, [checkApiHealth]);

  // Set up polling for all data
  usePolling(pollIncidents, 3000);
  usePolling(pollResources, 3000);
  usePolling(pollDeployments, 3000);
  usePolling(pollHotspots, 3000);

  return (
    <div className="layout">
      <Header apiHealth={apiHealth} />
      <div className="layout-container">
        <Sidebar />
        <main className="main-content">
          {children}
        </main>
      </div>
    </div>
  );
};

export default Layout;
