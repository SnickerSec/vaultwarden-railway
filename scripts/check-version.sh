#!/bin/bash
#
# Vaultwarden Version Checker
# Checks current vs latest version and optionally triggers update
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Function to get current version from Dockerfile
get_current_version() {
    if [ -f "Dockerfile" ]; then
        grep "FROM vaultwarden/server:" Dockerfile | cut -d':' -f2
    else
        print_error "Dockerfile not found!"
        exit 1
    fi
}

# Function to get latest version from Docker Hub
get_latest_version() {
    print_status "Fetching latest version from Docker Hub..."

    # Get latest semantic version
    local latest=$(curl -s https://hub.docker.com/v2/repositories/vaultwarden/server/tags/?page_size=100 | \
        jq -r '.results[].name' | \
        grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | \
        sort -V | \
        tail -1)

    if [ -z "$latest" ]; then
        print_error "Failed to fetch latest version"
        exit 1
    fi

    echo "$latest"
}

# Function to get recent versions
get_recent_versions() {
    print_status "Fetching recent versions..."

    curl -s https://hub.docker.com/v2/repositories/vaultwarden/server/tags/?page_size=100 | \
        jq -r '.results[].name' | \
        grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | \
        sort -V | \
        tail -5
}

# Function to compare versions
compare_versions() {
    local current=$1
    local latest=$2

    if [ "$current" = "latest" ]; then
        print_success "Using 'latest' tag - always up to date on rebuild"
        return 0
    elif [ "$current" = "$latest" ]; then
        print_success "Already on the latest version: $current"
        return 0
    else
        print_warning "Update available!"
        print_warning "Current: $current"
        print_warning "Latest:  $latest"
        return 1
    fi
}

# Function to trigger update
trigger_update() {
    local version=$1

    print_status "Triggering update to version $version..."

    # Check if git repo
    if [ ! -d ".git" ]; then
        print_error "Not a git repository. Cannot trigger automatic update."
        print_status "To update manually:"
        echo "  1. Edit Dockerfile and change version tag"
        echo "  2. git commit -am 'Update to Vaultwarden $version'"
        echo "  3. git push"
        return 1
    fi

    # Create update commit
    git config user.name "Version Checker" 2>/dev/null || true
    git config user.email "version-checker@local" 2>/dev/null || true

    git commit --allow-empty -m "chore: update to Vaultwarden $version"

    print_success "Update commit created"
    print_status "Push to trigger Railway deployment:"
    echo "  git push"
}

# Main script
main() {
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║   Vaultwarden Version Checker         ║"
    echo "╚════════════════════════════════════════╝"
    echo ""

    # Get versions
    CURRENT=$(get_current_version)
    LATEST=$(get_latest_version)

    print_status "Current version: $CURRENT"
    print_status "Latest version:  $LATEST"
    echo ""

    # Compare versions
    if compare_versions "$CURRENT" "$LATEST"; then
        echo ""
        print_status "Recent versions:"
        get_recent_versions | while read version; do
            if [ "$version" = "$CURRENT" ] || [ "$CURRENT" = "latest" ]; then
                echo -e "  ${GREEN}✓${NC} $version (current)"
            else
                echo "    $version"
            fi
        done
    else
        echo ""
        print_status "Recent versions:"
        get_recent_versions | while read version; do
            if [ "$version" = "$CURRENT" ]; then
                echo -e "  ${YELLOW}○${NC} $version (current)"
            elif [ "$version" = "$LATEST" ]; then
                echo -e "  ${GREEN}●${NC} $version (latest)"
            else
                echo "    $version"
            fi
        done

        echo ""
        read -p "Do you want to trigger an update? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            trigger_update "$LATEST"
        else
            print_status "Skipping update. To update later, run:"
            echo "  git commit --allow-empty -m 'Update to Vaultwarden $LATEST'"
            echo "  git push"
        fi
    fi

    echo ""
    print_status "For more information, see UPDATES.md"
    echo ""
}

# Run main function
main "$@"
