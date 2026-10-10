#!/bin/bash
# agy status check — verifies agy is responsive before launching heavy tasks
# Usage: bash tools/agy_status_check.sh

TIMEOUT=15
PROJECT="/storage/emulated/0/Games/Muakbank_zombie"

echo "=== agy Status Check ==="
echo -n "Pinging agy (timeout: ${TIMEOUT}s) ... "

# agy responds with a greeting like "How can I help..." or "Ready..."
# Check for any non-empty response from agy
RESPONSE=$(timeout $TIMEOUT agy \
    --print='Reply with exactly one word: READY' \
    --model gemini-3.8-flash-high \
    --dangerously-skip-permissions 2>&1)

EXIT=$?

if [ $EXIT -eq 0 ]; then
    # Check if response contains READY (agy should echo the requested word)
    if echo "$RESPONSE" | grep -qi "READY"; then
        echo -e "\033[0;32m✓ READY\033[0m"
        echo "Response: $RESPONSE"
        exit 0
    else
        echo -e "\033[0;33m⚠ RESPONSIVE but unexpected reply${NC}"
        echo "Response: $RESPONSE"
        echo "Agy is running but may need attention. Continue with caution."
        exit 0
    fi
elif [ $EXIT -eq 124 ]; then
    echo -e "\033[0;31m✗ TIMEOUT ($TIMEOUTs)${NC}"
    echo "Agy not responding. Kill hung processes and retry."
    echo "  pkill -9 -f agy"
    exit 1
else
    echo -e "\033[0;31m✗ FAILED (exit $EXIT)${NC}"
    echo "Response: $RESPONSE"
    echo ""
    echo "Possible causes:"
    echo "  - OAuth token expired → re-auth needed"
    echo "  - agy process hung → kill and retry"
    echo "  - No network → check connection"
    exit 1
fi
