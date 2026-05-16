#!/bin/bash
# Prevent macOS sleep while any claude process is running.
# Managed by launchd: com.claude.caffeinate

CAFFEINATE_PID=""

cleanup() {
  if [ -n "$CAFFEINATE_PID" ] && kill -0 "$CAFFEINATE_PID" 2>/dev/null; then
    kill "$CAFFEINATE_PID"
  fi
  exit 0
}
trap cleanup SIGTERM SIGINT

while true; do
  if pgrep -x 'claude' >/dev/null 2>&1; then
    if [ -z "$CAFFEINATE_PID" ] || ! kill -0 "$CAFFEINATE_PID" 2>/dev/null; then
      caffeinate -dims &
      CAFFEINATE_PID=$!
    fi
  else
    if [ -n "$CAFFEINATE_PID" ] && kill -0 "$CAFFEINATE_PID" 2>/dev/null; then
      kill "$CAFFEINATE_PID"
      CAFFEINATE_PID=""
    fi
  fi
  sleep 10
done
