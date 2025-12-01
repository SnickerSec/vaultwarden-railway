#!/bin/bash
# Debug script to test item update

export BW_PASSWORD='dysyN4NxYHMWaMs'
VAULTWARDEN_URL="https://vaultwarden-railway-production.up.railway.app"
CLIENT_ID="REDACTED_BW_CLIENT_ID"
CLIENT_SECRET="REDACTED_BW_CLIENT_SECRET"

# Configure and login
bw config server "$VAULTWARDEN_URL" 2>/dev/null || true
export BW_CLIENTID="$CLIENT_ID"
export BW_CLIENTSECRET="$CLIENT_SECRET"
bw login --apikey 2>/dev/null || echo "Already logged in"

# Unlock
export BW_SESSION=$(bw unlock --passwordenv BW_PASSWORD --raw)

echo "Session: ${BW_SESSION:0:20}..."
echo ""

# Get first item with http://
ITEM=$(bw list items --session "$BW_SESSION" | jq -r '.[] | select(.login and .login.uris != null) | select(.login.uris | any(.uri | startswith("http://"))) | .id' | head -1)

echo "Testing with item ID: $ITEM"
echo ""

# Get the full item
echo "=== Original item ==="
bw get item "$ITEM" --session "$BW_SESSION" | jq '.login.uris'
echo ""

# Try to update it
echo "=== Attempting update ==="
FULL_ITEM=$(bw get item "$ITEM" --session "$BW_SESSION")
UPDATED=$(echo "$FULL_ITEM" | jq '.login.uris |= map(if .uri | startswith("http://") then (.uri |= sub("^http://"; "https://")) else . end)')

echo "$UPDATED" > /tmp/test_update.json

echo "Updated JSON saved to /tmp/test_update.json"
echo ""

echo "=== Updated URIs ==="
cat /tmp/test_update.json | jq '.login.uris'
echo ""

echo "=== Running bw edit ==="
bw edit item "$ITEM" /tmp/test_update.json --session "$BW_SESSION"

RESULT=$?
echo ""
echo "Exit code: $RESULT"

if [ $RESULT -eq 0 ]; then
    echo "✅ Update successful!"
else
    echo "❌ Update failed!"
    echo ""
    echo "Trying with encoded input instead..."
    cat /tmp/test_update.json | bw encode | bw edit item "$ITEM" --session "$BW_SESSION"
fi

bw lock
