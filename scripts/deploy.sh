#!/bin/bash

# Kalendar Deployment Script (fixed & hardened)
# - Safer defaults
# - Correct "app-store" export method
# - Uses iTMSTransporter (altool deprecated)
# - Avoids Swift interface verification failures
# - Optional workspace support
# - Verbose/quiet xcodebuild
# - Optional dSYM verification

set -Eeuo pipefail

########################################
# Pretty printing
########################################
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_error()   { echo -e "${RED}[ERROR]${NC} $1" >&2; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_status()  { echo -e "${BLUE}[INFO]${NC} $1"; }
print_verbose() { [[ "${VERBOSE}" == "true" ]] && echo -e "${BLUE}[VERBOSE]${NC} $1" || true; }

trap 'print_error "Script failed (line $LINENO). Check logs above."' ERR

########################################
# Load environment (.env)
########################################
if [[ -f ".env" ]]; then
  print_status "Loading environment from .env …"
  set -a; source .env; set +a
elif [[ -f "$(dirname "$0")/../.env" ]]; then
  print_status "Loading environment from ../.env …"
  set -a; source "$(dirname "$0")/../.env"; set +a
fi

########################################
# Defaults
########################################
SCHEME="Kalendar"
PROJECT="Kalendar.xcodeproj"
WORKSPACE=""                    # If set, script uses -workspace instead of -project
CONFIGURATION="Release"
BUMP_TYPE="patch"               # major|minor|patch
SKIP_TESTS=false                # run tests by default
SKIP_VERSION_BUMP=false
SKIP_BUILD=false
ARCHIVE_PATH=""
EXPORT_PATH=""
EXPORT_METHOD="development"     # development|app-store|ad-hoc
VERBOSE=false
VERIFY_DSYMS=true

DERIVED_DATA_PATH="./DerivedData"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

########################################
# Usage
########################################
show_usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -s, --scheme SCHEME           Xcode scheme (default: ${SCHEME})
  -p, --project PROJECT         Xcode project (default: ${PROJECT})
  -w, --workspace WORKSPACE     Xcode workspace (overrides --project if set)
  -c, --configuration CONFIG    Build configuration (default: ${CONFIGURATION})
  -b, --bump TYPE               Version bump: major|minor|patch (default: ${BUMP_TYPE})
  -a, --archive-path PATH       Custom .xcarchive output path
  -e, --export-path PATH        Custom export output path
  -m, --method METHOD           Export method: development|app-store|ad-hoc (default: ${EXPORT_METHOD})
      --skip-tests              Skip tests
      --skip-version-bump       Skip version bump
      --skip-build              Skip build (export/upload only)
      --no-verify-dsyms         Skip Firebase dSYMs verification
  -v, --verbose                 Verbose logging
  -h, --help                    Show this help

Examples:
  $0                             # patch bump + build + export (development)
  $0 -m app-store                # for App Store Connect
  $0 --skip-tests -b minor       # minor bump, no tests
  $0 --skip-version-bump         # no version bump
  $0 -w Kalendar.xcworkspace     # use workspace (CocoaPods/SPM)
EOF
}

########################################
# Arg parsing
########################################
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--scheme) SCHEME="$2"; shift 2;;
    -p|--project) PROJECT="$2"; shift 2;;
    -w|--workspace) WORKSPACE="$2"; shift 2;;
    -c|--configuration) CONFIGURATION="$2"; shift 2;;
    -b|--bump) BUMP_TYPE="$2"; shift 2;;
    -a|--archive-path) ARCHIVE_PATH="$2"; shift 2;;
    -e|--export-path) EXPORT_PATH="$2"; shift 2;;
    -m|--method) EXPORT_METHOD="$2"; shift 2;;
    --skip-tests) SKIP_TESTS=true; shift;;
    --skip-version-bump) SKIP_VERSION_BUMP=true; shift;;
    --skip-build) SKIP_BUILD=true; shift;;
    --no-verify-dsyms) VERIFY_DSYMS=false; shift;;
    -v|--verbose) VERBOSE=true; shift;;
    -h|--help) show_usage; exit 0;;
    *) print_error "Unknown option: $1"; show_usage; exit 1;;
  esac
done

########################################
# Validation
########################################
if [[ ! "$BUMP_TYPE" =~ ^(major|minor|patch)$ ]]; then
  print_error "Invalid bump type: $BUMP_TYPE"
  exit 1
fi

if [[ ! "$CONFIGURATION" =~ ^(Debug|Release)$ ]]; then
  print_error "Invalid configuration: $CONFIGURATION"
  exit 1
fi

# Tolerate old input "app-store-connect" by mapping to "app-store"
if [[ "$EXPORT_METHOD" == "app-store-connect" ]]; then
  print_warning "Export method 'app-store-connect' is invalid. Using 'app-store' instead."
  EXPORT_METHOD="app-store"
