import React, { createContext, useContext, useReducer, useCallback } from 'react';
import * as api from '../services/api';

const DashboardContext = createContext();

export const useDashboard = () => {
  const context = useContext(DashboardContext);
  if (!context) {
    throw new Error('useDashboard must be used within DashboardProvider');
  }
  return context;
};

const initialState = {
  // Incidents
  incidents: [],
  selectedIncident: null,
  
  // Resources
  resources: [],
  resourceSummary: {},
  
  // Deployments
  deployments: [],
  
  // Hotspots
  hotspots: [],
  
  // Dashboard summary
  summary: {
    incidents: { total: 0, by_priority: {}, processing: 0, completed: 0 },
    resources: {},
    hotspots: {},
  },
  
  // UI State
  loading: false,
  error: null,
  apiHealth: 'checking',
  lastUpdate: null,
};

const reducer = (state, action) => {
  switch (action.type) {
    case 'SET_LOADING':
      return { ...state, loading: action.payload };
    
    case 'SET_ERROR':
      return { ...state, error: action.payload };
    
    case 'SET_INCIDENTS':
      return {
        ...state,
        incidents: action.payload,
        lastUpdate: new Date().toISOString(),
      };
    
    case 'SET_SELECTED_INCIDENT':
      return { ...state, selectedIncident: action.payload };
    
    case 'SET_RESOURCES':
      return {
        ...state,
        resources: action.payload.resources || [],
        resourceSummary: action.payload.summary || {},
      };
    
    case 'ADD_RESOURCE':
      return {
        ...state,
        resources: [...state.resources, action.payload],
      };
    
    case 'DELETE_RESOURCE':
      return {
        ...state,
        resources: state.resources.filter(r => r.id !== action.payload),
      };
    
    case 'UPDATE_RESOURCE':
      return {
        ...state,
        resources: state.resources.map(r =>
          r.id === action.payload.id ? { ...r, ...action.payload } : r
        ),
      };
    
    case 'SET_DEPLOYMENTS':
      return {
        ...state,
        deployments: action.payload,
        lastUpdate: new Date().toISOString(),
      };
    
    case 'SET_HOTSPOTS':
      return {
        ...state,
        hotspots: action.payload,
      };
    
    case 'SET_SUMMARY':
      return {
        ...state,
        summary: action.payload,
      };
    
    case 'SET_API_HEALTH':
      return { ...state, apiHealth: action.payload };
    
    default:
      return state;
  }
};

export const DashboardProvider = ({ children }) => {
  const [state, dispatch] = useReducer(reducer, initialState);

  // Polling functions
  const pollIncidents = useCallback(async () => {
    try {
      const data = await api.fetchIncidents();
      if (data && data.incidents) {
        dispatch({ type: 'SET_INCIDENTS', payload: data.incidents });
        dispatch({ type: 'SET_ERROR', payload: null });
      }
    } catch (err) {
      dispatch({ type: 'SET_ERROR', payload: err.message });
    }
  }, []);

  const pollResources = useCallback(async () => {
    try {
      const data = await api.fetchResources();
      if (data) {
        dispatch({ type: 'SET_RESOURCES', payload: data });
      }
    } catch (err) {
      console.error('Error polling resources:', err);
    }
  }, []);

  const pollDeployments = useCallback(async () => {
    try {
      const data = await api.fetchDeployments();
      if (data && data.deployments) {
        dispatch({ type: 'SET_DEPLOYMENTS', payload: data.deployments });
      }
    } catch (err) {
      console.error('Error polling deployments:', err);
    }
  }, []);

  const pollHotspots = useCallback(async () => {
    try {
      const data = await api.fetchHotspots();
      if (data && data.hotspots) {
        dispatch({ type: 'SET_HOTSPOTS', payload: data.hotspots });
      }
    } catch (err) {
      console.error('Error polling hotspots:', err);
    }
  }, []);

  const pollSummary = useCallback(async () => {
    try {
      const data = await api.fetchDashboardSummary();
      if (data) {
        dispatch({ type: 'SET_SUMMARY', payload: data });
      }
    } catch (err) {
      console.error('Error polling summary:', err);
    }
  }, []);

  // Manual fetch functions
  const fetchIncidentDetail = useCallback(async (incidentId) => {
    try {
      const data = await api.fetchIncidentDetail(incidentId);
      if (data) {
        dispatch({ type: 'SET_SELECTED_INCIDENT', payload: data });
      }
    } catch (err) {
      dispatch({ type: 'SET_ERROR', payload: err.message });
    }
  }, []);

  const createResource = useCallback(async (resourceData) => {
    try {
      const result = await api.createResource(resourceData);
      if (result.success) {
        dispatch({ type: 'ADD_RESOURCE', payload: result.resource });
        return { success: true, resource: result.resource };
      }
      return { success: false, error: result.error };
    } catch (err) {
      return { success: false, error: err.message };
    }
  }, []);

  const deleteResource = useCallback(async (resourceId) => {
    try {
      const result = await api.deleteResource(resourceId);
      if (result.success) {
        dispatch({ type: 'DELETE_RESOURCE', payload: resourceId });
        return { success: true };
      }
      return { success: false, error: result.error };
    } catch (err) {
      return { success: false, error: err.message };
    }
  }, []);

  const updateResourceStatus = useCallback(async (resourceId, status, incidentId = null) => {
    try {
      const result = await api.updateResourceStatus(resourceId, status, incidentId);
      if (result.success) {
        dispatch({ type: 'UPDATE_RESOURCE', payload: { id: resourceId, status } });
        return { success: true };
      }
      return { success: false, error: result.error };
    } catch (err) {
      return { success: false, error: err.message };
    }
  }, []);

  const checkApiHealth = useCallback(async () => {
    try {
      const health = await api.healthCheck();
      dispatch({
        type: 'SET_API_HEALTH',
        payload: health.status === 'online' ? 'online' : 'offline',
      });
    } catch (err) {
      dispatch({ type: 'SET_API_HEALTH', payload: 'offline' });
    }
  }, []);

  const value = {
    // State
    ...state,
    
    // Polling
    pollIncidents,
    pollResources,
    pollDeployments,
    pollHotspots,
    pollSummary,
    
    // Manual operations
    fetchIncidentDetail,
    createResource,
    deleteResource,
    updateResourceStatus,
    checkApiHealth,
  };

  return (
    <DashboardContext.Provider value={value}>
      {children}
    </DashboardContext.Provider>
  );
};

export default DashboardContext;
