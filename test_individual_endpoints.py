#!/usr/bin/env python3
"""
Test Individual Backend Endpoints
This tests each endpoint separately to isolate the issue
"""

import requests
import json
from datetime import datetime, timedelta

# Configuration
BASE_URL = "http://127.0.0.1:8000"

def test_health():
    """Test health endpoint"""
    print("1. Testing health endpoint...")
    try:
        response = requests.get(f"{BASE_URL}/health", timeout=10)
        print(f"   Status: {response.status_code}")
        if response.status_code == 200:
            print("   ✅ Health check passed")
            return True
        else:
            print(f"   ❌ Health check failed: {response.text}")
            return False
    except Exception as e:
        print(f"   ❌ Health check error: {e}")
        return False

def test_user_creation():
    """Test user creation"""
    print("\n2. Testing user creation...")
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
            print(f"   ✅ User created successfully: {user_id}")
            return user_id
        else:
            print(f"   ❌ User creation failed: {response.text}")
            return None
    except Exception as e:
        print(f"   ❌ User creation error: {e}")
        return None

def test_agent_status(user_id):
    """Test agent status"""
    print(f"\n3. Testing agent status for user {user_id}...")
    try:
        response = requests.get(f"{BASE_URL}/api/users/{user_id}/agent/status", timeout=10)
        print(f"   Status: {response.status_code}")
        if response.status_code == 200:
            status = response.json()
            print(f"   ✅ Agent status: {status}")
            return True
        else:
            print(f"   ❌ Agent status failed: {response.text}")
            return False
    except Exception as e:
        print(f"   ❌ Agent status error: {e}")
        return False

def test_get_plans(user_id):
    """Test getting plans"""
    print(f"\n4. Testing get plans for user {user_id}...")
    try:
        response = requests.get(f"{BASE_URL}/api/users/{user_id}/plans", timeout=10)
        print(f"   Status: {response.status_code}")
        if response.status_code == 200:
            plans = response.json()
            print(f"   ✅ Plans retrieved: {len(plans)} plans")
            return True
        else:
            print(f"   ❌ Get plans failed: {response.text}")
            return False
    except Exception as e:
        print(f"   ❌ Get plans error: {e}")
        return False

def test_simple_night_data(user_id):
    """Test with minimal night data"""
    print(f"\n5. Testing minimal night data for user {user_id}...")
    
    now = datetime.now()
    night_date = now.strftime("%Y-%m-%d")
    start_time = now - timedelta(hours=8)
    
    # Minimal night data
    minimal_data = {
        "userId": user_id,
        "nightDateLocal": night_date,
        "date": now.isoformat() + "Z",
        "sleepStartTime": start_time.isoformat() + "Z", 
        "sleepEndTime": now.isoformat() + "Z",
        "totalSleepDuration": 28800.0,
        "sleepEfficiency": 0.85,
        "awakeningCount": 2,
        "stages": [],
        "vitals": []
    }
    
    print(f"   Sending minimal data: {json.dumps(minimal_data, indent=2)}")
    
    try:
        response = requests.post(f"{BASE_URL}/api/nights/ingest", json=minimal_data, timeout=10)
        print(f"   Status: {response.status_code}")
        print(f"   Response: {response.text}")
        
        if response.status_code == 200:
            print("   ✅ Minimal night data accepted")
            return True
        else:
            print("   ❌ Minimal night data failed")
            return False
    except Exception as e:
        print(f"   ❌ Minimal night data error: {e}")
        return False

def main():
    """Run all tests"""
    print("🔬 Testing Individual Backend Endpoints")
    print("=" * 50)
    
    # Test 1: Health
    if not test_health():
        print("\n❌ Backend is not running. Please start your backend first.")
        return
    
    # Test 2: User creation
    user_id = test_user_creation()
    if not user_id:
        print("\n❌ Cannot create user. Stopping tests.")
        return
    
    # Test 3: Agent status
    test_agent_status(user_id)
    
    # Test 4: Get plans
    test_get_plans(user_id)
    
    # Test 5: Minimal night data
    test_simple_night_data(user_id)
    
    print("\n🎉 All individual endpoint tests completed!")

if __name__ == "__main__":
    main()
