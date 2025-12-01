#!/bin/bash
# Test updating a single item

export BW_PASSWORD='dysyN4NxYHMWaMs'

echo "Getting session..."
SESSION=$(bw unlock --passwordenv BW_PASSWORD --raw)

if [ -z "$SESSION" ]; then
    echo "Failed to get session"
    exit 1
fi

echo "Session obtained: ${SESSION:0:20}..."
echo ""

# Get items count
TOTAL=$(bw list items --session "$SESSION" | jq 'length')
echo "Total items in vault: $TOTAL"
echo ""

# Get first HTTP item
echo "Finding first HTTP item..."
FIRST_HTTP=$(bw list items --session "$SESSION" | jq -c '.[] | select(.type == 1) | select(.login.uris != null) | select(.login.uris | any(.uri | startswith("http://")))' | head -1)

if [ -z "$FIRST_HTTP" ]; then
    echo "No HTTP items found!"
    bw lock
    exit 0
fi

ITEM_ID=$(echo "$FIRST_HTTP" | jq -r '.id')
ITEM_NAME=$(echo "$FIRST_HTTP" | jq -r '.name')

echo "Found item: $ITEM_NAME"
echo "ID: $ITEM_ID"
echo ""

echo "=== Current URIs ==="
echo "$FIRST_HTTP" | jq '.login.uris'
echo ""

echo "=== Updated URIs (will be) ==="
echo "$FIRST_HTTP" | jq '.login.uris | map(if .uri | startswith("http://") then (.uri |= sub("^http://"; "https://")) else . end)'
echo ""

# Get full item
echo "Fetching full item..."
FULL=$(bw get item "$ITEM_ID" --session "$SESSION")

if [ -z "$FULL" ]; then
    echo "Failed to get full item"
    bw lock
    exit 1
fi

echo "Full item fetched successfully"
echo ""

# Update URIs
echo "Updating URIs..."
UPDATED=$(echo "$FULL" | jq '.login.uris |= map(if .uri | startswith("http://") then (.uri |= sub("^http://"; "https://")) else . end)')

# Save to file
echo "$UPDATED" > /tmp/item_update.json

echo "Updated item saved to /tmp/item_update.json"
echo ""

# Try update with file
echo "=== Attempting update with file ==="
bw edit item "$ITEM_ID" /tmp/item_update.json --session "$SESSION" 2>&1

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ SUCCESS!"
else
    echo ""
    echo "❌ FAILED with file method"
    echo ""
    echo "=== Trying with encode method ==="
    cat /tmp/item_update.json | bw encode | bw edit item "$ITEM_ID" --session "$SESSION" 2>&1

    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ SUCCESS with encode!"
    else
        echo ""
        echo "❌ FAILED with encode too"
    fi
fi

bw lock
