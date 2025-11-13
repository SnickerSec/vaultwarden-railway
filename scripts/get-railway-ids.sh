#!/bin/bash
#
# Get Railway Project and Environment IDs
# These are needed for GitHub Actions backup workflow
#

set -e

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "╔════════════════════════════════════════╗"
echo "║   Railway Project ID Finder           ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Check if Railway CLI is installed
if ! command -v railway &> /dev/null; then
    echo -e "${YELLOW}Railway CLI is not installed${NC}"
    echo "Install with: npm install -g @railway/cli"
    exit 1
fi

# Check if logged in
if ! railway whoami &> /dev/null; then
    echo -e "${YELLOW}Not logged into Railway${NC}"
    echo "Login with: railway login"
    exit 1
fi

# Get project list
echo -e "${BLUE}Fetching your Railway projects...${NC}"
railway list

echo ""
echo -e "${YELLOW}To get your Project ID and Environment ID:${NC}"
echo ""
echo "1. Go to your Railway project dashboard:"
echo "   https://railway.app/dashboard"
echo ""
echo "2. Click on your 'vaultwarden-railway' project"
echo ""
echo "3. The Project ID is in the URL:"
echo "   https://railway.app/project/${BLUE}<PROJECT_ID>${NC}"
echo ""
echo "4. Click on your environment (usually 'production')"
echo ""
echo "5. The Environment ID is also in the URL:"
echo "   https://railway.app/project/<PROJECT_ID>/${BLUE}<ENVIRONMENT_ID>${NC}"
echo ""
echo "6. Add these to GitHub Secrets:"
echo "   - Go to: https://github.com/SnickerSec/vaultwarden-railway/settings/secrets/actions"
echo "   - Add secret: ${GREEN}RAILWAY_PROJECT_ID${NC} = <your project ID>"
echo "   - Add secret: ${GREEN}RAILWAY_ENVIRONMENT_ID${NC} = <your environment ID>"
echo ""
echo -e "${YELLOW}Alternative: Check .railway directory${NC}"

if [ -d ".railway" ]; then
    echo ""
    echo "Found .railway directory. Contents:"
    find .railway -type f -exec echo "  {}" \; -exec cat {} \; 2>/dev/null || echo "  (no readable files)"
fi

echo ""
