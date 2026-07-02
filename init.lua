-- ==========================================
-- Hammerspoon Configuration Entry Point
-- ==========================================

-- Add the 'modules' directory to the Lua path package so we can require them cleanly
package.path = package.path .. ";" .. hs.configdir .. "/modules/?.lua"

-- Import our modular features
local forceQuit       = require("force_quit")
local spotify         = require("spotify")
local wallpaper       = require("wallpaper")
local windowFocus     = require("window_focus")
local launchIndicator = require("launch_indicator")

-- Initialize all components
forceQuit.init()
spotify.init()
wallpaper.init()
wallpaper.forceUpdate()
windowFocus.init()
launchIndicator.init()

-- Set up global shutdown callbacks for features requiring cleanup
hs.shutdownCallback = function()
  if spotify and spotify.cleanup then
    spotify.cleanup()
  end
end

-- Notify that reload was successful
hs.alert.show("Hammerspoon configuration reloaded!")