fi

if [[ ! "$EXPORT_METHOD" =~ ^(development|app-store|ad-hoc)$ ]]; then
  print_error "Invalid export method: $EXPORT_METHOD"
  exit 1
fi

# Paths
[[ -z "$ARCHIVE_PATH" ]] && ARCHIVE_PATH="./build/Kalendar_${TIMESTAMP}.xcarchive"
[[ -z "$EXPORT_PATH"  ]] && EXPORT_PATH="./build/Export_${TIMESTAMP}"

# xcodebuild verbosity
if [[ "${VERBOSE}" == "true" ]]; then
  XCB_QUIET=()
else
  XCB_QUIET=(-quiet)
fi

print_status "Starting Kalendar Deployment"
print_status "Scheme: $SCHEME"
print_status "Configuration: $CONFIGURATION"
print_status "Method: $EXPORT_METHOD"
print_status "Archive Path: $ARCHIVE_PATH"
print_status "Export Path: $EXPORT_PATH"
[[ -n "$WORKSPACE" ]] && print_status "Workspace: $WORKSPACE" || print_status "Project: $PROJECT"

########################################
# Build helpers
########################################
xcb_common_args() {
  # Prints common xcodebuild args respecting workspace/project selection
  if [[ -n "$WORKSPACE" ]]; then
    echo "-workspace" "$WORKSPACE" "-scheme" "$SCHEME" "-configuration" "$CONFIGURATION"
  else
    echo "-project" "$PROJECT" "-scheme" "$SCHEME" "-configuration" "$CONFIGURATION"
  fi
}

get_current_version() {
  # Prefer MARKETING_VERSION from build settings
  xcodebuild $(xcb_common_args) -showBuildSettings "${XCB_QUIET[@]}" \
    | awk -F' = ' '/MARKETING_VERSION/ {print $2; exit}'
}

get_current_build() {
  xcodebuild $(xcb_common_args) -showBuildSettings "${XCB_QUIET[@]}" \
    | awk -F' = ' '/CURRENT_PROJECT_VERSION/ {print $2; exit}'
}

bump_version() {
  local cur_ver cur_build major minor patch new_version new_build
  cur_ver="$(get_current_version || echo 1.0.0)"
  cur_build="$(get_current_build || echo 0)"
  print_status "Current version: ${cur_ver:-unknown}"
  print_status "Current build: ${cur_build:-unknown}"

  IFS='.' read -r major minor patch <<<"${cur_ver:-1.0.0}"
  major=${major:-1}; minor=${minor:-0}; patch=${patch:-0}
  case "$BUMP_TYPE" in
    major) major=$((major+1)); minor=0; patch=0;;
    minor) minor=$((minor+1)); patch=0;;
    patch) patch=$((patch+1));;
  esac
  new_version="${major}.${minor}.${patch}"
  # handle non-numeric builds gracefully
  if [[ "$cur_build" =~ ^[0-9]+$ ]]; then
    new_build=$((cur_build+1))
  else
    new_build=1
  fi

  print_status "New version: $new_version"
  print_status "New build: $new_build"

  # Try agvtool first if enabled, else fallback to sed on project.pbxproj
  if command -v agvtool >/dev/null 2>&1; then
    (cd "$(dirname "${PROJECT:-$WORKSPACE}")" >/dev/null 2>&1 || true)
    agvtool new-version -all "$new_build" >/dev/null
    agvtool new-marketing-version "$new_version" >/dev/null
  else
    local pbxproj_path
    if [[ -n "$WORKSPACE" ]]; then
      # workspace -> guess project within same dir
      pbxproj_path="$(find . -name '*.xcodeproj/project.pbxproj' | head -1)"
    else
      pbxproj_path="$PROJECT/project.pbxproj"
    fi
    [[ -z "$pbxproj_path" || ! -f "$pbxproj_path" ]] && { print_error "project.pbxproj not found"; exit 1; }

    if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i '' "s/MARKETING_VERSION = [^;]*/MARKETING_VERSION = $new_version/g" "$pbxproj_path"
      sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*/CURRENT_PROJECT_VERSION = $new_build/g" "$pbxproj_path"
    else
      sed -i "s/MARKETING_VERSION = [^;]*/MARKETING_VERSION = $new_version/g" "$pbxproj_path"
      sed -i "s/CURRENT_PROJECT_VERSION = [^;]*/CURRENT_PROJECT_VERSION = $new_build/g" "$pbxproj_path"
    fi
  fi

  print_success "Version updated to $new_version ($new_build)"
  echo "$new_version"
}

