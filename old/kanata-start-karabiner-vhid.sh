#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Start Karabiner VirtualHIDDevice
# @raycast.mode fullOutput

# Optional parameters:
# @raycast.icon 🎹

# Documentation:
# @raycast.author plasmadice
# @raycast.authorURL https://github.com/plasmadice

# Name of the password in the keychain
pw_name="supa"
pw_account=$(id -un)

if ! cli_password=$(security find-generic-password -w -s "$pw_name" -a "$pw_account"); then
  echo "❌ Could not get password (error $?)"
  exit 1
fi

echo "=== Starting Karabiner VirtualHIDDevice Services ==="
echo ""

# Check if DriverKit extension is running
echo "1️⃣ Checking DriverKit extension..."
if ps aux | grep -E "[K]arabiner-DriverKit-VirtualHIDDevice\.dext" > /dev/null; then
  echo "   ✅ DriverKit extension is running"
else
  echo "   ❌ DriverKit extension NOT found!"
  echo "   Please activate it in System Settings > Privacy & Security"
  exit 1
fi
echo ""

# Start daemon
echo "2️⃣ Starting Karabiner VirtualHIDDevice Daemon..."
daemon_output=$(echo "$cli_password" | sudo -S -k launchctl bootstrap system /Library/LaunchDaemons/com.example.karabiner-vhiddaemon.plist 2>&1)
daemon_exit=$?

if [ $daemon_exit -eq 0 ]; then
  echo "   ✅ Daemon loaded successfully"
elif echo "$daemon_output" | grep -q "Already loaded"; then
  echo "   ⚠️  Daemon already loaded"
else
  echo "   ❌ Failed to load daemon:"
  echo "$daemon_output"
fi
echo ""

# Wait a moment
sleep 1

# Start manager
echo "3️⃣ Starting Karabiner VirtualHIDDevice Manager..."
manager_output=$(echo "$cli_password" | sudo -S launchctl bootstrap system /Library/LaunchDaemons/com.example.karabiner-vhidmanager.plist 2>&1)
manager_exit=$?

if [ $manager_exit -eq 0 ]; then
  echo "   ✅ Manager loaded successfully"
elif echo "$manager_output" | grep -q "Already loaded"; then
  echo "   ⚠️  Manager already loaded"
else
  echo "   ❌ Failed to load manager:"
  echo "$manager_output"
fi
echo ""

# Wait for processes to start
sleep 2

# Check running processes
echo "4️⃣ Checking running processes..."
ps aux | grep -E "[K]arabiner.*VirtualHIDDevice" | grep -v grep
echo ""

# Check service status
echo "5️⃣ Checking service status..."
echo ""
echo "Daemon status:"
echo "$cli_password" | sudo -S launchctl print system/com.example.karabiner-vhiddaemon 2>&1 | head -20
echo ""
echo "Manager status:"
echo "$cli_password" | sudo -S launchctl print system/com.example.karabiner-vhidmanager 2>&1 | head -20
echo ""

echo "=== Done ==="

