#!/bin/bash
#
# Setup Rate Limiting for Vaultwarden
# Configures recommended rate limiting settings via Railway CLI
#

set -e

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
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

echo ""
echo "╔════════════════════════════════════════╗"
echo "║   Vaultwarden Rate Limiting Setup     ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Check if Railway CLI is installed
if ! command -v railway &> /dev/null; then
    print_error "Railway CLI is not installed"
    echo "Install with: npm install -g @railway/cli"
    exit 1
fi

# Check if logged in
if ! railway whoami &> /dev/null; then
    print_error "Not logged into Railway"
    echo "Login with: railway login"
    exit 1
fi

# Security level selection
echo "Select security level:"
echo ""
echo "1) Personal Use (Balanced)"
echo "   - 10 login attempts per minute"
echo "   - 3 admin attempts per 5 minutes"
echo ""
echo "2) Strict Security (High Security)"
echo "   - 5 login attempts per minute"
echo "   - 3 admin attempts per 10 minutes"
echo ""
echo "3) Shared/Family Use (Relaxed)"
echo "   - 15 login attempts per minute"
echo "   - 5 admin attempts per 5 minutes"
echo ""
echo "4) Custom (Manual configuration)"
echo ""

read -p "Enter choice (1-4): " CHOICE

case $CHOICE in
    1)
        print_info "Configuring Personal Use settings..."
        LOGIN_BURST=10
        LOGIN_SECONDS=60
        ADMIN_BURST=3
        ADMIN_SECONDS=300
        ;;
    2)
        print_info "Configuring Strict Security settings..."
        LOGIN_BURST=5
        LOGIN_SECONDS=60
        ADMIN_BURST=3
        ADMIN_SECONDS=600
        ;;
    3)
        print_info "Configuring Shared/Family Use settings..."
        LOGIN_BURST=15
        LOGIN_SECONDS=60
        ADMIN_BURST=5
        ADMIN_SECONDS=300
        ;;
    4)
        print_info "Custom configuration..."
        read -p "Login attempts per burst: " LOGIN_BURST
        read -p "Login time window (seconds): " LOGIN_SECONDS
        read -p "Admin attempts per burst: " ADMIN_BURST
        read -p "Admin time window (seconds): " ADMIN_SECONDS
        ;;
    *)
        print_error "Invalid choice"
        exit 1
        ;;
esac

echo ""
print_info "Configuration Summary:"
echo "  Login Rate Limit: $LOGIN_BURST attempts per $LOGIN_SECONDS seconds"
echo "  Admin Rate Limit: $ADMIN_BURST attempts per $ADMIN_SECONDS seconds"
echo ""

read -p "Apply these settings? (y/n): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    print_warning "Cancelled"
    exit 0
fi

echo ""
print_info "Setting Railway environment variables..."

# Set variables using Railway CLI
railway variables --set "LOGIN_RATELIMIT_MAX_BURST=$LOGIN_BURST" \
                  --set "LOGIN_RATELIMIT_SECONDS=$LOGIN_SECONDS" \
                  --set "ADMIN_RATELIMIT_MAX_BURST=$ADMIN_BURST" \
                  --set "ADMIN_RATELIMIT_SECONDS=$ADMIN_SECONDS" \
                  --set "IP_HEADER=X-Forwarded-For"

if [ $? -eq 0 ]; then
    print_success "Rate limiting configured!"
else
    print_error "Failed to set variables"
    exit 1
fi

echo ""
print_warning "IMPORTANT: You need to redeploy for changes to take effect"
echo ""

read -p "Trigger redeploy now? (y/n): " REDEPLOY
if [[ "$REDEPLOY" =~ ^[Yy]$ ]]; then
    print_info "Triggering redeploy..."
    git commit --allow-empty -m "chore: apply rate limiting configuration"
    git push
    print_success "Redeploy triggered!"
else
    print_warning "Remember to redeploy manually:"
    echo "  git commit --allow-empty -m 'chore: apply rate limiting'"
    echo "  git push"
fi

echo ""
print_success "Rate limiting setup complete!"
echo ""
print_info "Configuration applied:"
echo "  LOGIN_RATELIMIT_MAX_BURST=$LOGIN_BURST"
echo "  LOGIN_RATELIMIT_SECONDS=$LOGIN_SECONDS"
echo "  ADMIN_RATELIMIT_MAX_BURST=$ADMIN_BURST"
echo "  ADMIN_RATELIMIT_SECONDS=$ADMIN_SECONDS"
echo "  IP_HEADER=X-Forwarded-For"
echo ""
print_info "To verify, check Railway logs after deployment:"
echo "  railway logs"
echo ""
print_info "For more information, see: docs/RATE_LIMITING.md"
echo ""
