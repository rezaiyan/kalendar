#!/bin/bash

# Quick Deployment Shortcuts for Kalendar
# This script provides easy shortcuts for common deployment scenarios

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Functions
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

show_usage() {
    cat << EOF
Quick Deployment Shortcuts for Kalendar

USAGE:
    $0 <command>

COMMANDS:
    patch           Deploy with patch version bump (1.0.0 -> 1.0.1)
    minor           Deploy with minor version bump (1.0.0 -> 1.1.0)  
    major           Deploy with major version bump (1.0.0 -> 2.0.0)
    hotfix          Quick patch deployment, skips tests
    release         Full release deployment with all checks
    development     Create development build for testing
    testflight      Create TestFlight build
    appstore        Create App Store submission build
    version         Show current version information
    help            Show this help message

EXAMPLES:
    $0 patch        # Quick patch deployment
    $0 minor        # Minor version update
    $0 testflight   # Build for TestFlight testing
    $0 appstore     # Final App Store submission
    $0 version      # Check current version

EOF
}

# Get current version info
show_version_info() {
    local project="Kalendar.xcodeproj"
    
    if [[ ! -d "$project" ]]; then
        print_warning "Project not found: $project"
        return 1
    fi
    
    local version=$(xcodebuild -project "$project" -showBuildSettings -configuration Release | grep "MARKETING_VERSION" | head -1 | awk '{print $3}')
    local build=$(xcodebuild -project "$project" -showBuildSettings -configuration Release | grep "CURRENT_PROJECT_VERSION" | head -1 | awk '{print $3}')
    
    echo
    echo "╔══════════════════════════════════════╗"
    echo "║           VERSION INFO               ║"
    echo "╠══════════════════════════════════════╣"
    echo "║ Current Version: ${version}                     ║"
    echo "║ Current Build:   ${build}                       ║"
    echo "╚══════════════════════════════════════╝"
    echo
}

# Main logic
case "${1:-help}" in
    patch)
        print_status "🔧 Deploying patch version..."
        ./scripts/deploy.sh -b patch
        ;;
    minor)
        print_status "🆕 Deploying minor version..."
        ./scripts/deploy.sh -b minor
        ;;
    major)
        print_status "🚀 Deploying major version..."
        ./scripts/deploy.sh -b major
        ;;
    hotfix)
        print_status "🚨 Quick hotfix deployment..."
        ./scripts/deploy.sh -b patch --skip-tests
        ;;
    release)
        print_status "📦 Full release deployment..."
        ./scripts/deploy.sh -b minor -c Release
        ;;
    development)
        print_status "🛠️ Creating development build..."
        ./scripts/deploy.sh -c Debug --skip-version-bump
        ;;
    testflight)
        print_status "✈️ Creating TestFlight build..."
        ./scripts/deploy.sh -b patch -c Release
        print_status "Ready for TestFlight upload!"
        ;;
    appstore)
        print_status "🏪 Creating App Store build..."
        ./scripts/deploy.sh -b minor -c Release
        print_success "Ready for App Store submission!"
        ;;
    version)
        show_version_info
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        echo "Unknown command: $1"
        echo
        show_usage
        exit 1
        ;;
esac
