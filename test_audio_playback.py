#!/usr/bin/env python3
"""
Audio Playback Test
==================

This script tests playing the generated audio files using the system's default audio player.
It verifies that the audio files are properly generated and can be played.

Usage: python3 test_audio_playback.py
"""

import os
import subprocess
import json
import time

def test_audio_playback():
    """Test playing the generated audio files"""
    print("🎵 AUDIO PLAYBACK TEST")
    print("=" * 30)
    
    # TrackStore directory
    trackstore_dir = os.path.expanduser("~/Library/Caches/AudioLibrary")
    index_file = os.path.join(trackstore_dir, "index.json")
    
    # Check if index exists
    if not os.path.exists(index_file):
        print("❌ TrackStore index not found. Run the Suno integration test first.")
        return False
    
    # Load track index
    try:
        with open(index_file, 'r') as f:
            tracks = json.load(f)
        print(f"✅ Loaded {len(tracks)} tracks from TrackStore")
    except Exception as e:
        print(f"❌ Failed to load TrackStore index: {e}")
        return False
    
    # Test each audio file
    for i, track in enumerate(tracks, 1):
        track_id = track['id']
        title = track['title']
        audio_file = os.path.join(trackstore_dir, f"{track_id}.m4a")
        
        print(f"\n🎵 Testing Track {i}: {title}")
        print(f"   File: {audio_file}")
        
        # Check if file exists
        if not os.path.exists(audio_file):
            print(f"   ❌ Audio file not found")
            continue
        
        # Get file size
        file_size = os.path.getsize(audio_file)
        print(f"   📁 File size: {file_size:,} bytes ({file_size/1024/1024:.1f} MB)")
        
        # Test audio file integrity (basic check)
        try:
            # Use file command to check if it's a valid audio file
            result = subprocess.run(['file', audio_file], capture_output=True, text=True)
            if 'audio' in result.stdout.lower() or 'm4a' in result.stdout.lower():
                print(f"   ✅ Valid audio file detected")
            else:
                print(f"   ⚠️  File type: {result.stdout.strip()}")
        except Exception as e:
            print(f"   ⚠️  Could not verify file type: {e}")
        
        # Ask user if they want to play this track
        try:
            response = input(f"   🎵 Play '{title}'? (y/n/q to quit): ").lower().strip()
            
            if response == 'q':
                print("   👋 Stopping playback test")
                break
            elif response == 'y':
                print(f"   🎵 Playing {title}...")
                print(f"   💡 Press Ctrl+C to stop playback")
                
                try:
                    # Use system default audio player
                    subprocess.run(['open', audio_file], check=True)
                    print(f"   ✅ Started playback of {title}")
                    
                    # Wait a bit for user to hear the audio
                    time.sleep(2)
                    
                except KeyboardInterrupt:
                    print(f"   ⏹️  Playback stopped by user")
                except Exception as e:
                    print(f"   ❌ Failed to play audio: {e}")
            else:
                print(f"   ⏭️  Skipping {title}")
                
        except KeyboardInterrupt:
            print(f"\n   👋 Playback test interrupted by user")
            break
    
    print(f"\n🎉 Audio playback test completed!")
    print(f"📁 All audio files are stored in: {trackstore_dir}")
    return True

def show_track_info():
    """Show information about all tracks"""
    print("\n📋 TRACK INFORMATION")
    print("=" * 30)
    
    trackstore_dir = os.path.expanduser("~/Library/Caches/AudioLibrary")
    index_file = os.path.join(trackstore_dir, "index.json")
    
    try:
        with open(index_file, 'r') as f:
            tracks = json.load(f)
        
        for i, track in enumerate(tracks, 1):
            track_id = track['id']
            title = track['title']
            duration = track.get('durationSec', 'Unknown')
            audio_file = os.path.join(trackstore_dir, f"{track_id}.m4a")
            
            file_size = 0
            if os.path.exists(audio_file):
                file_size = os.path.getsize(audio_file)
            
            print(f"\n{i}. {title}")
            print(f"   ID: {track_id}")
            print(f"   Duration: {duration} seconds ({duration/60:.1f} minutes)" if isinstance(duration, (int, float)) else f"   Duration: {duration}")
            print(f"   File: {audio_file}")
            print(f"   Size: {file_size:,} bytes ({file_size/1024/1024:.1f} MB)" if file_size > 0 else "   Size: File not found")
            
    except Exception as e:
        print(f"❌ Failed to load track information: {e}")

def main():
    """Main function"""
    print("🎵 Audio Playback Test for Generated Sleep Music")
    print("=" * 50)
    
    # Show track information first
    show_track_info()
    
    # Ask if user wants to test playback
    try:
        response = input("\n🎵 Would you like to test audio playback? (y/n): ").lower().strip()
        if response == 'y':
            test_audio_playback()
        else:
            print("👋 Skipping playback test")
    except KeyboardInterrupt:
        print("\n👋 Test interrupted by user")

if __name__ == "__main__":
    main()
