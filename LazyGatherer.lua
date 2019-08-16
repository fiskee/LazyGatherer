local herbObject, gatherPulse, skinOrLootUnit
local playerCasting, playerCombat, playerMoving, playerLooting = false, false, false, false
local pulseDelay = 0.5

local function Set(list)
  local set = {}
  for _, l in ipairs(list) do
    set[l] = true
  end
  return set
end

local herbs =
  Set {
  294125,
  276242,
  276234,
  281870,
  276237,
  276238,
  276239,
  281869,
  276240,
  281872,
  281079,
  281868,
  281867,
  276236,
  326598
}

local function CalculateDistance(unit1, unit2)
  local x1, y1, z1 = ObjectPosition(unit1)
  local x2, y2, z2 = ObjectPosition(unit2)
  return math.sqrt(((x2 - x1) ^ 2) + ((y2 - y1) ^ 2) + ((z2 - z1) ^ 2)) -
    ((UnitCombatReach(unit1) or 0) + (UnitCombatReach(unit2) or 0)), z2 - z1
end

local function GetGatherUnits()
  if skinOrLootUnit == nil or UnitIsVisible(skinOrLootUnit) == false then
    skinOrLootUnit = nil
  end
  if herbObject == nil or ObjectDescriptor(herbObject, 0xDC, Types.Byte) > 0 then
    herbObject = nil
  end
  for i = 1, GetObjectCount() do
    local thisObject = GetObjectWithIndex(i)
    local thisObjectDistance = CalculateDistance("player", thisObject)
    if herbs[ObjectID(thisObject)] and ObjectDescriptor(thisObject, 0xDC, Types.Byte) == 0 then
      if herbObject == nil or CalculateDistance("player", herbObject) > thisObjectDistance then
        herbObject = thisObject
      end
    end
    if (skinOrLootUnit == nil or CalculateDistance("player", skinOrLootUnit) > thisObjectDistance) and
        (UnitCanBeSkinned(thisObject) or UnitCanBeLooted(thisObject)) and
        UnitIsVisible(thisObject) and
        UnitIsDeadOrGhost(thisObject)
     then
      skinOrLootUnit = thisObject
    end
  end
end

local function Gather()
  GetGatherUnits()
  if not playerMoving and not playerCombat then
    if herbObject and CalculateDistance("player", herbObject) <= 5 and IsUsableSpell(GetSpellInfo(11993)) then
      InteractUnit(herbObject)
      herbObject = nil
      return
    end
    if skinOrLootUnit and CalculateDistance("player", skinOrLootUnit) <= 5 and IsUsableSpell(GetSpellInfo(10768)) then
      InteractUnit(skinOrLootUnit)
      skinOrLootUnit = nil
    end
  end
end

local GatherFrame = CreateFrame("BUTTON", "GatherFrame", UIParent)
local gatherStatus = GatherFrame:CreateFontString("GatherStatusText", "OVERLAY")
local distanceText = GatherFrame:CreateFontString("ArrowDistanceText", "OVERLAY")
local nodeArrow = GatherFrame:CreateTexture("nodeArrow", "OVERLAY")

