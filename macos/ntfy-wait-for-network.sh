#!/bin/bash
# Wrapper for ntfy subscriber that:
# 1. Waits for network connectivity before starting
# 2. Restarts ntfy every 10 minutes to prevent stale connections
#    (macOS sleep/wake silently kills the HTTP stream without ntfy detecting it)

MAX_WAIT=60
RECONNECT_INTERVAL=600  # 10 minutes

wait_for_network() {
  local waited=0
  while ! host ntfy.sh >/dev/null 2>&1; do
    sleep 2
    waited=$((waited + 2))
    if [ "$waited" -ge "$MAX_WAIT" ]; then
      echo "Network not available after ${MAX_WAIT}s, trying anyway" >&2
      break
    fi
  done
}

cleanup() {
  kill "$NTFY_PID" 2>/dev/null
  exit 0
}
trap cleanup SIGTERM SIGINT

while true; do
  wait_for_network
  /opt/homebrew/bin/ntfy subscribe --from-config &
  NTFY_PID=$!
  sleep "$RECONNECT_INTERVAL" &
  SLEEP_PID=$!
  wait "$SLEEP_PID" 2>/dev/null
  kill "$NTFY_PID" 2>/dev/null
  wait "$NTFY_PID" 2>/dev/null
done
