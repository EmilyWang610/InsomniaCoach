#!/usr/bin/env python3
"""
Simplified Suno API Integration Test
===================================

This script tests the complete flow up to Suno API calls:
1. Mocks night data ingestion
2. Triggers agent analysis
3. Extracts timing and LLM prompts from the plan
4. Shows what would be sent to Suno API

Usage: python3 test_suno_simple.py
"""

import requests
import json
import time
import os
from datetime import datetime, timedelta
import uuid

# Configuration
BASE_URL = 'http://127.0.0.1:8000'
SUNO_API_KEY = '7e74d019b8be4c558e17660a807cf1d8'
SUNO_BASE_URL = 'https://studio-api.prod.suno.com/api/v2/external/hackmit'
TIMEOUT = 30

class SimpleSunoTester:
    def __init__(self):
        self.session = requests.Session()
        self.user_id = None
        
    def log_test(self, test_name, success, message, details="", duration=0):
        """Log test results with formatting"""
        status = "✅ PASS" if success else "❌ FAIL"
        duration_str = f" ({duration:.2f}s)" if duration > 0 else ""
        print(f"{status} {test_name}{duration_str}")
        print(f"   {message}")
        if details:
            print(f"   Details: {details}")
        print()
    
    def create_user(self):
        """Create a test user"""
        start_time = time.time()
        
        try:
            response = self.session.post(
                f"{BASE_URL}/api/users",
                json={"name": "Suno Test User"},
                timeout=TIMEOUT
            )
            
            duration = time.time() - start_time
            success = response.status_code == 200
            
            if success:
                data = response.json()
                self.user_id = data.get("id")
                self.log_test(
                    "User Creation",
                    success,
                    f"User created successfully",
                    f"User ID: {self.user_id}",
                    duration
                )
                return True
            else:
                self.log_test(
                    "User Creation",
                    success,
                    f"User creation failed with status {response.status_code}",
                    response.text,
                    duration
                )
                return False
                
        except Exception as e:
            duration = time.time() - start_time
            self.log_test(
                "User Creation",
                False,
                f"Exception: {str(e)}",
                "",
                duration
            )
            return False
    
    def create_mock_night_data(self):
        """Create realistic mock night data for testing"""
        print("🌙 Creating mock night data...")
        
        now = datetime.now()
        night_date = now.strftime("%Y-%m-%d")
        start_time = now - timedelta(hours=8)
        
        # Create sleep stages with proper format
        stages = [
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
                "endTime": (start_time + timedelta(hours=3, minutes=30)).isoformat() + "Z"
            },
            {
                "stageType": "asleepCore",
                "startTime": (start_time + timedelta(hours=3, minutes=30)).isoformat() + "Z",
                "endTime": (start_time + timedelta(hours=6, minutes=30)).isoformat() + "Z"
            },
            {
                "stageType": "asleepREM",
                "startTime": (start_time + timedelta(hours=6, minutes=30)).isoformat() + "Z",
                "endTime": (start_time + timedelta(hours=7, minutes=30)).isoformat() + "Z"
            },
            {
                "stageType": "awake",
                "startTime": (start_time + timedelta(hours=7, minutes=30)).isoformat() + "Z",
                "endTime": now.isoformat() + "Z"
            }
        ]
        
        # Create vital data
        vitals = [
            {
                "timestamp": start_time.isoformat() + "Z",
                "heartRate": 65.0,
                "hrvSdnn": 45.0,
                "respiratoryRate": 16.0,
                "bloodOxygen": 98.0
            },
            {
                "timestamp": (start_time + timedelta(hours=2)).isoformat() + "Z",
                "heartRate": 58.0,
                "hrvSdnn": 52.0,
                "respiratoryRate": 14.0,
                "bloodOxygen": 97.0
            },
            {
                "timestamp": (start_time + timedelta(hours=4)).isoformat() + "Z",
                "heartRate": 55.0,
                "hrvSdnn": 48.0,
                "respiratoryRate": 13.0,
                "bloodOxygen": 96.0
            },
            {
                "timestamp": (start_time + timedelta(hours=6)).isoformat() + "Z",
                "heartRate": 62.0,
                "hrvSdnn": 50.0,
                "respiratoryRate": 15.0,
                "bloodOxygen": 97.0
            },
            {
                "timestamp": now.isoformat() + "Z",
                "heartRate": 70.0,
                "hrvSdnn": 45.0,
                "respiratoryRate": 18.0,
                "bloodOxygen": 98.0
            }
        ]
        
        # Create the proper night data structure
        night_data = {
            "userId": self.user_id,
            "nightDateLocal": night_date,  # Required by backend
            "date": now.isoformat() + "Z",
            "sleepStartTime": start_time.isoformat() + "Z",
            "sleepEndTime": now.isoformat() + "Z",
            "totalSleepDuration": 28800.0,  # 8 hours in seconds
            "sleepEfficiency": 0.85,
            "awakeningCount": 2,
            "stages": stages,
            "vitals": vitals
        }
        
        return night_data
    
    def ingest_night_data(self, night_data):
        """Ingest night data to backend"""
        start_time = time.time()
        
        try:
            response = self.session.post(
                f"{BASE_URL}/api/nights/ingest",
                json=night_data,
                timeout=TIMEOUT
            )
            
            duration = time.time() - start_time
            success = response.status_code == 200
            
            if success:
                data = response.json()
                night_id = data.get('nightId', 'N/A')
                ready_for_analysis = data.get('ready_for_analysis', False)
                
                self.log_test(
                    "Night Data Ingestion",
                    success,
                    f"Night ID: {night_id}, Ready for Analysis: {ready_for_analysis}",
                    f"Status: {response.status_code}",
                    duration
                )
                return night_id
            else:
                self.log_test(
                    "Night Data Ingestion",
                    success,
                    f"Failed with status {response.status_code}",
                    response.text,
                    duration
                )
                return None
                
        except Exception as e:
            duration = time.time() - start_time
            self.log_test(
                "Night Data Ingestion",
                False,
                f"Exception: {str(e)}",
                "",
                duration
            )
            return None
    
    def trigger_agent_analysis(self):
        """Trigger agent analysis to generate sleep plan"""
        start_time = time.time()
        
        try:
            # Get today's date for the analysis
            today = datetime.now().strftime("%Y-%m-%d")
            response = self.session.post(
                f"{BASE_URL}/api/users/{self.user_id}/agent/analyze?night_date={today}",
                timeout=TIMEOUT
            )
            
            duration = time.time() - start_time
            success = response.status_code == 200
            
            if success:
                data = response.json()
                report_id = data.get('report_id', 'N/A')
                plan_id = data.get('plan_id', 'N/A')
                loop_ids = data.get('loop_ids', [])
                
                self.log_test(
                    "Agent Analysis",
                    success,
                    f"Report ID: {report_id}, Plan ID: {plan_id}, Loop IDs: {len(loop_ids)} loops",
                    f"Status: {response.status_code}",
                    duration
                )
                return plan_id
            else:
                self.log_test(
                    "Agent Analysis",
                    success,
                    f"Failed with status {response.status_code}",
                    response.text,
                    duration
                )
                return None
                
        except Exception as e:
            duration = time.time() - start_time
            self.log_test(
                "Agent Analysis",
                False,
                f"Exception: {str(e)}",
                "",
                duration
            )
            return None
    
    def get_latest_plan(self):
        """Get the latest generated plan with blocks and prompts"""
        try:
            response = self.session.get(
                f"{BASE_URL}/api/users/{self.user_id}/agent/plans/latest",
                timeout=TIMEOUT
            )
            
            if response.status_code == 200:
                return response.json()
            else:
                print(f"❌ Failed to get plan: {response.status_code}")
                print(f"Response: {response.text}")
                return None
                
        except Exception as e:
            print(f"❌ Exception getting plan: {str(e)}")
            return None
    
    def extract_audio_blocks(self, plan):
        """Extract timing and prompts from plan blocks"""
        if not plan or 'blocks' not in plan:
            print("❌ No blocks found in plan")
            return []
        
        blocks = plan['blocks']
        audio_blocks = []
        
        print(f"\n🎵 Extracting {len(blocks)} audio blocks from plan...")
        print("=" * 60)
        
        for i, block in enumerate(blocks, 1):
            # Calculate duration in seconds
            start_minute = block.get('startMinute', 0)
            end_minute = block.get('endMinute', 0)
            duration_seconds = (end_minute - start_minute) * 60
            duration_minutes = end_minute - start_minute
            
            # Extract LLM prompt
            llm_prompt = block.get('llmPrompt', '')
            
            # Extract other relevant data
            music_type = block.get('musicType', 'unknown')
            target_stage = block.get('targetSleepStage', 'unknown')
            volume = block.get('targetVolume', 0.5)
            frequency_range = block.get('frequencyRange', {})
            binaural_beat = block.get('binauralBeatFreq')
            
            audio_block = {
                'block_id': block.get('id', f'block-{i}'),
                'block_index': i,
                'music_type': music_type,
                'target_stage': target_stage,
                'start_minute': start_minute,
                'end_minute': end_minute,
                'duration_seconds': duration_seconds,
                'duration_minutes': duration_minutes,
                'llm_prompt': llm_prompt,
                'volume': volume,
                'frequency_range': frequency_range,
                'binaural_beat_freq': binaural_beat,
                'audio_loop_id': block.get('audioLoopId', f'loop-{i}')
            }
            
            audio_blocks.append(audio_block)
            
            print(f"Block {i}: {music_type} ({target_stage})")
            print(f"  ├─ Duration: {duration_minutes} minutes ({duration_seconds} seconds)")
            print(f"  ├─ Time: {start_minute}-{end_minute} minutes")
            print(f"  ├─ Volume: {volume}")
            print(f"  ├─ Frequency: {frequency_range}")
            print(f"  ├─ Binaural Beat: {binaural_beat} Hz" if binaural_beat else "  ├─ Binaural Beat: None")
            print(f"  └─ Prompt: \"{llm_prompt[:100]}{'...' if len(llm_prompt) > 100 else ''}\"")
            print()
        
        return audio_blocks
    
    def create_suno_requests(self, audio_blocks):
        """Create Suno API requests for each block"""
        print(f"\n🎵 Creating Suno API requests for {len(audio_blocks)} blocks...")
        print("=" * 60)
        
        suno_requests = []
        
        for i, block in enumerate(audio_blocks, 1):
            print(f"\n🎵 Suno Request {i}/{len(audio_blocks)}: {block['music_type']}")
            
            # Create enhanced prompt for Suno
            enhanced_prompt = self.create_enhanced_prompt(block)
            
            # Limit duration for Suno (max 5 minutes per request)
            duration_seconds = min(block['duration_seconds'], 300)
            
            # Create Suno API request (using simple mode)
            suno_request = {
                'topic': enhanced_prompt,
                'tags': 'ambient, sleep, relaxation, binaural, instrumental',
                'make_instrumental': True
            }
            
            suno_requests.append({
                'block': block,
                'suno_request': suno_request,
                'original_duration': block['duration_seconds'],
                'suno_duration': duration_seconds
            })
            
            print(f"   📝 Topic: \"{enhanced_prompt[:150]}{'...' if len(enhanced_prompt) > 150 else ''}\"")
            print(f"   ⏱️  Duration: {duration_seconds} seconds (original: {block['duration_seconds']} seconds)")
            print(f"   🎵 Instrumental: {suno_request['make_instrumental']}")
            print(f"   🏷️  Tags: {suno_request['tags']}")
            
            # Show the full JSON request
            print(f"   📋 Full Request JSON:")
            print(f"   {json.dumps(suno_request, indent=4)}")
        
        return suno_requests
    
    def create_enhanced_prompt(self, block):
        """Create enhanced prompt for Suno API"""
        base_prompt = block['llm_prompt']
        music_type = block['music_type']
        duration_minutes = block['duration_minutes']
        frequency_range = block['frequency_range']
        binaural_beat = block['binaural_beat_freq']
        
        # Add technical specifications
        enhanced_prompt = f"{base_prompt}"
        
        if music_type:
            enhanced_prompt += f" Style: {music_type}"
        
        if frequency_range and isinstance(frequency_range, dict):
            low = frequency_range.get('low', '')
            high = frequency_range.get('high', '')
            target = frequency_range.get('target', '')
            if low and high:
                enhanced_prompt += f" Frequency range: {low}-{high} Hz"
            if target:
                enhanced_prompt += f" Target frequency: {target} Hz"
        
        if binaural_beat:
            enhanced_prompt += f" Binaural beat: {binaural_beat} Hz"
        
        # Add duration and looping instructions
        if duration_minutes > 5:
            enhanced_prompt += f" Duration: {duration_minutes} minutes. Create seamless loop for continuous playback."
        else:
            enhanced_prompt += f" Duration: {duration_minutes} minutes."
        
        # Add quality and format instructions
        enhanced_prompt += " High quality ambient music, no vocals, consistent tempo and key throughout."
        
        return enhanced_prompt
    
    def run_complete_test(self):
        """Run the complete integration test"""
        print("🚀 SIMPLIFIED SUNO API INTEGRATION TEST")
        print("=" * 50)
        print(f"Base URL: {BASE_URL}")
        print(f"Suno API: {SUNO_BASE_URL}")
        print()
        
        # Step 0: Create user
        print("STEP 0: Creating test user")
        print("-" * 50)
        if not self.create_user():
            print("❌ Cannot proceed without user")
            return False
        
        # Step 1: Create and ingest mock night data
        print("\nSTEP 1: Creating and ingesting mock night data")
        print("-" * 50)
        night_data = self.create_mock_night_data()
        night_id = self.ingest_night_data(night_data)
        
        if not night_id:
            print("❌ Cannot proceed without night data")
            return False
        
        # Step 2: Trigger agent analysis
        print("\nSTEP 2: Triggering agent analysis")
        print("-" * 50)
        plan_id = self.trigger_agent_analysis()
        
        if not plan_id:
            print("❌ Cannot proceed without plan")
            return False
        
        # Step 3: Get latest plan
        print("\nSTEP 3: Getting latest plan")
        print("-" * 50)
        plan = self.get_latest_plan()
        
        if not plan:
            print("❌ Cannot proceed without plan data")
            return False
        
        # Step 4: Extract audio blocks
        print("\nSTEP 4: Extracting audio blocks")
        print("-" * 50)
        audio_blocks = self.extract_audio_blocks(plan)
        
        if not audio_blocks:
            print("❌ No audio blocks found")
            return False
        
        # Step 5: Create Suno requests
        print("\nSTEP 5: Creating Suno API requests")
        print("-" * 50)
        suno_requests = self.create_suno_requests(audio_blocks)
        
        # Step 6: Summary
        print("\nSTEP 6: Test Summary")
        print("-" * 50)
        print(f"✅ Successfully extracted {len(audio_blocks)} audio blocks")
        print(f"✅ Created {len(suno_requests)} Suno API requests")
        
        print(f"\n📋 SUMMARY OF SUNO REQUESTS:")
        print("=" * 50)
        for i, req in enumerate(suno_requests, 1):
            block = req['block']
            suno_req = req['suno_request']
            print(f"\nRequest {i}: {block['music_type']}")
            print(f"  • Block ID: {block['block_id']}")
            print(f"  • Duration: {req['suno_duration']}s (original: {req['original_duration']}s)")
            print(f"  • Prompt: \"{suno_req['prompt'][:100]}{'...' if len(suno_req['prompt']) > 100 else ''}\"")
            print(f"  • Style: {suno_req['style']}")
            print(f"  • Tags: {suno_req['tags']}")
        
        print(f"\n🎯 NEXT STEPS:")
        print("=" * 50)
        print("1. The Suno API requests are ready to be sent")
        print("2. Each request will generate a job ID")
        print("3. You'll need to poll the status endpoint to get the audio")
        print("4. Once completed, download the audio files")
        print("5. Save them to your audio library")
        
        return True

def main():
    """Main function"""
    print("🎵 Simplified Suno API Integration Test")
    print("=" * 40)
    print()
    
    # Check if backend is running
    try:
        response = requests.get(f"{BASE_URL}/health", timeout=5)
        if response.status_code != 200:
            print("❌ Backend is not running. Please start the backend first.")
            return
    except:
        print("❌ Cannot connect to backend. Please start the backend first.")
        return
    
    # Run the test
    tester = SimpleSunoTester()
    success = tester.run_complete_test()
    
    if success:
        print("\n🎉 Test completed successfully!")
        print("🎵 The system is ready to generate music with Suno API!")
    else:
        print("\n❌ Test failed. Check the logs above for details.")

if __name__ == "__main__":
    main()
