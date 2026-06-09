# Music Funnel AI - Google Cloud Edition

A tool to find broken creator funnels automatically. This project uses AI-powered lead scoring to identify music creators with broken Instagram links, missing Linktrees, and inactive accounts.

This is a recreated version of the original [broken-links](https://github.com/vpss22/broken-links) repository, tailored for deployment on Google Cloud Platform using the **Google Gemini API**.

## Architecture

```
Google VPS (Ubuntu 22.04)
|
|-- Nginx (port 80/443) - Reverse proxy + static file serving
|   |-- /  --> React frontend (built SPA)
|   +-- /api/* --> FastAPI backend (port 8000)
|
|-- FastAPI Backend (Python)
|   |-- /api/health   - Health check
|   |-- /api/config   - Available Gemini models
|   +-- /api/scan     - Scan and score leads
|
+-- Frontend (React 19 + Vite + Tailwind CSS)
    |-- /  - Landing page
    +-- /dashboard - Lead scanner dashboard
```

## What's New

| Feature | Original | This Version |
|---------|----------|-------------|
| AI Provider | OpenAI GPT-4o | Google Gemini 1.5 Flash/Pro |
| Deployment | Vercel + Render | Google Cloud VPS (single server) |
| Reverse Proxy | N/A | Nginx |
| Process Management | N/A | systemd |
| SSL | Vercel managed | Let's Encrypt |
| Frontend Routing | BrowserRouter | HashRouter (for static hosting) |

## Tech Stack

### Frontend
- React 19 + TypeScript
- Vite 7.2.4
- Tailwind CSS v3.4.19
- shadcn/ui components
- React Router (HashRouter)
- Lucide React icons

### Backend
- FastAPI (Python)
- Google Generative AI (Gemini API)
- Uvicorn ASGI server
- python-dotenv for configuration

### Deployment
- Nginx reverse proxy
- systemd service management
- UFW firewall
- Let's Encrypt SSL (optional)

## Quick Deploy

### Prerequisites
- Google Compute Engine VPS (Ubuntu 22.04 LTS)
- A Gemini API key from [Google AI Studio](https://aistudio.google.com/app/apikey)
- SSH access to the server

### One-Command Install

```bash
# Clone or upload this repository to your VPS
git clone <your-repo-url> /tmp/music-funnel-ai
cd /tmp/music-funnel-ai/deployment

# Run the installer with your Gemini API key
sudo bash install.sh --gemini-key=YOUR_GEMINI_API_KEY
```

That's it! The application will be available at `http://YOUR_VPS_IP`.

### Manual Steps (if needed)

1. **Get a Gemini API Key:**
   - Visit [Google AI Studio](https://aistudio.google.com/app/apikey)
   - Create a new API key
   - Copy it for the next step

2. **Set Environment Variables:**
   ```bash
   sudo nano /opt/music-funnel-ai/.env
   # Add: GEMINI_API_KEY=your_key_here
   sudo systemctl restart music-funnel-ai
   ```

3. **Enable SSL (optional):**
   ```bash
   cd /opt/music-funnel-ai/deployment
   sudo bash ssl-setup.sh your-domain.com
   ```

## Development

### Running Locally

**Backend:**
```bash
cd backend
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt

# Set your Gemini API key
export GEMINI_API_KEY="your_key_here"

# Run the server
uvicorn main:app --reload --port 8000
```

The API docs will be available at `http://localhost:8000/api/docs`.

**Frontend:**
```bash
cd frontend
npm install
npm run dev
```

The frontend will be available at `http://localhost:3000` with API proxy to the backend.

### Project Structure

```
.
├── SPEC.md                    # Project specification
├── README.md                  # This file
├── backend/                   # FastAPI backend
|   ├── main.py               # API entry point
|   ├── ai.py                 # Gemini AI scoring
|   ├── scraper.py            # Lead scanner
|   ├── requirements.txt      # Python dependencies
|   └── .env.example          # Env vars template
|
├── frontend/                  # React frontend
|   ├── src/
|   |   ├── App.tsx           # Router setup
|   |   ├── main.tsx          # Entry point
|   |   ├── index.css         # Global styles
|   |   ├── types/
|   |   |   └── index.ts      # TypeScript types
|   |   ├── pages/
|   |   |   ├── Home.tsx      # Landing page
|   |   |   └── Dashboard.tsx # Scanner dashboard
|   |   ├── components/
|   |   |   └── ui/           # shadcn/ui components
|   |   └── lib/
|   |       └── utils.ts      # Utility functions
|   ├── package.json
|   ├── vite.config.ts
|   ├── tailwind.config.js
|   └── tsconfig.json
|
└── deployment/                # Deployment scripts
    ├── install.sh            # Main installer
    ├── nginx.conf            # Nginx config
    ├── backend.service       # systemd service
    ├── ssl-setup.sh          # SSL certificate setup
    ├── update.sh             # Update script
    ├── uninstall.sh          # Uninstall script
    └── .env.example          # Production env template
```

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/health` | GET | Health check |
| `/api/config` | GET | Get available Gemini models |
| `/api/scan` | GET | Scan leads (manual or AI mode) |

### Scan Parameters

- `mode`: `"manual"` (heuristic only) or `"ai"` (heuristic + Gemini)
- `model`: Gemini model ID (e.g., `gemini-1.5-flash`)
- `X-API-Key` header: Optional API key (can also be set server-side via env)

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GEMINI_API_KEY` | (required) | Google Gemini API key |
| `PORT` | `8000` | Backend server port |
| `ALLOWED_ORIGINS` | `*` | CORS origins (comma-separated) |

## Scoring Logic

Leads are scored on a 0-8 scale:

| Signal | Points |
|--------|--------|
| Broken Instagram link (404) | +4 |
| Inactive account | +2 |
| Missing Linktree | +1 |
| 10K+ subscribers | +1 |

**Tiers:**
- **HOT** (6-8): High-priority broken funnel
- **WARM** (3-5): Moderate opportunity
- **COLD** (0-2): Low priority

When AI mode is enabled, Google Gemini provides additional insights on each lead.

## Available Gemini Models

| Model | Speed | Quality | Best For |
|-------|-------|---------|----------|
| `gemini-1.5-flash` | Fast | Good | Most use cases (recommended) |
| `gemini-1.5-pro` | Medium | Best | Deep analysis |
| `gemini-2.0-flash-lite` | Fastest | Basic | Quick scans |

## Management Commands

```bash
# Check service status
sudo systemctl status music-funnel-ai

# View logs
sudo journalctl -u music-funnel-ai -f

# Restart backend
sudo systemctl restart music-funnel-ai

# Reload nginx
sudo systemctl reload nginx

# Update application
sudo bash /opt/music-funnel-ai/deployment/update.sh

# Uninstall
sudo bash /opt/music-funnel-ai/deployment/uninstall.sh
```

## Troubleshooting

**Backend won't start:**
```bash
# Check logs
sudo journalctl -u music-funnel-ai -n 50

# Verify env file
sudo cat /opt/music-funnel-ai/.env

# Test manually
cd /opt/music-funnel-ai/backend
sudo venv/bin/python -c "from main import app; print('OK')"
```

**Nginx errors:**
```bash
# Test config
sudo nginx -t

# Check nginx error logs
sudo tail -f /var/log/nginx/error.log
```

**API returns 502 Bad Gateway:**
- Check if backend is running: `sudo systemctl status music-funnel-ai`
- Verify port 8000 is listening: `sudo ss -tlnp | grep 8000`

## License

This project is a recreation of the original [vpss22/broken-links](https://github.com/vpss22/broken-links) repository, modified for Google Cloud Platform with Gemini API integration.
