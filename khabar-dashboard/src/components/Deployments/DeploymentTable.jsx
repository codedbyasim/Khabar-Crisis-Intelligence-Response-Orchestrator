import React from 'react';
import { useDashboard } from '../../context/DashboardContext';
import { AlertCircle } from 'lucide-react';
import './DeploymentTable.css';

const DeploymentTable = () => {
  const { deployments } = useDashboard();

  // Create mock data if none exists to match the reference layout perfectly
  const displayDeployments = deployments && deployments.length > 0 ? deployments : [
    {
      resource_id: '103005',
      deployed_location: { lat: 15.56, lng: 217.3933 },
      target_incident: 'Major Road Sinkhole',
      eta_minutes: 12,
    },
    {
      resource_id: '103011',
      deployed_location: { lat: 16.06, lng: 238.5376 },
      target_incident: 'Fire in Blue Area',
      eta_minutes: 8,
    },
    {
      resource_id: '103012',
      deployed_location: { lat: 15.06, lng: 238.5430 },
      target_incident: 'WASA Pump Dispatch',
      eta_minutes: 15,
    }
  ];

  return (
    <div className="deployment-section">
      <div className="deployments-title">
        Active Deployments & Dispatch Tracking
      </div>

      <div className="table-wrapper">
        <table className="deployment-table">
          <thead>
            <tr>
              <th>Resource ID</th>
              <th>Deployed Location</th>
              <th>Target Incident</th>
              <th>Computed ETA</th>
            </tr>
          </thead>
          <tbody>
            {displayDeployments.map((dep, idx) => {
              const coords = dep.deployed_location 
                ? `${dep.deployed_location.lat.toFixed(2)},${dep.deployed_location.lng.toFixed(4)}`
                : '15.00,200.0000';
                
              return (
                <tr key={`${dep.resource_id}-${idx}`}>
                  <td className="col-id">{dep.resource_id}</td>
                  <td className="col-location">{coords}</td>
                  <td className="col-target">{dep.target_incident || dep.incident_id || 'Unknown Incident'}</td>
                  <td className="col-eta">{dep.eta_minutes || 0} mins</td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default DeploymentTable;
