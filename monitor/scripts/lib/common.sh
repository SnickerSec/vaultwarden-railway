#!/bin/bash
#
# Common Shell Library
# Shared functions for all Vaultwarden scripts
#

# Prevent double-sourcing
[[ -n "$_COMMON_SH_LOADED" ]] && return
_COMMON_SH_LOADED=1

###############################################################################
# Colors
###############################################################################

export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export NC='\033[0m' # No Color

###############################################################################
# Logging Functions
###############################################################################

# Print informational message
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Print success message
print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Print warning message
print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Print error message
print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Print timestamped log message
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

# Print success with checkmark
success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Print error with X mark and exit
error() {
    echo -e "${RED}✗ ERROR:${NC} $1"
    exit 1
}

# Print warning with triangle
warning() {
    echo -e "${YELLOW}⚠ WARNING:${NC} $1"
}

###############################################################################
# Railway CLI Functions
###############################################################################

# Check if Railway CLI is installed
check_railway_cli() {
    if ! command -v railway &> /dev/null; then
        print_error "Railway CLI is not installed"
        echo "Install with: npm install -g @railway/cli"
        return 1
    fi
    return 0
}

# Check if logged into Railway
check_railway_auth() {
    if ! railway whoami &> /dev/null; then
        print_error "Not logged into Railway"
        echo "Login with: railway login"
        return 1
    fi
    return 0
}

# Check if project is linked
check_railway_project() {
    if ! railway status &> /dev/null; then
        print_error "No Railway project linked"
        echo "Link with: railway link"
        return 1
    fi
    return 0
}

# Full Railway prerequisite check
check_railway_prerequisites() {
    check_railway_cli || return 1
    check_railway_auth || return 1
    check_railway_project || return 1
    return 0
}

###############################################################################
# PostgreSQL Functions
###############################################################################

# Check if psql is available
check_psql() {
    if ! command -v psql &> /dev/null; then
        print_error "PostgreSQL client (psql) is not installed"
        return 1
    fi
    return 0
}

# Check if pg_dump is available
check_pg_dump() {
    if ! command -v pg_dump &> /dev/null; then
        print_error "PostgreSQL pg_dump is not installed"
        return 1
    fi
    return 0
}

# Check database connection via Railway or direct
check_database_connection() {
    # Use direct psql if DATABASE_URL is available (Railway container)
    # Otherwise use railway run command (local development)
    if [[ -n "$DATABASE_URL" ]]; then
        if ! psql "$DATABASE_URL" -c "SELECT 1;" &> /dev/null; then
            print_error "Cannot connect to database"
            return 1
        fi
    else
        if ! railway run psql "$DATABASE_URL" -c "SELECT 1;" &> /dev/null; then
            print_error "Cannot connect to database"
            return 1
        fi
    fi
    return 0
}

###############################################################################
# File Utilities
###############################################################################

# Get human-readable file size
get_file_size() {
    local file="$1"
    du -h "$file" | cut -f1
}

# Get file modification date
get_file_date() {
    local file="$1"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$file"
    else
        stat -c "%y" "$file" | cut -d'.' -f1
    fi
}

# Get file permissions
get_file_perms() {
    local file="$1"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        stat -f "%Sp" "$file"
    else
        stat -c "%A" "$file"
    fi
}

# Ensure directory exists
ensure_dir() {
    local dir="$1"
    mkdir -p "$dir"
}

###############################################################################
# Script Headers
###############################################################################

# Print script banner
print_banner() {
    local title="$1"
    local width=${2:-45}

    echo ""
    printf '╔%s╗\n' "$(printf '═%.0s' $(seq 1 $width))"
    printf '║  %-*s║\n' "$((width - 2))" "$title"
    printf '╚%s╝\n' "$(printf '═%.0s' $(seq 1 $width))"
    echo ""
}

# Print section divider
print_divider() {
    echo "========================================="
}

# Print section header
print_section() {
    local title="$1"
    echo ""
    print_divider
    echo "  $title"
    print_divider
    echo ""
}

###############################################################################
# Git Functions
###############################################################################

# Check if current directory is a git repository
check_git_repo() {
    if [[ ! -d ".git" ]]; then
        print_error "Not a git repository"
        return 1
    fi
    return 0
}

# Check for uncommitted changes
has_uncommitted_changes() {
    [[ -n "$(git status --porcelain)" ]]
}
