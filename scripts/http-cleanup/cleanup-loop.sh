#!/bin/bash
# Simple loop to run cleanup 150 times

export BW_PASSWORD='dysyN4NxYHMWaMs'

echo "🔐 Starting HTTP to HTTPS cleanup..."
echo "This will run up to 150 iterations"
echo ""

for i in {1..150}; do
    echo -n "Iteration $i: "

    # Run cleanup and capture output
    OUTPUT=$(./scripts/cleanup-simple.sh 2>&1)

    # Check remaining count
    REMAINING=$(echo "$OUTPUT" | grep "Found" | grep -o '[0-9]*' | head -1)

    if [ -z "$REMAINING" ] || [ "$REMAINING" -eq 0 ]; then
        echo "✅ DONE! All items updated."
        break
    fi

    # Count successes
    SUCCESS=$(echo "$OUTPUT" | grep -c "✅" || echo "0")

    echo "$SUCCESS updated, $REMAINING remaining"

    sleep 0.5
done

echo ""
echo "✨ Cleanup complete!"
