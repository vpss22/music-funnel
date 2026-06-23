"""
Music Funnel AI - Gemini AI Scoring Module

Integrates with Google Gemini API to provide AI-powered lead scoring insights.
Falls back gracefully to heuristic-only scoring when the API key is unavailable.
"""

import os
import logging
from typing import Dict, Any, Optional

from dotenv import load_dotenv

# Configure module-level logging
logger = logging.getLogger(__name__)

# Load environment variables from .env file
load_dotenv()

# Try to import google-genai
try:
    from google import genai
    from google.genai import types
    GEMINI_AVAILABLE = True
except ImportError:
    GEMINI_AVAILABLE = False
    genai = None

def get_gemini_client(api_key: Optional[str] = None) -> Optional[Any]:
    """Initialize Gemini client.
    
    Args:
        api_key: Optional API key. If not provided, uses GEMINI_API_KEY env var.
    """
    if not GEMINI_AVAILABLE:
        logger.warning("google-genai package not installed. Run: pip install google-genai")
        return None
        
    key = api_key or os.getenv("GEMINI_API_KEY")
    if not key:
        logger.warning("No Gemini API key available")
        return None
        
    try:
        return genai.Client(api_key=key)
    except Exception as e:
        logger.error(f"Failed to initialize Gemini client: {e}")
        return None

def score_lead(lead: Dict[str, Any], use_ai: bool = False, model: str = "gemini-1.5-flash", api_key: Optional[str] = None) -> Dict[str, Any]:
    """Score a lead based on heuristics, optionally enriched with Gemini AI."""
    # ... heuristic logic ...
    score = 0
    if lead.get("instagram_status") == "404":
        score += 4
    if not lead.get("linktree"):
        score += 1
    if lead.get("inactive"):
        score += 2
    if lead.get("subscribers", 0) > 10000:
        score += 1

    tier = "COLD"
    if score >= 6:
        tier = "HOT"
    elif score >= 3:
        tier = "WARM"

    ai_analysis: Optional[str] = None

    if use_ai:
        client = get_gemini_client(api_key=api_key)
        if client:
            try:
                prompt = f"""
Analyze this potential music industry lead:
- Name: {lead.get('name')}
- Genre: {lead.get('genre')}
- Instagram Status: {lead.get('instagram_status')}
- Linktree: {lead.get('linktree')}
- Inactive: {lead.get('inactive')}
- Subscribers: {lead.get('subscribers')}
- Location: {lead.get('location')}

Current Heuristic Score: {score}/8 ({tier})

Provide a brief insight (max 20 words) on why this lead might be valuable or a waste of time.
Also suggest if the score should be adjusted and why.
Format your response as a single concise paragraph.
"""
                response = client.models.generate_content(
                    model=model,
                    contents=prompt,
                    config=types.GenerateContentConfig(
                        system_instruction=(
                            "You are a music industry scout specializing in finding artists "
                            "with broken marketing funnels. Be concise and actionable."
                        ),
                        max_output_tokens=100,
                        temperature=0.7,
                    ),
                )
                ai_analysis = response.text.strip()
                logger.info(f"AI insight generated for lead '{lead.get('name')}'")
            except Exception as exc:
                ai_analysis = f"Gemini Error: {str(exc)}"
                logger.error(f"Gemini API error for lead '{lead.get('name')}': {exc}")
        else:
            ai_analysis = "Gemini API key not configured."
            
    return {
        "score": score,
        "tier": tier,
        "ai_insight": ai_analysis,
    }
