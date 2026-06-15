-- ==========================
-- Shared helper pattern list (used by Force Quit + Launch Indicator)
-- ==========================
local helperPatterns = {
  "webview", "renderer", "agent", "daemon", "extension", "plugin", "process", "content", "notification", "desktop", "updater", "worker",
}



-- ==========================
-- Better Force Quit Applications (with background apps and search functionality)
-- ==========================
local forceQuitChooser = nil

hs.hotkey.bind({"cmd", "alt"}, "`", function()
  local apps = hs.application.runningApplications()
  local choices = {}
  
  for _, app in ipairs(apps) do
    local name = app:name()
    local bundleID = app:bundleID()

    if name and bundleID then
      -- Convert to lowercase for robust, case-insensitive matching
      local lowerName = name:lower()
      local lowerBundle = bundleID:lower()

      -- Filter helper/extension processes from all apps
      local isHelper = false
      for _, pattern in ipairs(helperPatterns) do
        local lowerPattern = pattern:lower()
        if lowerName:find(lowerPattern, 1, true) or lowerBundle:find(lowerPattern, 1, true) then
          isHelper = true
          break
        end
      end

      if not isHelper then
        if app:kind() == 1 then
          table.insert(choices, {
            text = name,
            subText = bundleID,
            app = app,
            image = hs.image.imageFromAppBundle(bundleID)
          })
        else
          -- Keep non-Apple background apps (menu bar apps, etc.)
          if not bundleID:find("^com%.apple%.") then
            table.insert(choices, {
              text = name,
              subText = bundleID,
              app = app,
              image = hs.image.imageFromAppBundle(bundleID)
            })
          end
        end
      end
    end
  end

  local seen = {}
  local uniqueChoices = {}
  for _, choice in ipairs(choices) do
    if not seen[choice.text] then
      table.insert(uniqueChoices, choice)
      seen[choice.text] = true
    end
  end

  -- Store at module scope to prevent garbage collection before user picks
  if forceQuitChooser then forceQuitChooser:delete() end
  forceQuitChooser = hs.chooser.new(function(choice)
    forceQuitChooser = nil
    if choice and choice.app then
      choice.app:kill()
      hs.alert.show("Quit " .. choice.text)
    end
  end)
  forceQuitChooser:choices(uniqueChoices)
  forceQuitChooser:show()
end)



-- ==========================
-- Spotify in menu bar (artist and song names and media controls when clicked)
-- ==========================
local spotify = {}
local menubar = nil
local timer = nil
local updateInterval = 3
local lastTrackInfo = nil
 
function spotify.init()
    spotify.createMenuBar()
    spotify.startTimer()
end
 
function spotify.createMenuBar()
    if menubar then
        menubar:delete()
    end
    menubar = hs.menubar.new()
    
    menubar:setMenu(function()
        return spotify.createMenu()
    end)
end
 
function spotify.isSpotifyRunning()
    local success, result = pcall(function()
        local spotifyApp = hs.application.find("Spotify")
        if spotifyApp == nil then
            return false
        end
        
        local success2, isRunning = pcall(function()
            return spotifyApp:isRunning()
        end)
        
        if success2 then
            return isRunning
        else
            return false
        end
    end)
    
    if success then
        return result
    else
        return false
    end
end
 
function spotify.isSpotifyRunningAlternative()
    local result = hs.execute("pgrep -x Spotify")
    return result and result ~= ""
end
 
function spotify.getCurrentTrack()
    if not spotify.isSpotifyRunning() and not spotify.isSpotifyRunningAlternative() then
        return nil
    end
    
    local script = [[
        try
            tell application "Spotify"
                if player state is playing or player state is paused then
                    set trackName to name of current track
                    set artistName to artist of current track
                    set albumName to album of current track
                    set playerState to player state as string
                    return trackName & "||" & artistName & "||" & albumName & "||" & playerState
                else
                    return ""
                end if
            end tell
        on error
            return ""
        end try
    ]]
    
    local ok, result = hs.osascript.applescript(script)
    if ok and result and result ~= "" then
        local parts = {}
        local i = 1
        while true do
            local a, b = result:find("||", i, true)
            if not a then
                table.insert(parts, result:sub(i))
                break
            end
            table.insert(parts, result:sub(i, a - 1))
            i = b + 1
        end
        
        if #parts >= 4 then
            return {
                title = parts[1],
                artist = parts[2],
                album = parts[3],
                state = parts[4]
            }
        end
    end
    return nil
end
 
