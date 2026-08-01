-- Core.lua
-- Shared state, geometry, show-conditions, and the update driver.
--
-- The addon draws one line per "surface" (world map, zone map, minimap). Each
-- surface is a small adapter that knows how to find its own frame and where the
-- player sits inside it; all of them share the ray math and the show-condition
-- logic in this file.

local addonName, ns = ...

ns.addonName = addonName
ns.version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "unknown"
-- Display name, kept in sync with the TOC so the options panel and the folder
-- name can differ. The folder stays "CoyFlightline" so that this remains a
-- drop-in replacement for Coywolf's release, saved settings and all.
ns.title = C_AddOns.GetAddOnMetadata(addonName, "Title") or addonName

local sin, cos, min, huge = math.sin, math.cos, math.min, math.huge

--------------------------------------------------------------------------------
-- Defaults / database
--------------------------------------------------------------------------------

-- Bump dbVersion when the shape of a saved value changes, and migrate in Config.lua.
ns.DB_VERSION = 1

ns.defaults = {
  dbVersion = ns.DB_VERSION,

  enabled = true,

  showWorldMap = true,
  showZoneMap = true,
  showMinimap = true,

  thickness = 1,
  alpha = 1.0,
  color = "white",
  customColor = { r = 1, g = 1, b = 1 },

  showWhileFlying = true,
  showWhileGliding = true,
  showOnTaxi = true,
}

ns.COLORS = {
  white   = { r = 1.00, g = 1.00, b = 1.00 },
  yellow  = { r = 1.00, g = 0.82, b = 0.00 },
  cyan    = { r = 0.25, g = 0.90, b = 1.00 },
  magenta = { r = 1.00, g = 0.35, b = 0.85 },
  green   = { r = 0.35, g = 1.00, b = 0.45 },
}

local function DeepCopy(source)
  local copy = {}
  for key, value in pairs(source) do
    if type(value) == "table" then
      copy[key] = DeepCopy(value)
    else
      copy[key] = value
    end
  end
  return copy
end
ns.DeepCopy = DeepCopy

-- Populated with defaults immediately so that surfaces created before
-- ADDON_LOADED still have something to read. Config.lua copies the saved values
-- into this same table rather than replacing it, because the Settings API binds
-- to the table reference.
ns.db = DeepCopy(ns.defaults)

function ns.Print(...)
  print("|cff66ccffCoyFlightline|r:", ...)
end

--------------------------------------------------------------------------------
-- Geometry
--------------------------------------------------------------------------------
-- All surfaces work in a y-down pixel space with the origin at the frame's
-- TOPLEFT, which is the space C_Map normalized coordinates already live in.
-- Lines are clipped to their container mathematically rather than by drawing
-- them over-long and relying on the parent to crop them.

-- Ray/rectangle intersection. Origin is assumed to be inside [0,w] x [0,h].
-- Returns nil when the ray immediately leaves the rectangle.
function ns.ClipRayToRect(originX, originY, dirX, dirY, width, height)
  local t = huge

  if dirX > 0 then
    t = min(t, (width - originX) / dirX)
  elseif dirX < 0 then
    t = min(t, -originX / dirX)
  end

  if dirY > 0 then
    t = min(t, (height - originY) / dirY)
  elseif dirY < 0 then
    t = min(t, -originY / dirY)
  end

  if t == huge or t <= 0 then
    return nil
  end

  return originX + dirX * t, originY + dirY * t
end

-- Ray/circle intersection from the centre. The direction is already unit
-- length, so this is just a scale.
function ns.ClipRayToCircle(originX, originY, dirX, dirY, radius)
  return originX + dirX * radius, originY + dirY * radius
end

-- Player facing (radians, 0 = north, increasing counter-clockwise) as a unit
-- vector in the y-down map space used above.
function ns.FacingToVector(facing)
  return -sin(facing), -cos(facing)
end

--------------------------------------------------------------------------------
-- Show conditions
--------------------------------------------------------------------------------

local function IsGliding()
  -- Skyriding. Guarded because the API is retail-only.
  if C_PlayerInfo and C_PlayerInfo.GetGlidingInfo then
    return (C_PlayerInfo.GetGlidingInfo())
  end
  return false
end

-- Returns the player's facing when the line should be drawn, otherwise nil.
-- GetPlayerFacing() is #noinstance: it returns nil in dungeons, raids,
-- battlegrounds and arenas, which is also exactly where we do not want a line.
local function GetActiveFacing()
  local db = ns.db
  if not db.enabled then return nil end
  if IsInInstance() then return nil end

  local facing = GetPlayerFacing()
  if not facing then return nil end

  if db.showWhileFlying and IsFlying() then return facing end
  if db.showWhileGliding and IsGliding() then return facing end
  if db.showOnTaxi and UnitOnTaxi("player") then return facing end

  return nil
end

--------------------------------------------------------------------------------
-- Surface registry
--------------------------------------------------------------------------------

ns.surfaces = {}

-- surface contract:
--   surface.key      unique id, for diagnostics
--   surface.dbKey    boolean field in ns.db gating this surface
--   surface:IsAvailable()          -> is the host frame present and visible
--   surface:Update(dirX, dirY)     -> position and show the line
--   surface:HideLine()             -> hide the line
--   surface:ApplyStyle()           -> re-read colour/thickness from the db
function ns.RegisterSurface(surface)
  ns.surfaces[#ns.surfaces + 1] = surface
  if surface.ApplyStyle then
    surface:ApplyStyle()
  end
  return surface
end

-- Applies the current colour/thickness to a line. Shared by every surface.
function ns.StyleLine(line)
  local db = ns.db
  local color = ns.COLORS[db.color]
  if not color then
    color = db.customColor or ns.COLORS.white
  end
  line:SetColorTexture(color.r, color.g, color.b, db.alpha)
  line:SetThickness(db.thickness)
end

-- Called whenever a setting changes.
function ns.Refresh()
  for _, surface in ipairs(ns.surfaces) do
    if surface.ApplyStyle then
      surface:ApplyStyle()
    end
  end
end

--------------------------------------------------------------------------------
-- Driver
--------------------------------------------------------------------------------
-- One OnUpdate for every surface. Facing changes continuously, so there is no
-- useful event to drive this from, but the early-out below means an idle,
-- grounded player pays for four cheap C calls per frame and nothing else.

local driver = CreateFrame("Frame", "CoyFlightlineDriver")
driver:SetSize(1, 1)
driver:SetPoint("TOPLEFT")
driver:Show()

driver:SetScript("OnUpdate", function()
  local surfaces = ns.surfaces
  if #surfaces == 0 then return end

  local facing = GetActiveFacing()
  local dirX, dirY
  if facing then
    dirX, dirY = ns.FacingToVector(facing)
  end

  local db = ns.db
  for i = 1, #surfaces do
    local surface = surfaces[i]
    if facing and db[surface.dbKey] and surface:IsAvailable() then
      surface:Update(dirX, dirY)
    else
      surface:HideLine()
    end
  end
end)

ns.driver = driver