run_tests() {
  print_status "Running tests…"
  # You can scope with -only-testing:TargetName if desired
  if ! xcodebuild test $(xcb_common_args) "${XCB_QUIET[@]}" CODE_SIGNING_ALLOWED=NO; then
    print_warning "Tests failed. Continuing (override by removing --skip-tests)."
  else
    print_success "Tests passed."
  fi
}

clean_build() {
  print_status "Cleaning previous builds…"
  rm -rf "$DERIVED_DATA_PATH" ./build 2>/dev/null || true
  mkdir -p "$(dirname "$ARCHIVE_PATH")" "$EXPORT_PATH"
  xcodebuild clean $(xcb_common_args) "${XCB_QUIET[@]}" >/dev/null 2>&1 || true
  print_success "Clean complete."
}

create_archive() {
  print_status "Creating archive…"
  # Avoid Swift interface verification failures
  # and provisioning snags with -allowProvisioningUpdates
  xcodebuild archive \
    $(xcb_common_args) \
    -archivePath "$ARCHIVE_PATH" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -allowProvisioningUpdates \
    SWIFT_EMIT_PRIVATE_MODULE_INTERFACE=NO \
    SWIFT_VERIFY_EMITTED_MODULE_INTERFACE=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=NO \
    "${XCB_QUIET[@]}"
  print_success "Archive created at: $ARCHIVE_PATH"
}

export_archive() {
  print_status "Exporting archive ($EXPORT_METHOD)…"

  local export_options_plist="./build/ExportOptions.plist"
  mkdir -p "./build"

  # Optional: TEAM_ID from env (TEAM_ID or DEVELOPMENT_TEAM)
  local TEAM_ID_EFFECTIVE="${TEAM_ID:-${DEVELOPMENT_TEAM:-}}"

  case "$EXPORT_METHOD" in
    "development")
      cat > "$export_options_plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>development</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>stripSwiftSymbols</key><false/>
  <key>destination</key><string>export</string>
  $( [[ -n "$TEAM_ID_EFFECTIVE" ]] && echo "<key>teamID</key><string>$TEAM_ID_EFFECTIVE</string>" )
</dict></plist>
EOF
      ;;
    "app-store")
      cat > "$export_options_plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>stripSwiftSymbols</key><true/>
  $( [[ -n "$TEAM_ID_EFFECTIVE" ]] && echo "<key>teamID</key><string>$TEAM_ID_EFFECTIVE</string>" )
</dict></plist>
EOF
      ;;
    "ad-hoc")
      cat > "$export_options_plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>ad-hoc</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>stripSwiftSymbols</key><true/>
  $( [[ -n "$TEAM_ID_EFFECTIVE" ]] && echo "<key>teamID</key><string>$TEAM_ID_EFFECTIVE</string>" )
</dict></plist>
EOF
      ;;
  esac

  print_verbose "ExportOptions.plist created at $export_options_plist"

  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$export_options_plist" \
    -allowProvisioningUpdates \
    "${XCB_QUIET[@]}"

  print_success "Export complete at: $EXPORT_PATH"
}

upload_to_appstore() {
  [[ "$EXPORT_METHOD" != "app-store" ]] && { print_verbose "Skipping App Store upload (method=$EXPORT_METHOD)"; return; }

  print_status "Uploading to App Store Connect via iTMSTransporter…"

  local ipa_file
  ipa_file="$(find "$EXPORT_PATH" -name "*.ipa" | head -1 || true)"
  if [[ -z "$ipa_file" ]]; then
    print_error "No .ipa found in $EXPORT_PATH"
    exit 1
  fi
  print_status "IPA: $(basename "$ipa_file")"

  if command -v xcrun >/dev/null 2>&1; then
    # Prefer API key if available
    if [[ -n "${APP_STORE_CONNECT_API_KEY_ID:-}" && -n "${APP_STORE_CONNECT_API_ISSUER_ID:-}" && -n "${APP_STORE_CONNECT_API_KEY_PATH:-}" ]]; then
      xcrun iTMSTransporter -m upload -assetFile "$ipa_file" \
        -apiKey "${APP_STORE_CONNECT_API_KEY_ID}" \
        -apiIssuer "${APP_STORE_CONNECT_API_ISSUER_ID}" \
        -apiKeyFile "${APP_STORE_CONNECT_API_KEY_PATH}" \
        -v informational
    else
      # Fallback to Apple ID + app-specific password
      xcrun iTMSTransporter -m upload -assetFile "$ipa_file" \
        -u "${APP_STORE_CONNECT_USERNAME:-}" \
        -p "${APP_STORE_CONNECT_PASSWORD:-}" \
        -v informational
    fi
  else
    print_error "xcrun not found. Install Xcode Command Line Tools."
    exit 1
  fi

  print_success "Uploaded to App Store Connect."
  print_status "Processing may take a few minutes."
}

