#!/bin/bash
# Shipbell notification handler for macOS
# Called by the ntfy subscriber with environment variables:
#   $NTFY_TITLE    — notification title (e.g. "✅ my-app deployed")
#   $NTFY_MESSAGE  — notification body (branch, target, commit message)
#   $NTFY_RAW      — full JSON payload from ntfy
#   $NTFY_PRIORITY — priority level (1-5)
#
# Requires: alerter (brew install vjeantet/tap/alerter)

# Extract click URL from the raw JSON payload
CLICK_URL=$(echo "$NTFY_RAW" | python3 -c "import sys,json; print(json.load(sys.stdin).get('click',''))" 2>/dev/null)

# Only open web URLs. The click value arrives over the network, so never
# pass file://, app schemes, or anything else to `open`.
case "$CLICK_URL" in
  https://*) ;;
  *) CLICK_URL="" ;;
esac

# Split message into subtitle (first line) and body (rest)
SUBTITLE=$(echo "$NTFY_MESSAGE" | head -1)
BODY=$(echo "$NTFY_MESSAGE" | tail -n +2)

# Pick sound based on priority: 5=failure, 3=success, 2=cancelled
case "$NTFY_PRIORITY" in
  5) SOUND="Basso" ;;
  2) SOUND="Funk" ;;
  *) SOUND="Glass" ;;
esac

# Show notification with View/Dismiss buttons
RESULT=$(alerter \
  --title "$NTFY_TITLE" \
  --subtitle "$SUBTITLE" \
  --message "$BODY" \
  --app-icon "$HOME/.config/shipbell/vercel-circle.png" \
  --sound "$SOUND" \
  --timeout 30 \
  --actions "View Deploy" \
  --close-label "Dismiss" \
  2>/dev/null)

# If the user clicked "View Deploy" and we have a URL, open it
if [ "$RESULT" = "View Deploy" ] && [ -n "$CLICK_URL" ]; then
  open "$CLICK_URL"
fi