function spotify.createMenu()
    local track = spotify.getCurrentTrack()
    if not track then
        return {
            { title = "Spotify not available", disabled = true }
        }
    end
    
    local menu = {}
    
    table.insert(menu, {
        title = "🎤 " .. track.artist,
        disabled = true
    })
    table.insert(menu, {
        title = "🎵 " .. track.title,
        disabled = true
    })
    table.insert(menu, {
        title = "💽 " .. track.album,
        disabled = true
    })
    table.insert(menu, { title = "-" })
    
    local playPauseTitle = track.state == "playing" and "⏸ Pause" or "▶ Play"
    table.insert(menu, {
        title = playPauseTitle,
        fn = function()
            hs.osascript.applescript('tell application "Spotify" to playpause')
            hs.timer.doAfter(0.5, function()
                spotify.updateMenuBarDisplay()
            end)
        end
    })
    
    table.insert(menu, {
        title = "⏮ Previous Track",
        fn = function()
            hs.osascript.applescript('tell application "Spotify" to previous track')
            hs.timer.doAfter(1, function()
                spotify.updateMenuBarDisplay()
            end)
        end
    })
    
    table.insert(menu, {
        title = "⏭ Next Track",
        fn = function()
            hs.osascript.applescript('tell application "Spotify" to next track')
            hs.timer.doAfter(1, function()
                spotify.updateMenuBarDisplay()
            end)
        end
    })
    
    table.insert(menu, { title = "-" })
    
    table.insert(menu, {
        title = "🎵 Open Spotify",
        fn = function()
            hs.application.launchOrFocus("Spotify")
        end
    })
    
    return menu
end
 
function spotify.updateMenuBarDisplay()
    local success, error = pcall(function()
        if not spotify.isSpotifyRunning() and not spotify.isSpotifyRunningAlternative() then
            if menubar and menubar:isInMenuBar() then
                menubar:removeFromMenuBar()
            end
            lastTrackInfo = nil
            return
        end
        
        local track = spotify.getCurrentTrack()
        if not track then
            if menubar and menubar:isInMenuBar() then
                menubar:removeFromMenuBar()
            end
            lastTrackInfo = nil
            return
        end
        
        local currentTrackString = track.artist .. " - " .. track.title .. " - " .. track.state
        if lastTrackInfo == currentTrackString then
            return
        end
        lastTrackInfo = currentTrackString
        
        if not menubar:isInMenuBar() then
            menubar:returnToMenuBar()
        end
        
        local displayText = track.artist .. " - " .. track.title
        if #displayText > 30 then
            displayText = displayText:sub(1, 27) .. "..."
        end
 
        local stateIcon = track.state == "playing" and "" or "⏸"
        menubar:setIcon(nil)
        menubar:setTitle(stateIcon .. " " .. displayText)
    end)
    
    if not success then
    end
end
 
function spotify.startTimer()
    if timer then
        timer:stop()
    end
    
    timer = hs.timer.doEvery(updateInterval, function()
        spotify.updateMenuBarDisplay()
    end)
    timer:start()
    
    spotify.updateMenuBarDisplay()
end
 
function spotify.stop()
    if timer then
        timer:stop()
        timer = nil
    end
    if menubar then
        menubar:delete()
        menubar = nil
    end
end
 
function spotify.cleanup()
    spotify.stop()
end
 
hs.shutdownCallback = spotify.cleanup
 
spotify.init()



-- ==========================
-- Unsplash Daily Wallpaper
-- ==========================

-- Safely require secrets.lua
local hasSecrets, secrets = pcall(require, "secrets")
local ACCESS_KEY = hasSecrets and secrets.unsplash_access_key or ""

if ACCESS_KEY == "" then
  hs.notify.new({
    title = "Hammerspoon Warning",
    informativeText = "Unsplash API key is missing from secrets.lua"
  }):send()
end

local currentTask = nil
local lastChangeTime = 0

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
        scheduleNextCheck()
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
    scheduleNextCheck()
  end
end

local nextCheckTimer = nil

function scheduleNextCheck()
  if nextCheckTimer then
    nextCheckTimer:stop()
  end

  nextCheckTimer = hs.timer.doAfter(60, checkAndUpdateWallpaper)
end

scheduleNextCheck()



-- ==========================
-- Automatically switch focus to the next available window when a window is minimized
-- ==========================

-- Prevent window.filter from attempting to watch secure macOS system processes
hs.window.filter.ignoreAlways["loginwindow"] = true
hs.window.filter.ignoreAlways["ScreenSaverEngine"] = true
hs.window.filter.ignoreAlways["Control Centre"] = true
hs.window.filter.ignoreAlways["WindowManager"] = true

-- Watch for window minimization events
local wf = hs.window.filter.new()
wf:subscribe(hs.window.filter.windowMinimized, function()
    local nextWindow = hs.window.focusedWindow()
    -- If there is no focused window, or the focus is stuck on the minimized window
    if not nextWindow or nextWindow:isMinimized() then
        -- Retrieve all open windows ordered by most recently focused
        local windows = hs.window.orderedWindows()
        for _, w in ipairs(windows) do
            if w:isVisible() and not w:isMinimized() then
                w:focus() -- Switch focus to the next available window
                break
            end
        end
    end
end)



-- ==========================
-- Menu bar loading indicator for app launches
-- ==========================
local activeLaunches = {}
local launchMenu = nil
local launchTimers = {}

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
    for _, pattern in ipairs(helperPatterns) do
        if name:find(pattern, 1, true) then return true end
    end
    return false
end

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