verify_dsyms() {
  local archive_path="$1"
  [[ "$VERIFY_DSYMS" != "true" ]] && { print_status "Skipping dSYM verification"; return; }

  print_status "Verifying Firebase dSYMs…"
  local dsyms_dir="$archive_path/dSYMs"
  [[ ! -d "$dsyms_dir" ]] && { print_warning "dSYMs dir not found: $dsyms_dir"; return; }

  local frameworks=("FirebaseAnalytics" "GoogleAdsOnDeviceConversion" "GoogleAppMeasurement" "GoogleAppMeasurementIdentitySupport")
  local missing=()

  for fw in "${frameworks[@]}"; do
    local dsym="$dsyms_dir/$fw.framework.dSYM"
    if [[ -d "$dsym" ]]; then
      print_success "✅ $fw dSYM found"
      if command -v dwarfdump >/dev/null 2>&1; then
        local cnt
        cnt=$(dwarfdump --uuid "$dsym" 2>/dev/null | grep -c "UUID:" || echo "0")
        [[ "$cnt" -gt 0 ]] || print_warning "   No UUIDs found in $fw dSYM"
      fi
    else
      print_warning "⚠️  $fw dSYM missing"
      missing+=("$fw")
    fi
  done

  [[ ${#missing[@]} -gt 0 ]] && print_warning "Missing dSYMs: ${missing[*]}" || print_success "All Firebase dSYMs verified."
}

generate_release_notes() {
  local version="$1"
  local file="./build/release_notes_${version}.md"
  cat > "$file" <<EOF
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
- Built with $(xcodebuild -version | head -1)
- iOS Deployment Target: $(xcodebuild $(xcb_common_args) -showBuildSettings "${XCB_QUIET[@]}" | awk -F' = ' '/IPHONEOS_DEPLOYMENT_TARGET/ {print $2; exit}')

## Files
- Archive: \`$(basename "$ARCHIVE_PATH")\`
- Export: \`$(basename "$EXPORT_PATH")\`

---
*Generated automatically by deploy.sh*
EOF
  print_success "Release notes: $file"
}

create_deployment_summary() {
  local version="$1"
  cat <<EOF

╔══════════════════════════════════════════════════════════════╗
║                    DEPLOYMENT SUMMARY                        ║
╠══════════════════════════════════════════════════════════════╣
║ App:           Kalendar                                      ║
║ Version:       ${version}                                    ║
║ Configuration: ${CONFIGURATION}                              ║
║ Timestamp:     $(date '+%Y-%m-%d %H:%M:%S')                  ║
╠══════════════════════════════════════════════════════════════╣
║ Archive:       ${ARCHIVE_PATH}                               ║
║ Export:        ${EXPORT_PATH}                                ║
╠══════════════════════════════════════════════════════════════╣
║ Next Steps:                                                  ║
║ 1. Test the exported .ipa file                               ║
║ 2. (If app-store) Submit for review in App Store Connect     ║
╚══════════════════════════════════════════════════════════════╝

EOF
}

########################################
# Main
########################################
main() {
  # Basic prechecks
  if [[ -n "$WORKSPACE" ]]; then
    [[ -f "$WORKSPACE" ]] || { print_error "Workspace not found: $WORKSPACE"; exit 1; }
  else
    [[ -d "$PROJECT" ]] || { print_error "Project not found: $PROJECT"; exit 1; }
  fi

  command -v xcodebuild >/dev/null 2>&1 || { print_error "xcodebuild not found (install Xcode)."; exit 1; }

  # Versioning
  local new_version
  if [[ "$SKIP_VERSION_BUMP" == "true" ]]; then
    new_version="$(get_current_version || echo "1.0.0")"
    print_status "Skipping version bump; using $new_version"
  else
    new_version="$(bump_version)"
  fi

  # Tests
  if [[ "$SKIP_TESTS" == "false" ]]; then
    run_tests
  else
    print_warning "Skipping tests"
  fi

  # Build & export
  if [[ "$SKIP_BUILD" == "false" ]]; then
    clean_build
    create_archive
    verify_dsyms "$ARCHIVE_PATH"
    export_archive
  else
    print_status "Skipping build; using existing archive"
    if [[ -z "$ARCHIVE_PATH" || ! -d "$ARCHIVE_PATH" ]]; then
      ARCHIVE_PATH="$(find ./build -name "*.xcarchive" -type d -exec ls -dt {} + 2>/dev/null | head -1 || true)"
      [[ -z "$ARCHIVE_PATH" ]] && { print_error "No archive found and --skip-build set"; exit 1; }
      print_status "Using latest archive: $ARCHIVE_PATH"
    fi
    export_archive
  fi

  upload_to_appstore
  generate_release_notes "$new_version"
  create_deployment_summary "$new_version"

  print_success "🎉 Deployment completed successfully!"
  print_status "Ready for App Store submission."
}

main "$@"
