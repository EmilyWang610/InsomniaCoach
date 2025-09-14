#!/usr/bin/env python3
"""
Backend API Test Script for Insomnia Coach
Tests all endpoints and the complete night data processing pipeline
"""

import requests
import json
import time
from datetime import datetime, timedelta
from typing import Dict, Any, List
import uuid

# Configuration
BASE_URL = "http://127.0.0.1:8000"
TIMEOUT = 30

class BackendAPITester:
    def __init__(self, base_url: str = BASE_URL):
        self.base_url = base_url
        self.session = requests.Session()
        self.user_id = None
        self.test_results = []
        
    def log_test(self, test_name: str, success: bool, message: str, details: str = "", duration: float = 0.0):
        """Log test results"""
        status = "✅ PASS" if success else "❌ FAIL"
        print(f"{status} {test_name} ({duration:.2f}s)")
        print(f"   {message}")
        if details:
            print(f"   Details: {details}")
        print()
        
        self.test_results.append({
            "test_name": test_name,
            "success": success,
            "message": message,
            "details": details,
            "duration": duration
        })
    
    def test_health_check(self) -> bool:
        """Test GET /health endpoint"""
        start_time = time.time()
        try:
            response = self.session.get(f"{self.base_url}/health", timeout=TIMEOUT)
            duration = time.time() - start_time
            
            if response.status_code == 200:
                data = response.json()
                self.log_test(
                    "Health Check",
                    True,
                    "Backend is healthy",
                    f"Status: {data.get('status', 'unknown')}",
                    duration
                )
                return True
            else:
                self.log_test(
                    "Health Check",
                    False,
                    f"Health check failed with status {response.status_code}",
                    f"Response: {response.text}",
                    duration
                )
                return False
        except Exception as e:
            duration = time.time() - start_time
            self.log_test(
                "Health Check",
                False,
                f"Health check failed: {str(e)}",
                "",
                duration
            )
            return False
    
    def test_user_creation(self) -> bool:
        """Test POST /api/users endpoint"""
        start_time = time.time()
        try:
            user_data = {
                "preferences": {
                    "sleepGoal": 8,
                    "wakeTime": "2024-01-15T07:00:00Z",  # Full datetime format
                    "bedtime": "2024-01-15T23:00:00Z",   # Full datetime format
                    "notifications": True
                }
            }
            
            response = self.session.post(
                f"{self.base_url}/api/users",
                json=user_data,
                timeout=TIMEOUT
            )
            duration = time.time() - start_time
            
            if response.status_code == 200:
                data = response.json()
                self.user_id = data.get("id")
                self.log_test(
                    "User Creation",
                    True,
                    "User created successfully",
                    f"User ID: {self.user_id}",
                    duration
                )
                return True
            else:
                self.log_test(
                    "User Creation",
                    False,
                    f"User creation failed with status {response.status_code}",
                    f"Response: {response.text}",
                    duration
                )
                return False
        except Exception as e:
            duration = time.time() - start_time
            self.log_test(
                "User Creation",
                False,
                f"User creation failed: {str(e)}",
                "",
                duration
            )
            return False
    
    def create_mock_night_data(self) -> Dict[str, Any]:
        """Create mock night data for testing"""
        now = datetime.now()
        night_date = now.strftime("%Y-%m-%d")
        start_time = now - timedelta(hours=8)
        
        # Create sleep stages
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
                "timestamp": now.isoformat() + "Z",
                "heartRate": 70.0,
                "hrvSdnn": 50.0,
                "respiratoryRate": 18.0,
                "bloodOxygen": 97.0
            }
        ]
        
        return {
            "userId": self.user_id,
            "nightDateLocal": night_date,  # Required by your backend
            "date": now.isoformat() + "Z",
            "sleepStartTime": start_time.isoformat() + "Z",
            "sleepEndTime": now.isoformat() + "Z",
            "totalSleepDuration": 28800.0,  # 8 hours in seconds
            "sleepEfficiency": 0.85,
            "awakeningCount": 2,
            "stages": stages,
            "vitals": vitals
        }
    
    def test_night_ingestion(self) -> bool:
        """Test POST /api/nights/ingest endpoint"""
        if not self.user_id:
            self.log_test("Night Ingestion", False, "No user ID available", "")
            return False
            
        start_time = time.time()
        try:
            night_data = self.create_mock_night_data()
            
            response = self.session.post(
                f"{self.base_url}/api/nights/ingest",
                json=night_data,
                timeout=TIMEOUT
            )
            duration = time.time() - start_time
            
            if response.status_code == 200:
                data = response.json()
                self.log_test(
                    "Night Ingestion",
                    data.get("success", False),
                    data.get("message", "Night data ingested"),
                    f"Night ID: {data.get('nightId', 'N/A')}, Ready for Analysis: {data.get('ready_for_analysis', False)}",
                    duration
                )
                return data.get("success", False)
            else:
                self.log_test(
                    "Night Ingestion",
                    False,
                    f"Night ingestion failed with status {response.status_code}",
                    f"Response: {response.text}",
                    duration
                )
                return False
        except Exception as e:
            duration = time.time() - start_time
            self.log_test(
                "Night Ingestion",
                False,
                f"Night ingestion failed: {str(e)}",
                "",
                duration
            )
            return False
    
    def test_agent_analysis(self) -> bool:
        """Test POST /api/users/{user_id}/agent/analyze endpoint"""
        if not self.user_id:
            self.log_test("Agent Analysis", False, "No user ID available", "")
            return False
            
        start_time = time.time()
        try:
            night_date = datetime.now().strftime("%Y-%m-%d")
            
            response = self.session.post(
                f"{self.base_url}/api/users/{self.user_id}/agent/analyze",
                params={"night_date": night_date},
                timeout=TIMEOUT
            )
            duration = time.time() - start_time
            
            if response.status_code == 200:
                data = response.json()
                
                # Get the full analysis content from the latest plan
                plan_id = data.get('plan_id')
                analysis_content = ""
                if plan_id:
                    try:
                        plan_response = self.session.get(
                            f"{self.base_url}/api/users/{self.user_id}/agent/plans/latest",
                            timeout=TIMEOUT
                        )
                        if plan_response.status_code == 200:
                            plan_data = plan_response.json()
                            analysis_content = plan_data.get('sleepAnalysisData', '')
                            
                            # Also get enhanced metadata if available
                            enhanced_metadata = plan_data.get('enhanced_metadata', {})
                            if enhanced_metadata:
                                sleep_score = enhanced_metadata.get('sleep_score', 'N/A')
                                sleep_efficiency = enhanced_metadata.get('sleep_efficiency', 'N/A')
                                total_sleep = enhanced_metadata.get('total_sleep_minutes', 'N/A')
                                awakenings = enhanced_metadata.get('awakening_count', 'N/A')
                                
                                analysis_content += f"\n\n📊 SLEEP METRICS:\n"
                                analysis_content += f"• Sleep Score: {sleep_score}/100\n"
                                analysis_content += f"• Sleep Efficiency: {sleep_efficiency}%\n"
                                analysis_content += f"• Total Sleep: {total_sleep} minutes\n"
                                analysis_content += f"• Awakenings: {awakenings}\n"
                                
                                # Add detailed music notes
                                detailed_notes = enhanced_metadata.get('detailed_notes', [])
                                if detailed_notes:
                                    analysis_content += f"\n🎵 MUSIC GENERATION NOTES:\n"
                                    for i, note in enumerate(detailed_notes, 1):
                                        analysis_content += f"• {note}\n"
                    except Exception as e:
                        analysis_content = f"Could not fetch detailed analysis: {str(e)}"
                
                self.log_test(
                    "Agent Analysis",
                    data.get("success", False),
                    data.get("success", False) and "Agent analysis completed" or "Agent analysis failed",
                    f"Report ID: {data.get('report_id', 'N/A')}, Plan ID: {data.get('plan_id', 'N/A')}, Loop IDs: {len(data.get('loop_ids', []))} loops",
                    duration
                )
                
                # Display the full analysis content
                if analysis_content:
                    print(f"\n{'='*60}")
                    print("🧠 FULL AI SLEEP ANALYSIS")
                    print(f"{'='*60}")
                    print(analysis_content)
                    print(f"{'='*60}\n")
                
                return data.get("success", False)
            else:
                self.log_test(
                    "Agent Analysis",
                    False,
                    f"Agent analysis failed with status {response.status_code}",
                    f"Response: {response.text}",
                    duration
                )
                return False
        except Exception as e:
            duration = time.time() - start_time
            self.log_test(
                "Agent Analysis",
                False,
                f"Agent analysis failed: {str(e)}",
                "",
                duration
            )
            return False
    
    def test_get_latest_plan(self) -> bool:
        """Test GET /api/users/{user_id}/agent/plans/latest endpoint"""
        if not self.user_id:
            self.log_test("Get Latest Plan", False, "No user ID available", "")
            return False
            
        start_time = time.time()
        try:
            response = self.session.get(
                f"{self.base_url}/api/users/{self.user_id}/agent/plans/latest",
                timeout=TIMEOUT
            )
            duration = time.time() - start_time
            
            if response.status_code == 200:
                data = response.json()
                blocks_count = len(data.get("blocks", []))
                self.log_test(
                    "Get Latest Plan",
                    True,
                    "Latest plan retrieved successfully",
                    f"Plan ID: {data.get('id', 'N/A')}, Blocks: {blocks_count}, Summary: {data.get('summary', 'N/A')[:100]}...",
                    duration
                )
                return True
            else:
                self.log_test(
                    "Get Latest Plan",
                    False,
                    f"Get latest plan failed with status {response.status_code}",
                    f"Response: {response.text}",
                    duration
                )
                return False
        except Exception as e:
            duration = time.time() - start_time
            self.log_test(
                "Get Latest Plan",
                False,
                f"Get latest plan failed: {str(e)}",
                "",
                duration
            )
            return False
    
    def test_get_all_plans(self) -> bool:
        """Test GET /api/users/{user_id}/plans endpoint"""
        if not self.user_id:
            self.log_test("Get All Plans", False, "No user ID available", "")
            return False
            
        start_time = time.time()
        try:
            response = self.session.get(
                f"{self.base_url}/api/users/{self.user_id}/plans",
                timeout=TIMEOUT
            )
            duration = time.time() - start_time
            
            if response.status_code == 200:
                data = response.json()
                plans_count = len(data) if isinstance(data, list) else 0
                self.log_test(
                    "Get All Plans",
                    True,
                    f"Retrieved {plans_count} plans",
                    f"Plans: {[plan.get('id', 'N/A') for plan in data[:3]]}..." if plans_count > 3 else f"Plans: {[plan.get('id', 'N/A') for plan in data]}",
                    duration
                )
                return True
            else:
                self.log_test(
                    "Get All Plans",
                    False,
                    f"Get all plans failed with status {response.status_code}",
                    f"Response: {response.text}",
                    duration
                )
                return False
        except Exception as e:
            duration = time.time() - start_time
            self.log_test(
                "Get All Plans",
                False,
                f"Get all plans failed: {str(e)}",
                "",
                duration
            )
            return False
    
    def test_agent_status(self) -> bool:
        """Test GET /api/users/{user_id}/agent/status endpoint"""
        if not self.user_id:
            self.log_test("Agent Status", False, "No user ID available", "")
            return False
            
        start_time = time.time()
        try:
            response = self.session.get(
                f"{self.base_url}/api/users/{self.user_id}/agent/status",
                timeout=TIMEOUT
            )
            duration = time.time() - start_time
            
            if response.status_code == 200:
                data = response.json()
                features = data.get("features", {})
                self.log_test(
                    "Agent Status",
                    True,
                    "Agent status retrieved successfully",
                    f"Ready: {data.get('ready', False)}, OpenAI: {data.get('openaiConfigured', False)}, Suno Stub: {features.get('sunoStub', False)}",
                    duration
                )
                return True
            else:
                self.log_test(
                    "Agent Status",
                    False,
                    f"Get agent status failed with status {response.status_code}",
                    f"Response: {response.text}",
                    duration
                )
                return False
        except Exception as e:
            duration = time.time() - start_time
            self.log_test(
                "Agent Status",
                False,
                f"Get agent status failed: {str(e)}",
                "",
                duration
            )
            return False
    
    def test_complete_pipeline(self) -> bool:
        """Test the complete night data processing pipeline"""
        print("🚀 Testing Complete Pipeline...")
        print("=" * 50)
        
        # Step 1: Health Check
        if not self.test_health_check():
            return False
        
        # Step 2: Create User
        if not self.test_user_creation():
            return False
        
        # Step 3: Ingest Night Data
        if not self.test_night_ingestion():
            return False
        
        # Step 4: Wait for processing
        print("⏳ Waiting for backend processing...")
        time.sleep(3)
        
        # Step 5: Trigger Agent Analysis
        if not self.test_agent_analysis():
            return False
        
        # Step 6: Wait for analysis
        print("⏳ Waiting for AI analysis...")
        time.sleep(5)
        
        # Step 7: Get Latest Plan
        if not self.test_get_latest_plan():
            return False
        
        # Step 8: Get All Plans
        if not self.test_get_all_plans():
            return False
        
        # Step 9: Check Agent Status
        if not self.test_agent_status():
            return False
        
        print("🎉 Complete Pipeline Test Finished!")
        return True
    
    def run_all_tests(self):
        """Run all individual tests"""
        print("🧪 Running All Backend API Tests...")
        print("=" * 50)
        
        tests = [
            ("Health Check", self.test_health_check),
            ("User Creation", self.test_user_creation),
            ("Night Ingestion", self.test_night_ingestion),
            ("Agent Analysis", self.test_agent_analysis),
            ("Get Latest Plan", self.test_get_latest_plan),
            ("Get All Plans", self.test_get_all_plans),
            ("Agent Status", self.test_agent_status)
        ]
        
        for test_name, test_func in tests:
            test_func()
            time.sleep(1)  # Small delay between tests
        
        print("🎉 All Tests Completed!")
        self.print_summary()
    
    def print_summary(self):
        """Print test summary"""
        total_tests = len(self.test_results)
        passed_tests = sum(1 for result in self.test_results if result["success"])
        failed_tests = total_tests - passed_tests
        
        print("\n" + "=" * 50)
        print("📊 TEST SUMMARY")
        print("=" * 50)
        print(f"Total Tests: {total_tests}")
        print(f"✅ Passed: {passed_tests}")
        print(f"❌ Failed: {failed_tests}")
        print(f"Success Rate: {(passed_tests/total_tests)*100:.1f}%")
        
        if failed_tests > 0:
            print("\n❌ Failed Tests:")
            for result in self.test_results:
                if not result["success"]:
                    print(f"   - {result['test_name']}: {result['message']}")

def main():
    """Main function to run tests"""
    print("🔬 Insomnia Coach Backend API Tester")
    print("=" * 50)
    
    tester = BackendAPITester()
    
    while True:
        print("\nSelect test option:")
        print("1. Run Complete Pipeline Test")
        print("2. Run All Individual Tests")
        print("3. Run Health Check Only")
        print("4. Exit")
        
        choice = input("\nEnter your choice (1-4): ").strip()
        
        if choice == "1":
            tester.test_complete_pipeline()
        elif choice == "2":
            tester.run_all_tests()
        elif choice == "3":
            tester.test_health_check()
        elif choice == "4":
            print("👋 Goodbye!")
            break
        else:
            print("❌ Invalid choice. Please try again.")

if __name__ == "__main__":
    main()
