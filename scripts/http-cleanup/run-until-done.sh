#!/bin/bash
# Run fix script until all HTTP URIs are converted

echo "Starting batch conversion..."
echo ""

for i in {1..150}; do
    echo "=== Iteration $i ==="

    OUTPUT=$(./scripts/fix-http-working.sh 2>&1)

    REMAINING=$(echo "$OUTPUT" | grep "Found" | grep -o '[0-9]*' | head -1)
    SUCCESS=$(echo "$OUTPUT" | grep "Successful:" | grep -o '[0-9]*')

    echo "$OUTPUT" | grep -E "(Found|✅|❌|Successful|Failed)"

    if [ -z "$REMAINING" ] || [ "$REMAINING" = "0" ]; then
        echo ""
        echo "🎉 ALL DONE! No more HTTP URIs found."
        break
    fi

    echo "Remaining: $REMAINING"
    echo ""
    sleep 0.5
done
