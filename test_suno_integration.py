#!/usr/bin/env python3
"""
Suno API Integration Test
========================

This script tests the complete flow:
1. Mocks night data ingestion
2. Triggers agent analysis
3. Extracts timing and LLM prompts from the plan
4. Generates audio using Suno API
5. Saves and plays the generated audio

Usage: python3 test_suno_integration.py
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

class SunoIntegrationTester:
    def __init__(self):
        self.session = requests.Session()
        self.user_id = None
        self.generated_audio_files = []
        
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
    
    def generate_suno_audio(self, audio_blocks):
        """Generate audio using Suno API for each block"""
        print(f"\n🎵 Generating audio for {len(audio_blocks)} blocks using Suno API...")
        print("=" * 60)
        
        generated_files = []
        
        for i, block in enumerate(audio_blocks, 1):
            print(f"\n🎵 Generating Block {i}/{len(audio_blocks)}: {block['music_type']}")
            print(f"   Duration: {block['duration_minutes']} minutes")
            print(f"   Prompt: \"{block['llm_prompt'][:80]}{'...' if len(block['llm_prompt']) > 80 else ''}\"")
            
            try:
                # Create enhanced prompt for Suno
                enhanced_prompt = self.create_enhanced_prompt(block)
                
                # Generate audio
                audio_file = self.call_suno_api(enhanced_prompt, block)
                
                if audio_file:
                    generated_files.append({
                        'block': block,
                        'audio_file': audio_file,
                        'success': True
                    })
                    print(f"   ✅ Generated: {audio_file}")
                else:
                    print(f"   ❌ Failed to generate audio")
                    generated_files.append({
                        'block': block,
                        'audio_file': None,
                        'success': False
                    })
                    
            except Exception as e:
                print(f"   ❌ Error: {str(e)}")
                generated_files.append({
                    'block': block,
                    'audio_file': None,
                    'success': False,
                    'error': str(e)
                })
            
            # Add delay to respect rate limits
            if i < len(audio_blocks):
                print(f"   ⏳ Waiting 2 seconds before next generation...")
                time.sleep(2)
        
        return generated_files
    
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
    
    def call_suno_api(self, prompt, block):
        """Call Suno API to generate audio"""
        try:
            # Prepare request
            url = f"{SUNO_BASE_URL}/generate"
            headers = {
                'Authorization': f'Bearer {SUNO_API_KEY}',
                'Content-Type': 'application/json'
            }
            
            # Use topic instead of prompt for simple mode
            data = {
                'topic': prompt,
                'tags': 'ambient, sleep, relaxation, binaural, instrumental',
                'make_instrumental': True
            }
            
            print(f"   📡 Calling Suno API...")
            print(f"   📡 Topic: \"{prompt[:100]}{'...' if len(prompt) > 100 else ''}\"")
            
            # Submit job
            response = requests.post(url, json=data, headers=headers, timeout=30)
            
            if response.status_code == 200:
                job_data = response.json()
                job_id = job_data.get('id')
                
                if job_id:
                    print(f"   📡 Job submitted: {job_id}")
                    return self.poll_suno_job(job_id, block)
                else:
                    print(f"   ❌ No job ID in response")
                    return None
            else:
                print(f"   ❌ API error: {response.status_code}")
                print(f"   Response: {response.text}")
                return None
                
        except Exception as e:
            print(f"   ❌ Exception: {str(e)}")
            return None
    
    def poll_suno_job(self, job_id, block):
        """Poll Suno job until completion"""
        max_attempts = 60  # 5 minutes max
        poll_interval = 5  # 5 seconds
        
        print(f"   ⏳ Polling job {job_id}...")
        
        for attempt in range(1, max_attempts + 1):
            try:
                # Use the correct /clips endpoint
                status_url = f"{SUNO_BASE_URL}/clips?ids={job_id}"
                headers = {'Authorization': f'Bearer {SUNO_API_KEY}'}
                
                response = requests.get(status_url, headers=headers, timeout=10)
                
                if response.status_code == 200:
                    clips_data = response.json()
                    
                    # Response is an array, get the first clip
                    if clips_data and len(clips_data) > 0:
                        clip = clips_data[0]
                        status = clip.get('status')
                        audio_url = clip.get('audio_url')
                        
                        print(f"   ⏳ Attempt {attempt}/{max_attempts}: Status = {status}")
                        
                        if status == 'complete':
                            if audio_url:
                                print(f"   ✅ Job completed! Downloading audio...")
                                return self.download_audio(audio_url, block)
                            else:
                                print(f"   ❌ No audio URL in completed job")
                                return None
                        elif status == 'streaming':
                            if audio_url:
                                print(f"   🎵 Job streaming! Downloading audio...")
                                return self.download_audio(audio_url, block)
                            else:
                                print(f"   ❌ No audio URL in streaming job")
                                return None
                        elif status == 'error':
                            error_message = clip.get('error_message', 'Unknown error')
                            print(f"   ❌ Job failed: {error_message}")
                            return None
                        elif status in ['submitted', 'queued']:
                            if attempt < max_attempts:
                                time.sleep(poll_interval)
                                continue
                            else:
                                print(f"   ❌ Job timed out")
                                return None
                        else:
                            print(f"   ❌ Unknown status: {status}")
                            return None
                    else:
                        print(f"   ❌ No clips data in response")
                        return None
                else:
                    print(f"   ❌ Status check failed: {response.status_code}")
                    print(f"   Response: {response.text}")
                    return None
                    
            except Exception as e:
                print(f"   ❌ Polling error: {str(e)}")
                return None
        
        print(f"   ❌ Polling timed out after {max_attempts} attempts")
        return None
    
    def download_audio(self, audio_url, block):
        """Download generated audio file and save to TrackStore directory with M4A conversion"""
        try:
            print(f"   📥 Downloading from: {audio_url}")
            
            response = requests.get(audio_url, timeout=60)
            
            if response.status_code == 200:
                # Create TrackStore directory structure (matching iOS app)
                trackstore_dir = os.path.expanduser("~/Library/Caches/AudioLibrary")
                os.makedirs(trackstore_dir, exist_ok=True)
                
                # First save as temporary MP3 file
                temp_filename = f"{block['block_id']}.mp3"
                temp_filepath = os.path.join(trackstore_dir, temp_filename)
                
                with open(temp_filepath, 'wb') as f:
                    f.write(response.content)
                
                # Convert to M4A format for iOS compatibility
                final_filename = f"{block['block_id']}.m4a"
                final_filepath = os.path.join(trackstore_dir, final_filename)
                
                conversion_success = self.convert_to_m4a(temp_filepath, final_filepath)
                
                if conversion_success:
                    # Clean up temporary MP3 file
                    os.remove(temp_filepath)
                    file_size = os.path.getsize(final_filepath)
                    print(f"   ✅ Downloaded and converted: {final_filename} ({file_size} bytes)")
                else:
                    # If conversion failed, rename MP3 to M4A (for compatibility)
                    os.rename(temp_filepath, final_filepath)
                    file_size = os.path.getsize(final_filepath)
                    print(f"   ⚠️  Downloaded: {final_filename} (MP3 format, {file_size} bytes)")
                
                print(f"   📁 Saved to: {final_filepath}")
                
                # Also create a JSON entry for the TrackStore index
                track_item = {
                    "id": block['block_id'],
                    "title": f"{block['music_type']} - {block['start_minute']}-{block['end_minute']}min",
                    "createdAt": datetime.now().isoformat() + "Z",
                    "durationSec": block['duration_seconds']
                }
                
                self.generated_audio_files.append({
                    'filepath': final_filepath,
                    'track_item': track_item,
                    'block': block
                })
                return final_filepath
            else:
                print(f"   ❌ Download failed: {response.status_code}")
                return None
                
        except Exception as e:
            print(f"   ❌ Download error: {str(e)}")
            return None
    
    def convert_to_m4a(self, input_path, output_path):
        """Convert audio file to M4A format using ffmpeg"""
        try:
            import subprocess
            result = subprocess.run([
                'ffmpeg', '-i', input_path, '-c:a', 'aac', '-b:a', '256k', 
                '-y', output_path
            ], capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0:
                print(f"   ✅ Successfully converted to M4A: {os.path.basename(output_path)}")
                return True
            else:
                print(f"   ⚠️  FFmpeg conversion failed: {result.stderr}")
                return False
                
        except Exception as e:
            print(f"   ⚠️  FFmpeg conversion error: {e}")
            return False
    
    def run_complete_test(self):
        """Run the complete integration test"""
        print("🚀 SUNO API INTEGRATION TEST")
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
        
        # Step 5: Generate audio with Suno
        print("\nSTEP 5: Generating audio with Suno API")
        print("-" * 50)
        generated_files = self.generate_suno_audio(audio_blocks)
        
        # Step 6: Summary
        print("\nSTEP 6: Test Summary")
        print("-" * 50)
        successful_generations = [f for f in generated_files if f['success']]
        failed_generations = [f for f in generated_files if not f['success']]
        
        print(f"✅ Successful generations: {len(successful_generations)}/{len(generated_files)}")
        print(f"❌ Failed generations: {len(failed_generations)}")
        
        if successful_generations:
            print(f"\n🎵 Generated audio files:")
            for gen in successful_generations:
                block = gen['block']
                file_path = gen['audio_file']
                print(f"   • {block['music_type']} ({block['duration_minutes']} min): {file_path}")
        
        if failed_generations:
            print(f"\n❌ Failed generations:")
            for gen in failed_generations:
                block = gen['block']
                error = gen.get('error', 'Unknown error')
                print(f"   • {block['music_type']}: {error}")
        
        # Create TrackStore index file
        if successful_generations:
            self.create_trackstore_index(successful_generations)
        
        print(f"\n📁 Audio files saved to TrackStore directory")
        print(f"📁 TrackStore location: {os.path.expanduser('~/Library/Caches/AudioLibrary')}")
        
        return len(successful_generations) > 0
    
    def create_trackstore_index(self, successful_generations):
        """Create TrackStore index.json file"""
        try:
            trackstore_dir = os.path.expanduser("~/Library/Caches/AudioLibrary")
            index_file = os.path.join(trackstore_dir, "index.json")
            
            # Create track items for successful generations
            track_items = []
            for gen in successful_generations:
                if 'track_item' in gen:
                    track_items.append(gen['track_item'])
            
            # Write index file
            with open(index_file, 'w') as f:
                json.dump(track_items, f, indent=2)
            
            print(f"✅ Created TrackStore index: {index_file}")
            print(f"📋 Index contains {len(track_items)} track items")
            
        except Exception as e:
            print(f"❌ Failed to create TrackStore index: {str(e)}")

def main():
    """Main function"""
    print("🎵 Suno API Integration Test")
    print("=" * 30)
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
    tester = SunoIntegrationTester()
    success = tester.run_complete_test()
    
    if success:
        print("\n🎉 Test completed successfully!")
        print("🎵 Check the generated audio files in the current directory.")
    else:
        print("\n❌ Test failed. Check the logs above for details.")

if __name__ == "__main__":
    main()
