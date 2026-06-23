"""
Music Funnel AI - Lead Scanner Module

Generates realistic mock music industry leads for scouting purposes.
Identifies creators with broken Instagram links, missing Linktrees,
and inactive accounts to surface high-value lead opportunities.
"""

import os
from datetime import datetime, timedelta
import random
import re
import logging
from typing import List, Dict, Optional
import requests

logger = logging.getLogger(__name__)

# --- YouTube Search Constants ---
YOUTUBE_API_URL = "https://www.googleapis.com/youtube/v3/search"
CHANNELS_API_URL = "https://www.googleapis.com/youtube/v3/channels"

def check_instagram_status(username: str) -> str:
    """Check if an Instagram profile exists or returns 404.
    
    Args:
        username: Instagram handle
        
    Returns:
        str: 'active' or '404'
    """
    if not username:
        return "none"
    
    url = f"https://www.instagram.com/{username}/"
    try:
        # Note: In production, this might need a more robust scraper or API
        # but for this POC we try a simple HEAD request with a common UA
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        }
        response = requests.head(url, headers=headers, timeout=5, allow_redirects=True)
        if response.status_code == 404:
            return "404"
        return "active"
    except Exception as e:
        logger.warning(f"Failed to check IG status for {username}: {e}")
        return "active" # Assume active if we can't check

def extract_instagram_handle(text: str) -> Optional[str]:
    """Extract Instagram handle from bio text."""
    if not text:
        return None
    # Look for patterns like ig: @handle, instagram: handle, etc.
    patterns = [
        r"(?:ig|instagram|insta):\s*@?([a-zA-Z0-9_.]+)",
        r"@([a-zA-Z0-9_.]+)",
    ]
    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            return match.group(1)
    return None

def extract_linktree_url(text: str) -> Optional[str]:
    """Extract bio link URL (Linktree, etc.) from bio text."""
    if not text:
        return None
    patterns = [
        r"(https?://(?:www\.)?linktr\.ee/[a-zA-Z0-9_.-]+)",
        r"(https?://(?:www\.)?lnk\.bio/[a-zA-Z0-9_.-]+)",
        r"(https?://(?:www\.)?bio\.link/[a-zA-Z0-9_.-]+)",
        r"(https?://(?:www\.)?campsite\.bio/[a-zA-Z0-9_.-]+)",
    ]
    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            return match.group(1)
    return None

