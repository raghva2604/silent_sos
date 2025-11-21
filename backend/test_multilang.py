#!/usr/bin/env python
"""Test all supported languages for multi-language STT."""

import requests
import json
from pathlib import Path
import base64

# Read the test audio file
audio_file = Path("voice_test.wav")
if not audio_file.exists():
    print("ERROR: voice_test.wav not found")
    exit(1)

audio_bytes = audio_file.read_bytes()
b64 = base64.b64encode(audio_bytes).decode()

# Test all 4 languages
languages = [
    ("en", "English"),
    ("hi", "Hindi"),
    ("te", "Telugu"),
    ("gu", "Gujarati")
]

print("=" * 70)
print("MULTI-LANGUAGE STT TEST SUITE")
print("=" * 70)

results = []
for lang_code, lang_name in languages:
    print(f"\n[TEST] {lang_name} ({lang_code})")
    print("-" * 70)
    
    body = {
        "audio_b64": b64,
        "lang_hint": lang_code
    }
    
    try:
        resp = requests.post(
            "http://127.0.0.1:8000/api/v1/transcribe_and_analyze",
            json=body,
            timeout=30
        )
        
        if resp.status_code == 200:
            data = resp.json()
            provider = data.get("diagnostics", {}).get("transcription_provider")
            transcript = data.get("transcript", "")
            severity = data.get("severity", "N/A")
            
            # Show models tried
            models_tried = data.get("diagnostics", {}).get("models_tried", [])
            print(f"Provider: {provider}")
            print(f"Severity: {severity}")
            print(f"Transcript: {transcript if transcript else '(empty)'}")
            print(f"Models tried: {len(models_tried)}")
            for m in models_tried:
                status = m.get("status", "?")
                code = m.get("code", "?")
                print(f"  - {code}: {status}")
            
            # Overall status
            status_ok = provider == "vosk_multilang" and resp.status_code == 200
            status_str = "PASS" if status_ok else "FAIL"
            print(f"Status: {status_str}")
            results.append((lang_name, status_str))
        else:
            print(f"HTTP {resp.status_code}: {resp.text[:100]}")
            print("Status: FAIL")
            results.append((lang_name, "FAIL"))
    except Exception as e:
        print(f"ERROR: {e}")
        print("Status: FAIL")
        results.append((lang_name, "FAIL"))

print("\n" + "=" * 70)
print("TEST SUMMARY")
print("=" * 70)
for lang, status in results:
    symbol = "✓" if status == "PASS" else "✗"
    print(f"{symbol} {lang:12} {status}")
print("=" * 70)
