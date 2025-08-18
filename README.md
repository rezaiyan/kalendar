# Kalendar - iOS Calendar App with Widget

A beautiful and modern iOS calendar app featuring a creative monthly calendar widget.

## Features

- **Full Month Calendar Widget**: Displays the current month with today's date highlighted
- **Modern UI Design**: Clean, rounded design with gradients and shadows
- **Multiple Widget Sizes**: Supports both medium and large widget sizes
- **Interactive Main App**: Beautiful calendar interface in the main app
- **Real-time Updates**: Widget updates automatically to show current date

## Widget Features

### Medium Widget
- Shows month and year
- Highlights current day with blue circle
- Compact calendar grid layout
- Clean, modern design

### Large Widget
- Enhanced month header with gradient
- Larger calendar grid for better visibility
- Current day highlighted with blue-purple gradient
- Subtle grid lines for better readability

## Setup Instructions

### 1. Add Widget Extension Target

1. Open your project in Xcode
2. Go to **File** → **New** → **Target**
3. Select **Widget Extension** under iOS
4. Name it "KalendarWidgetExtension"
5. Make sure "Include Configuration Intent" is **unchecked**
6. Click **Finish**

### 2. Configure Widget Extension

1. In the new widget target, replace the default files with our custom ones:
   - `KalendarWidget.swift` - Main widget implementation
   - `KalendarWidgetBundle.swift` - Widget bundle configuration

2. Make sure the widget target has access to your app's shared code

### 3. Build and Run

1. Select your main app target and run it on a device or simulator
2. To test the widget:
   - Long press on the home screen
   - Tap the "+" button
   - Search for "Kalendar"
   - Add the widget to your home screen

## Widget Customization

The widget automatically:
- Updates to show the current month
- Highlights today's date
- Adjusts to different widget sizes
- Uses system colors for light/dark mode support

## Technical Details

- Built with SwiftUI and WidgetKit
- Supports iOS 14+ (WidgetKit requirement)
- Uses system fonts and colors for consistency
- Implements TimelineProvider for efficient updates
- Responsive design for different widget sizes

## App Structure

```
Kalendar/
├── KalendarApp.swift          # Main app entry point
├── ContentView.swift          # Main app interface
├── KalendarWidget.swift       # Widget implementation
├── KalendarWidgetBundle.swift # Widget bundle
└── Assets.xcassets/           # App assets
```

## Requirements

- iOS 14.0+
- Xcode 12.0+
- Swift 5.3+

## Notes

- The widget will automatically update to show the current month
- Today's date is highlighted with a blue circle (medium) or gradient (large)
- The widget supports both light and dark mode automatically
- Calendar calculations handle month boundaries and weekday alignments correctly 