# Foundation Models Tools

A collection of tools for Apple's Foundation Models Framework that enable you to interact with system frameworks and external services.

## Overview

**FoundationModelsTools** provides a set of pre-built tools that extend the capabilities of AI models using Apple's Foundation Models Framework. These tools allow you to:

- Access and manage calendar events
- Read and create contacts
- Get health data from HealthKit
- Access location services
- Control music playback
- Manage reminders
- Fetch weather information
- Extract metadata from web pages
- Search the web using Exa AI

## Requirements

- macOS 26.0+
- iOS 26.0+
- Swift 6.2+
- Xcode 26.0+

## Installation

Add **FoundationModelsTools** as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/rudrankriyam/FoundationModelsTools", from: "0.1.0")
]
```

## Available Tools

### CalendarTool
Access and manage calendar events. Requires Calendar entitlement.

### ContactsTool  
Search, read, and create contacts. Requires Contacts entitlement.

### HealthTool
Access health data from HealthKit. Requires HealthKit entitlement.

### LocationTool
Get current location, geocode addresses, and calculate distances. Requires Location Services entitlement.

### MusicTool
Control music playback and access music library. Requires Apple Music access.

### RemindersTool
Create, read, update, and complete reminders. Requires Reminders entitlement.

### WeatherTool
Fetch weather information using WeatherKit. Requires WeatherKit entitlement.

### WebMetadataTool
Extract metadata from web pages using LinkPresentation framework.

### WebTool
Search the web using Exa AI. Requires Exa API key.

## Configuration

Some tools require API keys or special entitlements:

- **WebTool**: Requires an Exa API key stored in `@AppStorage("exaAPIKey")`
- **WeatherTool**: Requires WeatherKit entitlement
- **HealthTool**: Requires HealthKit capabilities and usage descriptions

## License

[MIT License](LICENSE)