#!/usr/bin/env python3
"""
Integration test for SilentSOS backend services.
Tests /classify_text and optionally /transcribe endpoints.
Requires backend_inference to be running (e.g., python backend_inference/app.py).
"""

import requests
import json
import sys

BACKEND_URL = "http://localhost:8000"

def test_classify_text():
    """Test /classify_text endpoint with various inputs."""
    endpoint = f"{BACKEND_URL}/classify_text"
    print(f"\n=== Testing {endpoint} ===")
    
    test_cases = [
        ("I fell down the stairs", "fall"),
        ("Help me I'm bleeding", "injury"),
        ("I'm scared and panicking", "panic"),
        ("I'm safe and feeling good", "safe"),
        ("Just a normal message", "safe"),
    ]
    
    for text, expected_label in test_cases:
        try:
            resp = requests.post(endpoint, json={"text": text}, timeout=10)
            if resp.status_code == 200:
                result = resp.json()
                label = result.get("label", "unknown")
                score = result.get("score", 0.0)
                fallback = result.get("fallback", False)
                status = "✓" if label == expected_label else "✗"
                fallback_note = " (fallback)" if fallback else ""
                print(f"{status} '{text[:40]}...' → {label} ({score:.2f}){fallback_note}")
            else:
                print(f"✗ '{text[:40]}...' → HTTP {resp.status_code}: {resp.text}")
        except Exception as e:
            print(f"✗ '{text[:40]}...' → Error: {e}")

def test_health():
    """Test basic health endpoint."""
    print(f"\n=== Testing backend health ===")
    try:
        resp = requests.get(f"{BACKEND_URL}/", timeout=5)
        if resp.status_code == 200:
            print(f"✓ Backend is running: {resp.text}")
            return True
        else:
            print(f"✗ Backend returned {resp.status_code}")
            return False
    except Exception as e:
        print(f"✗ Backend unreachable: {e}")
        return False

def main():
    print("SilentSOS Backend Integration Test")
    print("=" * 50)
    
    # Check if backend is running
    if not test_health():
        print("\nERROR: Backend is not running. Start it with:")
        print("  cd backend_inference")
        print("  python -m venv .venv")
        print("  source .venv/bin/activate  # or .venv\\Scripts\\Activate.ps1 on Windows")
        print("  pip install -r requirements.txt")
        print("  python app.py")
        sys.exit(1)
    
    # Run tests
    test_classify_text()
    
    print("\n" + "=" * 50)
    print("Integration test complete!")

if __name__ == "__main__":
    main()
