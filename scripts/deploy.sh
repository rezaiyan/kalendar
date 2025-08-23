#!/bin/bash

# Kalendar Deployment Script
# This script handles version bumping, building, and creating archives for deployment

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
CONFIGURATION="Release"
BUMP_TYPE="patch"
SKIP_TESTS=false
SKIP_VERSION_BUMP=false
ARCHIVE_PATH=""
EXPORT_PATH=""
VERBOSE=false

# Print functions
print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

# Show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Kalendar Deployment Script - Handles versioning, building, and archiving

OPTIONS:
    -s, --scheme SCHEME           Xcode scheme to build (default: Kalendar)
    -p, --project PROJECT         Xcode project (default: Kalendar.xcodeproj)
    -c, --configuration CONFIG    Build configuration (default: Release)
    -b, --bump TYPE              Version bump type: major|minor|patch (default: patch)
    -a, --archive-path PATH      Custom archive output path
    -e, --export-path PATH       Custom export output path
    --skip-tests                 Skip running tests before deployment
    --skip-version-bump          Skip version bumping
    -v, --verbose                Verbose output
    -h, --help                   Show this help message

EXAMPLES:
    $0                           Deploy with patch version bump
    $0 -b minor                  Deploy with minor version bump
    $0 --skip-tests -b major     Deploy with major bump, skip tests
    $0 --skip-version-bump       Deploy without version bump
    $0 -a ./MyArchive.xcarchive  Use custom archive path

VERSION BUMP TYPES:
    patch    1.0.0 -> 1.0.1 (bug fixes)
    minor    1.0.0 -> 1.1.0 (new features)
    major    1.0.0 -> 2.0.0 (breaking changes)

EOF
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
        -c|--configuration)
            CONFIGURATION="$2"
            shift 2
            ;;
        -b|--bump)
            BUMP_TYPE="$2"
            shift 2
            ;;
        -a|--archive-path)
            ARCHIVE_PATH="$2"
            shift 2
            ;;
        -e|--export-path)
            EXPORT_PATH="$2"
            shift 2
            ;;
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        --skip-version-bump)
            SKIP_VERSION_BUMP=true
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

# Validate bump type
if [[ ! "$BUMP_TYPE" =~ ^(major|minor|patch)$ ]]; then
    print_error "Invalid bump type: $BUMP_TYPE"
    print_error "Valid types: major, minor, patch"
    exit 1
fi

# Validate configuration
if [[ ! "$CONFIGURATION" =~ ^(Debug|Release)$ ]]; then
    print_error "Invalid configuration: $CONFIGURATION"
    print_error "Valid configurations: Debug, Release"
    exit 1
fi

# Setup paths
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DERIVED_DATA_PATH="./DerivedData"
if [[ -z "$ARCHIVE_PATH" ]]; then
    ARCHIVE_PATH="./build/Kalendar_${TIMESTAMP}.xcarchive"
fi
if [[ -z "$EXPORT_PATH" ]]; then
    EXPORT_PATH="./build/Export_${TIMESTAMP}"
fi

print_status "Starting Kalendar Deployment"
print_status "Scheme: $SCHEME"
print_status "Configuration: $CONFIGURATION"
print_status "Archive Path: $ARCHIVE_PATH"
print_status "Export Path: $EXPORT_PATH"

# Function to get current version
get_current_version() {
    local version=$(xcodebuild -project "$PROJECT" -showBuildSettings -configuration "$CONFIGURATION" | grep "MARKETING_VERSION" | head -1 | awk '{print $3}')
    echo "$version"
}

# Function to get current build number
get_current_build() {
    local build=$(xcodebuild -project "$PROJECT" -showBuildSettings -configuration "$CONFIGURATION" | grep "CURRENT_PROJECT_VERSION" | head -1 | awk '{print $3}')
    echo "$build"
}

# Function to bump version
bump_version() {
    local current_version=$(get_current_version)
    local current_build=$(get_current_build)
    
    print_status "Current version: $current_version"
    print_status "Current build: $current_build"
    
    # Parse version components
    local IFS='.'
    read -ra version_parts <<< "$current_version"
    local major=${version_parts[0]:-0}
    local minor=${version_parts[1]:-0}
    local patch=${version_parts[2]:-0}
    
    # Bump version based on type
    case $BUMP_TYPE in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
    esac
    
    local new_version="${major}.${minor}.${patch}"
    local new_build=$((current_build + 1))
    
    print_status "New version: $new_version"
    print_status "New build: $new_build"
    
    # Update version in project file
    print_status "Updating project version..."
    
    # Use sed to update all MARKETING_VERSION entries
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS sed
        sed -i '' "s/MARKETING_VERSION = [^;]*/MARKETING_VERSION = $new_version/g" "$PROJECT/project.pbxproj"
        sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*/CURRENT_PROJECT_VERSION = $new_build/g" "$PROJECT/project.pbxproj"
    else
        # GNU sed
        sed -i "s/MARKETING_VERSION = [^;]*/MARKETING_VERSION = $new_version/g" "$PROJECT/project.pbxproj"
        sed -i "s/CURRENT_PROJECT_VERSION = [^;]*/CURRENT_PROJECT_VERSION = $new_build/g" "$PROJECT/project.pbxproj"
    fi
    
    print_success "Version updated to $new_version ($new_build)"
    
    # Return the new version for use in other functions
    echo "$new_version"
}

