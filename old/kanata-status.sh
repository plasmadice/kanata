#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Kanata Status
# @raycast.mode fullOutput

# Optional parameters:
# @raycast.icon 🔍

# Documentation:
# @raycast.author plasmadice
# @raycast.authorURL https://github.com/plasmadice

echo "=== Kanata & Karabiner Status ==="
echo ""

# Check if processes are running
echo "🔄 Running Processes:"
if ps aux | grep -E "[k]anata" | grep -v grep; then
  echo ""
else
  echo "  Kanata process not found"
fi

if ps aux | grep -E "[K]arabiner.*VirtualHIDDevice" | grep -v grep; then
  echo ""
else
  echo "  Karabiner VirtualHIDDevice processes not found"
fi
echo ""

# Check service status
echo "📋 Service Status:"
launchctl list | grep -E "(kanata|karabiner)" || echo "  No matching services found"
echo ""

# Check recent logs
echo "📝 Recent Kanata Logs (last 10 lines):"
if [ -f /Library/Logs/Kanata/kanata.out.log ]; then
  tail -10 /Library/Logs/Kanata/kanata.out.log
else
  echo "  No output log found"
fi
echo ""

echo "📝 Recent Error Logs (last 10 lines):"
if [ -f /Library/Logs/Kanata/kanata.err.log ]; then
  tail -10 /Library/Logs/Kanata/kanata.err.log
else
  echo "  No error log found"
fi









