local wallpaper = {}

-- Safely require secrets.lua
local hasSecrets, secrets = pcall(require, "secrets")
local ACCESS_KEY = hasSecrets and secrets.unsplash_access_key or ""

local currentTask = nil
local nextCheckTimer = nil
local caffeinateWatcher = nil

local UPDATE_INTERVAL_HOURS = 20
local RETRY_AFTER_FAILURE_MINUTES = 15
local CHECK_INTERVAL_MINUTES = 30
local SETTINGS_KEY = "wallpaper.lastChangeTime"

local function getLastChangeTime()
  return hs.settings.get(SETTINGS_KEY) or 0
end

local function setLastChangeTime(t)
  hs.settings.set(SETTINGS_KEY, t)
end

local function setWallpaperFromURL(url)
  if currentTask then
    currentTask:terminate()
    currentTask = nil
  end

  local tmpPath = os.tmpname() .. ".jpg"

  currentTask = hs.task.new("/usr/bin/curl", function(
    exitCode,
    stdOut,
    stdErr
  )
    if exitCode == 0 then
      for _, screen in pairs(hs.screen.allScreens()) do
        screen:desktopImageURL("file://" .. tmpPath)
      end

      hs.timer.doAfter(5, function()
        os.remove(tmpPath)
        os.remove(tmpPath:gsub("%.jpg$", ""))
      end)
    end
  end, { "-L", url, "-o", tmpPath })
  currentTask:start()
end

function wallpaper.scheduleNextCheck(overrideMinutes)
  if nextCheckTimer then
    nextCheckTimer:stop()
  end

  local delaySeconds = (overrideMinutes or CHECK_INTERVAL_MINUTES) * 60
  nextCheckTimer = hs.timer.doAfter(delaySeconds, wallpaper.checkAndUpdateWallpaper)
end

local function fetchRandomFromUnsplash()
  if ACCESS_KEY == "" then return end

  local apiUrl = "https://api.unsplash.com/photos/random?client_id="
    .. ACCESS_KEY
    .. "&collections=1065976,317099,1459961,7282015"
    .. "&orientation=landscape"

  hs.http.asyncGet(apiUrl, nil, function(status, body)
    local ok = false

    if status == 200 then
      local data = hs.json.decode(body)
      if data and data.urls and data.urls.full then
        setWallpaperFromURL(data.urls.full)
        setLastChangeTime(os.time())
        ok = true
      end
    end

    if ok then
      wallpaper.scheduleNextCheck()
    else
      hs.logger.new("wallpaper"):w("Unsplash fetch failed (status: " .. tostring(status) .. "), retrying in " .. RETRY_AFTER_FAILURE_MINUTES .. " min")
      wallpaper.scheduleNextCheck(RETRY_AFTER_FAILURE_MINUTES)
    end
  end)
end

function wallpaper.checkAndUpdateWallpaper()
  local hoursSinceLastChange = (os.time() - getLastChangeTime()) / 3600

  if hoursSinceLastChange >= UPDATE_INTERVAL_HOURS then
    fetchRandomFromUnsplash()
  else
    wallpaper.scheduleNextCheck()
  end
end

function wallpaper.forceUpdate()
  fetchRandomFromUnsplash()
end

function wallpaper.init()
  if ACCESS_KEY == "" then
    hs.notify.new({
      title = "Hammerspoon Warning",
      informativeText = "Unsplash API key is missing from secrets.lua"
    }):send()
    return
  end

  if caffeinateWatcher then
    caffeinateWatcher:stop()
  end
  caffeinateWatcher = hs.caffeinate.watcher.new(function(eventType)
    if eventType == hs.caffeinate.watcher.systemDidWake then
      wallpaper.checkAndUpdateWallpaper()
    end
  end)
  caffeinateWatcher:start()

  wallpaper.checkAndUpdateWallpaper()
end

return wallpaper
