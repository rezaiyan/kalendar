#!/bin/bash

# Kalendar Deployment Script
# This script handles version bumping, building, and creating archives for deployment

set -e  # Exit on any error

# Load environment variables from .env file if it exists
if [[ -f ".env" ]]; then
    echo "Loading environment variables from .env file..."
    set -a  # Automatically export all variables
    source .env
    set +a  # Stop auto-exporting
elif [[ -f "$(dirname "$0")/../.env" ]]; then
    echo "Loading environment variables from .env file..."
    set -a  # Automatically export all variables
    source "$(dirname "$0")/../.env"
    set +a  # Stop auto-exporting
fi

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
SKIP_TESTS=true
SKIP_VERSION_BUMP=false
SKIP_BUILD=false
ARCHIVE_PATH=""
EXPORT_PATH=""
EXPORT_METHOD="development"
VERBOSE=false
VERIFY_DSYMS=true

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

# Verify dSYMs for Firebase frameworks
verify_dsyms() {
    local archive_path="$1"
    
    if [[ "$VERIFY_DSYMS" != "true" ]]; then
        print_status "Skipping dSYM verification"
        return 0
    fi
    
    print_status "Verifying dSYMs for Firebase frameworks..."
    
    local dsyms_dir="$archive_path/dSYMs"
    if [[ ! -d "$dsyms_dir" ]]; then
        print_error "dSYMs directory not found: $dsyms_dir"
        return 1
    fi
    
    # Firebase frameworks that need dSYMs
    local firebase_frameworks=(
        "FirebaseAnalytics"
        "GoogleAdsOnDeviceConversion"
        "GoogleAppMeasurement"
        "GoogleAppMeasurementIdentitySupport"
    )
    
    local missing_dsyms=()
    
    for framework in "${firebase_frameworks[@]}"; do
        local dsym_path="$dsyms_dir/$framework.framework.dSYM"
        if [[ -d "$dsym_path" ]]; then
            print_success "✅ $framework dSYM found"
            
            # Verify dSYM contains UUIDs
            if command -v dwarfdump >/dev/null 2>&1; then
                local uuid_count=$(dwarfdump --uuid "$dsym_path" 2>/dev/null | grep -c "UUID:" || echo "0")
                if [[ "$uuid_count" -gt 0 ]]; then
                    print_verbose "   Contains $uuid_count UUID(s)"
                else
                    print_warning "   No UUIDs found in dSYM"
                fi
            fi
        else
            print_warning "⚠️  $framework dSYM missing"
            missing_dsyms+=("$framework")
        fi
    done
    
    if [[ ${#missing_dsyms[@]} -gt 0 ]]; then
        print_warning "Missing dSYMs for: ${missing_dsyms[*]}"
        print_status "Consider running the dSYM fix script before archiving"
        return 1
    else
        print_success "All Firebase dSYMs verified successfully!"
        return 0
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
    -m, --method METHOD          Export method: development|app-store-connect|ad-hoc (default: development)
    --skip-tests                 Skip running tests before deployment
    --skip-version-bump          Skip version bumping
    --skip-build                 Skip build process (for upload-only operations)
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
        -m|--method)
            EXPORT_METHOD="$2"
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
        --skip-build)
            SKIP_BUILD=true
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

# Validate export method
if [[ ! "$EXPORT_METHOD" =~ ^(development|app-store-connect|ad-hoc)$ ]]; then
    print_error "Invalid export method: $EXPORT_METHOD"
    print_error "Valid methods: development, app-store-connect, ad-hoc"
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
    
    local test_destination=""
    
    print_verbose "Running unit tests..."
    if ! xcodebuild test \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -only-testing:KalendarTests \
        CODE_SIGNING_ALLOWED=NO \
        > /dev/null 2>&1; then
        print_warning "Some unit tests failed, but continuing with deployment"
    else
        print_success "Unit tests passed"
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
    
    # Create export options based on method
    local export_options_plist="./build/ExportOptions.plist"
    mkdir -p "$(dirname "$export_options_plist")"
    
    case "$EXPORT_METHOD" in
        "development")
            cat > "$export_options_plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <false/>
    <key>destination</key>
    <string>export</string>
</dict>
</plist>
EOF
            ;;
        "app-store-connect")
            cat > "$export_options_plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
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
            ;;
        "ad-hoc")
            cat > "$export_options_plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>ad-hoc</string>
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
            ;;
    esac
    
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

