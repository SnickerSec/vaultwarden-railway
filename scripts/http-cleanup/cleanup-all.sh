#!/bin/bash
# Batch cleanup script - runs until all HTTP URIs are converted

set -e

export BW_PASSWORD='dysyN4NxYHMWaMs'

TOTAL_UPDATED=0
ITERATION=1

echo "🔐 Vaultwarden HTTP to HTTPS Batch Cleanup"
echo "=========================================="
echo ""

while true; do
    echo "🔄 Iteration $ITERATION"
    echo "---"

    # Run the cleanup script
    OUTPUT=$(./scripts/cleanup-simple.sh 2>&1)

    # Check how many items remain
    REMAINING=$(echo "$OUTPUT" | grep "Found [0-9]* items" | grep -o '[0-9]*' || echo "0")

    if [ "$REMAINING" -eq 0 ]; then
        echo ""
        echo "✅ All HTTP URIs have been converted to HTTPS!"
        echo "📊 Total items updated: $TOTAL_UPDATED"
        break
    fi

    echo "Remaining: $REMAINING items"

    # Count successful updates in this iteration
    SUCCESS=$(echo "$OUTPUT" | grep -c "✅" || echo "0")
    TOTAL_UPDATED=$((TOTAL_UPDATED + SUCCESS))

    echo "Updated this iteration: $SUCCESS"
    echo ""

    # Increment iteration
    ITERATION=$((ITERATION + 1))

    # Safety limit
    if [ $ITERATION -gt 200 ]; then
        echo "⚠️  Reached iteration limit. Some items may still remain."
        echo "📊 Total updated: $TOTAL_UPDATED"
        break
    fi

    # Small delay to avoid rate limiting
    sleep 1
done

echo ""
echo "======================================"
echo "✨ Cleanup complete!"
echo "======================================"
