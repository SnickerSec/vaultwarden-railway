#!/bin/bash
#
# Vaultwarden Version Checker
# Checks current vs latest version and optionally triggers update
#

set -e

# Source shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

###############################################################################
# Version Functions
###############################################################################

# Get current version from Dockerfile
get_current_version() {
    if [[ -f "Dockerfile" ]]; then
        grep "FROM vaultwarden/server:" Dockerfile | cut -d':' -f2
    else
        print_error "Dockerfile not found!"
        exit 1
    fi
}

# Get latest version from Docker Hub
get_latest_version() {
    print_info "Fetching latest version from Docker Hub..."

    local latest=$(curl -s https://hub.docker.com/v2/repositories/vaultwarden/server/tags/?page_size=100 | \
        jq -r '.results[].name' | \
        grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | \
        sort -V | \
        tail -1)

    if [[ -z "$latest" ]]; then
        print_error "Failed to fetch latest version"
        exit 1
    fi

    echo "$latest"
}

# Get recent versions
get_recent_versions() {
    print_info "Fetching recent versions..."

    curl -s https://hub.docker.com/v2/repositories/vaultwarden/server/tags/?page_size=100 | \
        jq -r '.results[].name' | \
        grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | \
        sort -V | \
        tail -5
}

# Compare versions
compare_versions() {
    local current=$1
    local latest=$2

    if [[ "$current" = "latest" ]]; then
        print_success "Using 'latest' tag - always up to date on rebuild"
        return 0
    elif [[ "$current" = "$latest" ]]; then
        print_success "Already on the latest version: $current"
        return 0
    else
        print_warning "Update available!"
        print_warning "Current: $current"
        print_warning "Latest:  $latest"
        return 1
    fi
}

# Trigger update
trigger_update() {
    local version=$1

    print_info "Triggering update to version $version..."

    check_git_repo || {
        print_info "To update manually:"
        echo "  1. Edit Dockerfile and change version tag"
        echo "  2. git commit -am 'Update to Vaultwarden $version'"
        echo "  3. git push"
        return 1
    }

    # Create update commit
    git config user.name "Version Checker" 2>/dev/null || true
    git config user.email "version-checker@local" 2>/dev/null || true

    git commit --allow-empty -m "chore: update to Vaultwarden $version"

    print_success "Update commit created"
    print_info "Push to trigger Railway deployment:"
    echo "  git push"
}

###############################################################################
# Main Script
###############################################################################

main() {
    print_banner "Vaultwarden Version Checker"

    # Get versions
    CURRENT=$(get_current_version)
    LATEST=$(get_latest_version)

    print_info "Current version: $CURRENT"
    print_info "Latest version:  $LATEST"
    echo ""

    # Compare versions
    if compare_versions "$CURRENT" "$LATEST"; then
        echo ""
        print_info "Recent versions:"
        get_recent_versions | while read version; do
            if [[ "$version" = "$CURRENT" ]] || [[ "$CURRENT" = "latest" ]]; then
                echo -e "  ${GREEN}✓${NC} $version (current)"
            else
                echo "    $version"
            fi
        done
    else
        echo ""
        print_info "Recent versions:"
        get_recent_versions | while read version; do
            if [[ "$version" = "$CURRENT" ]]; then
                echo -e "  ${YELLOW}○${NC} $version (current)"
            elif [[ "$version" = "$LATEST" ]]; then
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
            print_info "Skipping update. To update later, run:"
            echo "  git commit --allow-empty -m 'Update to Vaultwarden $LATEST'"
            echo "  git push"
        fi
    fi

    echo ""
    print_info "For more information, see docs/UPDATES.md"
    echo ""
}

main "$@"
