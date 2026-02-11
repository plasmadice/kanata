-- Kanata monitoring service for Hammerspoon
-- This service monitors for new Kanata devices and restarts Kanata when detected

--[[
====================================
USER CONFIGURATION - EDIT THIS
====================================
--]]

-- REQUIRED: Path to your kanata-restart script
-- local restartScript = "/path/to/kanata-restart.sh"
local restartScript = os.getenv("HOME") .. "/Repos/box/raycast/scripts/kanata-restart.sh"

-- OPTIONAL: Path to your Kanata config file (for parsing macos-dev-names-exclude)
-- If not set, all devices will trigger monitoring
-- I noticed a mouse was restarting kanata while the machine was asleep
-- Set to empty string ("") or nil to disable config parsing
-- local kanataConfigPath = nil
local kanataConfigPath = os.getenv("HOME") .. "/.config/kanata/kanata.kbd"

-- NO REAL IMPACT: Move hammerspoon config file location
-- defaults write org.hammerspoon.Hammerspoon MJConfigFile "~/.config/hammerspoon/init.lua"
-- Remember to restart hammerspoon and move the file to the new location (new folder is NOT .hidden)

--[[
====================================
DO NOT EDIT BELOW THIS LINE
====================================
--]]
hs.allowAppleScript(true) -- Raycast allows AppleScript to access the Hammerspoon API

local checkInterval = 5 -- seconds (interval between device checks)
local kanataWatcher = nil
local isMonitoring = false
local wasMonitoringBeforeSleep = false
local excludedDevices = {} -- Devices to exclude from monitoring (parsed from config)
local includedDevices = {} -- Devices to include for monitoring (parsed from config)
local useIncludeList = false -- If true, only monitor devices in includedDevices

-- Logging function
function log(message)
  hs.printf("[Kanata Monitor] %s", message)
end

-- Parse Kanata config file for included and excluded devices
function parseDeviceLists(logDevices)
  local excluded = {}
  local included = {}
  
  -- Check if config path is set
  if not kanataConfigPath or kanataConfigPath == "" then
    return excluded, included
  end
  
  -- Check if config file exists
  local file = io.open(kanataConfigPath, "r")
  if not file then
    if logDevices then
      log("WARNING: Could not open Kanata config file at: " .. kanataConfigPath)
    end
    return excluded, included
  end
  
  local content = file:read("*all")
  file:close()
  
  -- Look for macos-dev-names-include and macos-dev-names-exclude sections
  local inIncludeSection = false
  local inExcludeSection = false
  
  for line in content:gmatch("[^\r\n]+") do
    -- Trim whitespace
    line = line:match("^%s*(.-)%s*$")
    
    -- Check if we're entering the include section
    if line:match("macos%-dev%-names%-include%s*%(") then
      inIncludeSection = true
      inExcludeSection = false
    -- Check if we're entering the exclude section
    elseif line:match("macos%-dev%-names%-exclude%s*%(") then
      inExcludeSection = true
      inIncludeSection = false
    -- Check if we're exiting a section
    elseif (inIncludeSection or inExcludeSection) and line:match("^%)") then
      inIncludeSection = false
      inExcludeSection = false
    -- Extract device names
    elseif inIncludeSection then
      local deviceName = line:match('"([^"]+)"')
      if deviceName then
        table.insert(included, deviceName)
        if logDevices then
          log("Including device for monitoring: " .. deviceName)
        end
      end
    elseif inExcludeSection then
      local deviceName = line:match('"([^"]+)"')
      if deviceName then
        table.insert(excluded, deviceName)
        if logDevices then
          log("Excluding device from monitoring: " .. deviceName)
        end
      end
    end
  end
  
  return excluded, included
end

-- Reload device lists from config and log if changed
function reloadDeviceLists()
  local newExcluded, newIncluded = parseDeviceLists(false)
  
  -- Check if lists have changed
  local hasChanged = false
  
  -- Check excluded list
  if #newExcluded ~= #excludedDevices then
    hasChanged = true
  else
    local oldSet = {}
    for _, device in ipairs(excludedDevices) do
      oldSet[device] = true
    end
    for _, device in ipairs(newExcluded) do
      if not oldSet[device] then
        hasChanged = true
        break
      end
    end
  end
  
  -- Check included list
  if not hasChanged then
    if #newIncluded ~= #includedDevices then
      hasChanged = true
    else
      local oldSet = {}
      for _, device in ipairs(includedDevices) do
        oldSet[device] = true
      end
      for _, device in ipairs(newIncluded) do
        if not oldSet[device] then
          hasChanged = true
          break
        end
      end
    end
  end
  
  -- Update and log if changed
  if hasChanged then
    excludedDevices = newExcluded
    includedDevices = newIncluded
    useIncludeList = #includedDevices > 0
    
    if useIncludeList then
      log("Device monitoring mode: INCLUDE list (only monitor listed devices)")
      log("Included devices:")
      for _, device in ipairs(includedDevices) do
        log("  - " .. device)
      end
    elseif #excludedDevices > 0 then
      log("Device monitoring mode: EXCLUDE list (monitor all except listed)")
      log("Excluded devices:")
      for _, device in ipairs(excludedDevices) do
        log("  - " .. device)
      end
    else
      log("Device monitoring mode: ALL devices (no include/exclude list)")
    end
  end