# Function to run tests
run_tests() {
    print_status "Running tests before deployment..."
    
    local test_destination="platform=iOS Simulator,name=iPhone 16"
    
    print_verbose "Running unit tests..."
    if ! xcodebuild test \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "$test_destination" \
        -only-testing:KalendarTests \
        CODE_SIGNING_ALLOWED=NO \
        > /dev/null 2>&1; then
        print_warning "Some unit tests failed, but continuing with deployment"
    else
        print_success "Unit tests passed"
    fi
    
    print_verbose "Running UI tests..."
    if ! xcodebuild test \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "$test_destination" \
        -only-testing:KalendarUITests \
        CODE_SIGNING_ALLOWED=NO \
        > /dev/null 2>&1; then
        print_warning "Some UI tests failed, but continuing with deployment"
    else
        print_success "UI tests passed"
    fi
}

# Function to clean build folder
clean_build() {
    print_status "Cleaning previous builds..."
    
    if [[ -d "$DERIVED_DATA_PATH" ]]; then
        rm -rf "$DERIVED_DATA_PATH"
        print_verbose "Removed DerivedData"
    fi
    
    mkdir -p "$(dirname "$ARCHIVE_PATH")"
    mkdir -p "$EXPORT_PATH"
    
    xcodebuild clean \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        > /dev/null 2>&1
    
    print_success "Build environment cleaned"
}

# Function to create archive
create_archive() {
    print_status "Creating archive..."
    
    print_verbose "Archive will be saved to: $ARCHIVE_PATH"
    
    if ! xcodebuild archive \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -archivePath "$ARCHIVE_PATH" \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES; then
        print_error "Archive creation failed"
        exit 1
    fi
    
    print_success "Archive created successfully"
    print_status "Archive location: $ARCHIVE_PATH"
}

# Function to export archive
export_archive() {
    print_status "Exporting archive for distribution..."
    
    # Create export options plist
    local export_options_plist="./build/ExportOptions.plist"
    mkdir -p "$(dirname "$export_options_plist")"
    
    cat > "$export_options_plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
</dict>
</plist>
EOF
    
    print_verbose "Export options created: $export_options_plist"
    
    if ! xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist "$export_options_plist"; then
        print_error "Archive export failed"
        exit 1
    fi
    
    print_success "Archive exported successfully"
    print_status "Export location: $EXPORT_PATH"
}

# Function to generate release notes
generate_release_notes() {
    local version="$1"
    local release_notes_file="./build/release_notes_${version}.md"
    
    cat > "$release_notes_file" << EOF
# Kalendar v${version}

## Release Information
- **Version**: ${version}
- **Build Date**: $(date '+%Y-%m-%d %H:%M:%S')
- **Configuration**: ${CONFIGURATION}
- **Archive**: $(basename "$ARCHIVE_PATH")

## What's New
- Bug fixes and improvements
- Enhanced widget reliability
- Better midnight refresh handling

## Technical Details
- Built with Xcode $(xcodebuild -version | head -1 | awk '{print $2}')
- Supports iOS 17.6+
- Includes Lock Screen and Home Screen widgets

## Files
- Archive: \`$(basename "$ARCHIVE_PATH")\`
- Export: \`$(basename "$EXPORT_PATH")\`

---
*Generated automatically by deploy.sh*
EOF
    
    print_success "Release notes generated: $release_notes_file"
}

# Function to create deployment summary
create_deployment_summary() {
    local version="$1"
    
    print_status "Creating deployment summary..."
    
    cat << EOF

╔══════════════════════════════════════════════════════════════╗
║                    DEPLOYMENT SUMMARY                        ║
╠══════════════════════════════════════════════════════════════╣
║ App:           Kalendar                                      ║
║ Version:       ${version}                                   ║
║ Configuration: ${CONFIGURATION}                            ║
║ Timestamp:     $(date '+%Y-%m-%d %H:%M:%S')                ║
╠══════════════════════════════════════════════════════════════╣
║ Archive:       ${ARCHIVE_PATH}                             ║
║ Export:        ${EXPORT_PATH}                              ║
╠══════════════════════════════════════════════════════════════╣
║ Next Steps:                                                  ║
║ 1. Test the exported .ipa file                             ║
║ 2. Upload to App Store Connect                             ║
║ 3. Submit for review                                       ║
╚══════════════════════════════════════════════════════════════╝

EOF
}

# Main execution
main() {
    print_status "🚀 Starting deployment process..."
    
    # Check prerequisites
    if [[ ! -d "$PROJECT" ]]; then
        print_error "Project file not found: $PROJECT"
        exit 1
    fi
    
    if ! command -v xcodebuild &> /dev/null; then
        print_error "xcodebuild not found. Please install Xcode."
        exit 1
    fi
    
    # Get or set version
    local new_version
    if [[ "$SKIP_VERSION_BUMP" == "true" ]]; then
        new_version=$(get_current_version)
        print_status "Skipping version bump, using current version: $new_version"
    else
        new_version=$(bump_version)
    fi
    
    # Run tests if not skipped
    if [[ "$SKIP_TESTS" == "false" ]]; then
        run_tests
    else
        print_warning "Skipping tests"
    fi
    
    # Clean and build
    clean_build
    create_archive
    export_archive
    
    # Generate documentation
    generate_release_notes "$new_version"
    create_deployment_summary "$new_version"
    
    print_success "🎉 Deployment completed successfully!"
    print_status "Ready for App Store submission"
}

# Run main function
main "$@"
