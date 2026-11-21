-- Minimap.lua
-- Surface for the minimap. The player is always at the centre; the line is
-- clipped to a circle (or square) and points straight up when the minimap rotates.

local addonName, ns = ...

local MINIMAP_INSET = 1 -- keeps the line from tucking under the minimap border

local MinimapSurface = setmetatable({}, { __index = ns.Surface })
MinimapSurface.__index = MinimapSurface

local rotateMinimap = false
local squareMinimap = false

local function RefreshRotationState()
  rotateMinimap = C_CVar.GetCVarBool("rotateMinimap") and true or false
end

-- Minimap addons that make it square define GetMinimapShape (community
-- convention). Resolved on login and zoning; the shape is static.
local function RefreshShapeState()
  if type(GetMinimapShape) ~= "function" then
    squareMinimap = false
    return
  end
  local shape = GetMinimapShape()
  squareMinimap = shape ~= nil and shape ~= "ROUND"
end

function MinimapSurface:Update(dirX, dirY)
  local width, height = self.lineFrame:GetWidth(), self.lineFrame:GetHeight()
  if width <= 0 or height <= 0 then
    return self:HideLine()
  end

  -- A rotating minimap already puts the player's facing at the top.
  if rotateMinimap then
    dirX, dirY = 0, -1
  end

  local centerX, centerY = width / 2, height / 2

  local endX, endY
  if squareMinimap then
    endX, endY = ns.ClipRayToRect(centerX, centerY, dirX, dirY, width, height)
  else
    local radius = math.min(width, height) / 2 - MINIMAP_INSET
    endX, endY = ns.ClipRayToCircle(centerX, centerY, dirX, dirY, radius)
  end

  if not endX then
    return self:HideLine()
  end

  -- Minimap-replacement addons rescale the minimap.
  self:RefreshThickness()
  self.line:SetStartPoint("TOPLEFT", centerX, -centerY)
  self.line:SetEndPoint("TOPLEFT", endX, -endY)
  self.line:Show()
end

--------------------------------------------------------------------------------
-- Attachment
--------------------------------------------------------------------------------

local lineFrame = CreateFrame("Frame", nil, Minimap)
lineFrame:SetAllPoints(Minimap)
lineFrame:SetFrameLevel(Minimap:GetFrameLevel() + 5)
lineFrame:Show()

local line = lineFrame:CreateLine()
line:Hide()

ns.RegisterSurface(setmetatable({
  key = "minimap",
  dbKey = "showMinimap",
  host = Minimap,
  lineFrame = lineFrame,
  line = line,
}, MinimapSurface))

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterEvent("CVAR_UPDATE")
watcher:SetScript("OnEvent", function(_, event, cvarName)
  if event == "CVAR_UPDATE" then
    if cvarName ~= "rotateMinimap" and cvarName ~= "ROTATE_MINIMAP" then
      return
    end
    RefreshRotationState()
    return
  end

  -- PLAYER_ENTERING_WORLD: minimap addons have had a chance to load and set
  -- their shape by now.
  RefreshRotationState()
  RefreshShapeState()
end)

RefreshRotationState()
RefreshShapeState()
