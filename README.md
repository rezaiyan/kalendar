# Kalendar

A beautiful iOS calendar app with widgets built using SwiftUI and WidgetKit.

## 📱 Screenshots & Media

### 🎥 Video Demo
[**📺 Watch App Demo Video**](screenshots/app_demo.mp4)  
*Experience the Kalendar app in action - see the smooth transitions between light/dark modes and responsive design*

### 🌅 App Screenshots
| Dark | Light |
|----------|-----------|
| ![Light Portrait](screenshots/app_light_portrait.png) | ![Light Landscape](screenshots/app_light_landscape.png) |

### 🏠 Widget Integration
| Light Mode | Dark Mode |
|------------|-----------|
| ![Home Light](screenshots/home_screen_light.png) | ![Home Dark](screenshots/home_screen_dark.png) |
| *Seamless widget integration on home screen* | *Consistent dark theme across entire system* |

### 📅 Widget Close-up
![Widget](screenshots/widget.png)  
*Elegant lock screen widget with current time display and monthly calendar view*

## 🎨 New App Icon

The app now features a unique, modern icon design:
- **Design**: Geometric "K" letter with gradient background
- **Colors**: Blue-to-purple gradient with white accents
- **Style**: Modern, minimalist, and distinctive from Apple's Calendar app

## 📋 App Store Screenshots

For App Store compliance, screenshots must show:
1. **Main Calendar View** - Current month with weather icons
2. **Weather Display** - Selected date with weather details  
3. **Widget Setup Guide** - Step-by-step installation process
4. **Dark Mode View** - Calendar in dark theme
5. **iPad Layout** - Proper iPad interface (if supported)
6. **Widget Preview** - Widget on home screen

**Requirements**:
- Must show actual app functionality (not splash screens)
- Include core features: calendar, weather, widgets
- Use proper device frames (iPhone for iPhone, iPad for iPad)
- Show app in use, not marketing materials

## Quick Start

```bash
git clone <repository-url>
cd Kalendar
open Kalendar.xcodeproj
```

**Requirements**: iOS 17.6+, Xcode 15.0+

## Development

```bash
# Run tests
./scripts/run_tests.sh

# Deploy to TestFlight
./scripts/quick-deploy.sh testflight

# Check current version
./scripts/quick-deploy.sh version

# Generate App Store screenshots
./scripts/generate_screenshots.sh

# Convert app icon (SVG to PNG)
./scripts/convert_icon.sh
```

## Features

- Monthly calendar widget for Home Screen and Lock Screen
- Clean, minimal design with current time display
- Automatic dark/light mode support
- Reliable midnight refresh handling
- Weather integration for selected dates
- Unique, App Store compliant icon design

## 🔧 App Store Fixes

If you're updating the app for App Store submission:

1. **Update App Icon**: Use the new `kalendar_new_icon.svg` design
2. **Generate Screenshots**: Run `./scripts/generate_screenshots.sh`
3. **Follow Guidelines**: Ensure screenshots show actual app functionality
4. **Test Thoroughly**: Verify new icon works on all devices

See `APP_STORE_FIXES.md` for detailed instructions.

## Contributing

Fork → Create branch → Submit PR

---

**Built with ❤️ by [@rezaiyan](https://github.com/rezaiyan)** 