GatherFrame:SetScript(
  "OnEvent",
  function(self, event, ...)
    local arg1, arg2, arg3 = ...
    if event == "PLAYER_LOGIN" then
      if LazyGathererEnabled == nil then
        LazyGathererEnabled = false
      end
      if LazyGathererPosition == nil then
        LazyGathererPosition = {}
        LazyGathererPosition.point = "CENTER"
        LazyGathererPosition.relativePoint = "TOP"
        LazyGathererPosition.xOfs = 2
        LazyGathererPosition.yOfs = -70
      end
      GatherFrame:SetWidth(80)
      GatherFrame:SetHeight(80)
      GatherFrame:SetPoint(
        LazyGathererPosition.point,
        UIParent,
        LazyGathererPosition.relativePoint,
        LazyGathererPosition.xOfs,
        LazyGathererPosition.yOfs
      )
      GatherFrame:SetMovable(true)
      GatherFrame:EnableMouse(true)
      GatherFrame:RegisterForClicks("RightButtonUp")
      GatherFrame:SetScript(
        "OnClick",
        function(self, button, down)
          if LazyGathererEnabled == false then
            LazyGathererEnabled = true
          else
            LazyGathererEnabled = false
          end
        end
      )
      GatherFrame:SetScript(
        "OnMouseDown",
        function(self, button)
          if button == "LeftButton" and not self.isMoving then
            self:StartMoving()
            self.isMoving = true
          end
        end
      )
      GatherFrame:SetScript(
        "OnMouseUp",
        function(self, button)
          if button == "LeftButton" and self.isMoving then
            self:StopMovingOrSizing()
            self.isMoving = false
            local point, _, relativePoint, xOfs, yOfs = self:GetPoint(1)
            LazyGathererPosition.point = point
            LazyGathererPosition.relativePoint = relativePoint
            LazyGathererPosition.xOfs = xOfs
            LazyGathererPosition.yOfs = yOfs
          end
        end
      )
      gatherStatus:SetFontObject(GameFontNormalSmall)
      gatherStatus:SetJustifyH("CENTER")
      gatherStatus:SetPoint("CENTER", GatherFrame, "CENTER", 0, 0)
      gatherStatus:SetText("Gathering |cffff0000Disabled")
      nodeArrow:SetAllPoints(true)
      nodeArrow:SetPoint("CENTER")
      nodeArrow:SetTexture("Interface\\Minimap\\Vehicle-SilvershardMines-Arrow")
      distanceText:SetFontObject(GameFontNormalSmall)
      distanceText:SetJustifyH("CENTER")
      distanceText:SetPoint("CENTER", GatherFrame, "BOTTOM", 0, 0)
      distanceText:SetText("Distance")
    elseif event == "PLAYER_REGEN_ENABLED" then
      playerCombat = false
    elseif event == "PLAYER_REGEN_DISABLED" then
      playerCombat = true
    elseif event == "PLAYER_STARTED_MOVING" then
      playerMoving = true
    elseif event == "PLAYER_STOPPED_MOVING" then
      playerMoving = false
    elseif event == "LOOT_OPENED" then
      playerLooting = true
    elseif event == "LOOT_CLOSED" then
      playerLooting = false
      gatherPulse = GetTime() + 1
    elseif event == "UNIT_SPELLCAST_START" then
      if arg1 == "player" then
        playerCasting = true
      end
    elseif event == "UNIT_SPELLCAST_STOP" then
      if arg1 == "player" then
        playerCasting = false
        gatherPulse = GetTime() + 1
      end
    end
  end
)

local sqrt2 = sqrt(2)
local rads45 = 0.25 * PI
local rads135 = 0.75 * PI
local rads225 = 1.25 * PI
local cos, sin = math.cos, math.sin
local function corner(r)
  return 0.5 + cos(r) / sqrt2, 0.5 + sin(r) / sqrt2
end

local function UpdateArrow()
  if herbObject == nil then
    nodeArrow:Hide()
    distanceText:Hide()
    return
  end
  local playerX, playerY, playerZ = ObjectPosition("player")
  local unitX, unitY, unitZ = ObjectPosition(herbObject)
  local distance, zDif = CalculateDistance("player", herbObject)
  if not playerX or not unitX or CalculateDistance("player", herbObject) > 1000 then
    nodeArrow:Hide()
    distanceText:Hide()
    return
  end

  if distance < 40 then
    nodeArrow:SetVertexColor(0, 1, 0)
  elseif distance < 150 then
    nodeArrow:SetVertexColor(1, 1, 1)
  elseif distance < 500 then
    nodeArrow:SetVertexColor(1, 0, 0)
  else
    nodeArrow:SetVertexColor(.5, .5, 1)
  end

  local angle = atan2(unitY - playerY, unitX - playerX) * PI / 180 - GetPlayerFacing()
  local ULx, ULy = corner(angle + rads225)
  local LLx, LLy = corner(angle + rads135)
  local URx, URy = corner(angle - rads45)
  local LRx, LRy = corner(angle + rads45)

  nodeArrow:SetTexCoord(ULx, ULy, LLx, LLy, URx, URy, LRx, LRy)

  distanceText:SetText(format("%d yds (%d)", distance, zDif))

  distanceText:Show()
  nodeArrow:Show()
end

GatherFrame:RegisterEvent("PLAYER_LOGIN")
GatherFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
GatherFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
GatherFrame:RegisterEvent("PLAYER_STARTED_MOVING")
GatherFrame:RegisterEvent("PLAYER_STOPPED_MOVING")
GatherFrame:RegisterEvent("LOOT_OPENED")
GatherFrame:RegisterEvent("LOOT_CLOSED")
GatherFrame:RegisterUnitEvent("UNIT_SPELLCAST_START")
GatherFrame:RegisterUnitEvent("UNIT_SPELLCAST_STOP")

GatherFrame:SetScript(
  "OnUpdate",
  function(self, elapsed)
    if LazyGathererEnabled and not playerLooting and not playerCasting then
      if gatherPulse == nil then
        gatherPulse = GetTime()
      end
      if GetTime() > gatherPulse then
        Gather()
        gatherPulse = GetTime() + pulseDelay
      end
    end
    if LazyGathererEnabled then
      gatherStatus:SetText("Gathering |cFF00FF00Enabled")
    end
    if not LazyGathererEnabled then
      gatherStatus:SetText("Gathering |cffff0000Disabled")
      herbObject, skinOrLootUnit = nil, nil
    end
    UpdateArrow()
  end
)
