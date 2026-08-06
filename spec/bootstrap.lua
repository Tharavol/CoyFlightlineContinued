-- spec/bootstrap.lua
-- Stubs just enough of the WoW API surface for Core.lua, Settings.lua,
-- Config.lua, WorldMap.lua and Minimap.lua to survive loadfile() outside the
-- game, and loads them in TOC order into a fresh `ns` table.
--
-- These stubs exist to survive load, not to model WoW behaviour. Surface
-- Update() methods stay untested (see #12) precisely so this file never grows
-- into a WoW emulator -- if it starts needing more than this, that's the
-- signal to pull the geometry into its own WoW-API-free file instead.
--
-- Assumes busted is invoked from the repository root, matching the plain
-- loadfile("Core.lua")-style paths used below.

local ADDON_NAME = "CoyFlightline"

local ADDON_FILES = {
  "Core.lua",
  "Settings.lua",
  "Config.lua",
  "WorldMap.lua",
  "Minimap.lua",
}

local function noop() end

local function NewFrameStub()
  local frame = {}
  frame.SetScript = noop
  frame.RegisterEvent = noop
  frame.UnregisterEvent = noop
  frame.SetPoint = noop
  frame.SetAllPoints = noop
  frame.SetSize = noop
  frame.Show = noop
  frame.Hide = noop
  frame.SetFrameLevel = noop
  frame.SetClipsChildren = noop
  frame.GetFrameLevel = function() return 0 end
  frame.GetEffectiveScale = function() return 1 end
  frame.GetWidth = function() return 0 end
  frame.GetHeight = function() return 0 end
  frame.IsVisible = function() return false end
  frame.CreateLine = function()
    local line = {}
    line.Hide = noop
    line.Show = noop
    line.SetColorTexture = noop
    line.SetThickness = noop
    line.SetStartPoint = noop
    line.SetEndPoint = noop
    return line
  end
  return frame
end

-- Version metadata deliberately mimics a source install (the token the
-- packager would otherwise substitute), since that's the path DeriveVersionLabel
-- has to fall back safely on.
local function InstallGlobals()
  _G.CreateFrame = function()
    return NewFrameStub()
  end

  _G.C_AddOns = {
    GetAddOnMetadata = function(_, field)
      if field == "Version" then return "@project-version@" end
      if field == "Title" then return "CoyFlightline Continued" end
      return nil
    end,
    IsAddOnLoaded = function() return false end,
  }

  _G.UIParent = NewFrameStub()
  _G.Minimap = NewFrameStub()

  _G.IsInInstance = function() return false end
  _G.GetPlayerFacing = function() return nil end
  _G.IsFlying = function() return false end
  _G.UnitOnTaxi = function() return false end

  _G.SlashCmdList = {}
  _G.CoyFlightline_GlobalData = nil
end

local function InstallPrintCapture()
  local prints = {}
  _G.print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    prints[#prints + 1] = table.concat(parts, " ")
  end
  return prints
end

local M = {}

-- Loads a fresh copy of the addon, in TOC order, with clean stubs and a clean
-- print buffer. Returns:
--   ns        the addon's shared namespace table
--   prints    array of captured print() calls, oldest first, one string each
--   dispatch  the function registered as SlashCmdList["COYFLIGHTLINE"]
function M.LoadAddon()
  InstallGlobals()
  local prints = InstallPrintCapture()

  local ns = {}
  for _, file in ipairs(ADDON_FILES) do
    local chunk = assert(loadfile(file))
    chunk(ADDON_NAME, ns)
  end

  return ns, prints, _G.SlashCmdList["COYFLIGHTLINE"]
end

return M
