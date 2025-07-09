# FoundationModelsTools Examples

## Using WebTool for Web Search

```swift
import FoundationModels
import FoundationModelsTools
import SwiftUI

struct ContentView: View {
    @State private var searchResults = ""
    @AppStorage("exaAPIKey") private var exaAPIKey = ""
    
    var body: some View {
        VStack {
            // Set your Exa API key first
            SecureField("Exa API Key", text: $exaAPIKey)
                .textFieldStyle(.roundedBorder)
                .padding()
            
            Button("Search Web") {
                Task {
                    do {
                        let webTool = WebTool()
                        let result = try await webTool.call(
                            arguments: WebTool.Arguments(
                                query: "Latest Swift programming updates"
                            )
                        )
                        // Process the result
                        if let content = result.content {
                            searchResults = content.description
                        }
                    } catch {
                        print("Error: \(error)")
                    }
                }
            }
            
            ScrollView {
                Text(searchResults)
                    .padding()
            }
        }
    }
}
```

## Using CalendarTool to Create Events

```swift
import FoundationModels
import FoundationModelsTools
import EventKit

struct CalendarExample {
    func createMeeting() async throws {
        let calendarTool = CalendarTool()
        
        let result = try await calendarTool.call(
            arguments: CalendarTool.Arguments(
                action: .create,
                title: "Team Meeting",
                startDate: Date().addingTimeInterval(3600), // 1 hour from now
                endDate: Date().addingTimeInterval(7200),    // 2 hours from now
                location: "Conference Room A",
                notes: "Discuss Q1 project updates"
            )
        )
        
        print("Event created: \(result)")
    }
}
```

## Using ContactsTool to Search Contacts

```swift
import FoundationModels
import FoundationModelsTools
import Contacts

struct ContactsExample {
    func searchContacts() async throws {
        let contactsTool = ContactsTool()
        
        let result = try await contactsTool.call(
            arguments: ContactsTool.Arguments(
                action: .search,
                searchQuery: "John"
            )
        )
        
        // Process the contacts found
        if let content = result.content {
            print("Found contacts: \(content)")
        }
    }
}
```

## Using WeatherTool to Get Weather

```swift
import FoundationModels
import FoundationModelsTools
import CoreLocation

struct WeatherExample {
    func getCurrentWeather() async throws {
        let weatherTool = WeatherTool()
        
        let result = try await weatherTool.call(
            arguments: WeatherTool.Arguments(
                location: "San Francisco, CA"
            )
        )
        
        if let content = result.content {
            print("Weather: \(content)")
        }
    }
}
```

## Using LocationTool for Geocoding

```swift
import FoundationModels
import FoundationModelsTools
import CoreLocation

struct LocationExample {
    func geocodeAddress() async throws {
        let locationTool = LocationTool()
        
        let result = try await locationTool.call(
            arguments: LocationTool.Arguments(
                action: .geocode,
                address: "1 Infinite Loop, Cupertino, CA"
            )
        )
        
        if let content = result.content {
            print("Location: \(content)")
        }
    }
}
```

## Integration with Foundation Models

These tools can be integrated with AI models:

```swift
import FoundationModels
import FoundationModelsTools

struct AIAssistant {
    let model: Model // Your Foundation Models instance
    
    func assistWithTask() async throws {
        // Register tools with the model
        let tools: [any Tool] = [
            WebTool(),
            CalendarTool(),
            ContactsTool(),
            WeatherTool(),
            LocationTool()
        ]
        
        // Model can now use these tools to help with tasks
        let response = try await model.generate(
            prompt: "What's the weather like in New York and create a reminder to bring an umbrella if it's raining",
            tools: tools
        )
        
        print(response)
    }
}
```

## Important Notes

1. **Permissions**: Each tool requires appropriate permissions and entitlements:
   - CalendarTool: Calendar access
   - ContactsTool: Contacts access  
   - HealthTool: HealthKit capabilities
   - LocationTool: Location services
   - WeatherTool: WeatherKit entitlement

2. **API Keys**: WebTool requires an Exa API key

3. **Error Handling**: Always handle errors appropriately as tools may fail due to permissions or network issues

4. **Privacy**: Be mindful of user privacy when accessing personal data