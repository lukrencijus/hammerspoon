-- Shared helper patterns for helper/extension processes
local helperPatterns = {
  "webview", "renderer", "agent", "daemon", "extension", "plugin", "process", "content", "notification", "desktop", "updater", "worker",
}

local forceQuit = {}
local forceQuitChooser = nil

function forceQuit.init()
  hs.hotkey.bind({"cmd", "alt"}, "`", function()
    local apps = hs.application.runningApplications()
    local choices = {}
    
    for _, app in ipairs(apps) do
      local name = app:name()
      local bundleID = app:bundleID()

      if name and bundleID then
        local lowerName = name:lower()
        local lowerBundle = bundleID:lower()

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
end

return forceQuit
