# KHABAR Admin Dashboard - Quick Start Guide

## 🚀 How to Run the Dashboard

### Prerequisites
- Node.js v18+ and npm v9+
- Backend servers running (api_server.py on port 8000, dashboard_server.py on port 8001)
- Python 3.8+ with FastAPI running

### Step 1: Start the Backend (Terminal 1)
```bash
cd d:\Khabar
python api_server.py
# Output: Uvicorn running on http://127.0.0.1:8000
```

### Step 2: Start the Dashboard API Server (Terminal 2)
```bash
cd d:\Khabar
python dashboard_server.py
# Output: Uvicorn running on http://127.0.0.1:8001
```

### Step 3: Start the React Development Server (Terminal 3)
```bash
cd d:\Khabar\khabar-dashboard
npm run dev
# Output: http://localhost:5173/
```

### Step 4: Open in Browser
```
http://localhost:5173/
```

---

## 📊 Dashboard Components Overview

### Left Side
- **Interactive Map**: Shows all incidents (colored by priority) and resources (colored by status)
  - Red markers = P1 Critical incidents
  - Orange = P2 High priority
  - Green = Available resources
  - Lines show dispatch routes

### Top Right
- **AI Recommendations Panel**: Priority-sorted list of incidents (1-5)
  - Click to expand and see full details
  - Color-coded urgency flags
  - Live AI status indicator

### Bottom Right  
- **Hotspots Analysis**: Donut chart showing incident distribution by sector
  - Faizabad, G-10 Markaz, Saddar, Chungi zones
  - Percentages for each sector
  - Total incident count

### Bottom Left & Center
- **Resource Management**: Table with all registered resources
  - Columns: ID, Type, Coordinates, Status, Available quantity
  - Delete button for each resource
  - Form on right to add new resources

### Bottom (Full Width)
- **Active Deployments**: Tracks real-time dispatch assignments
  - Columns: Resource ID, Deployed Location, Target Incident, Status, ETA

---

## 🎮 How to Use Each Feature

### Adding a Resource
1. Fill in the form on the right side of Resource Management
   - Resource Name: e.g., "Ambulance-001"
   - Type: Select from dropdown (Ambulance, Rescue, Pump, Medical Kit)
   - Quantity: Number of units available
   - Latitude: Current position (default: 33.74)
   - Longitude: Current position (default: 73.15)
2. Click "Register New Resource"
3. Resource appears in table immediately
4. Visible on map with green marker (available status)

### Viewing Incidents
1. Click any red/orange/yellow marker on the map
2. Popup shows:
   - Priority level (P1-P5)
   - Incident type
   - Location area
   - Confidence score (AI)

### Managing Resources
1. View all resources in the table
2. Click red delete button to remove (requires confirmation)
3. Status badges show: Available (green), En-route (blue), Deployed (orange)

### Monitoring Deployments
1. Scroll down to "Active Deployments & Dispatch Tracking"
2. See all active resource assignments
3. ETA calculated in minutes
4. Status updates in real-time (3-second polling)

---

## 🔄 Data Polling

- **Polling Interval**: 3 seconds
- **Polled Endpoints**:
  - GET /incidents (priority-sorted list)
  - GET /resources (resource inventory)
  - GET /deployments (active dispatch tracking)
  - GET /hotspots (spatial analysis data)

No manual refresh needed - data updates automatically!

---

## 🎨 Design Features

### Colors
- **Primary**: Teal (#00c896, #00e5ff)
- **Critical**: Red (#ff3366) - P1 incidents
- **High**: Orange (#ff9500) - P2 incidents
- **Success**: Green (#00e676)
- **Info**: Blue (#2196F3)
- **Warning**: Yellow (#ffb300)

### Theme
- Dark background (#030712)
- Glassmorphism effects
- Rounded corners (24px cards, 12px elements)
- Smooth transitions (0.2-0.3s)

### Responsive Design
- Desktop (1400px+): 2-column grid layout
- Tablet (1024-1400px): Flexible grid
- Mobile (<1024px): Single column stack

---

## 🔧 Troubleshooting

### "Dashboard API offline" Error
**Cause**: dashboard_server.py not running
**Solution**: 
```bash
python dashboard_server.py  # Start on port 8001
```

### No incidents/resources showing
**Cause**: Backend not returning data
**Solution**:
1. Check if api_server.py is running on port 8000
2. Verify database connection
3. Check browser console for error messages

### Map not rendering
**Cause**: Leaflet library not loaded
**Solution**:
```bash
npm install  # Reinstall dependencies
npm run dev   # Restart dev server
```

### Slow performance
**Cause**: Polling interval too aggressive
**Solution**: Polling is already optimized at 3 seconds
- Check network tab for API response times
- Reduce browser extensions

### Component not showing
**Cause**: Missing data from API
**Solution**:
1. Check Network tab in DevTools
2. Verify API endpoints return data
3. Check console for error logs

---

## 📋 Verification Checklist

- [ ] Dashboard loads at http://localhost:5173
- [ ] Header shows "LIVE" status
- [ ] Map displays with OpenStreetMap tiles
- [ ] Sidebar navigation appears (collapsible)
- [ ] At least one incident marker visible on map
- [ ] Recommendations panel shows incident queue
- [ ] Hotspots chart displays sector distribution
- [ ] Resource table shows existing resources
- [ ] Add Resource form is functional
- [ ] Deployment table updates every 3 seconds
- [ ] No console errors (check DevTools F12)
- [ ] Colors match design (teal primary, red P1, etc.)

---

## 🚀 Production Build

When ready for deployment:
```bash
cd khabar-dashboard
npm run build
# Creates optimized build in dist/ folder

# Preview production build locally:
npm run preview
```

---

## 📞 Support

**Common Issues & Solutions:**
- API connectivity → Check ports 8000, 8001
- Styling issues → Clear browser cache (Ctrl+Shift+R)
- Module not found → Run `npm install` again
- Port already in use → Use different port in vite.config.js

---

**Status**: ✅ Ready for Testing
**Next**: Run the 3 terminal commands above and open http://localhost:5173
