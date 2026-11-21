-- Config.lua
-- Saved variables, the options panel, and the /cfl slash commands.

local addonName, ns = ...

local BOOLEAN, NUMBER, STRING = "boolean", "number", "string"

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
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
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
    -- Custom can only be set from the slash command, so only offer it once set.
    if ns.db.color == "custom" then
      container:Add("custom", COLOR_LABELS.custom)
    end
    return container:GetData()
  end

  Settings.CreateDropdown(category, colorSetting, GetColorOptions,
    "Colour of the flight line. Use /cfl color <r> <g> <b> for anything else.")

  AddSlider("thickness", "Line thickness", "Thickness of the line in pixels.",
    1, 6, 0.5, function(value) return ("%.1f"):format(value) end)
  AddSlider("alpha", "Line opacity", "Opacity of the line.",
    0.1, 1.0, 0.05, function(value) return ("%d%%"):format(math.floor(value * 100 + 0.5)) end)

  Settings.RegisterAddOnCategory(category)
  ns.settingsCategory = category
end

local function OpenPanel()
  if ns.settingsCategory then
    Settings.OpenToCategory(ns.settingsCategory:GetID())
  else
    ns.Print("the options panel is unavailable; use /cfl help for slash commands.")
  end
end

--------------------------------------------------------------------------------
-- Slash commands
--------------------------------------------------------------------------------

-- Bare toggles; explicit on/off sets; anything else is rejected.
local function ToggleBool(key, label, value)
  value = value and value:lower()
  if value == "on" then
    ns.db[key] = true
  elseif value == "off" then
    ns.db[key] = false
  elseif value == nil then
    ns.db[key] = not ns.db[key]
  else
    ns.Print(("'%s' - expected 'on' or 'off'."):format(value))
    return
  end
  ns.Refresh()
  ns.Print(("%s: %s"):format(label, ns.db[key] and "|cff44ff44on|r" or "|cffff4444off|r"))
end

local function HandleDebug(value)
  value = value and value:lower()
  if value == "on" then
    ns.db.debug = true
  elseif value == "off" then
    ns.db.debug = false
  elseif value == nil then
    ns.db.debug = not ns.db.debug
  else
    ns.Print(("'%s' - expected 'on' or 'off'."):format(value))
    return
  end
  ns.Print(("debug logging: %s"):format(ns.db.debug and "|cff44ff44on|r" or "|cffff4444off|r"))
end

local function PrintStatus()
  local db = ns.db
  ns.Print(("%s - %s"):format(ns.versionLabel, db.enabled and "enabled" or "disabled"))
  ns.Print(("surfaces: minimap %s, zone map %s, world map %s"):format(
    tostring(db.showMinimap), tostring(db.showZoneMap), tostring(db.showWorldMap)))
  ns.Print(("triggers: flying %s, skyriding %s, taxi %s"):format(
    tostring(db.showWhileFlying), tostring(db.showWhileGliding), tostring(db.showOnTaxi)))

  -- Show the RGB triple for "custom"; it is not visible anywhere else.
  local colorLabel = db.color
  if db.color == "custom" then
    colorLabel = ("custom (%.2f, %.2f, %.2f)"):format(
      db.customColor.r, db.customColor.g, db.customColor.b)
  end

  ns.Print(("colour %s, thickness %.1f, opacity %d%%"):format(
    colorLabel, db.thickness, math.floor(db.alpha * 100 + 0.5)))
  ns.Print(("debug logging: %s"):format(tostring(db.debug)))
end

local function HandleReset()
  ns.Merge(ns.db, ns.defaults)
  ns.Refresh()
  ns.Print("settings restored to defaults. Reload (/reload) to refresh the options panel.")
end

-- { name, help, handler }; PrintHelp derives the help list from this table.
-- Entries with empty help ("", "config", "gui", "off", "colour") are aliases.
local COMMANDS
local function PrintHelp()
  ns.Print("commands:")
  for _, entry in ipairs(COMMANDS) do
    for _, line in ipairs(entry.help) do
      ns.Print(line)
    end
  end
end

COMMANDS = {
  {name = "", help = {}, handler = OpenPanel},
  {
    name = "options",
    help = {"/cfl, /cfl options, /cfl config, /cfl gui - open the options panel"},
    handler = OpenPanel
  },
  {name = "config", help = {}, handler = OpenPanel},
  {name = "gui", help = {}, handler = OpenPanel},
  {
    name = "on",
    help = {"/cfl on | off             - master switch"},
    handler = function()
      ns.db.enabled = true
      ns.Refresh()
      ns.Print("enabled.")
    end
  },
  {
    name = "off",
    help = {},
    handler = function()
      ns.db.enabled = false
      ns.Refresh()
      ns.Print("disabled.")
    end
  },
  {
    name = "minimap",
    help = {"/cfl minimap [on|off]     - toggle or set the minimap line"},
    handler = function(value) ToggleBool("showMinimap", "minimap", value) end
  },
  {
    name = "zonemap",
    help = {"/cfl zonemap [on|off]     - toggle or set the zone map line"},
    handler = function(value) ToggleBool("showZoneMap", "zone map", value) end
  },
  {
    name = "worldmap",
    help = {"/cfl worldmap [on|off]    - toggle or set the world map line"},
    handler = function(value) ToggleBool("showWorldMap", "world map", value) end
  },
  {
    name = "thickness",
    help = {"/cfl thickness <1-6>      - line thickness"},
    handler = function(value)
      ns.Settings.HandleNumber("thickness", "thickness", value, 1, 6, function(v) return ("%.1f"):format(v) end)
    end
  },
  {
    name = "alpha",
    help = {"/cfl alpha <0.1-1>        - line opacity"},
    handler = function(value)
      ns.Settings.HandleNumber("alpha", "opacity", value, 0.1, 1,
        function(v) return ("%d%%"):format(math.floor(v * 100 + 0.5)) end)
    end
  },
  {
    name = "color",
    help = {
      "/cfl color <name>         - white, yellow, cyan, magenta, green",
      "/cfl color <r> <g> <b>    - custom colour, each 0-1"
    },
    handler = function(first, second, third) ns.Settings.HandleColor(first, second, third) end
  },
  {
    name = "colour",
    help = {},
    handler = function(first, second, third) ns.Settings.HandleColor(first, second, third) end
  },
  {
    name = "debug",
    help = {"/cfl debug [on|off]       - toggle or set debug logging"},
    handler = HandleDebug
  },
  {name = "status", help = {"/cfl status               - show the current settings"}, handler = PrintStatus},
  {
    name = "version",
    help = {"/cfl version              - show the addon version"},
    handler = function() ns.Print(ns.versionLabel) end
  },
  {name = "reset", help = {"/cfl reset                - restore defaults"}, handler = HandleReset}
}

COMMANDS[#COMMANDS + 1] = {name = "help", help = {"/cfl help                 - show this list"}, handler = PrintHelp}

local function HandleSlash(input)
  local rawArgs = {}
  for word in tostring(input or ""):gmatch("%S+") do
    rawArgs[#rawArgs + 1] = word
  end

  -- Only the command word is lowercased; handlers lowercase their own keywords.
  local command = rawArgs[1] and rawArgs[1]:lower() or ""

  for _, entry in ipairs(COMMANDS) do
    if entry.name == command then
      entry.handler(rawArgs[2], rawArgs[3], rawArgs[4])
      return
    end
  end

  ns.Print(("unknown command: %s"):format(command))
  PrintHelp()
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

  ns.Settings.LoadSavedVariables(CoyFlightline_GlobalData)
  BuildPanel()

  ns.Refresh()
end)
