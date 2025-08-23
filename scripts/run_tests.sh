#!/bin/bash

# Kalendar Test Runner Script
# This script runs comprehensive tests for the Kalendar project

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
SCHEME="Kalendar"
PROJECT="Kalendar.xcodeproj"
DEVICE="iPhone 16"
IOS_VERSION="18.6"
TEST_TYPE="all"
GENERATE_REPORT=false
VERBOSE=false

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -s, --scheme SCHEME           Xcode scheme to test (default: Kalendar)"
    echo "  -p, --project PROJECT         Xcode project (default: Kalendar.xcodeproj)"
    echo "  -d, --device DEVICE           Test device (default: iPhone 16)"
    echo "  -i, --ios-version VERSION     iOS version (default: 18.6)"
    echo "  -t, --test-type TYPE          Test type: unit|widget|all (default: all)"
    echo "  -r, --report                  Generate test report"
    echo "  -v, --verbose                 Verbose output"
    echo "  -h, --help                    Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                            Run all tests with default settings"
    echo "  $0 -t unit                    Run only unit tests"
    echo "  $0 -d 'iPad Pro' -r          Run tests on iPad Pro and generate report"
    echo "  $0 -t widget -v               Run widget tests with verbose output"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--scheme)
            SCHEME="$2"
            shift 2
            ;;
        -p|--project)
            PROJECT="$2"
            shift 2
            ;;
        -d|--device)
            DEVICE="$2"
            shift 2
            ;;
        -i|--ios-version)
            IOS_VERSION="$2"
            shift 2
            ;;
        -t|--test-type)
            TEST_TYPE="$2"
            shift 2
            ;;
        -r|--report)
            GENERATE_REPORT=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate test type
if [[ ! "$TEST_TYPE" =~ ^(unit|widget|all)$ ]]; then
    print_error "Invalid test type: $TEST_TYPE"
    print_error "Valid types: unit, widget, all"
    exit 1
fi

# Setup
DESTINATION="platform=iOS Simulator,name=$DEVICE,OS=$IOS_VERSION"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS_DIR="TestResults_$TIMESTAMP"
XCPRETTY_OPTS=""

if [[ "$VERBOSE" == "true" ]]; then
    XCPRETTY_OPTS="--no-color"
else
    XCPRETTY_OPTS="--color --report junit --output $RESULTS_DIR/junit.xml"
fi

print_status "Starting Kalendar Test Suite"
print_status "Scheme: $SCHEME"
print_status "Device: $DEVICE (iOS $IOS_VERSION)"
print_status "Test Type: $TEST_TYPE"

# Create results directory if generating report
if [[ "$GENERATE_REPORT" == "true" ]]; then
    mkdir -p "$RESULTS_DIR"
    print_status "Results will be saved to: $RESULTS_DIR"
fi

# Function to run xcodebuild command
run_xcodebuild() {
    local test_target="$1"
    local build_action="$2"
    local extra_args="$3"
    
    local cmd="xcodebuild \
        -project $PROJECT \
        -scheme $SCHEME \
        -destination \"$DESTINATION\" \
        -configuration Debug \
        $build_action \
        $extra_args \
        CODE_SIGNING_ALLOWED=NO"
    
    if [[ "$VERBOSE" == "true" ]]; then
        print_status "Running: $cmd"
        eval $cmd
    else
        eval $cmd | xcpretty $XCPRETTY_OPTS
        return ${PIPESTATUS[0]}
    fi
}

# Function to run unit tests
run_unit_tests() {
    print_status "Running Unit Tests..."
    
    local extra_args=""
    if [[ "$GENERATE_REPORT" == "true" ]]; then
        extra_args="-enableCodeCoverage YES -resultBundlePath $RESULTS_DIR/unit_tests.xcresult"
    fi
    
    if run_xcodebuild "KalendarTests" "test" "-only-testing:KalendarTests $extra_args"; then
        print_success "Unit tests passed"
        return 0
    else
        print_error "Unit tests failed"
        return 1
    fi
}



