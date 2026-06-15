local window_focus = {}

function window_focus.init()
  -- Prevent window.filter from attempting to watch secure macOS system processes
  hs.window.filter.ignoreAlways["loginwindow"] = true
  hs.window.filter.ignoreAlways["ScreenSaverEngine"] = true
  hs.window.filter.ignoreAlways["Control Centre"] = true
  hs.window.filter.ignoreAlways["WindowManager"] = true

  -- Watch for window minimization events
  local wf = hs.window.filter.new()
  wf:subscribe(hs.window.filter.windowMinimized, function()
      local nextWindow = hs.window.focusedWindow()
      if not nextWindow or nextWindow:isMinimized() then
          local windows = hs.window.orderedWindows()
          for _, w in ipairs(windows) do
              if w:isVisible() and not w:isMinimized() then
                  w:focus()
                  break
              end
          end
      end
  end)
end

return window_focus