def scan_leads(query: str = "Producer", youtube_key: Optional[str] = None, min_subs: int = 0, location: Optional[str] = None) -> List[Dict]:
    """
    Scan for music industry leads with broken funnels.
    
    Uses YouTube Data API if key is provided, otherwise falls back to mock data.
    """
    api_key = youtube_key or os.getenv("YOUTUBE_API_KEY")
    
    # Basic validation for API key to prevent 400 errors with obvious garbage
    if not api_key or len(api_key) < 20 or " " in api_key or "(" in api_key:
        logger.info(f"No valid YouTube API key provided (key length: {len(api_key) if api_key else 0}), returning mock leads.")
        return MOCK_LEADS

    logger.info(f"Fetching real leads from YouTube API for query: {query}")
    try:
        # 1. Search for channels (Paginated to get 100 results)
        channel_ids = []
        next_page_token = None
        
        # Refine query to target producers specifically
        search_query = f"{query} music producer beats"
        if location:
            search_query += f" {location}"
            
        for _ in range(2): # 2 pages of 50 = 100 results
            search_params = {
                "part": "snippet",
                "q": search_query,
                "type": "channel",
                "maxResults": 50,
                "key": api_key
            }
            if next_page_token:
                search_params["pageToken"] = next_page_token
                
            search_res = requests.get(YOUTUBE_API_URL, params=search_params, timeout=10)
            
            if search_res.status_code == 400:
                error_msg = search_res.json().get("error", {}).get("message", "Unknown error")
                logger.error(f"YouTube API Key rejected: {error_msg}")
                return MOCK_LEADS
                
            search_res.raise_for_status()
            data = search_res.json()
            items = data.get("items", [])
            channel_ids.extend([item["id"]["channelId"] for item in items])
            
            next_page_token = data.get("nextPageToken")
            if not next_page_token:
                break

        if not channel_ids:
            return []

        # 2. Get detailed channel info in batches of 50
        all_items = []
        for i in range(0, len(channel_ids), 50):
            batch_ids = channel_ids[i:i+50]
            channels_params = {
                "part": "snippet,statistics,brandingSettings,contentDetails",
                "id": ",".join(batch_ids),
                "key": api_key
            }
            channels_res = requests.get(CHANNELS_API_URL, params=channels_params, timeout=10)
            channels_res.raise_for_status()
            all_items.extend(channels_res.json().get("items", []))
        
        leads = []
        for item in all_items:
            snippet = item.get("snippet", {})
            stats = item.get("statistics", {})
            
            description = snippet.get("description", "")
            ig_handle = extract_instagram_handle(description)
            linktree_url = extract_linktree_url(description)
            
            # Improved Linktree detection
            link_patterns = ["linktr.ee", "lnk.bio", "campsite.bio", "bio.link", "linkpop.com"]
            has_linktree = any(p in description.lower() for p in link_patterns) or bool(linktree_url)
            
            ig_status = "active"
            instagram_url = None
            if ig_handle:
                ig_status = check_instagram_status(ig_handle)
                instagram_url = f"https://www.instagram.com/{ig_handle}/"
            else:
                ig_status = "missing"

            # ... (inactivity logic) ...
            published_at = snippet.get("publishedAt", "")
            is_inactive = False
            if published_at:
                pub_date = datetime.fromisoformat(published_at.replace("Z", "+00:00"))
                if (datetime.now(pub_date.tzinfo) - pub_date).days > 730 and int(stats.get("subscriberCount", 0)) < 1000:
                    is_inactive = True

            # Apply filters
            sub_count = int(stats.get("subscriberCount", 0))
            if sub_count < min_subs:
                continue
            
            lead_location = snippet.get("country", "Unknown")
            if location and location.lower() not in lead_location.lower() and location.lower() not in description.lower():
                continue

            lead = {
                "id": f"yt_{item['id']}",
                "name": snippet.get("title", "Unknown Artist"),
                "genre": query,
                "subscribers": int(stats.get("subscriberCount", 0)),
                "instagram_status": ig_status,
                "linktree": has_linktree,
                "inactive": is_inactive,
                "location": snippet.get("country", "Unknown"),
                "bio_snippet": description[:150] + "..." if len(description) > 150 else description,
                "created_at": published_at,
                "youtube_url": f"https://www.youtube.com/channel/{item['id']}",
                "instagram_url": instagram_url,
                "linktree_url": linktree_url,
            }
            leads.append(lead)
            
        return leads

    except Exception as e:
        logger.error(f"Error fetching real leads: {e}")
        return MOCK_LEADS

# --- Mock Lead Database ---

