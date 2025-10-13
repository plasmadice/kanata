#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Check Kanata Status
# @raycast.mode fullOutput

# Optional parameters:
# @raycast.icon 🔍

# Documentation:
# @raycast.author plasmadice
# @raycast.authorURL https://github.com/plasmadice

echo "=== Checking Kanata and Dependencies Status ==="
echo ""

# Check if services are loaded
echo "📋 Loaded Services:"
sudo launchctl list | grep -E "(kanata|karabiner)" || echo "  No kanata/karabiner services found in launchctl"
echo ""

# Check if process is running
echo "🔄 Running Processes:"
if ps aux | grep -E "[k]anata" | grep -v grep; then
  echo ""
else
  echo "  Kanata process not found"
fi
echo ""

# Check recent logs
echo "📝 Recent Error Log (last 10 lines):"
if [ -f /Library/Logs/Kanata/kanata.err.log ]; then
  tail -10 /Library/Logs/Kanata/kanata.err.log
else
  echo "  No error log found"
fi
echo ""

echo "📝 Recent Output Log (last 10 lines):"
if [ -f /Library/Logs/Kanata/kanata.out.log ]; then
  tail -10 /Library/Logs/Kanata/kanata.out.log
else
  echo "  No output log found"
fi

