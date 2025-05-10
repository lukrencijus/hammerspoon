-- -- Create the menubar item
-- local spotifyMenubar = hs.menubar.new()

-- -- Function to update the menubar icon
-- function updateSpotifyArtwork()
--     if hs.spotify.isRunning() and hs.spotify.isPlaying() then
--         local url = hs.spotify.getCurrentTrackArtworkURL()
--         if url then
--             local img = hs.image.imageFromURL(url)
--             if img then
--                 -- Resize image for menubar (e.g., 22x22)
--                 img = img:setSize({w=22, h=22})
--                 spotifyMenubar:setIcon(img)
--                 spotifyMenubar:setTitle("") -- Remove any text
--                 return
--             end
--         end
--     end
--     -- If not playing, show a default icon or clear
--     spotifyMenubar:setIcon(nil)
--     spotifyMenubar:setTitle("🎵")
-- end

-- -- Update every 5 seconds
-- local spotifyTimer = hs.timer.doEvery(5, updateSpotifyArtwork)
-- updateSpotifyArtwork() -- Initial call

-- -- Open or focus Spotify when clicked
-- spotifyMenubar:setClickCallback(function()
--     hs.application.launchOrFocus("Spotify")
-- end)


hs.hotkey.bind({"cmd", "alt"}, "tab", function()
  hs.hints.windowHints()
end)

hs.hotkey.bind({"cmd", "alt"}, "A", function()
  local apps = hs.application.runningApplications()
  local choices = {}
  for _, app in ipairs(apps) do
    -- Only include regular GUI apps with a bundle ID and name
    if app:kind() == 1 and app:bundleID() and app:name() and app:name() ~= "loginwindow" then
      table.insert(choices, {
        text = app:name(),
        subText = app:bundleID(),
        app = app
      })
    end
  end

  -- Remove duplicates by app name
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
      choice.app:kill() -- or use :terminate() for a gentle quit
      hs.alert.show("Quit " .. choice.text)
    end
  end)
  chooser:choices(uniqueChoices)
  chooser:show()
end)



