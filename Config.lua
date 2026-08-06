-- Config.lua
-- Saved variables, the options panel, and the /cfl slash commands.

local addonName, ns = ...

local BOOLEAN, NUMBER, STRING = "boolean", "number", "string"

--------------------------------------------------------------------------------
-- Saved variables
--------------------------------------------------------------------------------

local function LoadSavedVariables()
  local saved = CoyFlightline_GlobalData

  if type(saved) == "table" then
    -- Copy into the existing ns.db rather than replacing it: the Settings API
    -- binds controls to this exact table reference. Unknown keys are dropped.
    for key, value in pairs(saved) do
      local default = ns.defaults[key]
      if default ~= nil and type(value) == type(default) then
        if type(value) == "table" then
          ns.db[key] = ns.DeepCopy(value)
        else
          ns.db[key] = value
        end
      end
    end
  end

  ns.db.dbVersion = ns.DB_VERSION
  CoyFlightline_GlobalData = ns.db
end

--------------------------------------------------------------------------------
-- Options panel
--------------------------------------------------------------------------------

local COLOR_ORDER = { "white", "yellow", "cyan", "magenta", "green" }
local COLOR_LABELS = {
  white = "White",
  yellow = "Yellow",
  cyan = "Cyan",
  magenta = "Magenta",
  green = "Green",
  custom = "Custom (/cfl color r g b)",
}

local function BuildPanel()
  local category, layout = Settings.RegisterVerticalLayoutCategory(ns.title)

  local function AddHeader(text)
    if layout and CreateSettingsListSectionHeaderInitializer then
      layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
    end
  end

  local function NewSetting(key, varType, name)
    local setting = Settings.RegisterAddOnSetting(
      category, "CoyFlightline_" .. key, key, ns.db, varType, name, ns.defaults[key])
    setting:SetValueChangedCallback(ns.Refresh)
    return setting
  end

  local function AddCheckbox(key, name, tooltip)
    Settings.CreateCheckbox(category, NewSetting(key, BOOLEAN, name), tooltip)
  end

  local function AddSlider(key, name, tooltip, minValue, maxValue, step, formatter)
    local options = Settings.CreateSliderOptions(minValue, maxValue, step)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, formatter)
    Settings.CreateSlider(category, NewSetting(key, NUMBER, name), options, tooltip)
  end

  AddCheckbox("enabled", "Enable " .. ns.title,
    "Master switch. When off, no line is drawn anywhere.")

  AddHeader("Where to draw")
  AddCheckbox("showMinimap", "Minimap", "Draw the flight line on the minimap.")
  AddCheckbox("showZoneMap", "Zone map", "Draw the flight line on the zone map (Shift+M).")
  AddCheckbox("showWorldMap", "World map", "Draw the flight line on the main map (M).")

  AddHeader("When to draw")
  AddCheckbox("showWhileFlying", "While flying", "Draw while you are in flight.")
  AddCheckbox("showWhileGliding", "While skyriding", "Draw while gliding on a skyriding mount.")
  AddCheckbox("showOnTaxi", "On a flight path", "Draw while travelling on a taxi.")

  AddHeader("Appearance")

  local colorSetting = Settings.RegisterAddOnSetting(
    category, "CoyFlightline_color", "color", ns.db, STRING, "Line colour", ns.defaults.color)
  colorSetting:SetValueChangedCallback(ns.Refresh)

  local function GetColorOptions()
    local container = Settings.CreateControlTextContainer()
    for _, key in ipairs(COLOR_ORDER) do
      container:Add(key, COLOR_LABELS[key])
    end
    -- Only offered once a custom colour actually exists, since it can only be
    -- set from the slash command.
    if ns.db.color == "custom" then
      container:Add("custom", COLOR_LABELS.custom)
    end
    return container:GetData()
  end

  local CreateDropdown = Settings.CreateDropdown or Settings.CreateDropDown
  CreateDropdown(category, colorSetting, GetColorOptions,
    "Colour of the flight line. Use /cfl color <r> <g> <b> for anything else.")

  AddSlider("thickness", "Line thickness", "Thickness of the line in pixels.",
    1, 6, 0.5, function(value) return ("%.1f"):format(value) end)
  AddSlider("alpha", "Line opacity", "Opacity of the line.",
    0.1, 1.0, 0.05, function(value) return ("%d%%"):format(math.floor(value * 100 + 0.5)) end)

  Settings.RegisterAddOnCategory(category)
  ns.settingsCategory = category
end

local function OpenPanel()
  if ns.settingsCategory and Settings and Settings.OpenToCategory then
    Settings.OpenToCategory(ns.settingsCategory:GetID())
  else
    ns.Print("the options panel is unavailable; use /cfl help for slash commands.")
  end
end

--------------------------------------------------------------------------------
-- Slash commands
--------------------------------------------------------------------------------

local function ToggleBool(key, label)
  ns.db[key] = not ns.db[key]
  ns.Refresh()
  ns.Print(("%s: %s"):format(label, ns.db[key] and "|cff44ff44on|r" or "|cffff4444off|r"))
end

