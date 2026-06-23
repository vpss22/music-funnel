"""
Music Funnel AI - FastAPI Backend Application

Provides REST API endpoints for scanning and scoring music industry leads.
Integrates with Google Gemini API for AI-powered insights.

Endpoints:
    GET /api          - List available API endpoints
    GET /api/health   - Health check
    GET /api/config   - Get available Gemini models
    GET /api/scan     - Scan and score leads (manual or AI mode)
"""

import os
import logging
from typing import Optional

from fastapi import FastAPI, Header, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from scraper import scan_leads
from ai import score_lead

# ---------------------------------------------------------------------------
# Logging configuration
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
)
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# FastAPI application
# ---------------------------------------------------------------------------
app = FastAPI(
    title="Music Funnel AI API",
    description="AI-powered lead scoring for music industry scouts. "
                "Finds music creators with broken Instagram links, missing Linktrees, "
                "and inactive accounts. Optional Gemini AI enrichment.",
    version="1.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    openapi_url="/api/openapi.json",
)

# --- CORS ---
_origins_env = os.getenv("ALLOWED_ORIGINS", "*")
origins = [o.strip() for o in _origins_env.split(",") if o.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins if origins[0] != "*" else ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.get("/api/health")
def health_check():
    """Health check endpoint.

    Returns:
        dict: Service status, version, and name.
    """
    return {
        "status": "healthy",
        "version": "1.0.0",
        "service": "Music Funnel AI API",
    }


@app.get("/api/config")
def get_config():
    """Get available Gemini models for AI-powered scoring.

    Returns:
        dict: List of supported Gemini model options.
    """
    return {
        "models": [
            {
                "id": "gemini-1.5-flash",
                "name": "Gemini 1.5 Flash (Recommended)",
                "description": "Fast, cost-effective for most use cases",
            },
            {
                "id": "gemini-1.5-pro",
                "name": "Gemini 1.5 Pro (High Quality)",
                "description": "Best quality, larger context window",
            },
            {
                "id": "gemini-2.0-flash-lite",
                "name": "Gemini 2.0 Flash Lite (Fastest)",
                "description": "Ultra-fast responses, most economical",
            },
        ]
    }


@app.get("/api/scan")
def scan(
    mode: str = Query("manual", enum=["manual", "ai"]),
    model: str = Query("gemini-1.5-flash"),
    query: str = Query("Producer"),
    min_subs: int = Query(0),
    location: Optional[str] = Query(None),
    api_key: Optional[str] = Header(None, alias="X-API-Key"),
    youtube_key: Optional[str] = Header(None, alias="X-YouTube-Key"),
):
    """Scan for leads and score them using the selected mode.

    Args:
        mode: Scoring mode - ``manual`` (heuristic only) or ``ai`` (heuristic + Gemini).
        model: Gemini model ID when ``mode=ai`` (e.g., ``gemini-1.5-flash``).
        query: Search query for finding creators.
        min_subs: Minimum subscriber count filter.
        location: Location filter (e.g., "US", "UK").
        api_key: Optional client API key passed via ``X-API-Key`` header.
        youtube_key: Optional YouTube API key passed via ``X-YouTube-Key`` header.

    Returns:
        list: Scored lead objects with embedded ``score`` metadata.
    """
    logger.info(f"Scan request: mode={mode}, query={query}, min_subs={min_subs}, location={location}")

    try:
        leads = scan_leads(query=query, youtube_key=youtube_key, min_subs=min_subs, location=location)
        use_ai = mode == "ai"
        results = []

        for lead in leads:
            lead["score"] = score_lead(
                lead,
                use_ai=use_ai,
                model=model,
                api_key=api_key,
            )
            results.append(lead)

        logger.info(f"Scan complete: {len(results)} leads processed")
        return results

    except Exception as exc:
        logger.error(f"Scan error: {exc}")
        return JSONResponse(
            status_code=500,
            content={
                "error": "Internal server error",
                "detail": str(exc),
            },
        )


@app.get("/api")
def api_root():
    """API root - list all available endpoints.

    Returns:
        dict: Endpoint catalog with paths, methods, and descriptions.
    """
    return {
        "service": "Music Funnel AI API",
        "version": "1.0.0",
        "documentation": "/api/docs",
        "endpoints": [
            {"path": "/api/health", "method": "GET", "description": "Health check"},
            {"path": "/api/config", "method": "GET", "description": "Get available Gemini models"},
            {"path": "/api/scan", "method": "GET", "description": "Scan and score leads (manual or AI mode)"},
        ],
    }


# ---------------------------------------------------------------------------
# Entry point for direct execution
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    import uvicorn

    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)
