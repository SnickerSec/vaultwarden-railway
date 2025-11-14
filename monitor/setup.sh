#!/bin/bash

###############################################################################
# Vaultwarden Backup Monitor Setup Script
#
# This script sets up the monitoring dashboard with proper configuration.
###############################################################################

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo "========================================="
echo "  Vaultwarden Backup Monitor Setup"
echo "========================================="
echo ""

# Check for Python
if ! command -v python3 &> /dev/null; then
    echo -e "${YELLOW}Python 3 is not installed. Please install it first.${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Python 3 found"

# Create virtual environment
if [ ! -d "venv" ]; then
    echo -e "${BLUE}Creating virtual environment...${NC}"
    python3 -m venv venv
    echo -e "${GREEN}✓${NC} Virtual environment created"
fi

# Activate virtual environment
source venv/bin/activate

# Install dependencies
echo -e "${BLUE}Installing dependencies...${NC}"
pip install -q --upgrade pip
pip install -q -r requirements.txt
echo -e "${GREEN}✓${NC} Dependencies installed"

# Create .env file if it doesn't exist
if [ ! -f ".env" ]; then
    echo -e "${BLUE}Creating .env file...${NC}"
    cp .env.example .env

    # Generate secret key
    SECRET_KEY=$(python3 -c "import os; print(os.urandom(32).hex())")

    # Prompt for admin password
    echo ""
    echo "Please enter an admin password for the monitoring dashboard:"
    read -s ADMIN_PASSWORD
    echo ""
    echo "Confirm password:"
    read -s ADMIN_PASSWORD_CONFIRM
    echo ""

    if [ "$ADMIN_PASSWORD" != "$ADMIN_PASSWORD_CONFIRM" ]; then
        echo -e "${YELLOW}Passwords don't match. Using default password 'admin'${NC}"
        ADMIN_PASSWORD="admin"
    fi

    # Generate password hash
    PASSWORD_HASH=$(python3 -c "from werkzeug.security import generate_password_hash; print(generate_password_hash('$ADMIN_PASSWORD'))")

    # Update .env file
    sed -i "s|MONITOR_SECRET_KEY=.*|MONITOR_SECRET_KEY=$SECRET_KEY|g" .env
    sed -i "s|MONITOR_PASSWORD_HASH=.*|MONITOR_PASSWORD_HASH=$PASSWORD_HASH|g" .env

    echo -e "${GREEN}✓${NC} Configuration file created"
    echo -e "${YELLOW}Note: Admin password configured. Keep it safe!${NC}"
else
    echo -e "${GREEN}✓${NC} Configuration file already exists"
fi

# Create necessary directories
mkdir -p ../backups
mkdir -p ../restore-logs
mkdir -p ../verification-logs

echo ""
echo "========================================="
echo "  Setup Complete!"
echo "========================================="
echo ""
echo "To start the monitoring dashboard:"
echo "  1. Activate the virtual environment: source venv/bin/activate"
echo "  2. Run the application: python app.py"
echo "  3. Open your browser to: http://localhost:5000"
echo ""
echo "Default credentials:"
echo "  Password: (the one you just set)"
echo ""
echo "To change the password later:"
echo "  python -c \"from werkzeug.security import generate_password_hash; print(generate_password_hash('new-password'))\""
echo "  Then update MONITOR_PASSWORD_HASH in .env"
echo ""
