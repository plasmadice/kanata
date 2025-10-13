#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Stop Kanata
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

# Try to bootout Kanata and capture any error
error_output=$(echo "$cli_password" | sudo -S -k launchctl bootout system /Library/LaunchDaemons/com.example.kanata.plist 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
  echo "✅ Kanata stopped successfully!"
elif echo "$error_output" | grep -q "Could not find service"; then
  echo "⚠️  Kanata is not running!"
  exit 0
else
  echo "❌ Failed to stop Kanata:"
  echo "$error_output"
  exit 1
fi
