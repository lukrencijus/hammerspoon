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
 
return spotify
