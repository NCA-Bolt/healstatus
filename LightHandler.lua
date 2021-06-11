local _, addon = ...;

addon.LIGHT_ACTION_VALUES = {
	Light = 0,
	FlashSix = 1,

	Blessing = 2,
	BlessingAlt = 3,
	Cleanse = 4,

	Drink = 5,

	Follow = 6,
	Jump = 7,

	FlashFour = 8,
	FlashOne = 9,

	Ressurect = 10,

	Mount = 11,
	Interact = 12,

	Protection = 13,
	Bubble = 14,

	AcceptTrade = 31,

	Nothing = -1
};
addon.LIGHT_ACTION_VALUES_PRIEST = {
	GreaterHeal = 0,
	Heal = 1,
	FlashHeal = 8,

	Fortitude = 2,
	Spirit = 3,
	
	DispelMagic = 4,
	CleanseDisease = 9,

	Drink = 5,
	Follow = 6,
	Jump = 7,

	Ressurect = 10,

	Mount = 11,
	Nothing = -1
};

local LIGHT_SIZE = 4;

local LIGHT_ROWS = 100;
local LIGHT_KEY_COUNT = 1;
local LIGHT_TARGET_COUNT = 2;
local LIGHT_ACTION_COUNT = 2;

local LIGHT_COUNT = LIGHT_KEY_COUNT + LIGHT_TARGET_COUNT + LIGHT_ACTION_COUNT;

local TARGET_LIGHT_PLAYER_VALUE = 1;
local TARGET_LIGHT_PARTY_VALUE = 2;
local TARGET_LIGHT_FOCUS_VALUE = 6;
local TARGET_LIGHT_RAID_VALUE = 7;

local KEY_LIGHT_ACTIVE_VALUE = 1;

addon.initLights = function() 
	local scale = string.match( GetCVar( "gxWindowedResolution" ), "%d+x(%d+)" );
	local uiScale = UIParent:GetScale( );
	local scaleScalar = 768 / scale / uiScale;

	for i=1,LIGHT_COUNT do
		local ai = i - 1;
		local x = math.floor(ai / LIGHT_ROWS) * scaleScalar;
		local y = (ai % LIGHT_ROWS * LIGHT_SIZE) * scaleScalar;

		addon.lights[i] = CreateFrame("frame", nil, UIParent); 
		addon.lights[i]:SetFrameStrata("TOOLTIP");

		addon.lights[i]:SetWidth(LIGHT_SIZE * scaleScalar);
		addon.lights[i]:SetHeight(LIGHT_SIZE * scaleScalar);
		addon.lights[i]:SetPoint("TOPLEFT", UIParent, "TOPLEFT", y, y);
		addon.lights[i].texture = addon.lights[i]:CreateTexture(nil, "BACKGROUND");
		addon.lights[i].texture:SetAllPoints(true);
		addon.lights[i]:SetClampedToScreen(true);
		addon.updateLightStatus(i, 1, 0, 0);
	end
end

addon.updateLightStatus = function(index, r, g, b)
	if (addon.lights[index] ~= nil) then
		local color = r + g * 2 + b * 4;

		if (addon.lights[index].previousColor ~= color) then
			if (color == 1) then
				addon.lights[index].texture:SetTexture("Interface\\AddOns\\HealLightStatus\\assets\\red");
			elseif (color == 2) then
				addon.lights[index].texture:SetTexture("Interface\\AddOns\\HealLightStatus\\assets\\green");
			elseif (color == 3) then
				addon.lights[index].texture:SetTexture("Interface\\AddOns\\HealLightStatus\\assets\\yellow");
			elseif (color == 4) then
				addon.lights[index].texture:SetTexture("Interface\\AddOns\\HealLightStatus\\assets\\blue");
			elseif (color == 5) then
				addon.lights[index].texture:SetTexture("Interface\\AddOns\\HealLightStatus\\assets\\magenta");
			elseif (color == 6) then
				addon.lights[index].texture:SetTexture("Interface\\AddOns\\HealLightStatus\\assets\\teal");
			elseif (color == 7) then
				addon.lights[index].texture:SetTexture("Interface\\AddOns\\HealLightStatus\\assets\\white");
			else
				addon.lights[index].texture:SetTexture("Interface\\AddOns\\HealLightStatus\\assets\\black");
			end
			addon.lights[index].previousColor = color;

			-- print("color updated: " .. tostring(index) .. " to " .. tostring(color));
		end
	end
