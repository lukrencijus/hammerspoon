-- ==========================
-- Better Force Quit Applications (with background apps and search functionality)
-- ==========================
hs.hotkey.bind({"cmd", "alt"}, "`", function()
  local apps = hs.application.runningApplications()
  local choices = {}
  for _, app in ipairs(apps) do
    local name = app:name()
    local bundleID = app:bundleID()
    if app:kind() == 1 then
      if name and bundleID then
        table.insert(choices, {
          text = name,
          subText = bundleID,
          app = app,
          image = hs.image.imageFromAppBundle(bundleID)
        })
      end
    else
      if name and bundleID and not bundleID:find("^com%.apple%.") then
        table.insert(choices, {
          text = name,
          subText = bundleID,
          app = app,
          image = hs.image.imageFromAppBundle(bundleID)
        })
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

  local chooser = hs.chooser.new(function(choice)
    if choice and choice.app then
      choice.app:kill()
      hs.alert.show("Quit " .. choice.text)
    end
  end)
  chooser:choices(uniqueChoices)
  chooser:show()
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
        print("Error checking Spotify status: " .. tostring(result))
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
        for part in string.gmatch(result, "([^||]+)") do
            table.insert(parts, part)
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
                print("Spotify not running - hiding menu bar item")
            end
            lastTrackInfo = nil
            return
        end
        
        local track = spotify.getCurrentTrack()
        if not track then
            if menubar and menubar:isInMenuBar() then
                menubar:removeFromMenuBar()
                print("No track info available - hiding menu bar item")
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
            print("Showing menu bar item for: " .. track.artist .. " - " .. track.title)
        end
        
        local displayText = track.artist .. " - " .. track.title
        if string.len(displayText) > 45 then
            displayText = string.sub(displayText, 1, 42) .. "..."
        end
        
        local stateIcon = track.state == "playing" and "" or "⏸"
        menubar:setIcon(nil)
        menubar:setTitle(stateIcon .. " " .. displayText)
    end)
    
    if not success then
        print("Error updating menu bar display: " .. tostring(error))
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
    print("Spotify menu bar integration stopped")
end

hs.shutdownCallback = spotify.cleanup

spotify.init()



-- ==========================
-- Unsplash Daily Wallpaper
-- ==========================
local ACCESS_KEY = "Axj4KOYrIzX2r67ymh4U4jKb0RU2g6yjSH6xLg4PHlU"

local currentTask = nil
local lastChangeTime = 0

local function setWallpaperFromURL(url)
  if currentTask then
    currentTask:terminate()
    currentTask = nil
  end

  local tmpPath = os.tmpname() .. ".jpg"
  print("Saving wallpaper temp file at:", tmpPath)

  currentTask = hs.task.new("/usr/bin/curl", function(
    exitCode,
    stdOut,
    stdErr
  )
    if exitCode == 0 then
      for _, screen in pairs(hs.screen.allScreens()) do
        screen:desktopImageURL("file://" .. tmpPath)
        print("Wallpaper updated on " .. screen:name() .. " ✅")
      end

      hs.timer.doAfter(5, function()
        os.remove(tmpPath)
        os.remove(tmpPath:gsub("%.jpg$", ""))
        print("Temp files deleted 🗑️")
      end)
    else
      print("curl failed:", stdErr)
    end
  end, { "-L", url, "-o", tmpPath })
  currentTask:start()
end

local function fetchRandomFromUnsplash()
  local http = require("hs.http")

  local apiUrl = "https://api.unsplash.com/photos/random?client_id="
    .. ACCESS_KEY
    .. "&collections=1065976,317099,1459961,7282015"
    .. "&orientation=landscape"

  http.asyncGet(apiUrl, nil, function(status, body, headers)
    if status == 200 then
      local data = hs.json.decode(body)
      if data and data.urls and data.urls.full then
        print("Fetched random image:", data.urls.full)
        setWallpaperFromURL(data.urls.full)
        lastChangeTime = os.time()
        print("Updated lastChangeTime to:", lastChangeTime)
        
        -- Schedule next check
        scheduleNextCheck()
      else
        print("Error: Unexpected Unsplash API response")
      end
    else
      print("Unsplash API error:", status, body)
    end
  end)
end

local function checkAndUpdateWallpaper()
  local currentTime = os.time()
  local hoursSinceLastChange = (currentTime - lastChangeTime) / 3600

  print(
    string.format(
      "⏰ Check triggered - %.1f hours since last change",
      hoursSinceLastChange
    )
  )

  if hoursSinceLastChange >= 20 then
    print("20+ hours passed, updating wallpaper...")
    fetchRandomFromUnsplash()
  else
    print(
      string.format(
        "Only %.1f hours since last change, skipping...",
        hoursSinceLastChange
      )
    )
    -- Schedule next check even if we skip
    scheduleNextCheck()
  end
end

-- Use delayed timer that reschedules itself
local nextCheckTimer = nil

function scheduleNextCheck()
  if nextCheckTimer then
    nextCheckTimer:stop()
  end
  
  print("📅 Scheduling next check in 1 hour...")
  nextCheckTimer = hs.timer.doAfter(60 * 60, function()
    checkAndUpdateWallpaper()
  end)
end

-- Start the chain
scheduleNextCheck()

-- Manual trigger
hs.hotkey.bind({ "cmd", "alt" }, "W", function()
  print("🔥 Manual trigger pressed")
  fetchRandomFromUnsplash()
end)

print("📸 Wallpaper module loaded")
print("Initial lastChangeTime:", lastChangeTime)