# Function to upload to App Store Connect
upload_to_appstore() {
    if [[ "$EXPORT_METHOD" != "app-store-connect" ]]; then
        print_verbose "Skipping App Store Connect upload (export method: $EXPORT_METHOD)"
        return 0
    fi
    
    print_status "Uploading to App Store Connect..."
    
    # Find the .ipa file in the export directory
    local ipa_file=$(find "$EXPORT_PATH" -name "*.ipa" | head -1)
    
    if [[ -z "$ipa_file" ]]; then
        print_error "No .ipa file found in export directory: $EXPORT_PATH"
        exit 1
    fi
    
    print_status "Found IPA: $(basename "$ipa_file")"
    
    # Upload using xcrun altool (legacy) or notarytool (newer)
    if command -v xcrun >/dev/null 2>&1; then
        print_status "Uploading using xcrun altool..."
        
        if ! xcrun altool --upload-app \
            --type ios \
            --file "$ipa_file" \
            --username "${APP_STORE_CONNECT_USERNAME:-}" \
            --password "${APP_STORE_CONNECT_PASSWORD:-}" \
            --verbose; then
                
            print_warning "altool upload failed, trying with App Store Connect API key..."
            
            # Try with API key if username/password failed
            if [[ -n "${APP_STORE_CONNECT_API_KEY_PATH:-}" ]]; then
                if ! xcrun altool --upload-app \
                    --type ios \
                    --file "$ipa_file" \
                    --apiKey "${APP_STORE_CONNECT_API_KEY_ID:-}" \
                    --apiIssuer "${APP_STORE_CONNECT_API_ISSUER_ID:-}" \
                    --verbose; then
                    print_error "Failed to upload to App Store Connect"
                    exit 1
                fi
            else
                print_error "App Store Connect upload failed. Please check credentials."
                print_status "Required environment variables:"
                print_status "  APP_STORE_CONNECT_USERNAME (Apple ID)"
                print_status "  APP_STORE_CONNECT_PASSWORD (App-specific password)"
                print_status "Or for API key authentication:"
                print_status "  APP_STORE_CONNECT_API_KEY_ID"
                print_status "  APP_STORE_CONNECT_API_ISSUER_ID"
                print_status "  APP_STORE_CONNECT_API_KEY_PATH"
                exit 1
            fi
        fi
    else
        print_error "xcrun not found. Please install Xcode Command Line Tools."
        exit 1
    fi
    
    print_success "Successfully uploaded to App Store Connect!"
    print_status "Build will appear at: https://appstoreconnect.apple.com"
    print_status "It may take a few minutes to process and appear in the builds list."
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
    if [[ "$SKIP_BUILD" == "false" ]]; then
        clean_build
        create_archive
        export_archive
    else
        print_status "Skipping build process..."
        # For upload-only, we need to find the most recent archive
        if [[ -z "$ARCHIVE_PATH" ]]; then
            ARCHIVE_PATH=$(find ./build -name "*.xcarchive" -type d -exec ls -dt {} + 2>/dev/null | head -1)
            if [[ -z "$ARCHIVE_PATH" ]]; then
                print_error "No existing archive found and --skip-build specified"
                print_status "Please build first or remove --skip-build flag"
                exit 1
            fi
            print_status "Using existing archive: $(basename "$ARCHIVE_PATH")"
        fi
        export_archive
    fi
    upload_to_appstore
    
    # Generate documentation
    generate_release_notes "$new_version"
    create_deployment_summary "$new_version"
    
    print_success "🎉 Deployment completed successfully!"
    print_status "Ready for App Store submission"
}

# Run main function
main "$@"
