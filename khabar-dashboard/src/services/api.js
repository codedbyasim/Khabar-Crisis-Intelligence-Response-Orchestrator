/**
 * API Client Service
 * Handles all HTTP requests to the KHABAR backend
 */
import axios from 'axios';

const API_BASE_URL = 'http://localhost:8000';
const DASHBOARD_API_URL = 'http://localhost:8001';

const apiClient = axios.create({
  baseURL: API_BASE_URL,
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
  },
});

const dashboardClient = axios.create({
  baseURL: DASHBOARD_API_URL,
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Error handling
const handleError = (error, endpoint) => {
  console.error(`API Error [${endpoint}]:`, error.message);
  if (error.response) {
    console.error('Response:', error.response.data);
  }
  return null;
};

// ════════════════════════════════════════════
// INCIDENTS
// ════════════════════════════════════════════
export const fetchIncidents = async () => {
  try {
    const response = await apiClient.get('/incidents');
    return response.data;
  } catch (error) {
    handleError(error, 'GET /incidents');
    return { total: 0, incidents: [] };
  }
};

export const fetchIncidentDetail = async (incidentId) => {
  try {
    const response = await apiClient.get(`/incident/${incidentId}`);
    return response.data;
  } catch (error) {
    handleError(error, `GET /incident/${incidentId}`);
    return null;
  }
};

// ════════════════════════════════════════════
// RESOURCES
// ════════════════════════════════════════════
export const fetchResources = async () => {
  try {
    const response = await apiClient.get('/resources');
    return response.data;
  } catch (error) {
    handleError(error, 'GET /resources');
    return { resources: [], summary: {} };
  }
};

export const createResource = async (payload) => {
  try {
    const response = await dashboardClient.post('/resource/create', payload);
    return response.data;
  } catch (error) {
    handleError(error, 'POST /resource/create');
    return { success: false, error: error.message };
  }
};

export const deleteResource = async (resourceId) => {
  try {
    const response = await dashboardClient.delete(`/resource/${resourceId}`);
    return response.data;
  } catch (error) {
    handleError(error, `DELETE /resource/${resourceId}`);
    return { success: false, error: error.message };
  }
};

export const updateResourceStatus = async (resourceId, status, incidentId = null) => {
  try {
    const response = await dashboardClient.put(`/resource/${resourceId}/status`, {
      status,
      incident_id: incidentId,
    });
    return response.data;
  } catch (error) {
    handleError(error, `PUT /resource/${resourceId}/status`);
    return { success: false, error: error.message };
  }
};

// ════════════════════════════════════════════
// DEPLOYMENTS
// ════════════════════════════════════════════
export const fetchDeployments = async () => {
  try {
    const response = await dashboardClient.get('/deployments');
    return response.data;
  } catch (error) {
    handleError(error, 'GET /deployments');
    return { total: 0, deployments: [] };
  }
};

// ════════════════════════════════════════════
// SPATIAL ANALYSIS
// ════════════════════════════════════════════
export const fetchHotspots = async () => {
  try {
    const response = await dashboardClient.get('/hotspots');
    return response.data;
  } catch (error) {
    handleError(error, 'GET /hotspots');
    return { total_incidents: 0, sectors: 0, hotspots: [] };
  }
};

// ════════════════════════════════════════════
// DASHBOARD SUMMARY
// ════════════════════════════════════════════
export const fetchDashboardSummary = async () => {
  try {
    const response = await dashboardClient.get('/dashboard/summary');
    return response.data;
  } catch (error) {
    handleError(error, 'GET /dashboard/summary');
    return {
      incidents: { total: 0, by_priority: {}, processing: 0, completed: 0 },
      resources: {},
      hotspots: {},
    };
  }
};

// ════════════════════════════════════════════
// ACTIONS
// ════════════════════════════════════════════
export const executeManualAction = async (incidentId, actionType, payload = {}) => {
  try {
    const response = await dashboardClient.post('/action/execute', {
      incident_id: incidentId,
      action_type: actionType,
      ...payload,
    });
    return response.data;
  } catch (error) {
    handleError(error, `POST /action/execute`);
    return { success: false, error: error.message };
  }
};

// ════════════════════════════════════════════
// HEALTH CHECK
// ════════════════════════════════════════════
export const healthCheck = async () => {
  try {
    const response = await dashboardClient.get('/health');
    return response.data;
  } catch (error) {
    console.warn('Dashboard API health check failed:', error.message);
    return { status: 'offline' };
  }
};

export default {
  fetchIncidents,
  fetchIncidentDetail,
  fetchResources,
  createResource,
  deleteResource,
  updateResourceStatus,
  fetchDeployments,
  fetchHotspots,
  fetchDashboardSummary,
  executeManualAction,
  healthCheck,
};
