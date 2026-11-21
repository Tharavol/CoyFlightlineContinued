-- WorldMap.lua
-- Surfaces for the main map (WorldMapFrame) and the zone map (BattlefieldMapFrame).
--
-- Both are MapCanvasMixin frames. The line frame is parented to the canvas
-- (ScrollContainer.Child), which scales and pans; parenting to the container
-- makes the line drift when the map is zoomed or dragged.

local addonName, ns = ...

local CanvasSurface = setmetatable({}, { __index = ns.Surface })
CanvasSurface.__index = CanvasSurface

function CanvasSurface:Update(dirX, dirY)
  local mapID = self.host:GetMapID()
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

  -- The canvas rescales as the map is zoomed.
  self:RefreshThickness()
  self.line:SetStartPoint("TOPLEFT", originX, -originY)
  self.line:SetEndPoint("TOPLEFT", endX, -endY)
  self.line:Show()
end

local function CreateCanvasSurface(mapFrame, key, dbKey)
  local canvas = mapFrame:GetCanvas()
  local lineFrame = CreateFrame("Frame", nil, canvas)
  lineFrame:SetAllPoints(canvas)
  -- Map pins on the canvas use frame levels up to 9000
  -- (MapCanvasPinFrameLevelsManagerMixin); a higher strata stays above them (#32).
  lineFrame:SetFrameStrata("DIALOG")
  lineFrame:SetFrameLevel(canvas:GetFrameLevel() + 150)
  lineFrame:SetClipsChildren(true)
  lineFrame:Show()

  local line = lineFrame:CreateLine()
  line:Hide()

  local surface = setmetatable({
    key = key,
    dbKey = dbKey,
    host = mapFrame,
    lineFrame = lineFrame,
    line = line,
  }, CanvasSurface)

  return ns.RegisterSurface(surface)
end

--------------------------------------------------------------------------------
-- Attachment
--------------------------------------------------------------------------------
-- Both map addons may load after this file (Blizzard_BattlefieldMap is
-- load-on-demand), so attach once each has loaded.

EventUtil.ContinueOnAddOnLoaded("Blizzard_WorldMap", function()
  CreateCanvasSurface(WorldMapFrame, "worldMap", "showWorldMap")
end)

EventUtil.ContinueOnAddOnLoaded("Blizzard_BattlefieldMap", function()
  CreateCanvasSurface(BattlefieldMapFrame, "zoneMap", "showZoneMap")
end)
