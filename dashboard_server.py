"""
dashboard_server.py — KHABAR Real-Time Web Dashboard
Serves the React Admin Dashboard (Vite Production Build)
Run: python dashboard_server.py  →  http://127.0.0.1:8001
"""
import os
import uvicorn
from fastapi import FastAPI
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="KHABAR Admin Dashboard")

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Paths
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DIST_DIR = os.path.join(BASE_DIR, "dashboard", "dist")
ASSETS_DIR = os.path.join(DIST_DIR, "assets")

# Mount static assets if they exist
if os.path.exists(ASSETS_DIR):
    app.mount("/assets", StaticFiles(directory=ASSETS_DIR), name="assets")

@app.get("/{fallback_path:path}")
async def serve_dashboard(fallback_path: str = None):
    # Support client-side routing fallback if needed, but primarily index.html
    index_path = os.path.join(DIST_DIR, "index.html")
    if os.path.exists(index_path):
        return FileResponse(index_path)
    return {
        "status": "error",
        "message": "Dashboard assets not found. Please compile the React project using 'npm run build' inside the 'dashboard' folder."
    }

if __name__ == "__main__":
    print("\n" + "="*65)
    print("  KHABAR React Admin Dashboard Server Running")
    print("  Open: http://127.0.0.1:8001")
    print("="*65 + "\n")
    uvicorn.run(app, host="0.0.0.0", port=8001)
