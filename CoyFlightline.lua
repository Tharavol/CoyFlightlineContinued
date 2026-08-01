
-- make a frame to hold the line, parented to the map window
-- parenting to the map window hides and shows the line frame automatically when the map is opened/closed
local lineFrame = CreateFrame("frame", "CoyFlightlineFrame", WorldMapFrame.ScrollContainer)
lineFrame:SetAllPoints()  -- set this new frame to the same size and location as the map
lineFrame:SetFrameLevel(150)  -- raise the line's draw level a bit
lineFrame:SetClipsChildren(true)  -- set the frame to clip children. the line is drawn intentionally too long, this clips it down to stay within the map

-- make the line itself, set color and thickness
local line = lineFrame:CreateLine()
line:SetColorTexture(1,1,1,1)
line:SetThickness(1)

-- every frame
lineFrame:SetScript("OnUpdate", function(self, elapsed)
  if (WorldMapFrame:IsShown() and IsFlying() and not IsInInstance() and GetPlayerFacing()) then
    -- get the player direction in radians, convert that to a vector
    local direction = GetPlayerFacing()
    local directionVector = {x = -math.sin(direction), y = -math.cos(direction)}

    -- this can return null if the player isn't actually on the map, so like if you change zones
    local vec2Position = C_Map.GetPlayerMapPosition(WorldMapFrame.mapID, "player")
    -- if that's the case, hide the line
    if vec2Position then
      line:Show()
    else
      line:Hide()
      return
    end

    -- get the frame's width and height. this could probably be pulled out of the update function, but nice to have here in case you resize the map window
    local width, height = lineFrame:GetWidth(), lineFrame:GetHeight()
    -- the line length is just set to roughly the largest that could be drawn on the map window
    -- this approximates the hypotenuse, good enough and faster than a square root
    local lineLength = 5 * (width+height) / 7 

    -- get the players position and convert to coordinates relative to the frame
    local playerXPos, playerYPos = vec2Position:GetXY()
    local playerXCoord = playerXPos * width
    local playerYCoord = playerYPos * height

    -- project in the player's direction. This will almost always go way outside the map window, but since the frame clips children it'll be cut off at the edge
    local endX = (directionVector.x * lineLength) + playerXCoord
    local endY = (directionVector.y * lineLength) + playerYCoord

    -- set the line end points
    line:SetStartPoint("TOPLEFT", playerXCoord, -playerYCoord)
    line:SetEndPoint("TOPLEFT", endX, -endY)
  else
    -- if the line isn't being updated, then hide it
    line:Hide()
  end
end)

lineFrame:Show()
