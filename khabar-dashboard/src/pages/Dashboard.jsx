import React from 'react';
import InteractiveMap from '../components/Map/InteractiveMap';
import RecommendationsPanel from '../components/AIPanel/RecommendationsPanel';
import HotspotsPanel from '../components/Analysis/HotspotsPanel';
import ResourcePanel from '../components/Resources/ResourcePanel';
import DeploymentTable from '../components/Deployments/DeploymentTable';
import './Dashboard.css';

const Dashboard = () => {
  return (
    <div className="dashboard">
      <div className="dashboard-grid">
        {/* Main Map Section — center-left */}
        <section id="map-section" className="map-card grid-item">
          <InteractiveMap />
        </section>

        {/* AI Recommendations Panel — top right */}
        <section id="incidents-section" className="recommendations-card grid-item">
          <RecommendationsPanel />
        </section>

        {/* Resource Management Panel — below map */}
        <section id="resources-section" className="resources-card grid-item">
          <ResourcePanel />
        </section>

        {/* Spatial Analysis / Hotspots — right of resources */}
        <section id="hotspots-section" className="hotspots-card grid-item">
          <HotspotsPanel />
        </section>

        {/* Deployment Tracking — full width bottom */}
        <section id="deployments-section" className="deployments-card grid-item">
          <DeploymentTable />
        </section>
      </div>
    </div>
  );
};

export default Dashboard;
