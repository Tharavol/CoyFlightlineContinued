-- Core.lua
-- Shared state, geometry, show-conditions, and the update driver. Each map
-- "surface" (world map, zone map, minimap) is a small adapter over this.

local addonName, ns = ...

ns.addonName = addonName

-- A source install reads back the unsubstituted packager token. Matched by
-- pattern: the literal token here would itself be substituted at release time.
-- Tags already carry a "v"; add one only when missing.
function ns.DeriveVersionLabel(raw)
  if not raw or raw == "" or raw:match("^@.+@$") then
    return "dev", "dev"
  end

  if raw:match("^[vV]%d") then
    return raw, raw
  end

  return raw, "v" .. raw
end

ns.version, ns.versionLabel = ns.DeriveVersionLabel(C_AddOns.GetAddOnMetadata(addonName, "Version"))
-- Display name from the TOC; the folder stays "CoyFlightline" so this installs
-- over the original release.
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

  debug = false,
}

ns.COLORS = {
  white   = { r = 1.00, g = 1.00, b = 1.00 },
  yellow  = { r = 1.00, g = 0.82, b = 0.00 },
  cyan    = { r = 0.25, g = 0.90, b = 1.00 },
  magenta = { r = 1.00, g = 0.35, b = 0.85 },
  green   = { r = 0.35, g = 1.00, b = 0.45 },
}

-- Copies `source` into `target`, deep-copying nested tables. With `template`,
-- only keys present in it with a matching value type are copied.
function ns.Merge(target, source, template)
  for key, value in pairs(source) do
    local default = template and template[key]
    if not template or (default ~= nil and type(value) == type(default)) then
      target[key] = type(value) == "table" and ns.Merge({}, value) or value
    end
  end
  return target
end

-- Filled with defaults now so surfaces created before ADDON_LOADED can read it.
-- Saved values are later merged into this same table: the Settings API binds to
-- the table reference.
ns.db = ns.Merge({}, ns.defaults)

function ns.Print(...)
  print("|cff66ccff" .. ns.title .. "|r:", ...)
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

-- Whether the player is in a dungeon, raid, battleground or arena. Cached off
-- zoning events rather than polled: it can only change by loading a new world,
-- and GetActiveFacing below runs every frame.
local inInstance = false

local function RefreshInstanceState()
  inInstance = IsInInstance() and true or false
end

-- Skyriding.
local function IsGliding()
  return (C_PlayerInfo.GetGlidingInfo())
end

-- Returns the player's facing when the line should be drawn, otherwise nil.
-- GetPlayerFacing() is #noinstance: it returns nil in dungeons, raids,
-- battlegrounds and arenas, which is also where no line is wanted.
local function GetActiveFacing()
  local db = ns.db
  if not db.enabled then return nil end
  if inInstance then return nil end

  local facing = GetPlayerFacing()
  if not facing then return nil end

  if db.showWhileFlying and IsFlying() then return facing end
  if db.showWhileGliding and IsGliding() then return facing end
  if db.showOnTaxi and UnitOnTaxi("player") then return facing end

  return nil
end

-- PLAYER_ENTERING_WORLD covers instance entry and exit; ZONE_CHANGED_NEW_AREA
-- catches seamless transitions. GetPlayerFacing()'s nil in instances is the
-- backstop if both miss one.
local instanceWatcher = CreateFrame("Frame")
instanceWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
instanceWatcher:RegisterEvent("ZONE_CHANGED_NEW_AREA")
instanceWatcher:SetScript("OnEvent", RefreshInstanceState)
RefreshInstanceState()

--------------------------------------------------------------------------------
-- Surface registry
--------------------------------------------------------------------------------

ns.surfaces = {}

-- surface contract:
--   surface.key        unique id, for diagnostics
--   surface.dbKey      boolean field in ns.db gating this surface
--   surface.host       frame the line belongs to; visible == surface usable
--   surface.lineFrame  frame the line is drawn in, in whose space it is measured
--   surface.line       the line texture itself
--   surface:Update(dirX, dirY)     -> position and show the line
--
-- Everything else comes from the ns.Surface base below. An adapter that only
-- implements Update is a complete surface.
function ns.RegisterSurface(surface)
  ns.surfaces[#ns.surfaces + 1] = surface
  surface:ApplyStyle()
  return surface
end

-- Line thickness is in the parent's coordinate space, not screen pixels. On a
-- canvas scaled well below 1.0 (the zone map) a 1px line renders as a dotted
-- trail, so scale by UIParent / frame to keep the on-screen width constant.
function ns.ScaledThickness(frame)
  local thickness = ns.db.thickness
  if not frame then return thickness end

  local scale = frame:GetEffectiveScale()
  local reference = UIParent:GetEffectiveScale()
  if not scale or scale <= 0 or not reference or reference <= 0 then
    return thickness
  end

  return thickness * reference / scale
end

--------------------------------------------------------------------------------
-- Surface base
--------------------------------------------------------------------------------
-- Behaviour shared by every surface. Adapters chain to this with
--   setmetatable(Adapter, { __index = ns.Surface })
-- and override Update. Any frame can be rescaled by the user or another addon,
-- so every surface re-derives its width while drawing, not once at style time.

ns.Surface = {}
ns.Surface.__index = ns.Surface

function ns.Surface:IsAvailable()
  return self.host:IsVisible() and self.lineFrame:GetWidth() > 0
end

function ns.Surface:HideLine()
  self.line:Hide()
end

-- Colour and opacity only; thickness follows from RefreshThickness.
function ns.Surface:ApplyStyle()
  local db = ns.db
  local color = ns.COLORS[db.color] or db.customColor
  self.line:SetColorTexture(color.r, color.g, color.b, db.alpha)

  -- The thickness setting may have changed, so drop the cache and re-derive.
  self.appliedThickness = nil
  self:RefreshThickness()
end

-- Called from Update, every frame the line is drawn. The cache keeps this to a
-- comparison in the common case where nothing has been rescaled.
function ns.Surface:RefreshThickness()
  local thickness = ns.ScaledThickness(self.lineFrame)
  if thickness ~= self.appliedThickness then
    self.appliedThickness = thickness
    self.line:SetThickness(thickness)
  end
end

-- Called whenever a setting changes.
function ns.Refresh()
  for _, surface in ipairs(ns.surfaces) do
    surface:ApplyStyle()
  end
end

--------------------------------------------------------------------------------
-- Driver
--------------------------------------------------------------------------------
-- One OnUpdate for every surface: facing has no change event. A grounded
-- player costs a few cheap C calls per frame.

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