local function PrintHelp()
  ns.Print("commands:")
  print("  /cfl                     - open the options panel")
  print("  /cfl on | off            - master switch")
  print("  /cfl minimap             - toggle the minimap line")
  print("  /cfl zonemap             - toggle the zone map line")
  print("  /cfl worldmap            - toggle the world map line")
  print("  /cfl thickness <1-6>     - line thickness")
  print("  /cfl alpha <0.1-1>       - line opacity")
  print("  /cfl color <name>        - white, yellow, cyan, magenta, green")
  print("  /cfl color <r> <g> <b>   - custom colour, each 0-1")
  print("  /cfl status              - show the current settings")
  print("  /cfl reset               - restore defaults")
end

local function PrintStatus()
  local db = ns.db
  ns.Print(("%s - %s"):format(ns.versionLabel, db.enabled and "enabled" or "disabled"))
  print(("  surfaces: minimap %s, zone map %s, world map %s"):format(
    tostring(db.showMinimap), tostring(db.showZoneMap), tostring(db.showWorldMap)))
  print(("  triggers: flying %s, skyriding %s, taxi %s"):format(
    tostring(db.showWhileFlying), tostring(db.showWhileGliding), tostring(db.showOnTaxi)))
  print(("  colour %s, thickness %.1f, opacity %d%%"):format(
    db.color, db.thickness, math.floor(db.alpha * 100 + 0.5)))
end

local function HandleColor(first, second, third)
  if not first then
    ns.Print("usage: /cfl color <name> or /cfl color <r> <g> <b>")
    return
  end

  if ns.COLORS[first] then
    ns.db.color = first
    ns.Refresh()
    ns.Print("colour set to " .. first .. ".")
    return
  end

  local r, g, b = tonumber(first), tonumber(second), tonumber(third)
  if r and g and b then
    ns.db.customColor = {
      r = math.max(0, math.min(1, r)),
      g = math.max(0, math.min(1, g)),
      b = math.max(0, math.min(1, b)),
    }
    ns.db.color = "custom"
    ns.Refresh()
    ns.Print(("colour set to %.2f, %.2f, %.2f."):format(
      ns.db.customColor.r, ns.db.customColor.g, ns.db.customColor.b))
    return
  end

  ns.Print("unknown colour. Try white, yellow, cyan, magenta, green, or three numbers 0-1.")
end

local function HandleNumber(key, label, value, minValue, maxValue, format)
  local number = tonumber(value)
  if not number then
    ns.Print(("usage: /cfl %s <%s-%s>"):format(key, minValue, maxValue))
    return
  end
  ns.db[key] = math.max(minValue, math.min(maxValue, number))
  ns.Refresh()
  ns.Print(("%s set to %s."):format(label, format(ns.db[key])))
end

local function HandleSlash(input)
  local args = {}
  for word in tostring(input or ""):gmatch("%S+") do
    args[#args + 1] = word:lower()
  end

  local command = args[1]

  if not command then
    OpenPanel()
  elseif command == "help" then
    PrintHelp()
  elseif command == "status" then
    PrintStatus()
  elseif command == "on" or command == "off" then
    ns.db.enabled = (command == "on")
    ns.Refresh()
    ns.Print(ns.db.enabled and "enabled." or "disabled.")
  elseif command == "minimap" then
    ToggleBool("showMinimap", "minimap")
  elseif command == "zonemap" then
    ToggleBool("showZoneMap", "zone map")
  elseif command == "worldmap" then
    ToggleBool("showWorldMap", "world map")
  elseif command == "thickness" then
    HandleNumber("thickness", "thickness", args[2], 1, 6, function(v) return ("%.1f"):format(v) end)
  elseif command == "alpha" then
    HandleNumber("alpha", "opacity", args[2], 0.1, 1, function(v) return ("%d%%"):format(math.floor(v * 100 + 0.5)) end)
  elseif command == "color" or command == "colour" then
    HandleColor(args[2], args[3], args[4])
  elseif command == "reset" then
    for key, value in pairs(ns.defaults) do
      ns.db[key] = (type(value) == "table") and ns.DeepCopy(value) or value
    end
    ns.Refresh()
    ns.Print("settings restored to defaults. Reload (/reload) to refresh the options panel.")
  else
    PrintHelp()
  end
end

SLASH_COYFLIGHTLINE1 = "/cfl"
SLASH_COYFLIGHTLINE2 = "/coyflightline"
SlashCmdList["COYFLIGHTLINE"] = HandleSlash

--------------------------------------------------------------------------------
-- Bootstrap
--------------------------------------------------------------------------------

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, loadedAddOn)
  if loadedAddOn ~= addonName then return end
  self:UnregisterEvent("ADDON_LOADED")

  LoadSavedVariables()

  -- The Settings API has changed signatures before (10.0.0, then again in
  -- 11.0.2). If it changes again the addon should still work from slash
  -- commands rather than erroring on load.
  local ok, err = pcall(BuildPanel)
  if not ok then
    ns.Print("could not build the options panel (" .. tostring(err) ..
      "). Slash commands still work - try /cfl help.")
  end

  ns.Refresh()
end)