end

addon.clearLights = function() 
  for i=1, LIGHT_KEY_COUNT do
    addon.updateLightStatus(i, 0, 0, 0);
  end

  for i=1, LIGHT_TARGET_COUNT do
    addon.updateLightStatus(LIGHT_KEY_COUNT + i, 0, 0, 0);
  end

  for i=1, LIGHT_ACTION_COUNT do
    local adjustedI = LIGHT_KEY_COUNT + LIGHT_TARGET_COUNT + i;
    addon.updateLightStatus(adjustedI, 0, 0, 0);
  end
end

local bitand = function(a, b)
	local result = 0
	local bitval = 1
	while a > 0 and b > 0 do
		if a % 2 == 1 and b % 2 == 1 then -- test the rightmost bits
				result = result + bitval      -- set the current bit
		end
		bitval = bitval * 2 -- shift left
		a = math.floor(a/2) -- shift right
		b = math.floor(b/2)
	end
	return result
end

local writeLightSpan = function(value, offset, length)
	if value < 0 then
		value = 0;
	end

  for i=1, length do
    local adjustedI = offset + i;
    local subIndexStart = ((i - 1) * 3);

    local rPixelValue = math.pow(2, subIndexStart);
    local gPixelValue = math.pow(2, subIndexStart + 1);
    local bPixelValue = math.pow(2, subIndexStart + 2);

    local r = (bitand(value, rPixelValue) ~= 0 and 1) or 0;
    local g = (bitand(value, gPixelValue) ~= 0 and 1) or 0;
    local b = (bitand(value, bPixelValue) ~= 0 and 1) or 0;

		-- print(tostring(value) .. "=" .. tostring(r) .. ":" .. tostring(g) .. ":" .. tostring(b));

    addon.updateLightStatus(adjustedI, r, g, b);
  end
end

addon.writeLights = function(nextCastTarget, nextCastAbility)
  addon.nextCastTarget = nextCastTarget;
  addon.nextCastAbility = nextCastAbility;

  local keyValue = (((addon.nextCastAbility ~= "Nothing" and 1) or 0) + ((addon.nextCastTarget ~= -1 and 1) or 0);

  local target;
  local targetValue = 0;

  if (type(addon.nextCastTarget) == "number") then
    target = addon.nextCastTarget;
    targetValue = addon.nextCastTarget;
  else
    target = addon.getIndexFromTargetString(addon.nextCastTarget);
    
    local friend = addon.getFriendFromTargetString(addon.nextCastTarget);
    if (friend) then
      friend.isOutOfLOS = false;
    end
      
    if (target) then
      if (target.type == "player") then
        targetValue = TARGET_LIGHT_PLAYER_VALUE;
      elseif (target.type == "focus") then
        targetValue = TARGET_LIGHT_FOCUS_VALUE;
      elseif (target.type == "party") then
        targetValue = TARGET_LIGHT_PARTY_VALUE + target.index;
      elseif (target.type == "raid") then
        targetValue = TARGET_LIGHT_RAID_VALUE + target.index;
      end
    end
  end

  local actionValueMap = 
    (addon.isPaladin() and addon.LIGHT_ACTION_VALUES) or
    (addon.isPriest() and addon.LIGHT_ACTION_VALUES_PRIEST) or
    addon.LIGHT_ACTION_VALUES;
  
  local actionValue = actionValueMap[addon.nextCastAbility];

  writeLightSpan(keyValue, 0, LIGHT_KEY_COUNT);
  writeLightSpan(targetValue, LIGHT_KEY_COUNT, LIGHT_TARGET_COUNT);
  writeLightSpan(actionValue, LIGHT_KEY_COUNT + LIGHT_TARGET_COUNT, LIGHT_ACTION_COUNT);
end