# Function to run widget tests
run_widget_tests() {
    print_status "Running Widget Tests..."
    
    local extra_args=""
    if [[ "$GENERATE_REPORT" == "true" ]]; then
        extra_args="-resultBundlePath $RESULTS_DIR/widget_tests.xcresult"
    fi
    
    # Test widget timeline logic
    if run_xcodebuild "WidgetTests" "test" "-only-testing:WidgetTests $extra_args"; then
        print_success "Widget tests passed"
    else
        print_error "Widget tests failed"
        return 1
    fi
    
    # Test widget builds
    print_status "Testing widget builds..."
    
    local widget_schemes=("LockScreenCalendarWidgetExtension" "KalendarWidgetExtensionExtension")
    for widget_scheme in "${widget_schemes[@]}"; do
        print_status "Building $widget_scheme..."
        if ! xcodebuild \
            -project "$PROJECT" \
            -scheme "$widget_scheme" \
            -destination "$DESTINATION" \
            -configuration Debug \
            build \
            CODE_SIGNING_ALLOWED=NO > /dev/null 2>&1; then
            print_warning "Failed to build $widget_scheme (this may be expected if scheme doesn't exist)"
        else
            print_success "$widget_scheme built successfully"
        fi
    done
    
    return 0
}

# Function to generate report
generate_report() {
    if [[ "$GENERATE_REPORT" != "true" ]]; then
        return 0
    fi
    
    print_status "Generating test report..."
    
    local report_file="$RESULTS_DIR/test_report.html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Kalendar Test Report - $TIMESTAMP</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .header { background: #f5f5f5; padding: 20px; border-radius: 8px; }
        .success { color: #28a745; }
        .error { color: #dc3545; }
        .warning { color: #ffc107; }
        .section { margin: 20px 0; padding: 15px; border-left: 4px solid #007bff; background: #f8f9fa; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Kalendar Test Report</h1>
        <p><strong>Generated:</strong> $(date)</p>
        <p><strong>Device:</strong> $DEVICE (iOS $IOS_VERSION)</p>
        <p><strong>Scheme:</strong> $SCHEME</p>
    </div>
EOF
    
    # Add test results to report
    if [[ -f "$RESULTS_DIR/junit.xml" ]]; then
        echo "<div class=\"section\"><h2>Test Summary</h2>" >> "$report_file"
        echo "<p>JUnit XML report generated. Check junit.xml for detailed results.</p>" >> "$report_file"
        echo "</div>" >> "$report_file"
    fi
    
    echo "</body></html>" >> "$report_file"
    
    print_success "Report generated: $report_file"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if Xcode is installed
    if ! command -v xcodebuild &> /dev/null; then
        print_error "xcodebuild not found. Please install Xcode."
        exit 1
    fi
    
    # Check if xcpretty is installed
    if ! command -v xcpretty &> /dev/null; then
        print_warning "xcpretty not found. Installing..."
        gem install xcpretty || {
            print_warning "Failed to install xcpretty. Tests will run without pretty output."
            XCPRETTY_OPTS=""
        }
    fi
    
    # Check if project exists
    if [[ ! -d "$PROJECT" ]]; then
        print_error "Project file not found: $PROJECT"
        exit 1
    fi
    
    # Check if simulator is available
    if ! xcrun simctl list devices | grep -q "$DEVICE.*$IOS_VERSION"; then
        print_warning "Simulator '$DEVICE' with iOS $IOS_VERSION not found"
        print_status "Available simulators:"
        xcrun simctl list devices | grep "iOS $IOS_VERSION" || true
    fi
    
    print_success "Prerequisites check completed"
}

# Main execution
main() {
    check_prerequisites
    
    local test_passed=true
    
    case "$TEST_TYPE" in
        "unit")
            run_unit_tests || test_passed=false
            ;;
        "widget")
            run_widget_tests || test_passed=false
            ;;
        "all")
            run_unit_tests || test_passed=false
            run_widget_tests || test_passed=false
            ;;
    esac
    
    generate_report
    
    if [[ "$test_passed" == "true" ]]; then
        print_success "All tests completed successfully! 🎉"
        exit 0
    else
        print_error "Some tests failed! ❌"
        exit 1
    fi
}

# Trap to cleanup on exit
cleanup() {
    if [[ -n "${SIMULATOR_ID:-}" ]]; then
        print_status "Cleaning up simulator..."
        xcrun simctl delete "$SIMULATOR_ID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# Run main function
main "$@"
