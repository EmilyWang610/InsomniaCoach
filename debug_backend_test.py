#!/usr/bin/env python3
"""
Debug Backend API Test - Let's see exactly what's happening
"""

import requests
import json
from datetime import datetime, timedelta

# Configuration
BASE_URL = "http://127.0.0.1:8000"

def test_backend_debug():
    """Debug test to see what's happening with the backend"""
    print("🔬 Debug Backend Test")
    print("=" * 40)
    
    # Step 1: Test health
    print("\n1. Testing health...")
    try:
        response = requests.get(f"{BASE_URL}/health", timeout=10)
        print(f"   Status: {response.status_code}")
        print(f"   Response: {response.json()}")
    except Exception as e:
        print(f"   Error: {e}")
        return
    
    # Step 2: Create user
    print("\n2. Creating user...")
    user_data = {
        "preferences": {
            "sleepGoal": 8,
            "wakeTime": "2024-01-15T07:00:00Z",
            "bedtime": "2024-01-15T23:00:00Z",
            "notifications": True
        }
    }
    
    try:
        response = requests.post(f"{BASE_URL}/api/users", json=user_data, timeout=10)
        print(f"   Status: {response.status_code}")
        if response.status_code == 200:
            user_result = response.json()
            user_id = user_result.get("id")
            print(f"   User ID: {user_id}")
        else:
            print(f"   Error: {response.text}")
            return
    except Exception as e:
        print(f"   Error: {e}")
        return
    
    # Step 3: Test night data with minimal structure
    print("\n3. Testing minimal night data...")
    now = datetime.now()
    night_date = now.strftime("%Y-%m-%d")
    start_time = now - timedelta(hours=8)
    
    # Try the exact structure your backend expects
    minimal_night_data = {
        "userId": user_id,
        "nightDateLocal": night_date,
        "date": now.isoformat() + "Z",
        "sleepStartTime": start_time.isoformat() + "Z",
        "sleepEndTime": now.isoformat() + "Z",
        "totalSleepDuration": 28800.0,
        "sleepEfficiency": 0.85,
        "awakeningCount": 2,
        "stages": [
            {
                "stageType": "awake",
                "startTime": start_time.isoformat() + "Z",
                "endTime": (start_time + timedelta(minutes=5)).isoformat() + "Z"
            }
        ],
        "vitals": [
            {
                "timestamp": start_time.isoformat() + "Z",
                "heartRate": 65.0,
                "hrvSdnn": 45.0,
                "respiratoryRate": 16.0,
                "bloodOxygen": 98.0
            }
        ]
    }
    
    print(f"   Sending data: {json.dumps(minimal_night_data, indent=2)}")
    
    try:
        response = requests.post(f"{BASE_URL}/api/nights/ingest", json=minimal_night_data, timeout=10)
        print(f"   Status: {response.status_code}")
        print(f"   Response: {response.text}")
        
        if response.status_code == 200:
            print("   ✅ Success!")
        else:
            print("   ❌ Failed!")
            
    except Exception as e:
        print(f"   Error: {e}")

if __name__ == "__main__":
    test_backend_debug()
