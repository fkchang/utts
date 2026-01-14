#!/bin/bash
# Prosody Demo - Hear the difference between emotions
# Usage: ./scripts/prosody-demo.sh [engine]
# Example: ./scripts/prosody-demo.sh say

ENGINE="${1:-say}"
UTTS="$(dirname "$0")/../bin/utts"

echo "=== utts Prosody Demo ==="
echo "Engine: $ENGINE"
echo ""

pause() {
  sleep 1.5
}

# Header announcement
echo "1. NEUTRAL - Baseline prosody"
$UTTS --engine "$ENGINE" --emotion neutral "This is neutral speech. Normal pace and pitch."
pause

echo "2. EXCITED - Fast and high pitched"
$UTTS --engine "$ENGINE" --emotion excited "This is excited speech. Wow, amazing!"
pause

echo "3. CELEBRATION - Moderately fast, upbeat"
$UTTS --engine "$ENGINE" --emotion celebration "This is celebration. Finally, we did it!"
pause

echo "4. SUCCESS - Warm and confident"
$UTTS --engine "$ENGINE" --emotion success "This is success. Task completed successfully."
pause

echo "5. CAUTION - Slow and low"
$UTTS --engine "$ENGINE" --emotion caution "This is caution. Warning, be careful here."
pause

echo "6. URGENT - Very fast and high"
$UTTS --engine "$ENGINE" --emotion urgent "This is urgent. Critical error detected!"
pause

echo "7. QUESTION - Slightly slower, inquiring"
$UTTS --engine "$ENGINE" --emotion question "This is a question. Waiting for your input."
pause

echo ""
echo "=== Same Message, Different Emotions ==="
echo ""

MSG="The system is ready"

echo "Neutral: $MSG"
$UTTS --engine "$ENGINE" --emotion neutral "$MSG"
pause

echo "Excited: $MSG"
$UTTS --engine "$ENGINE" --emotion excited "$MSG"
pause

echo "Urgent: $MSG"
$UTTS --engine "$ENGINE" --emotion urgent "$MSG"
pause

echo "Caution: $MSG"
$UTTS --engine "$ENGINE" --emotion caution "$MSG"
pause

echo ""
echo "=== Auto-Detection Demo ==="
echo ""

echo "Auto: 'Hello world' (should be neutral)"
$UTTS --engine "$ENGINE" "Hello world"
pause

echo "Auto: 'Finally fixed the bug!' (should be celebration)"
$UTTS --engine "$ENGINE" "Finally fixed the bug!"
pause

echo "Auto: 'Critical error in production!' (should be urgent)"
$UTTS --engine "$ENGINE" "Critical error in production!"
pause

echo "Auto: 'Warning: partial results only' (should be caution)"
$UTTS --engine "$ENGINE" "Warning: partial results only"
pause

echo "Auto: 'Wow, this is amazing!!' (should be excited)"
$UTTS --engine "$ENGINE" "Wow, this is amazing!!"
pause

echo ""
echo "=== Done ==="
