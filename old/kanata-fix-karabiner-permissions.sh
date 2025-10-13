#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Fix Karabiner Permissions
# @raycast.mode fullOutput

# Optional parameters:
# @raycast.icon 🔧

# Documentation:
# @raycast.author plasmadice
# @raycast.authorURL https://github.com/plasmadice

echo "=== Fixing Karabiner Permissions ==="
echo ""

# Name of the password in the keychain
pw_name="supa"
pw_account=$(id -un)

if ! cli_password=$(security find-generic-password -w -s "$pw_name" -a "$pw_account"); then
  echo "❌ Could not get password"
  exit 1
fi

echo "1️⃣ Fixing file permissions..."
echo "$cli_password" | sudo -S chmod +x "/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon"
echo "$cli_password" | sudo -S chmod +x "/Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager"

echo ""
echo "2️⃣ Fixing plist file permissions..."
echo "$cli_password" | sudo -S chmod 644 /Library/LaunchDaemons/com.example.karabiner-vhiddaemon.plist
echo "$cli_password" | sudo -S chmod 644 /Library/LaunchDaemons/com.example.karabiner-vhidmanager.plist
echo "$cli_password" | sudo -S chown root:wheel /Library/LaunchDaemons/com.example.karabiner-vhiddaemon.plist
echo "$cli_password" | sudo -S chown root:wheel /Library/LaunchDaemons/com.example.karabiner-vhidmanager.plist

echo ""
echo "3️⃣ Validating plist files..."
if plutil -lint /Library/LaunchDaemons/com.example.karabiner-vhiddaemon.plist; then
  echo "   ✅ Daemon plist is valid"
else
  echo "   ❌ Daemon plist has errors"
fi

if plutil -lint /Library/LaunchDaemons/com.example.karabiner-vhidmanager.plist; then
  echo "   ✅ Manager plist is valid"
else
  echo "   ❌ Manager plist has errors"
fi

echo ""
echo "4️⃣ Trying to start services with proper permissions..."

# First try to unload any existing services
echo "$cli_password" | sudo -S launchctl bootout system /Library/LaunchDaemons/com.example.karabiner-vhiddaemon.plist 2>/dev/null || true
echo "$cli_password" | sudo -S launchctl bootout system /Library/LaunchDaemons/com.example.karabiner-vhidmanager.plist 2>/dev/null || true

sleep 1

# Try to start them
echo "   Starting daemon..."
daemon_output=$(echo "$cli_password" | sudo -S launchctl bootstrap system /Library/LaunchDaemons/com.example.karabiner-vhiddaemon.plist 2>&1)
if [ $? -eq 0 ]; then
  echo "   ✅ Daemon started successfully"
elif echo "$daemon_output" | grep -q "Already loaded"; then
  echo "   ⚠️  Daemon already loaded"
else
  echo "   ❌ Daemon failed: $daemon_output"
fi

echo "   Starting manager..."
manager_output=$(echo "$cli_password" | sudo -S launchctl bootstrap system /Library/LaunchDaemons/com.example.karabiner-vhidmanager.plist 2>&1)
if [ $? -eq 0 ]; then
  echo "   ✅ Manager started successfully"
elif echo "$manager_output" | grep -q "Already loaded"; then
  echo "   ⚠️  Manager already loaded"
else
  echo "   ❌ Manager failed: $manager_output"
fi

echo ""
echo "5️⃣ Checking service status..."
echo "   Daemon status:"
echo "$cli_password" | sudo -S launchctl print system/com.example.karabiner-vhiddaemon 2>&1 | head -5 || echo "   Service not found"

echo ""
echo "   Manager status:"
echo "$cli_password" | sudo -S launchctl print system/com.example.karabiner-vhidmanager 2>&1 | head -5 || echo "   Service not found"

echo ""
echo "6️⃣ Checking running processes..."
ps aux | grep -E "[K]arabiner.*VirtualHIDDevice" | grep -v grep || echo "   No Karabiner processes found"

echo ""
echo "=== Done ==="

