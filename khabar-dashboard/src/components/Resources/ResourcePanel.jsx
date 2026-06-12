import React from 'react';
import ResourceTable from './ResourceTable';
import ResourceForm from './ResourceForm';
import './ResourcePanel.css';

const ResourcePanel = () => {
  return (
    <div className="resource-panel">
      <div className="panel-header-teal">
        <h2>Resource Management</h2>
      </div>

      <div className="resource-content">
        <ResourceTable />
        <ResourceForm />
      </div>
    </div>
  );
};

export default ResourcePanel;
