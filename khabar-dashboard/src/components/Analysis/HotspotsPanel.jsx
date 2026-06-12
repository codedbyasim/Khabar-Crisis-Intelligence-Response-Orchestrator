import React from 'react';
import { PieChart, Pie, Cell, ResponsiveContainer } from 'recharts';
import { useDashboard } from '../../context/DashboardContext';
import './HotspotsPanel.css';

// Exact colors from reference image
const COLORS = {
  'Faizabad': '#1d7a72',     // Deep Teal
  'G-10 Markaz': '#e53935',  // Red
  'Saddar': '#fb8c00',       // Orange
  'Others': '#9aa0a6'        // Grey
};

const defaultColors = ['#1d7a72', '#e53935', '#fb8c00', '#9aa0a6', '#fdd835', '#1e88e5'];

const HotspotsPanel = () => {
  const { hotspots } = useDashboard();

  // Ensure we have 'Others' category for the exact chart representation if needed
  let chartData = (hotspots || [])
    .sort((a, b) => b.count - a.count)
    .map(spot => ({
      name: spot.sector,
      value: spot.count,
    }));

  // Fallback data matching reference if real data is empty
  if (chartData.length === 0) {
    chartData = [
      { name: 'Faizabad', value: 35 },
      { name: 'G-10 Markaz', value: 25 },
      { name: 'Saddar', value: 20 },
      { name: 'Others', value: 20 },
    ];
  }

  const total = chartData.reduce((sum, item) => sum + item.value, 0);

  // Mock data for the bar chart at the bottom
  const barData = [10, 30, 20, 15, 25, 45, 12, 28];

  return (
    <div className="hotspots-panel">
      <div className="panel-header-teal">
        <h2>Spatial Analysis</h2>
      </div>

      <div className="hotspots-title">
        Emergency Hotspots
      </div>

      <div className="hotspots-content">
        <div className="chart-wrapper">
          <ResponsiveContainer width="100%" height={220}>
            <PieChart>
              <Pie
                data={chartData}
                cx="50%"
                cy="50%"
                innerRadius={60}
                outerRadius={90}
                paddingAngle={2}
                dataKey="value"
                stroke="none"
              >
                {chartData.map((entry, index) => (
                  <Cell
                    key={`cell-${index}`}
                    fill={COLORS[entry.name] || defaultColors[index % defaultColors.length]}
                  />
                ))}
              </Pie>
            </PieChart>
          </ResponsiveContainer>

          <div className="donut-legend">
            {chartData.map((item, idx) => (
              <div key={item.name} className="legend-item">
                <span
                  className="legend-color"
                  style={{ backgroundColor: COLORS[item.name] || defaultColors[idx % defaultColors.length] }}
                ></span>
                <span>
                  {item.name}: {((item.value / total) * 100).toFixed(0)}%
                </span>
              </div>
            ))}
          </div>

          <div style={{ display: 'flex', width: '100%', marginTop: 'auto' }}>
            <div className="y-axis">
              <span>20</span>
              <span>10</span>
              <span>0</span>
            </div>
            <div style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
              <div className="bar-chart-preview">
                {barData.map((val, i) => (
                  <div key={i} className="bar" style={{ height: `${(val / 50) * 100}%` }}></div>
                ))}
              </div>
              <div className="bar-labels">
                <span>Tam</span>
                <span>Wed</span>
                <span>Fri</span>
                <span>Sun</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default HotspotsPanel;
