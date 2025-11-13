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

echo "This script will help you generate a secure Argon2 PHC hashed admin token."
echo ""
echo "You have two options:"
echo ""
echo "1. Interactive mode - You'll enter your password directly (recommended)"
echo "2. Generate random password - Script creates a random password for you"
echo ""
read -p "Choose option (1 or 2): " OPTION

if [ "$OPTION" == "2" ]; then
    # Generate random password
    ADMIN_PASSWORD=$(openssl rand -base64 32)
    echo ""
    echo "Generated random password: $ADMIN_PASSWORD"
    echo "⚠️  SAVE THIS PASSWORD - You'll need it to access the admin panel!"
    echo ""
    echo "Press Enter to continue..."
    read
fi

echo ""
echo "=========================================="
echo "Running Vaultwarden hash command..."
echo "=========================================="
echo ""

if [ "$OPTION" == "2" ]; then
    echo "The Docker container will now prompt you to enter a password."
    echo "Enter this password: $ADMIN_PASSWORD"
    echo ""
    echo "Press Enter to continue..."
    read
fi

# Run the hash command interactively
docker run --rm -it vaultwarden/server:latest /vaultwarden hash --preset owasp

echo ""
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo ""
echo "1. Copy the hash that starts with \$argon2id\$ (from above)"
echo "2. Go to your Railway dashboard"
echo "3. Navigate to your Vaultwarden service → Variables"
echo "4. Update ADMIN_TOKEN with the hash you copied"
echo "5. Save and redeploy"
echo ""
echo "6. Access admin panel at: https://your-domain.railway.app/admin"
if [ "$OPTION" == "2" ]; then
    echo "   Use password: $ADMIN_PASSWORD"
    echo ""
    echo "⚠️  IMPORTANT: Save this password somewhere secure!"
else
    echo "   Use the password you just entered"
fi
echo "=========================================="
