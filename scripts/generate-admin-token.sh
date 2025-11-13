#!/bin/bash
#
# Generate a secure Argon2 hashed ADMIN_TOKEN for Vaultwarden
#
# Usage: ./scripts/generate-admin-token.sh

set -e

echo "=========================================="
echo "Vaultwarden Admin Token Generator"
echo "=========================================="
echo ""

# Check if docker is available
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not in PATH"
    echo "Please install Docker first: https://docs.docker.com/get-docker/"
    exit 1
fi

echo "This script will generate a secure Argon2 PHC hashed admin token."
echo ""
read -p "Enter a password for your admin token (or press Enter for random): " ADMIN_PASSWORD

if [ -z "$ADMIN_PASSWORD" ]; then
    # Generate random password
    ADMIN_PASSWORD=$(openssl rand -base64 32)
    echo ""
    echo "Generated random password: $ADMIN_PASSWORD"
    echo "⚠️  SAVE THIS PASSWORD - You'll need it to access the admin panel!"
    echo ""
fi

echo ""
echo "Generating Argon2 hash..."
echo ""

# Use vaultwarden docker image to hash the password
HASHED_TOKEN=$(docker run --rm -it vaultwarden/server:latest \
    /vaultwarden hash --preset owasp "$ADMIN_PASSWORD" 2>/dev/null | grep -v "Password" | tr -d '\r')

if [ -z "$HASHED_TOKEN" ]; then
    echo "Error: Failed to generate hash"
    exit 1
fi

echo "=========================================="
echo "✅ Success! Your secure ADMIN_TOKEN:"
echo "=========================================="
echo ""
echo "$HASHED_TOKEN"
echo ""
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo ""
echo "1. Copy the hash above"
echo "2. Go to your Railway dashboard"
echo "3. Navigate to your Vaultwarden service → Variables"
echo "4. Update ADMIN_TOKEN with the hash above"
echo "5. Save and redeploy"
echo ""
echo "6. Access admin panel at: https://your-domain.railway.app/admin"
echo "   Use password: $ADMIN_PASSWORD"
echo ""
echo "⚠️  IMPORTANT: Save this password somewhere secure!"
echo "=========================================="
