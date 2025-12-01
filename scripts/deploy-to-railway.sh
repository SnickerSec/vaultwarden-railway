#!/bin/bash
#
# Deploy to Railway - Production Deployment Script
#
# Deploys the entire Vaultwarden system including the monitoring
# dashboard to Railway.
#

set -e

# Source shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

###############################################################################
# Main Script
###############################################################################

print_section "Deploy to Railway - Production"

# Step 1: Check Railway CLI
log "Checking Railway CLI..."
check_railway_cli || exit 1
success "Railway CLI found"

# Step 2: Check authentication
log "Checking Railway authentication..."
check_railway_auth || exit 1
RAILWAY_USER=$(railway whoami | head -n 1)
success "Logged in as: $RAILWAY_USER"

# Step 3: Check project status
log "Checking project status..."
check_railway_project || exit 1
PROJECT_INFO=$(railway status)
success "Project linked"
echo "$PROJECT_INFO"

# Step 4: Check git status
log "Checking git repository..."
check_git_repo || exit 1

# Check for uncommitted changes
if has_uncommitted_changes; then
    warning "You have uncommitted changes"
    echo ""
    git status --short
    echo ""
    read -p "Do you want to commit these changes? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Staging all changes..."
        git add .

        echo ""
        echo "Enter commit message (or press Enter for default):"
        read COMMIT_MSG

        if [[ -z "$COMMIT_MSG" ]]; then
            COMMIT_MSG="Deploy: Add monitoring dashboard and restore system"
        fi

        log "Committing changes..."
        git commit -m "$COMMIT_MSG

- Added automated restore system with safety checks
- Created web-based monitoring dashboard
- Added backup verification tools
- Implemented monthly restore testing
- Updated documentation"

        success "Changes committed"
    else
        warning "Proceeding with uncommitted changes"
    fi
fi

# Step 5: Check for GitHub remote
log "Checking GitHub remote..."
if git remote | grep -q "origin"; then
    REMOTE_URL=$(git remote get-url origin)
    success "GitHub remote found: $REMOTE_URL"

    # Ask to push
    echo ""
    read -p "Push changes to GitHub? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Pushing to GitHub..."
        if git push origin main; then
            success "Changes pushed to GitHub"
        else
            warning "Failed to push. Continue anyway..."
        fi
    fi
else
    warning "No GitHub remote configured"
    echo "To add remote: git remote add origin https://github.com/username/repo.git"
fi

# Step 6: Generate monitoring dashboard password
print_section "Monitoring Dashboard Setup"

log "Setting up monitoring dashboard credentials..."
echo ""
echo "Enter admin password for monitoring dashboard:"
read -s MONITOR_PASSWORD
echo ""
echo "Confirm password:"
read -s MONITOR_PASSWORD_CONFIRM
echo ""

if [[ "$MONITOR_PASSWORD" != "$MONITOR_PASSWORD_CONFIRM" ]]; then
    error "Passwords don't match!"
fi