MOCK_LEADS = [
    {
        "id": "lead_001",
        "name": "Taze Da Driller",
        "genre": "UK Drill",
        "subscribers": 84700,
        "instagram_status": "404",
        "linktree": False,
        "inactive": True,
        "location": "London, UK",
        "bio_snippet": "Upcoming UK drill artist with raw street energy",
        "created_at": (datetime.now() - timedelta(days=45)).isoformat(),
    },
    {
        "id": "lead_002",
        "name": "Amaara Beats",
        "genre": "Afrobeat",
        "subscribers": 23400,
        "instagram_status": "404",
        "linktree": False,
        "inactive": False,
        "location": "Lagos, Nigeria",
        "bio_snippet": "Afrobeat producer crafting rhythms for the diaspora",
        "created_at": (datetime.now() - timedelta(days=12)).isoformat(),
    },
    {
        "id": "lead_003",
        "name": "Lofi Luna",
        "genre": "Lo-Fi",
        "subscribers": 156000,
        "instagram_status": "active",
        "linktree": True,
        "inactive": False,
        "location": "Portland, OR",
        "bio_snippet": "Chill beats to study and relax to - 24/7",
        "created_at": (datetime.now() - timedelta(days=3)).isoformat(),
    },
    {
        "id": "lead_004",
        "name": "DJ Voltage",
        "genre": "EDM",
        "subscribers": 52000,
        "instagram_status": "404",
        "linktree": False,
        "inactive": True,
        "location": "Amsterdam, NL",
        "bio_snippet": "Festival-ready EDM bangers and electrifying drops",
        "created_at": (datetime.now() - timedelta(days=78)).isoformat(),
    },
    {
        "id": "lead_005",
        "name": "Maya Soul",
        "genre": "R&B",
        "subscribers": 8900,
        "instagram_status": "active",
        "linktree": False,
        "inactive": True,
        "location": "Atlanta, GA",
        "bio_snippet": "Smooth R&B vocals with neo-soul influences",
        "created_at": (datetime.now() - timedelta(days=120)).isoformat(),
    },
    {
        "id": "lead_006",
        "name": "Kilo Gram",
        "genre": "Hip-Hop",
        "subscribers": 127000,
        "instagram_status": "404",
        "linktree": True,
        "inactive": False,
        "location": "Chicago, IL",
        "bio_snippet": "Bars-heavy hip-hop with conscious storytelling",
        "created_at": (datetime.now() - timedelta(days=8)).isoformat(),
    },
    {
        "id": "lead_007",
        "name": "Eliza Vox",
        "genre": "Pop",
        "subscribers": 45000,
        "instagram_status": "active",
        "linktree": False,
        "inactive": False,
        "location": "Los Angeles, CA",
        "bio_snippet": "Pop sensation with catchy hooks and vibrant visuals",
        "created_at": (datetime.now() - timedelta(days=22)).isoformat(),
    },
    {
        "id": "lead_008",
        "name": "Sax Walker",
        "genre": "Jazz",
        "subscribers": 3400,
        "instagram_status": "404",
        "linktree": False,
        "inactive": True,
        "location": "New Orleans, LA",
        "bio_snippet": "Contemporary jazz saxophonist blending tradition with fusion",
        "created_at": (datetime.now() - timedelta(days=200)).isoformat(),
    },
    {
        "id": "lead_009",
        "name": "Trap Ghost",
        "genre": "Trap",
        "subscribers": 67000,
        "instagram_status": "active",
        "linktree": True,
        "inactive": False,
        "location": "Houston, TX",
        "bio_snippet": "Dark trap beats with haunting melodies",
        "created_at": (datetime.now() - timedelta(days=5)).isoformat(),
    },
    {
        "id": "lead_010",
        "name": "Reggae Roots Collective",
        "genre": "Reggae",
        "subscribers": 18200,
        "instagram_status": "404",
        "linktree": False,
        "inactive": False,
        "location": "Kingston, Jamaica",
        "bio_snippet": "Roots reggae with a modern conscious message",
        "created_at": (datetime.now() - timedelta(days=30)).isoformat(),
    },
    {
        "id": "lead_011",
        "name": "Synthwave Surfer",
        "genre": "Synthwave",
        "subscribers": 98000,
        "instagram_status": "active",
        "linktree": False,
        "inactive": True,
        "location": "Miami, FL",
        "bio_snippet": "Retro-futuristic synthwave for neon nights",
        "created_at": (datetime.now() - timedelta(days=60)).isoformat(),
    },
    {
        "id": "lead_012",
        "name": "Acoustic Annie",
        "genre": "Indie Folk",
        "subscribers": 5600,
        "instagram_status": "404",
        "linktree": True,
        "inactive": True,
        "location": "Nashville, TN",
        "bio_snippet": "Raw indie folk storytelling with acoustic charm",
        "created_at": (datetime.now() - timedelta(days=90)).isoformat(),
    },
]