end

-- Check if a device should be monitored based on include/exclude lists
function shouldMonitorDevice(deviceName)
  -- If include list exists, only monitor devices in the include list
  if useIncludeList then
    for _, included in ipairs(includedDevices) do
      if deviceName == included then
        return true
      end
    end
    return false -- Not in include list, so don't monitor
  end
  
  -- Otherwise, monitor all devices except those in exclude list
  for _, excluded in ipairs(excludedDevices) do
    if deviceName == excluded then
      return false -- In exclude list, so don't monitor
    end
  end
  
  return true -- Not excluded, so monitor
end

-- Check if Kanata is available
function isKanataAvailable()
  local result = hs.execute("which kanata 2>/dev/null")
  return result ~= nil and result ~= ""
end

-- Run the restart script
function restartKanata(newDevices, suppressLog)
  if not isKanataAvailable() then
    log("ERROR: Kanata not available, stopping monitoring service")
    stopKanataMonitoring()
    hs.alert.show("Kanata not available!\nStopping monitoring service.")
    return
  end
  
  local deviceList = table.concat(newDevices, ", ")
  log("New device(s) detected: " .. deviceList .. " - Restarting Kanata")
  
  -- Run restart script with quiet flag to suppress "Service already running" messages
  local args = {}
  if suppressLog then
    table.insert(args, "--quiet")
  end
  
  local task = hs.task.new(restartScript, function(exitCode, stdOut, stdErr)
    if exitCode ~= 0 then
      log("ERROR: Restart script failed with exit code " .. tostring(exitCode))
    end
  end, args)
  task:start()
end

-- Get Kanata device list as a table of names
function getKanataDeviceList()
  if not isKanataAvailable() then
    return {}
  end
  
  local output = hs.execute("kanata -l 2>/dev/null")
  local devices = {}
  for line in output:gmatch("[^\r\n]+") do
    line = line:match("^%s*(.-)%s*$")  -- trim whitespace
    if line ~= "" then
      devices[line] = true
    end
  end
  return devices
end

-- Compare old and new lists, return lists of new and removed device names
function getDeviceChanges(prev, curr)
  local added = {}
  local removed = {}
  
  -- Find added devices (only devices we should monitor)
  for name, _ in pairs(curr) do
    if not prev[name] and shouldMonitorDevice(name) then
      table.insert(added, name)
    end
  end
  
  -- Find removed devices (only devices we should monitor)
  for name, _ in pairs(prev) do
    if not curr[name] and shouldMonitorDevice(name) then
      table.insert(removed, name)
    end
  end
  
  return added, removed
end

-- Start Kanata monitoring service
function startKanataMonitoring(suppressLog)
  if isMonitoring then
    if not suppressLog then
      log("Monitoring service already running")
    end
    return
  end
  
  if not isKanataAvailable() then
    log("ERROR: Cannot start monitoring - Kanata not available")
    hs.alert.show("Cannot start Kanata monitoring!\nKanata is not installed or not in PATH.")
    return
  end
  
  log("Starting Kanata monitoring service")
  isMonitoring = true
  
  -- Initialize device list
  local prevDevices = getKanataDeviceList()
  
  kanataWatcher = hs.timer.doEvery(checkInterval, function()
    if not isKanataAvailable() then
      log("ERROR: Kanata no longer available, stopping monitoring service")
      stopKanataMonitoring()
      hs.alert.show("Kanata monitoring stopped!\nKanata is no longer available.")
      return
    end
    
    local currDevices = getKanataDeviceList()
    local newDevices, removedDevices = getDeviceChanges(prevDevices, currDevices)

    -- Log removed devices
    if #removedDevices > 0 then
      local removedList = table.concat(removedDevices, ", ")
      log("Device(s) removed: " .. removedList)
    end

    -- Restart if new devices detected
    if #newDevices > 0 then
      restartKanata(newDevices, true)
    end

    prevDevices = currDevices
  end)
  
  hs.alert.show("Kanata monitoring started")
end

-- Stop Kanata monitoring service
function stopKanataMonitoring(suppressAlert)
  if not isMonitoring then
    if not suppressAlert then
      log("Monitoring service not running")
    end
    return
  end
  
  log("Stopping Kanata monitoring service")
  isMonitoring = false
  
  if kanataWatcher then
    kanataWatcher:stop()
    kanataWatcher = nil
  end
  
  if not suppressAlert then
    hs.alert.show("Kanata monitoring stopped")
  end
end

-- Toggle Kanata monitoring service
function toggleKanataMonitoring()
  if isMonitoring then
    stopKanataMonitoring()
  else
    startKanataMonitoring()
  end
end

