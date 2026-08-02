-- WorldMap.lua
-- Surfaces for the main map (WorldMapFrame) and the zone map (BattlefieldMapFrame).
--
-- Both are MapCanvasMixin frames, so one adapter covers them. The important
-- detail is that the line frame is parented to the *canvas* (ScrollContainer.Child)
-- and not to the ScrollContainer: the canvas is the thing that scales and pans,
-- and it is what Blizzard's own map pins attach to. Parenting to the container
-- instead makes the line drift away from the player as soon as the map is
-- zoomed or dragged.

local addonName, ns = ...

local CanvasSurface = {}
CanvasSurface.__index = CanvasSurface

local function GetCanvas(mapFrame)
  if mapFrame.GetCanvas then
    return mapFrame:GetCanvas()
  end
  -- Fallback for the (unlikely) case that the mixin accessor is renamed.
  return mapFrame.ScrollContainer and mapFrame.ScrollContainer.Child
end

local function GetMapID(mapFrame)
  if mapFrame.GetMapID then
    return mapFrame:GetMapID()
  end
  return mapFrame.mapID
end

function CanvasSurface:IsAvailable()
  return self.mapFrame:IsVisible() and self.lineFrame:GetWidth() > 0
end

function CanvasSurface:HideLine()
  self.line:Hide()
end

function CanvasSurface:ApplyStyle()
  ns.StyleLine(self.line)
  -- Force RefreshThickness to recompute: the thickness setting may have changed.
  self.appliedThickness = nil
end

-- The canvas is rescaled as the map is zoomed, so the scale-compensated
-- thickness cannot be set once in ApplyStyle; it has to be re-derived while the
-- line is being drawn. The cache keeps this to a comparison per frame in the
-- common case where the zoom is not moving.
function CanvasSurface:RefreshThickness()
  local thickness = ns.ScaledThickness(self.lineFrame)
  if thickness ~= self.appliedThickness then
    self.appliedThickness = thickness
    self.line:SetThickness(thickness)
  end
end

function CanvasSurface:Update(dirX, dirY)
  local mapID = GetMapID(self.mapFrame)
  if not mapID then
    return self:HideLine()
  end

  -- nil when the player is not on the map currently being displayed, e.g. after
  -- panning to another continent.
  local position = C_Map.GetPlayerMapPosition(mapID, "player")
  if not position then
    return self:HideLine()
  end

  local normalizedX, normalizedY = position:GetXY()
  if not normalizedX or not normalizedY then
    return self:HideLine()
  end

  local width, height = self.lineFrame:GetWidth(), self.lineFrame:GetHeight()
  if width <= 0 or height <= 0 then
    return self:HideLine()
  end

  local originX, originY = normalizedX * width, normalizedY * height
  local endX, endY = ns.ClipRayToRect(originX, originY, dirX, dirY, width, height)
  if not endX then
    -- Player is on the very edge of the map facing off it.
    return self:HideLine()
  end

  self:RefreshThickness()
  self.line:SetStartPoint("TOPLEFT", originX, -originY)
  self.line:SetEndPoint("TOPLEFT", endX, -endY)
  self.line:Show()
end

local function CreateCanvasSurface(mapFrame, key, dbKey)
  local canvas = GetCanvas(mapFrame)
  if not canvas then
    ns.Print(("could not find the map canvas for %s; that surface is disabled."):format(key))
    return
  end

  local lineFrame = CreateFrame("Frame", nil, canvas)
  lineFrame:SetAllPoints(canvas)
  lineFrame:SetFrameLevel(canvas:GetFrameLevel() + 150)
  -- Belt and braces: the line is already clipped to the canvas rectangle by
  -- ClipRayToRect, and the ScrollContainer clips the canvas to the viewport.
  lineFrame:SetClipsChildren(true)
  lineFrame:Show()

  local line = lineFrame:CreateLine()
  line:Hide()

  local surface = setmetatable({
    key = key,
    dbKey = dbKey,
    mapFrame = mapFrame,
    lineFrame = lineFrame,
    line = line,
  }, CanvasSurface)

  return ns.RegisterSurface(surface)
end

--------------------------------------------------------------------------------
-- Attachment
--------------------------------------------------------------------------------
-- Neither map frame can be touched at file scope: Blizzard_BattlefieldMap is
-- load-on-demand (it only loads when the zone map is first opened) and the world
-- map is not guaranteed to be loaded either.

local function OnAddOnLoaded(addOnName, callback)
  if EventUtil and EventUtil.ContinueOnAddOnLoaded then
    EventUtil.ContinueOnAddOnLoaded(addOnName, callback)
  elseif C_AddOns.IsAddOnLoaded(addOnName) then
    callback()
  end
end

OnAddOnLoaded("Blizzard_WorldMap", function()
  if WorldMapFrame then
    CreateCanvasSurface(WorldMapFrame, "worldMap", "showWorldMap")
  end
end)

-- The zone map addon was called Blizzard_BattlefieldMinimap before Legion; the
-- old name is watched too so a single unexpected rename does not silently drop
-- the surface.
local zoneMapAttached = false
local function AttachZoneMap()
  if zoneMapAttached then return end
  if BattlefieldMapFrame then
    zoneMapAttached = true
    CreateCanvasSurface(BattlefieldMapFrame, "zoneMap", "showZoneMap")
  end
end

OnAddOnLoaded("Blizzard_BattlefieldMap", AttachZoneMap)
OnAddOnLoaded("Blizzard_BattlefieldMinimap", AttachZoneMap)
