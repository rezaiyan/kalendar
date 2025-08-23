# Kalendar - iOS Calendar App with Widget

A beautiful and modern iOS calendar app featuring a creative monthly calendar widget. Built with SwiftUI and WidgetKit for a seamless user experience.

## 📱 Screenshots

### Main App Interface
![Main App](screenshots/app.png)

### Home Screen Widget
![Widget](screenshots/widget.png)

## 🚀 Setup Instructions

1. Clone the repository
2. Open `Kalendar.xcodeproj` in Xcode
3. Select your target device or simulator
4. Build and run the project

## 📋 Requirements

- **iOS**: 14.0+
- **Xcode**: 15.0+
- **Swift**: 5.9+
- **Device**: iPhone or iPad with iOS 14+

## 🧪 Testing

This project includes comprehensive test coverage:

- **Unit Tests**: Core functionality and business logic
- **UI Tests**: User interface automation and interaction testing  
- **Widget Tests**: Widget timeline and refresh logic testing
- **Performance Tests**: Launch time and memory usage benchmarks

### Running Tests

```bash
# Run all tests
./scripts/run_tests.sh

# Run specific test types
./scripts/run_tests.sh -t unit      # Unit tests only
./scripts/run_tests.sh -t ui        # UI tests only  
./scripts/run_tests.sh -t widget    # Widget tests only

# Generate test reports
./scripts/run_tests.sh -r

# Test on specific device
./scripts/run_tests.sh -d "iPad Pro"
```

For detailed testing information, see [TESTING.md](TESTING.md).

## 🔄 Continuous Integration

The project uses GitHub Actions for automated testing:

- **CI Pipeline**: Runs on every push and pull request
- **Nightly Builds**: Comprehensive testing across device matrix
- **Code Coverage**: Tracked with Codecov integration
- **Code Quality**: Enforced with SwiftLint

### Build Status

[![CI](https://github.com/rezaiyan/kalendar/workflows/CI/badge.svg)](https://github.com/rezaiyan/kalendar/actions)
[![codecov](https://codecov.io/gh/rezaiyan/kalendar/branch/main/graph/badge.svg)](https://codecov.io/gh/rezaiyan/kalendar)

## 🌟 Key Features

- **No Year Display**: Clean month-only headers
- **Simplified Day Format**: Just day name, no "Today is..." text
- **Time Integration**: Current time displayed in corner
- **Professional Appearance**: Clean, minimal design
- **Open Source**: Community-driven development

## 🤝 Contributing

This is an open source project! Contributions are welcome:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📄 License

This project is open source and available under the MIT License.

## 🎉 Notes

- The widget automatically updates to show the current month
- Today's date is highlighted with a beautiful blue-purple gradient
- Supports both light and dark mode automatically
- Calendar calculations handle month boundaries and weekday alignments correctly
- Time display updates in real-time
- Clean, professional design without unnecessary text clutter

---

**Built with ❤️ by [@rezaiyan](https://github.com/rezaiyan)** 
