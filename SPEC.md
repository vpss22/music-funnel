# Music Funnel AI - Google Cloud Edition SPEC

## Overview
Recreate the Music Funnel AI application for deployment on Google Compute Engine VPS. Replace OpenAI with Google Gemini API. Single-server architecture with Nginx reverse proxy.

## Architecture
```
Google VPS (Ubuntu 22.04)
├── Nginx (port 80/443) - Reverse proxy + static file serving
│   ├── / → serves frontend/dist (React SPA)
│   └── /api → proxies to backend (port 8000)
├── FastAPI Backend (port 8000) - Python + Gemini API
│   ├── /api/scan - Scan leads endpoint
│   ├── /api/health - Health check
│   └── /api/config - Get config (models list)
└── Frontend (built static files) - React 19 + Vite + Tailwind
    ├── / - Landing page (Home)
    └── /dashboard - Lead scanner dashboard
```

## Backend (FastAPI + Python)

### Files
- `backend/main.py` - FastAPI app, CORS, routes
- `backend/ai.py` - Gemini API integration for lead scoring
- `backend/scraper.py` - Lead scanning logic
- `backend/requirements.txt` - Python dependencies
- `backend/.env.example` - Environment variables template

### API Endpoints
- `GET /api/health` → `{"status": "healthy", "version": "1.0.0"}`
- `GET /api/config` → `{"models": ["gemini-1.5-flash", "gemini-1.5-pro", "gemini-2.0-flash-lite"]}`
- `GET /api/scan?mode=manual|ai&model=gemini-1.5-flash` → Array of Lead objects

### Lead Object
```json
{
  "name": "Artist Name",
  "instagram_status": "404|active",
  "linktree": true|false,
  "inactive": true|false,
  "subscribers": 24000,
  "score": {
    "score": 5,
    "tier": "WARM|HOT|COLD",
    "ai_insight": "Optional Gemini analysis"
  }
}
```

### Gemini Integration
- Use `google-generativeai` package
- API key from `GEMINI_API_KEY` env var
- Default model: `gemini-1.5-flash`
- System prompt: "You are a music industry scout specializing in finding artists with broken marketing funnels."
- Max output tokens: 100

## Frontend (React + TypeScript + Vite)

### Files
- `frontend/src/App.tsx` - HashRouter with routes
- `frontend/src/pages/Home.tsx` - Landing page
- `frontend/src/pages/Dashboard.tsx` - Dashboard with tabs
- `frontend/src/types/index.ts` - TypeScript interfaces
- `frontend/src/components/ui/*` - shadcn/ui components
- `frontend/src/lib/utils.ts` - Utility functions
- `frontend/src/index.css` - Global styles
- `frontend/src/main.tsx` - Entry point
- `frontend/index.html` - HTML template
- `frontend/package.json` - Dependencies
- `frontend/vite.config.ts` - Vite config
- `frontend/tailwind.config.js` - Tailwind config
- `frontend/tsconfig.json` - TypeScript config
- `frontend/components.json` - shadcn/ui config

### Key Changes from Original
1. Branding: "Music Funnel AI" → "Music Funnel AI" (keep name)
2. API base: `/api` (proxied through Nginx, no separate origin)
3. AI model dropdown: Gemini models instead of GPT models
4. All OpenAI references → Google Gemini
5. Remove Vercel/Render specific config
6. Update AI insight card to show "Gemini Insight" instead of "AI Insight"
7. Add Google Cloud branding elements

## Deployment

### Files
- `deployment/nginx.conf` - Nginx site configuration
- `deployment/backend.service` - systemd service for FastAPI
- `deployment/install.sh` - One-command setup script
- `deployment/.env.example` - Production environment template

### install.sh Steps
1. Update system packages
2. Install Node.js 20 + npm
3. Install Python 3.11 + pip + venv
4. Install Nginx
5. Create app directory `/opt/music-funnel-ai`
6. Copy backend files, create venv, install requirements
7. Copy built frontend dist to `/opt/music-funnel-ai/frontend`
8. Copy systemd service, enable and start
9. Copy nginx config, enable site, reload
10. Setup firewall (ufw allow 80, 443, 8000)
11. Create .env file with GEMINI_API_KEY

## Environment Variables
- `GEMINI_API_KEY` - Google Gemini API key
- `PORT` - Backend port (default: 8000)
- `ALLOWED_ORIGINS` - CORS origins (default: *)
- `FRONTEND_URL` - Frontend URL for CORS

## Data Flow
1. User visits landing page → static files served by Nginx
2. User clicks "Open Dashboard" → React Router navigates
3. Dashboard loads → calls `/api/scan` → Nginx proxies to FastAPI
4. FastAPI calls Gemini API (if AI mode enabled) → returns scored leads
5. Dashboard displays leads with tier badges and Gemini insights