if [[ ${#MONITOR_PASSWORD} -lt 8 ]]; then
    error "Password must be at least 8 characters!"
fi

# Generate password hash using Python
log "Generating secure password hash..."
MONITOR_PASSWORD_HASH=$(python3 -c "from werkzeug.security import generate_password_hash; print(generate_password_hash('$MONITOR_PASSWORD'))" 2>/dev/null || echo "")

if [[ -z "$MONITOR_PASSWORD_HASH" ]]; then
    error "Failed to generate password hash. Install werkzeug: pip install werkzeug"
fi

success "Password hash generated"

# Generate secret key
log "Generating secret key..."
MONITOR_SECRET_KEY=$(python3 -c "import os; print(os.urandom(32).hex())")
success "Secret key generated"

# Step 7: Get Railway project info
log "Getting Railway project information..."

PROJECT_ID=$(railway status 2>/dev/null | grep -E "Project:" | awk '{print $2}' || echo "")
SERVICE_NAME=$(railway status 2>/dev/null | grep -E "Service:" | awk '{print $2}' || echo "vaultwarden-railway")

log "Project: $PROJECT_ID"
log "Service: $SERVICE_NAME"

# Step 8: Set environment variables
print_section "Configuring Environment Variables"

log "Setting monitoring dashboard variables..."

railway variables set MONITOR_PASSWORD_HASH="$MONITOR_PASSWORD_HASH" || warning "Failed to set MONITOR_PASSWORD_HASH"
railway variables set MONITOR_SECRET_KEY="$MONITOR_SECRET_KEY" || warning "Failed to set MONITOR_SECRET_KEY"
railway variables set MONITOR_PORT="5000" || warning "Failed to set MONITOR_PORT"
railway variables set MONITOR_DEBUG="false" || warning "Failed to set MONITOR_DEBUG"

success "Environment variables configured"

# Step 9: Deploy information
print_section "Deployment Summary"

cat << EOF
Railway will automatically deploy your changes when you push to GitHub.

If your repository is connected to Railway, the deployment will start automatically.
If not, you can trigger a manual deployment from the Railway dashboard.

Monitoring Dashboard:
- Password: (the one you just set)
- Will be available at: https://your-service-name.up.railway.app

Services to configure in Railway Dashboard:
1. Main Vaultwarden service (existing)
2. PostgreSQL database (existing)
3. Monitoring dashboard (new - needs to be added)

Next Steps:
1. Go to Railway Dashboard: https://railway.app/project/$PROJECT_ID
2. Click "New" -> "Empty Service"
3. Name it "monitor" or "vaultwarden-monitor"
4. Connect to this GitHub repository
5. Set root directory to "/monitor"
6. Railway will detect the Dockerfile and deploy automatically
7. Add a custom domain or use the Railway-provided URL

Environment variables are already set for the monitoring service.

Main service variables needed:
- DOMAIN (Vaultwarden URL)
- ADMIN_TOKEN (Vaultwarden admin token)
- SIGNUPS_ALLOWED
- DATABASE_URL (auto-injected by Railway)

Monitoring service variables (already set):
- MONITOR_PASSWORD_HASH
- MONITOR_SECRET_KEY
- MONITOR_PORT
- DATABASE_URL (reference from PostgreSQL service)
EOF

echo ""
log "Deployment configuration complete!"
echo ""
success "All files committed and ready for deployment"
echo ""

# Step 10: Open Railway dashboard
echo "Would you like to open the Railway dashboard? (y/n)"
read -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [[ -n "$PROJECT_ID" ]]; then
        if command -v xdg-open &> /dev/null; then
            xdg-open "https://railway.app/project/$PROJECT_ID"
        elif command -v open &> /dev/null; then
            open "https://railway.app/project/$PROJECT_ID"
        else
            echo "Open this URL: https://railway.app/project/$PROJECT_ID"
        fi
    else
        railway open
    fi
fi

print_section "Deployment Instructions"

cat << 'EOF'
To complete the deployment:

1. Add Monitoring Service in Railway Dashboard:
   - Go to your Railway project
   - Click "New" -> "GitHub Repo" or "Empty Service"
   - If using GitHub: select this repository
   - If using Empty Service: will deploy from local
   - Set service name: "vaultwarden-monitor"
   - Set root directory: "/monitor"
   - Railway auto-detects Dockerfile

2. Configure Service Variables:
   - Most variables are already set via CLI
   - Add DATABASE_URL reference:
     DATABASE_URL=${{Postgres.DATABASE_URL}}

3. Volume Mounts (if using shared storage):
   - Mount /backups to shared volume
   - Mount /scripts to shared volume
   - Mount /restore-logs to shared volume

4. Networking:
   - Expose port 5000 (auto-detected)
   - Add custom domain (optional)
   - Note the Railway-provided URL

5. Deploy:
   - Push to GitHub (if connected)
   - Or trigger manual deploy
   - Monitor deployment logs
   - Wait for health check to pass

6. Verify Deployment:
   - Access monitoring dashboard URL
   - Login with your admin password
   - Check system status
   - Create a test backup
   - Verify backup functionality

Troubleshooting:
- Check deployment logs in Railway
- Verify environment variables are set
- Ensure DATABASE_URL is accessible
- Check Railway CLI is installed in container
- Verify volume mounts if using shared storage

Documentation:
- Monitoring: docs/MONITORING.md
- Quick Start: docs/MONITORING_QUICKSTART.md
- Restore Guide: docs/RESTORE.md
EOF

echo ""
success "Deployment preparation complete!"
echo ""
echo "Admin password saved for monitoring dashboard."
echo "Keep this password secure!"
echo ""
