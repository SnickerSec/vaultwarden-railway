#!/bin/bash
#
# Get Railway Project and Environment IDs
# These are needed for GitHub Actions backup workflow
#

set -e

# Source shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

print_banner "Railway Project ID Finder"

# Check if Railway CLI is installed
check_railway_cli || exit 1

# Check if logged in
check_railway_auth || exit 1

# Get project list
print_info "Fetching your Railway projects..."
railway list

echo ""
print_warning "To get your Project ID and Environment ID:"
echo ""
echo "1. Go to your Railway project dashboard:"
echo "   https://railway.app/dashboard"
echo ""
echo "2. Click on your 'vaultwarden-railway' project"
echo ""
echo "3. The Project ID is in the URL:"
echo -e "   https://railway.app/project/${BLUE}<PROJECT_ID>${NC}"
echo ""
echo "4. Click on your environment (usually 'production')"
echo ""
echo "5. The Environment ID is also in the URL:"
echo -e "   https://railway.app/project/<PROJECT_ID>/${BLUE}<ENVIRONMENT_ID>${NC}"
echo ""
echo "6. Add these to GitHub Secrets:"
echo "   - Go to: https://github.com/SnickerSec/vaultwarden-railway/settings/secrets/actions"
echo -e "   - Add secret: ${GREEN}RAILWAY_PROJECT_ID${NC} = <your project ID>"
echo -e "   - Add secret: ${GREEN}RAILWAY_ENVIRONMENT_ID${NC} = <your environment ID>"
echo ""
print_warning "Alternative: Check .railway directory"

if [[ -d ".railway" ]]; then
    echo ""
    echo "Found .railway directory. Contents:"
    find .railway -type f -exec echo "  {}" \; -exec cat {} \; 2>/dev/null || echo "  (no readable files)"
fi

echo ""
