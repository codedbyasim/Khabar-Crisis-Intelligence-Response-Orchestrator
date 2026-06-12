import React, { useState } from 'react';
import { useDashboard } from '../../context/DashboardContext';
import './ResourceForm.css';

const ResourceForm = () => {
  const { createResource } = useDashboard();
  const [formData, setFormData] = useState({
    type: '',
    coordinate: '',
    name: '',
  });
  const [loading, setLoading] = useState(false);

  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: value,
    }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);

    // Simple parse of coords for the API
    const coords = formData.coordinate.split(',');
    let lat = 33.74, lng = 73.15;
    if (coords.length === 2) {
      lat = parseFloat(coords[0]) || lat;
      lng = parseFloat(coords[1]) || lng;
    }

    try {
      await createResource({
        name: formData.name || 'New Resource',
        resource_type: formData.type || 'AMBULANCE',
        quantity_available: 1,
        lat,
        lng,
        status: 'available',
      });

      setFormData({ type: '', coordinate: '', name: '' });
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="resource-form-section">
      <h3>Add Resource Form</h3>
      <form className="resource-form" onSubmit={handleSubmit}>
        
        <div className="form-group">
          <select
            name="type"
            value={formData.type}
            onChange={handleChange}
            className="form-select"
            required
          >
            <option value="" disabled>Type</option>
            <option value="AMBULANCE">AMBULANCE</option>
            <option value="WASA PUMP">WASA PUMP</option>
            <option value="RESCUE TEAM">RESCUE TEAM</option>
          </select>
        </div>

        <div className="form-group">
          <input
            type="text"
            name="coordinate"
            placeholder="Coordinate"
            value={formData.coordinate}
            onChange={handleChange}
            className="form-input"
            required
          />
        </div>

        <div className="form-group">
          <input
            type="text"
            name="name"
            placeholder="Name"
            value={formData.name}
            onChange={handleChange}
            className="form-input"
            required
          />
        </div>

        <button
          type="submit"
          disabled={loading}
          className="submit-button"
        >
          Register New Resource
        </button>
      </form>
    </div>
  );
};

export default ResourceForm;
