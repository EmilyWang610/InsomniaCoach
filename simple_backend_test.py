#!/usr/bin/env python3
"""
Simple Backend API Test for Insomnia Coach
Quick test to verify your backend is working
"""

import requests
import json
from datetime import datetime, timedelta

# Configuration
BASE_URL = "http://127.0.0.1:8000"

def test_health():
    """Test if backend is running"""
    try:
        response = requests.get(f"{BASE_URL}/health", timeout=10)
        if response.status_code == 200:
            print("✅ Backend is running!")
            print(f"   Response: {response.json()}")
            return True
        else:
            print(f"❌ Backend returned status {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Cannot connect to backend: {e}")
        return False

def create_user():
    """Create a test user"""
    try:
        user_data = {
            "preferences": {
                "sleepGoal": 8,
                "wakeTime": "2024-01-15T07:00:00Z",  # Full datetime format
                "bedtime": "2024-01-15T23:00:00Z",   # Full datetime format
                "notifications": True
            }
        }
        
        response = requests.post(f"{BASE_URL}/api/users", json=user_data, timeout=10)
        if response.status_code == 200:
            data = response.json()
            user_id = data.get("id")
            print(f"✅ User created! ID: {user_id}")
            return user_id
        else:
            print(f"❌ User creation failed: {response.status_code}")
            print(f"   Response: {response.text}")
            return None
    except Exception as e:
        print(f"❌ User creation error: {e}")
        return None

def send_night_data(user_id):
    """Send mock night data to backend"""
    try:
        now = datetime.now()
        night_date = now.strftime("%Y-%m-%d")
        start_time = now - timedelta(hours=8)
        
        # Create the exact structure your backend expects with ISO strings
        night_data = {
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
                },
                {
                    "stageType": "asleepCore", 
                    "startTime": (start_time + timedelta(minutes=5)).isoformat() + "Z",
                    "endTime": (start_time + timedelta(hours=1, minutes=30)).isoformat() + "Z"
                },
                {
                    "stageType": "asleepDeep",
                    "startTime": (start_time + timedelta(hours=1, minutes=30)).isoformat() + "Z",
                    "endTime": (start_time + timedelta(hours=2, minutes=30)).isoformat() + "Z"
                },
                {
                    "stageType": "asleepREM",
                    "startTime": (start_time + timedelta(hours=2, minutes=30)).isoformat() + "Z",
                    "endTime": now.isoformat() + "Z"
                }
            ],
            "vitals": [
                {
                    "timestamp": start_time.isoformat() + "Z",
                    "heartRate": 65.0,
                    "hrvSdnn": 45.0,
                    "respiratoryRate": 16.0,
                    "bloodOxygen": 98.0
                },
                {
                    "timestamp": now.isoformat() + "Z",
                    "heartRate": 70.0,
                    "hrvSdnn": 50.0,
                    "respiratoryRate": 18.0,
                    "bloodOxygen": 97.0
                }
            ]
        }
        
        response = requests.post(f"{BASE_URL}/api/nights/ingest", json=night_data, timeout=10)
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Night data sent! Night ID: {data.get('nightId')}")
            print(f"   Ready for analysis: {data.get('readyForAnalysis', data.get('ready_for_use', False))}")
            if 'agent_analysis' in data:
                agent = data['agent_analysis']
                print(f"   Agent analysis: {'✅ Success' if agent.get('success') else '❌ Failed'}")
                if agent.get('success'):
                    print(f"   Plan ID: {agent.get('plan_id')}")
                    print(f"   Report ID: {agent.get('report_id')}")
            return True
        else:
            print(f"❌ Night data failed: {response.status_code}")
            print(f"   Response: {response.text}")
            return False
    except Exception as e:
        print(f"❌ Night data error: {e}")
        return False

def trigger_agent_analysis(user_id):
    """Trigger AI agent analysis"""
    try:
        night_date = datetime.now().strftime("%Y-%m-%d")
        response = requests.post(
            f"{BASE_URL}/api/users/{user_id}/agent/analyze",
            params={"night_date": night_date},
            timeout=30
        )
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Agent analysis triggered!")
            print(f"   Report ID: {data.get('reportId')}")
            print(f"   Plan ID: {data.get('planId')}")
            print(f"   Loop IDs: {data.get('loopIds')}")
            return True
        else:
            print(f"❌ Agent analysis failed: {response.status_code}")
            print(f"   Response: {response.text}")
            return False
    except Exception as e:
        print(f"❌ Agent analysis error: {e}")
        return False

def get_latest_plan(user_id):
    """Get the latest adaptive plan"""
    try:
        response = requests.get(f"{BASE_URL}/api/users/{user_id}/agent/plans/latest", timeout=10)
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Got latest plan!")
            print(f"   Plan ID: {data.get('id')}")
            print(f"   Night Date: {data.get('nightDate')}")
            print(f"   Blocks: {len(data.get('blocks', []))}")
            print(f"   Summary: {data.get('summary', '')[:100]}...")
            
            # Show plan blocks
            for i, block in enumerate(data.get('blocks', [])[:3]):  # Show first 3 blocks
                print(f"   Block {i+1}: {block.get('title', 'N/A')} ({block.get('duration', 0)}s)")
            
            return True
        else:
            print(f"❌ Get plan failed: {response.status_code}")
            print(f"   Response: {response.text}")
            return False
    except Exception as e:
        print(f"❌ Get plan error: {e}")
        return False

def main():
    """Run the complete test"""
    print("🔬 Insomnia Coach Backend Test")
    print("=" * 40)
    
    # Step 1: Check if backend is running
    print("\n1. Testing backend health...")
    if not test_health():
        print("❌ Backend is not running. Please start your backend first.")
        return
    
    # Step 2: Create user
    print("\n2. Creating test user...")
    user_id = create_user()
    if not user_id:
        print("❌ Cannot create user. Stopping test.")
        return
    
    # Step 3: Send night data
    print("\n3. Sending night data...")
    if not send_night_data(user_id):
        print("❌ Cannot send night data. Stopping test.")
        return
    
    # Step 4: Wait a moment
    print("\n4. Waiting for backend processing...")
    import time
    time.sleep(3)
    
    # Step 5: Trigger agent analysis
    print("\n5. Triggering AI agent analysis...")
    if not trigger_agent_analysis(user_id):
        print("❌ Agent analysis failed. Stopping test.")
        return
    
    # Step 6: Wait for analysis
    print("\n6. Waiting for AI analysis...")
    time.sleep(5)
    
    # Step 7: Get the plan
    print("\n7. Getting adaptive plan...")
    if not get_latest_plan(user_id):
        print("❌ Cannot get plan. Stopping test.")
        return
    
    print("\n🎉 Test completed successfully!")
    print("Your backend is working correctly!")

if __name__ == "__main__":
    main()
