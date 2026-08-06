-- Minimap.lua
-- Surface for the minimap.
--
-- Simpler than the map canvases: the player is always at the centre of the
-- minimap, so there is no C_Map lookup to do. The two things that need handling
-- are the round shape (clip the ray to a circle, not a rectangle) and minimap
-- rotation, where the map spins under a fixed player arrow and the line must
-- therefore always point straight up.

local addonName, ns = ...

local MINIMAP_INSET = 1 -- keeps the line from tucking under the minimap border

-- IsAvailable, HideLine, ApplyStyle and RefreshThickness all come from
-- ns.Surface; only Update differs between the minimap and the map canvases.
local MinimapSurface = setmetatable({}, { __index = ns.Surface })
MinimapSurface.__index = MinimapSurface

local rotateMinimap = false
local squareMinimap = false

local function RefreshRotationState()
  if C_CVar and C_CVar.GetCVarBool then
    rotateMinimap = C_CVar.GetCVarBool("rotateMinimap") and true or false
  elseif GetCVarBool then
    rotateMinimap = GetCVarBool("rotateMinimap") and true or false
  end
end

-- Some addons make the minimap square and advertise it through this long
-- standing community convention. Honouring it costs almost nothing and avoids a
-- visibly wrong line for those users.
--
-- Resolved on login and on zoning rather than per frame: the shape is set by
-- whichever minimap addon is installed and is even more static than the
-- rotation CVar cached above it.
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

  -- With minimap rotation on, the minimap itself is rotated so that the
  -- player's facing is always up; drawing the world-space vector would double
  -- the rotation.
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

  -- The minimap sits at UIParent scale by default, but minimap-replacement
  -- addons rescale it routinely, so this is re-derived here for the same reason
  -- the map canvases do it.
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
