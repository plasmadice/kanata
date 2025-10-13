#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Start Kanata
# @raycast.mode inline

# Optional parameters:
# @raycast.icon 🤖

# Documentation:
# @raycast.author plasmadice
# @raycast.authorURL https://github.com/plasmadice

# Retrieve password from keychain https://scriptingosx.com/2021/04/get-password-from-keychain-in-shell-scripts/
# Added with security add-generic-password -s 'kanata'  -a 'myUser' -w 'myPassword'
# Retrieve password with security find-generic-password -w -s 'kanata' -a 'myUser'
# Deleted with security delete-generic-password -s 'kanata' -a 'myUser'

# Name of the password in the keychain
pw_name="supa" # name of the password in the keychain
# current username e.g. "viper"
pw_account=$(id -un)

if ! cli_password=$(security find-generic-password -w -s "$pw_name" -a "$pw_account"); then
  echo "❌ Could not get password (error $?)"
  exit 1
fi

# First, ensure dependencies are loaded
echo "Starting Karabiner dependencies..."

daemon_output=$(echo "$cli_password" | sudo -S -k launchctl bootstrap system /Library/LaunchDaemons/com.example.karabiner-vhiddaemon.plist 2>&1)
daemon_exit=$?

manager_output=$(echo "$cli_password" | sudo -S launchctl bootstrap system /Library/LaunchDaemons/com.example.karabiner-vhidmanager.plist 2>&1)
manager_exit=$?

# Check if dependencies loaded successfully or were already loaded
if [ $daemon_exit -ne 0 ] && ! echo "$daemon_output" | grep -q "Already loaded"; then
  echo "⚠️  Warning: Karabiner daemon may not have started:"
  echo "$daemon_output"
fi

if [ $manager_exit -ne 0 ] && ! echo "$manager_output" | grep -q "Already loaded"; then
  echo "⚠️  Warning: Karabiner manager may not have started:"
  echo "$manager_output"
fi

# Give dependencies a moment to start
sleep 2

# Verify at least one Karabiner process is running
if ! ps aux | grep -E "[K]arabiner.*VirtualHIDDevice" > /dev/null; then
  echo "❌ Error: Karabiner VirtualHIDDevice not running!"
  echo "   Kanata requires Karabiner-DriverKit-VirtualHIDDevice to be installed and activated."
  exit 1
fi

# Try to bootstrap Kanata and capture any error
error_output=$(echo "$cli_password" | sudo -S launchctl bootstrap system /Library/LaunchDaemons/com.example.kanata.plist 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
  echo "✅ Kanata started successfully!"
elif echo "$error_output" | grep -q "Already loaded"; then
  echo "⚠️  Kanata is already running!"
  exit 0
else
  echo "❌ Failed to start Kanata:"
  echo "$error_output"
  exit 1
fi
