local wallpaper = {}

-- Safely require secrets.lua
local hasSecrets, secrets = pcall(require, "secrets")
local ACCESS_KEY = hasSecrets and secrets.unsplash_access_key or ""

local currentTask = nil
local lastChangeTime = 0
local nextCheckTimer = nil

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

local function fetchRandomFromUnsplash()
  if ACCESS_KEY == "" then return end
  local http = require("hs.http")

  local apiUrl = "https://api.unsplash.com/photos/random?client_id="
    .. ACCESS_KEY
    .. "&collections=1065976,317099,1459961,7282015"
    .. "&orientation=landscape"

  http.asyncGet(apiUrl, nil, function(status, body)
    if status == 200 then
      local data = hs.json.decode(body)
      if data and data.urls and data.urls.full then
        setWallpaperFromURL(data.urls.full)
        lastChangeTime = os.time()
        wallpaper.scheduleNextCheck()
      end
    end
  end)
end

local function checkAndUpdateWallpaper()
  local currentTime = os.time()
  local hoursSinceLastChange = (currentTime - lastChangeTime) / 3600

  if hoursSinceLastChange >= 20 then
    fetchRandomFromUnsplash()
  else
    wallpaper.scheduleNextCheck()
  end
end

function wallpaper.scheduleNextCheck()
  if nextCheckTimer then
    nextCheckTimer:stop()
  end

  nextCheckTimer = hs.timer.doAfter(60, checkAndUpdateWallpaper)
end

function wallpaper.init()
  if ACCESS_KEY == "" then
    hs.notify.new({
      title = "Hammerspoon Warning",
      informativeText = "Unsplash API key is missing from secrets.lua"
    }):send()
    return
  end
  wallpaper.scheduleNextCheck()
end

return wallpaper
