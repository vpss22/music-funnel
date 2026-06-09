"""
Music Funnel AI - Gemini AI Scoring Module

Integrates with Google Gemini API to provide AI-powered lead scoring insights.
Falls back gracefully to heuristic-only scoring when the API key is unavailable.
"""

import os
import logging
from typing import Dict, Any, Optional

import google.generativeai as genai
from dotenv import load_dotenv

# Configure module-level logging
logger = logging.getLogger(__name__)

# Load environment variables from .env file
load_dotenv()


def get_gemini_client() -> Optional[Any]:
    """Initialize Gemini with API key from environment.

    Returns the configured ``genai`` module on success, or ``None`` if the
    ``GEMINI_API_KEY`` environment variable is missing.

    Returns:
        Optional[Any]: Configured ``genai`` module, or ``None``.
    """
    key = os.getenv("GEMINI_API_KEY")
    if not key:
        logger.warning("GEMINI_API_KEY environment variable not set")
        return None
    genai.configure(api_key=key)
    return genai


def score_lead(lead: Dict[str, Any], use_ai: bool = False, model: str = "gemini-1.5-flash") -> Dict[str, Any]:
    """Score a lead based on heuristics, optionally enriched with Gemini AI.

    Heuristic scoring (0-8 scale):
        - Instagram 404/broken link: +4
        - Missing Linktree: +1
        - Inactive account: +2
        - >10,000 subscribers: +1

    Tiers:
        - HOT:   score >= 6 (high-priority broken funnel)
        - WARM:  score >= 3 (moderate opportunity)
        - COLD:  score < 3  (low priority)

    Args:
        lead: Lead dictionary from :func:`scraper.scan_leads`.
        use_ai: Whether to call the Gemini API for additional insight.
        model: Gemini model identifier (e.g., ``gemini-1.5-flash``).

    Returns:
        dict: Scoring result with ``score``, ``tier``, and ``ai_insight`` keys.
    """
    # --- Base heuristic score (0-8 scale) ---
    score = 0
    if lead.get("instagram_status") == "404":
        score += 4
    if not lead.get("linktree"):
        score += 1
    if lead.get("inactive"):
        score += 2
    if lead.get("subscribers", 0) > 10000:
        score += 1

    # --- Determine tier ---
    tier = "COLD"
    if score >= 6:
        tier = "HOT"
    elif score >= 3:
        tier = "WARM"

    ai_analysis: Optional[str] = None

    # --- Optional Gemini AI enrichment ---
    if use_ai:
        client = get_gemini_client()
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
                model_instance = genai.GenerativeModel(
                    model_name=model,
                    system_instruction=(
                        "You are a music industry scout specializing in finding artists "
                        "with broken marketing funnels. Be concise and actionable."
                    ),
                )
                response = model_instance.generate_content(
                    prompt,
                    generation_config=genai.types.GenerationConfig(
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
            ai_analysis = "Gemini API key not configured. Set GEMINI_API_KEY environment variable."
            logger.warning("Skipping AI insight: GEMINI_API_KEY not configured")

    return {
        "score": score,
        "tier": tier,
        "ai_insight": ai_analysis,
    }
