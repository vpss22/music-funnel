"""
Music Funnel AI - Lead Scanner Module

Generates realistic mock music industry leads for scouting purposes.
Identifies creators with broken Instagram links, missing Linktrees,
and inactive accounts to surface high-value lead opportunities.
"""

from datetime import datetime, timedelta
import random


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


def scan_leads():
    """
    Scan for music industry leads with broken funnels.

    Returns a list of lead dictionaries containing creator metadata,
    social presence status, and engagement signals.

    Returns:
        list: Lead dictionaries with keys:
            - id (str): Unique lead identifier
            - name (str): Creator/artist name
            - genre (str): Music genre
            - subscribers (int): Subscriber/follower count
            - instagram_status (str): '404' or 'active'
            - linktree (bool): Whether Linktree is present
            - inactive (bool): Whether account is inactive
            - location (str): Geographic location
            - bio_snippet (str): Short bio description
            - created_at (str): ISO timestamp of lead creation
    """
    return MOCK_LEADS
