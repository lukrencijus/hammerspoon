local helperPatterns = {
  "webview", "renderer", "agent", "daemon", "extension", "plugin", "process", "content", "notification", "desktop", "updater", "worker",
}

local launch_indicator = {}
local activeLaunches = {}
local launchMenu = nil
local launchTimers = {}
local globalAppWatcher = nil

local function updateMenuBar()
    local currentAppName = nil
    for _, appName in pairs(activeLaunches) do
        currentAppName = appName
        break
    end

    if currentAppName then
        if not launchMenu then
            launchMenu = hs.menubar.new()
        end
        launchMenu:setTitle("⏳ " .. currentAppName)
        launchMenu:setTooltip("Launching " .. currentAppName)
    else
        if launchMenu then
            launchMenu:delete()
            launchMenu = nil
        end
    end
end

local function clearLaunch(bundleID)
    activeLaunches[bundleID] = nil
    if launchTimers[bundleID] then
        launchTimers[bundleID]:stop()
        launchTimers[bundleID] = nil
    end
    updateMenuBar()
end

local function isHelperProcess(app, name)
    if app:kind() ~= 1 then return true end
    
    local bid = app:bundleID()
    local lowerName = name and name:lower() or ""
    local lowerBid = bid and bid:lower() or ""

    for _, pattern in ipairs(helperPatterns) do
        local lowerPattern = pattern:lower()
        if lowerName:find(lowerPattern, 1, true) or lowerBid:find(lowerPattern, 1, true) then
            return true
        end
    end
    return false
end

function launch_indicator.init()
  globalAppWatcher = hs.application.watcher.new(function(appName, eventType, appObject)
      if eventType ~= hs.application.watcher.launching then return end
      if not appObject then return end

      local bid  = appObject:bundleID()
      local name = appObject:name() or appName

      if not bid or not name or name == "" then return end
      if activeLaunches[bid] then return end
      if isHelperProcess(appObject, name) then return end

      activeLaunches[bid] = name
      updateMenuBar()

      local deadline = hs.timer.secondsSinceEpoch() + 20
      local t = hs.timer.new(0.4, function()
          local ok, ready = pcall(function()
              local apps = hs.application.applicationsForBundleID(bid)
              local a = apps and apps[1]
              return a and (#a:allWindows() > 0 or a:isFrontmost())
          end)
          if (ok and ready) or hs.timer.secondsSinceEpoch() > deadline then
              clearLaunch(bid)
          end
      end)
      t:start()
      launchTimers[bid] = t
  end)
  globalAppWatcher:start()
end

return launch_indicator
