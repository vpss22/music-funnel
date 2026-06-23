#!/usr/bin/env python3
"""
Music Funnel AI - API Test Script
Run this to verify the backend is working correctly before deploying.

Usage:
    cd backend
    source venv/bin/activate
    python test_api.py
"""

import sys
import time
import requests

BASE_URL = "http://localhost:8000"

def check(name: str, method: str, path: str, expected_status: int = 200, **kwargs):
    """Make a request and validate the response."""
    url = f"{BASE_URL}{path}"
    try:
        resp = requests.request(method, url, timeout=10, **kwargs)
        if resp.status_code == expected_status:
            print(f"  [PASS] {name} ({resp.status_code})")
            return resp.json() if resp.text else {}
        else:
            print(f"  [FAIL] {name} - Expected {expected_status}, got {resp.status_code}")
            print(f"         Response: {resp.text[:200]}")
            return None
    except Exception as e:
        print(f"  [FAIL] {name} - {e}")
        return None

def main():
    print("=" * 50)
    print("Music Funnel AI - Backend API Tests")
    print("=" * 50)
    print()

    # Check if server is running
    print("Checking if backend is running...")
    try:
        requests.get(f"{BASE_URL}/api/health", timeout=2)
    except requests.ConnectionError:
        print("  [ERROR] Backend is not running!")
        print()
        print("Start it with:")
        print("  cd backend")
        print("  source venv/bin/activate")
        print("  uvicorn main:app --reload --port 8000")
        print()
        sys.exit(1)

    # Run tests
    print("Running tests...")
    print()

    # 1. Health check
    check("Health Check", "GET", "/api/health")

    # 2. API root
    check("API Root", "GET", "/api")

    # 3. Config
    config = check("Get Config", "GET", "/api/config")
    if config:
        print(f"         Models: {len(config.get('models', []))} available")

    # 4. Manual scan
    leads = check("Manual Scan", "GET", "/api/scan?mode=manual")
    if leads:
        print(f"         Leads: {len(leads)}")
        hot = sum(1 for l in leads if l["score"]["tier"] == "HOT")
        warm = sum(1 for l in leads if l["score"]["tier"] == "WARM")
        cold = sum(1 for l in leads if l["score"]["tier"] == "COLD")
        print(f"         Tiers: {hot} HOT, {warm} WARM, {cold} COLD")

    # 5. AI scan (no key - should still work but no insights)
    leads_ai = check("AI Scan (no key)", "GET", "/api/scan?mode=ai")
    if leads_ai:
        insights = sum(1 for l in leads_ai if l["score"].get("ai_insight"))
        print(f"         Insights generated: {insights}")

    # 6. AI scan with custom model
    check("AI Scan (custom model)", "GET", "/api/scan?mode=ai&model=gemini-1.5-pro")

    # 7. Scan with API key header
    check("Scan with API Key Header", "GET", "/api/scan?mode=manual",
          headers={"X-API-Key": "test-key-123"})

    print()
    print("=" * 50)
    print("All tests completed!")
    print("=" * 50)

if __name__ == "__main__":
    main()
