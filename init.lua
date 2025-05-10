-- Better Force Quit Applications (including background apps and with search functionality)
hs.hotkey.bind({"cmd", "alt"}, "§", function()
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
      choice.app:kill() -- or use :terminate() for a gentle quit
      hs.alert.show("Quit " .. choice.text)
    end
  end)
  chooser:choices(uniqueChoices)
  chooser:show()
end)