-- Handle sleep/wake events
function handleSleepEvent()
  if isMonitoring then
    log("Device going to sleep - stopping monitoring service")
    wasMonitoringBeforeSleep = true
    stopKanataMonitoring(true) -- Suppress alert
  end
end

function handleWakeEvent()
  if wasMonitoringBeforeSleep then
    log("Device woke up - restarting monitoring service")
    wasMonitoringBeforeSleep = false
    startKanataMonitoring(true) -- Suppress "already running" message
  end
end

-- URL scheme handlers
hs.urlevent.bind("kanata", function(eventName, params)
  local action = params["action"]
  local suppressLog = params["suppressLog"] == "true"
  if action == "start" then
    startKanataMonitoring(suppressLog)
  elseif action == "stop" then
    stopKanataMonitoring()
  elseif action == "toggle" then
    toggleKanataMonitoring()
  else
    log("ERROR: Unknown action: " .. tostring(action))
  end
end)

-- Set up sleep/wake event handlers
hs.caffeinate.watcher.new(function(eventType)
  if eventType == hs.caffeinate.watcher.systemDidSleep then
    handleSleepEvent()
  elseif eventType == hs.caffeinate.watcher.systemDidWake then
    handleWakeEvent()
  end
end):start()

-- Initialize - monitoring service starts disabled by default
log("Kanata monitoring service loaded")
log("Status: " .. (isMonitoring and "ENABLED" or "DISABLED (by default)"))
log("Use 'hammerspoon://kanata?action=start' to enable monitoring")

-- Parse device lists from Kanata config file
if not kanataConfigPath or kanataConfigPath == "" then
  log("NOTE: Kanata config path not set - device filtering preferences cannot be determined")
  log("      Set kanataConfigPath in the configuration section to enable device filtering")
else
  excludedDevices, includedDevices = parseDeviceLists(true)
  useIncludeList = #includedDevices > 0
  
  if useIncludeList then
    log("Loaded " .. #includedDevices .. " included device(s) from config (INCLUDE mode)")
  elseif #excludedDevices > 0 then
    log("Loaded " .. #excludedDevices .. " excluded device(s) from config (EXCLUDE mode)")
  else
    log("No device filtering found in config (monitoring ALL devices)")
  end
end

-- Set up watcher for Kanata config file changes (only if config path is provided)
if kanataConfigPath and kanataConfigPath ~= "" then
  local kanataConfigDir = kanataConfigPath:match("(.*/)")
  local kanataConfigFilename = kanataConfigPath:match("([^/]+)$")
  
  if kanataConfigDir and kanataConfigFilename then
    -- Debounce timer to prevent multiple restarts on rapid file changes
    local configChangeTimer = nil
    
    hs.pathwatcher.new(kanataConfigDir, function(files)
      for _, file in ipairs(files) do
        -- Check if the changed file matches our config file
        if file == kanataConfigPath or file:match(kanataConfigFilename .. "$") then
          -- Cancel existing timer if it exists
          if configChangeTimer then
            configChangeTimer:stop()
          end
          
          -- Set new timer to process after 500ms of no changes (debounce)
          configChangeTimer = hs.timer.doAfter(0.5, function()
            -- Only process if monitoring is enabled
            if isMonitoring then
              log("Kanata config file changed - validating configuration")
              hs.alert.show("Validating Kanata configuration...")
              
              -- Reload device lists first
              reloadDeviceLists()
              
              -- Validate the config with --check
              local checkCmd = "kanata -c " .. kanataConfigPath .. " --nodelay --check 2>&1"
              local checkOutput, checkStatus = hs.execute(checkCmd)
              
              if checkStatus then
                -- Config is valid, proceed with restart
                log("Config validation passed - restarting Kanata")
                hs.alert.show("Success! Restarting Kanata")
                
                -- Run restart script with quiet flag to suppress standard output
                local task = hs.task.new(restartScript, function(exitCode, stdOut, stdErr)
                  if exitCode == 0 then
                    log("Kanata restarted successfully after config change")
                  else
                    log("ERROR: Failed to restart Kanata after config change (exit code: " .. tostring(exitCode) .. ")")
                    hs.alert.show("Failed to restart Kanata!\nCheck console for details")
                  end
                end, {"--quiet"})
                task:start()
              else
                -- Config has errors, show them to user
                log("ERROR: Config validation failed:")
                log(checkOutput)
                
                -- Show error alert with first line of error
                local firstLine = checkOutput:match("^(.-)\n") or checkOutput
                hs.alert.show("Kanata config error!\n" .. firstLine:sub(1, 100))
                
                -- Show detailed notification
                hs.notify.new({
                  title = "Kanata Config Error",
                  informativeText = checkOutput:sub(1, 500),
                  soundName = "Basso"
                }):send()
              end
            else
              -- Monitoring is disabled, just log the change
              log("Kanata config file changed (monitoring disabled - no action taken)")
            end
            
            configChangeTimer = nil
          end)
          break
        end
      end
    end):start()
    
    log("Watching Kanata config file: " .. kanataConfigPath)
  end
end

