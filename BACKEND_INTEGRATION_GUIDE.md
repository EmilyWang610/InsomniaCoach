# 🚀 Backend Integration Guide for Insomnia Coach

This guide shows how to integrate your specific backend API with the Insomnia Coach iOS app.

## 📋 **What's Been Created**

I've built a complete integration system for your backend API:

### **1. Core Backend Services**
- **`BackendAPIManager.swift`** - Main API client for your backend endpoints
- **`NightDataProcessor.swift`** - Handles the complete night data processing pipeline
- **`AdaptivePlanView.swift`** - Displays the AI-generated adaptive plans
- **`BackendTestView.swift`** - Test interface for backend integration

### **2. API Integration Flow**
```
iOS App → Backend API → MongoDB → AI Agent → Adaptive Plan → iOS App
```

## 🔧 **Configuration**

### **Step 1: Update Backend URL**

Edit `Services/BackendAPIManager.swift`:

```swift
struct BackendAPIConfiguration {
    static let baseURL = "https://your-actual-backend-domain.com" // Replace with your URL
    static let timeout: TimeInterval = 30.0
}
```

### **Step 2: Test the Integration**

1. Run the app
2. Navigate to "Backend Test" view
3. Tap "Check Health" to verify connection
4. Tap "Test Night Data Processing" to test the full pipeline

## 🎯 **How It Works**

### **1. Night Data Ingestion**

When a user completes a sleep session:

```swift
// The app converts sleep session to your NightDTO format
let nightData = NightDTO(
    userId: "user123",
    date: "2024-01-15",
    stages: [
        SleepStage(stage: "awake", startTime: "2024-01-15T22:30:00Z", endTime: "2024-01-15T22:35:00Z", duration: 300),
        SleepStage(stage: "light", startTime: "2024-01-15T22:35:00Z", endTime: "2024-01-15T23:30:00Z", duration: 3300),
        // ... more stages
    ],
    vitals: nil,
    metadata: NightMetadata(deviceType: "iOS", appVersion: "1.0", timezone: "UTC", notes: "Good sleep")
)

// Sends to your backend
POST /api/nights/ingest
```

### **2. AI Agent Analysis**

After ingestion, the app automatically triggers your AI agent:

```swift
// Triggers your agent analysis
POST /api/users/{user_id}/agent/analyze?night_date=2024-01-15

// Waits for analysis to complete
// Then fetches the generated plan
GET /api/users/{user_id}/agent/plans/latest
```

### **3. Adaptive Plan Display**

The app displays the AI-generated plan with:
- Plan summary
- Individual plan blocks
- Duration information
- Audio mix information (if available)

## 📊 **Data Flow**

### **Complete Pipeline:**

1. **User completes sleep session** → iOS app
2. **Convert to NightDTO** → iOS app
3. **Send to backend** → `POST /api/nights/ingest`
4. **Backend stores in MongoDB** → Your backend
5. **Trigger AI analysis** → `POST /api/users/{user_id}/agent/analyze`
6. **AI generates plan** → Your backend
7. **Fetch adaptive plan** → `GET /api/users/{user_id}/agent/plans/latest`
8. **Display plan to user** → iOS app

## 🎵 **Audio Integration**

Your backend can include audio in the adaptive plan:

```json
{
  "blocks": [
    {
      "type": "meditation",
      "title": "Sleep Meditation",
      "description": "10-minute guided meditation",
      "duration": 600,
      "order": 1,
      "mix": {
        "audioUrl": "https://your-cdn.com/audio/meditation.m4a",
        "fileName": "meditation.m4a",
        "durationSec": 600
      }
    }
  ]
}
```

The iOS app will automatically handle audio playback for these blocks.

## 🔍 **Testing Your Integration**

### **1. Health Check**
```swift
// Tests: GET /health
env.backendAPI.checkHealth()
```

### **2. User Creation**
```swift
// Tests: POST /api/users
let userId = try await env.backendAPI.createUser()
```

### **3. Night Data Processing**
```swift
// Tests the complete pipeline
await env.nightProcessor.processNightData(sleepSession, quality: 85)
```

### **4. Plan Retrieval**
```swift
// Tests: GET /api/users/{user_id}/agent/plans/latest
let plan = try await env.backendAPI.getLatestPlan(userId: userId)
```

## 🛠 **Customization**

### **Add New Plan Block Types**

Edit `PlanBlock` in `BackendAPIManager.swift`:

```swift
struct PlanBlock: Codable {
    let type: String // "meditation", "breathing", "music", "custom"
    let title: String
    let description: String
    let duration: Int
    let order: Int
    let mix: AudioMix?
    let customData: [String: String]? // Add custom fields
}
```

### **Add Vital Data**

Edit `Vitals` in `BackendAPIManager.swift`:

```swift
struct Vitals: Codable {
    let heartRate: [VitalDataPoint]?
    let heartRateVariability: [VitalDataPoint]?
    let oxygenSaturation: [VitalDataPoint]?
    let bodyTemperature: [VitalDataPoint]?
    let bloodPressure: [VitalDataPoint]? // Add new vital
    let sleepPosition: [VitalDataPoint]? // Add new vital
}
```

### **Customize Sleep Stage Conversion**

Edit `convertToSleepStages` in `BackendAPIManager.swift` to match your sleep analysis algorithm.

## 🚨 **Error Handling**

The app handles these scenarios:
- Network connectivity issues
- Backend API errors
- MongoDB connection problems
- AI agent failures
- Invalid data formats

All errors are displayed to the user with helpful messages.

## 📱 **UI Integration**

### **Add to Your Main App**

```swift
// In your main navigation
NavigationLink("Sleep Plan") {
    AdaptivePlanView()
}

// In your dashboard
Button("Process Last Night") {
    Task {
        await env.nightProcessor.processNightData(
            sleepSession: lastSession,
            quality: 85
        )
    }
}
```

### **Real-time Updates**

The app automatically updates when:
- New plans are generated
- Processing completes
- Errors occur
- Agent status changes

## 🎯 **Next Steps**

1. **Update the backend URL** in `BackendAPIManager.swift`
2. **Test the health endpoint** using the Backend Test view
3. **Run a complete test** with mock sleep data
4. **Customize the plan display** to match your design
5. **Add audio playback** for plan blocks with audio
6. **Integrate with your existing sleep tracking**

## 📞 **Support**

The integration is ready to work with your backend! The app will:
- ✅ Send night data in your exact format
- ✅ Wait for AI agent processing
- ✅ Display adaptive plans beautifully
- ✅ Handle all error cases
- ✅ Provide real-time feedback

Just update the backend URL and test it out! 🚀
