--[[
	Author: perryfraser@gmail.com
--]]

local function has_value (tab, val)
	for index, value in ipairs(tab) do
			-- We grab the first index of our sub-table instead
			if value[1] == val then
					return true
			end
	end

	return false
end

-- Addon Global Variables (shared between files but not addons). addon var name can be renamed
local _, addon = ...;
local swingTimer = 0.00001;
local currentSwingTime = 2;

local TANK_COMBAT_DURATION_THRESHOLD = 4;
local TANK_STILL_DURATION_THRESHOLD = 2;
local TANK_STILL_AOE_DURATION_THRESHOLD = 8;

local BIG_MAX = 9999;

local FORCE_ACTION_TIME = 1.5;
local FLASH_TIME = 2;
local LIGHT_TIME = 3;
local BLESSING_VALUE = 20;
local FORTITUDE_VALUE = 20;
local RESSURECT_DEFAULT_VALUE = 25;
local COMBAT_DEFAULT_VALUE = 14;
local RESOLVE_THRESHOLD = 4;
local COMBAT_FOLLOW_SCALAR = 0.5;

local OUT_OF_LINE_OF_SIGHT_FADE = 18;
local OUT_OF_LINE_OF_SIGHT_FADE_SCALAR = 3;

local FOCUS_INDEX = -1234;
local PLAYER_INDEX = -1233;

local BLESSING_KEY = "Blessing";
local FORTITUDE_KEY = "Fortitude";

-- there is a macro that sets this to 1 then 2, etc.
local jumpAdjustor = 0;

-- # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # test if this works with offline people
LightStatus = {}
LightStatus.followBlock = false;
LightStatus.onlyFollow = false;
LightStatus.buffBlock = false;
LightStatus.aoeFocus = false;
LightStatus.onlyTankHeals = false;

LightStatus.parseCommand = function(ctrl, alt, shift) 
	local text = "";

	if (ctrl and alt and shift) then

	elseif (ctrl and alt) then
		LightStatus.aoeFocus = not LightStatus.aoeFocus;
		text = "AOE Focus: " .. tostring(LightStatus.aoeFocus);
	elseif (ctrl and shift) then

	elseif (alt and shift) then
		
	elseif (alt) then
		LightStatus.buffBlock = not LightStatus.buffBlock;
		text = "Buff Block: " .. tostring(LightStatus.buffBlock);
	elseif (ctrl) then
		LightStatus.onlyFollow = not LightStatus.onlyFollow;
		text = "Only Follow: " .. tostring(LightStatus.onlyFollow);
	elseif (shift) then
		LightStatus.onlyTankHeals = not LightStatus.onlyTankHeals;
		text = "Only Tank: " .. tostring(LightStatus.onlyTankHeals);
	else
		LightStatus.followBlock = not LightStatus.followBlock;

		text = "Follow Block: " .. tostring(LightStatus.followBlock);

		if (LightStatus.followBlock) then
			FollowUnit('player');
		end
	end

	RaidNotice_AddMessage(RaidWarningFrame, text, ChatTypeInfo["RAID_WARNING"])
end

addon.version = "1.0.0"
addon.name = "Light Status"
addon.debug = false;
addon.initd = false;

addon.playerBean = {};
addon.friendBean = {};
addon.followBean = {
	targetName = "Cherrypear",
	followScore = 0
};
addon.tankBean = {
	targetName = "Pearberry",
	isInCombatStart = -1,
	isInCombat = false,
	isStillStart = -1,
	isStill = false
};

addon.nextActionBean = {};

addon.lights = {};

addon.nextCastTarget = -1;
addon.nextCastAbility = -1;

addon.currentDangerValue = 0;

local playerClass = UnitClass("player");
addon.isPriest = function()
	return playerClass == "Priest";
end
addon.isPaladin = function() 
	return playerClass == "Paladin";
end
addon.isWarrior = function()
	return playerClass == "Warrior";
end

addon.updateUI = function()
	if (addon.lights[0] ~= nil) then
		-- print('')
	end
end

-- onUpdateHandler
addon.onUpdateHandler = function(self, elapsed)
	if (not addon.initd) then 
		return;
	end

	if (UnitIsDeadOrGhost("player")) then
		addon.clearLights();
		addon.updateUI();
		
		return;
	end

	-- general update;

	if (not addon.nextActionBean.force) then
		addon.nextActionBean = addon.getActionBean();
	end

	if (addon.nextActionBean) then
		-- check the force action
		if (addon.nextActionBean.force) then
			local currentForceTimeDiff = GetTime() - addon.nextActionBean.forceTime;

			if (currentForceTimeDiff >= FORCE_ACTION_TIME) then
				addon.nextActionBean.force = false;
			end
		end

		-- print(tostring(addon.nextCastAbility) .. " : " .. tostring(addon.nextCastTarget));
		addon.writeLights(addon.nextActionBean.target, addon.nextActionBean.action);
	end
	addon.updateUI();
end

addon.updatePlayer = function()
	local isInCombat = UnitAffectingCombat("player");
	local speed = GetUnitSpeed("player");
	local castingSpell, _, _, _, _, _, _, _, castingSpellId = CastingInfo();
	local channelingSpell, _, _, _, _, _, _, channelingSpellId = ChannelInfo();
	local mana = UnitPower("player");
	local manaMax = UnitPowerMax("player");

	local isDrinking = addon.getTargetHasBuff("player", "Drink") or addon.getTargetHasBuff("player", "Underspore Pod");

	addon.playerBean["isDrinking"] = isDrinking;
	addon.playerBean["speed"] = speed;
	addon.playerBean["isMoving"] = speed ~= 0;
	addon.playerBean["isInCombat"] = isInCombat;
	addon.playerBean["castingSpell"] = castingSpell or channelingSpell;
	addon.playerBean["castingSpellId"] = castingSpellId or channelingSpellId;
	addon.playerBean["manaRatio"] = mana / manaMax;
	addon.playerBean["mana"] = mana;
end

addon.getForceActionBean = function(action, target) 
	return {
		force = true,
		forceTime = GetTime(),
		action = action,
		target = target
	};
end

addon.getDefaultActionBean = function()
	local highestAction = "Nothing";
	local highestActionValue = RESOLVE_THRESHOLD;
	local highestActionTarget = "";
	
	if (addon.playerBean["isDrinking"]) then
		-- check player mana percentage
		if (addon.playerBean["manaRatio"] >= 0.96) then
			highestAction = "Jump";
			highestActionValue = BIG_MAX;
		else
			highestAction = "Nothing";
			highestActionValue = (addon.playerBean["isInCombat"] and 90) or BIG_MAX;
		end
	else
		if (not addon.playerBean["isInCombat"]) then
			local drinkValue = math.min(((1 - addon.playerBean["manaRatio"]) * 100) / 2 - 10, 30);

			if (drinkValue >= RESOLVE_THRESHOLD) then
				highestAction = "Drink";
				highestActionValue = drinkValue;
			end
		end
	end

	if (addon.followBean.followScore > highestActionValue) then
		highestAction = addon.followBean.followAction;
		highestActionValue = addon.followBean.followScore;
		highestActionTarget = addon.followBean.followTarget;
	end

	return {
		value = highestActionValue,
		target = highestActionTarget,
		action = highestAction
	}
end

addon.getActionBeanPaladin = function() 
	if (addon.playerBean["castingSpell"]) then
		-- can't do anything, so just clear info.
		if (string.match(addon.playerBean["castingSpell"], "Redemption")) then
			local unitIsDead = UnitIsDeadOrGhost("target");

			if (not unitIsDead) then
				return {
					action = "Cleanse",
					value = BIG_MAX
				}
			end
		end

		local maxHealth = UnitHealthMax("target");
		local health = UnitHealth("target");
		local healthMissing = maxHealth - health;
		
		if (addon.playerBean["castingSpellId"] == 27136) then
			-- test the current targets info.
			local testScore = addon.getLightCancelScore(healthMissing);
			
			if (testScore < RESOLVE_THRESHOLD) then
				return {
					action = "Cleanse",
					value = BIG_MAX
				}
			end
		elseif (addon.playerBean["castingSpellId"] == 27137) then
			local testScore = addon.getFlashCancelScore(healthMissing);

			if (testScore < RESOLVE_THRESHOLD) then
				return {
					action = "Cleanse",
					value = BIG_MAX
				}
			end
		end
	
		return {
			action = "Nothing",
			value = BIG_MAX
		}
	else
		local highestAction = "Nothing";
		local highestActionValue = RESOLVE_THRESHOLD;
		local highestActionTarget = "";
		-- print(tostring(drinkValue));

		for k, v in pairs(addon.friendBean) do
			if ((v ~= nil) and
				 ((not LightStatus.onlyTankHeals) or (v["name"] == addon.tankBean.targetName))) then

				if (v["cleanseScore"] and v["cleanseScore"] > highestActionValue) then
					highestAction = "Cleanse";
					highestActionValue = v["cleanseScore"];
					highestActionTarget = v["targetString"];
				end
				
				if (not LightStatus.buffBlock) then
					if (v["blessingScore"] and v["blessingScore"] > highestActionValue) then
						highestAction = (v["class"] == "Warrior" and "BlessingAlt") or (v["class"] == "Rogue" and "BlessingAlt") or "Blessing";
						highestActionValue = v["blessingScore"];
						highestActionTarget = v["targetString"];
					end
				end

				if (not addon.playerBean["isMoving"]) then
					-- can only cast moving things
					if ((not LightStatus.onlyTankHeals) and v["lightScore"] and v["lightScore"] > highestActionValue) then
						highestAction = ((addon.playerBean["isInCombat"]) and "Light") or "FlashSix";
						highestActionValue = v["lightScore"];
						highestActionTarget = v["targetString"];
					end

					if (v["flashScore"] and (v["flashScore"] > highestActionValue)) then
						highestAction = "FlashSix";
						highestActionValue = v["flashScore"];
						highestActionTarget = v["targetString"];
					end
					
					if (v["ressurectScore"] and v["ressurectScore"] > highestActionValue) then
						highestAction = "Ressurect";
						highestActionValue = v["ressurectScore"];
						highestActionTarget = v["targetString"];
					end
				end
			end
		end

		if (highestAction == "Nothing" and addon.playerBean.isMoving and (highestActionValue <= RESOLVE_THRESHOLD) and ((GetTime() % (5 - jumpAdjustor)) < 0.5)) then
			jumpAdjustor = math.random() * 4;
			-- jump sometimes
			highestActionValue = RESOLVE_THRESHOLD;
			highestAction = "Jump";
		end

		return {
			value = highestActionValue,
			target = highestActionTarget,
			action = highestAction
		}
	end
end

addon.getRangedAOEActionBean = function() 
  local inTen = CheckInteractDistance(addon.tankBean.target, 2); -- 10 yard range
  local inEighteen = IsItemInRange(6450, addon.tankBean.target); -- 18 yard range
  local inTwentyThree = IsItemInRange(21519, addon.tankBean.target); -- 23 yard range
  local inThirty = CheckInteractDistance(addon.tankBean.target, 4); -- 28 yard range
  local inThirtyThree = IsItemInRange(1180, addon.tankBean.target);

  -- send the target as a number
  return {
    action = "RainOfFire",
    target = 
      (inThirtyThree and 5) or
      (inThirtyThree and 4) or
      (inThirtyThree and 3) or
      (inThirtyThree and 2) or
      (inThirtyThree and 1),
    value = COMBAT_DEFAULT_VALUE
  };
end

addon.getActionBeanPriest = function() 
	if (addon.playerBean["castingSpell"]) then
		-- can't do anything, so just clear info.
		if (string.match(addon.playerBean["castingSpell"], "Resurrection")) then
			local unitIsDead = UnitIsDeadOrGhost("target");

			if (not unitIsDead) then
				return {
					action = "DispelMagic",
					value = BIG_MAX
				}
			end
		end

		local maxHealth = UnitHealthMax("target");
		local health = UnitHealth("target");
		local healthMissing = maxHealth - health;
		
		if (string.match(addon.playerBean["castingSpell"], "Greater Heal")) then
			-- test the current targets info.
			local testScore = addon.getGreaterHealCancelScore(healthMissing);

			if (testScore < RESOLVE_THRESHOLD) then
				return {
					action = "DispelMagic",
					value = BIG_MAX
				}
			end
		elseif (addon.playerBean["castingSpell"] == "Heal") then
			local testScore = addon.getHealCancelScore(healthMissing);

			if (testScore < RESOLVE_THRESHOLD) then
				return {
					action = "DispelMagic",
					value = BIG_MAX
				}
			end
		elseif (string.match(addon.playerBean["castingSpell"], "Flash Heal")) then
			local testScore = addon.getFlashHealCancelScore(healthMissing);

			if (testScore < RESOLVE_THRESHOLD) then
				return {
					action = "DispelMagic",
					value = BIG_MAX
				}
			end
		end
	
		return {
			action = "Nothing",
			value = BIG_MAX
		}
	else
		local highestAction = "Nothing";
		local highestActionValue = RESOLVE_THRESHOLD;
		local highestActionTarget = "";

		for k, v in pairs(addon.friendBean) do
			if (v ~= nil) then

				if (v["dispelMagicScore"] and v["dispelMagicScore"] > highestActionValue) then
					highestAction = "DispelMagic";
					highestActionValue = v["dispelMagicScore"];
					highestActionTarget = v["targetString"];
				end

				if (v["cleanseDiseaseScore"] and v["cleanseDiseaseScore"] > highestActionValue) then
					highestAction = "CleanseDisease";
					highestActionValue = v["cleanseDiseaseScore"];
					highestActionTarget = v["targetString"];
				end
				
				if (not LightStatus.buffBlock) then
					if (v["fortitudeScore"] and v["fortitudeScore"] > highestActionValue) then
						highestAction = "Fortitude";
						highestActionValue = v["fortitudeScore"];
						highestActionTarget = v["targetString"];
					end
				end

				if (not addon.playerBean["isMoving"]) then
					-- can only cast moving things
					if (v["flashHealScore"] and v["flashHealScore"] > highestActionValue) then
						highestAction = "FlashHeal";
						highestActionValue = v["flashHealScore"];
						highestActionTarget = v["targetString"];
					end

					if (v["healScore"] and (v["healScore"] > highestActionValue)) then
						highestAction = "Heal";
						highestActionValue = v["healScore"];
						highestActionTarget = v["targetString"];
					end
					
					if (v["greaterHealScore"] and v["greaterHealScore"] > highestActionValue) then
						highestAction = "GreaterHeal";
						highestActionValue = v["greaterHealScore"];
						highestActionTarget = v["targetString"];
					end
					
					if (v["ressurectScore"] and v["ressurectScore"] > highestActionValue) then
						highestAction = "Ressurect";
						highestActionValue = v["ressurectScore"];
						highestActionTarget = v["targetString"];
					end
				end
			end
		end

		return {
			value = highestActionValue,
			target = highestActionTarget,
			action = highestAction
		}
	end
end

addon.updateTank = function()
  if (addon.tankBean.target) then
    local isInCombat = UnitAffectingCombat(addon.tankBean.targetName);
    local isMoving = GetUnitSpeed("player");
    local isStill = isMoving == 0;

    local currentTime = GetTime();

    -- check if the tank is in combat, 
    addon.tankBean.isStill = isStill;
    addon.tankBean.isInCombat = isInCombat;

    if (not isStill) then
      addon.tankBean.isStillStart = -1;
    elseif (addon.tankBean.isStillStart == -1) then
      addon.tankBean.isStillStart = currentTime;
    end

    if (not isInCombat) then
      addon.tankBean.isInCombatStart = -1;
    elseif (addon.tankBean.isInCombatStart == -1) then
      addon.tankBean.isInCombatStart = currentTime;
    end
  end
end

addon.getActionBean = function()
	local dangerScore = 0;
	local activeCount = 0;

	addon.updatePlayer();

	local friendCount = 0;
	local friendHealthRatio = 0;
	
	local focusValue = addon.updateFriendAtRaidIndex(FOCUS_INDEX);

	if (focusValue and focusValue["name"] == addon.followBean.targetName) then
		addon.followBean.target = focusValue["targetString"];
	end
	
	for raidIndex = 1, 40 do
		-- update the raid members
		local friendValue = addon.updateFriendAtRaidIndex(raidIndex);

		if (friendValue) then
			friendCount = friendCount + 1;
			friendHealthRatio = friendHealthRatio + friendValue["health"] / friendValue["maxHealth"];
			
			if (friendValue["name"] == addon.followBean.targetName) then
				addon.followBean.target = friendValue["targetString"];
			end
			
			if (friendValue["name"] == addon.tankBean.targetName) then
				addon.tankBean.target = friendValue["targetString"];
			end
		end
	end

	addon.updateFriendAtRaidIndex(PLAYER_INDEX);
	
	addon.currentDangerValue = 1 - (friendHealthRatio / (friendCount + 1));

	addon.updateTank();
	addon.updateFollow();
	local defaultBean = addon.getDefaultActionBean();

	if (addon.isPaladin()) then
		local paladinBean = addon.getActionBeanPaladin();

		if (paladinBean.value > defaultBean.value) then
			return paladinBean;
		end
	elseif (addon.isPriest()) then
		local priestBean = addon.getActionBeanPriest();

		if (priestBean.value and (priestBean.value > defaultBean.value)) then
			return priestBean;
		end
	end
	return defaultBean;
end

addon.getTargetHasBuff = function(targetString, buffTargetNames, isPlayerBuff)
	if (type(buffTargetNames) == "string") then
		buffTargetNames = {
			buffTargetNames
		};
	end

	for i=1, 40 do
		-- buffName, icon, count, debuffType, duration, expirationTime, caster
		local buffName, _, _, _, _, _, caster = UnitBuff(targetString, i);
	
		for i, buffTargetName in ipairs(buffTargetNames) do
			if ((buffName and string.find(buffName, buffTargetName))) then
				if (isPlayerBuff) then
					if (caster and caster == "player") then
						return true;
					end
				else
					return true;
				end
			end
		end
	end
	
	return false;
end

addon.getFriendFromTargetString = function(targetString)
	for k, v in pairs(addon.friendBean) do
		if (v ~= nil) then
			if (v.targetString == targetString) then
				return v;
			end
		end
	end
	return nil;
end

addon.getTargetStringFromName = function(name)
	for k, v in pairs(addon.friendBean) do
		if (v ~= nil) then
			if (v.name == name) then
				return v.targetString;
			end
		end
	end
	return nil;
end

addon.getIndexFromTargetString = function(targetString)
	for raidIndex = 1, 40 do
		local testString = "raid" .. tostring(raidIndex);

		if (targetString == testString) then
			return {
				type = "raid",
				index = raidIndex
			};
		end
	end

	for partyIndex = 1, 4 do
		local testString = "party" .. tostring(partyIndex);

		if (targetString == testString) then
			return {
				type = "party",
				index = partyIndex
			};
		end
	end

	if targetString == "focus" then
		return {
			type = "focus"
		};
	end

	if (targetString == "player") then return { type = "player" } end
	return nil;
end

addon.getTargetStringFromIndex = function(index)
	if (index == FOCUS_INDEX) then
		return "focus";
	end

	if (index == PLAYER_INDEX) then
		return "player";
	end

	local name, rank, subgroup, _, class, _, zone, online, isDead, role = GetRaidRosterInfo(index);

	for raidIndex = 1, 40 do
		local testString = "raid" .. tostring(raidIndex);
		local nameTest = GetUnitName(testString);

		if (nameTest == name) then
			return testString;
		end
	end

	for partyIndex = 1, 4 do
		local testString = "party" .. tostring(partyIndex);
		local nameTest = GetUnitName("party" .. tostring(partyIndex))

		if (nameTest == name) then
			return testString;
		end
	end

	local playerName = GetUnitName("player");
	if (playerName == name) then return "player"; end
	
	return "";
end

addon.setObjectToNoValue = function(guid)
	local object = addon.friendBean[guid];

	if (object) then
		-- pally stuff
		object.lightScore = 0;
		object.flashScore = 0;
		object.cleanseScore = 0;
		object.blessingScore = 0;
		-- priest stuff
		object.healScore = 0;
		object.greaterHealScore = 0;
		object.flashHealScore = 0;
		object.dispelMagicScore = 0;
		object.cleanseDiseaseScore = 0;
		object.fortitudeScore = 0;
		-- default stuff
		object.ressurectScore = 0;
		object.targetUid = nil;
		object.isInFollowRange = false;
	end
end

addon.updateFriendForPaladin = function(object)
	local isInCleanseRange = IsSpellInRange("Purify", object.targetString) == 1;
	local isInHealRange = IsSpellInRange("Flash of Light", object.targetString) == 1;

	local highestDebuff = addon.getCleanseScore(object.targetString);
	local hasBlessing = addon.getTargetHasBuff(object.targetString, BLESSING_KEY, true);

	local BLESSING_LOCK_DURATION = 180;

	if (hasBlessing and ((object.blessingApplied == 0) or (object.blessingDuration and object.blessingDuration > 0 and object.blessingDuration < BLESSING_LOCK_DURATION))) then
		object.blessingApplied = GetTime();
		object.blessingRemoved = BIG_MAX;
		object.blessingDuration = 0;
	end

	if (not hasBlessing) then
		if (object.blessingRemoved == BIG_MAX) then
			object.blessingRemoved = GetTime();
			object.blessingDuration = object.blessingRemoved - object.blessingApplied;
		end
		
		if (object.blessingDuration and object.blessingDuration < BLESSING_LOCK_DURATION) then
			-- don't reapply
			hasBlessing = true;
		end
	end

	if (not hasBlessing) then
		object.blessingApplied = 0;
		object.blessingRemoved = BIG_MAX;
	end

	local isOutOfLOSValue = (not object.isOutOfLOS and 1) or 0;

	-- work out the amounts
	if (isInHealRange) then
		local healthMissing = object.maxHealth - object.health;

		object.lightScore = addon.getLightScore(addon.playerBean["mana"], healthMissing, object.maxHealth, addon.currentDangerValue) * isOutOfLOSValue;
		object.flashScore = addon.getflashScore(addon.playerBean["mana"], healthMissing, object.maxHealth, addon.currentDangerValue) * isOutOfLOSValue;
	end
	
	if (isInCleanseRange) then
		object.cleanseScore = highestDebuff * isOutOfLOSValue;
		object.blessingScore = (((not hasBlessing) and BLESSING_VALUE) or 0) * isOutOfLOSValue;
	end
end

addon.updateFriendForPriest = function(object)
	local isInCleanseRange = IsSpellInRange("Dispel Magic", object.targetString) == 1;
	local isInHealRange = IsSpellInRange("Heal", object.targetString) == 1;

	local highestMagicDebuff = addon.getDispelMagicScore(object.targetString);
	local highestDiseaseDebuff = addon.getCleanseDiseaseScore(object.targetString);

	local hasFortitude = addon.getTargetHasBuff(object.targetString, FORTITUDE_KEY);

	local isOutOfLOSValue = (not object.isOutOfLOS and 1) or 0;

	-- work out the amounts
	if (isInHealRange) then
		local healthMissing = object.maxHealth - object.health;

		object.healScore = addon.getHealScore(addon.playerBean["mana"], healthMissing, object.maxHealth, addon.currentDangerValue) * isOutOfLOSValue;
		object.greaterHealScore = addon.getGreaterHealScore(addon.playerBean["mana"], healthMissing, object.maxHealth, addon.currentDangerValue) * isOutOfLOSValue;
		object.flashHealScore = addon.getFlashHealScore(addon.playerBean["mana"], healthMissing, object.maxHealth, addon.currentDangerValue) * isOutOfLOSValue;
	end

	if (isInCleanseRange) then
		object.dispelMagicScore = highestMagicDebuff * isOutOfLOSValue;
		object.cleanseDiseaseScore = highestDiseaseDebuff * isOutOfLOSValue;

		object.fortitudeScore = (((not hasFortitude) and FORTITUDE_VALUE) or 0) * isOutOfLOSValue;
	end
end

addon.updateFriendAtRaidIndex = function(raidIndex)
	local name, rank, subgroup, _, class, _, zone, online, isDead, role = GetRaidRosterInfo(raidIndex);
	local targetString = addon.getTargetStringFromIndex(raidIndex);
	local guid = UnitGUID(targetString);

	local object = addon.friendBean[guid] or {};

	if raidIndex == FOCUS_INDEX then
		name = UnitName("focus");
		guid = name;
		online = true;
	end

	if raidIndex == PLAYER_INDEX then
		name = UnitName("player");
		guid = name;
		online = true;
	end

	object.blessingApplied = object.blessingApplied or 0;
	object.blessingRemoved = object.blessingRemoved or BIG_MAX;

	if (guid == nil or name == nil) then
		return;
	end
	
	addon.friendBean[guid] = object;

	addon.setObjectToNoValue(guid);

	object.targetString = targetString;
	object.name = name; 
	object.class = class;


	local reaction = UnitReaction("player", targetString);
	if (reaction and (UnitReaction("player", targetString) <= 3)) then
		return;
	end

	-- check zone
	if (not online) then
		return;
	elseif (isDead) then
		local isInRessurectRange = (IsSpellInRange("Redemption", targetString) == 1) or (IsSpellInRange("Resurrection", targetString) == 1);

		object.ressurectScore = (isInRessurectRange and (RESSURECT_DEFAULT_VALUE + math.random() * 4)) or 0;

		object.health = 1;
		object.maxHealth = 1;

		object.blessingApplied = 0;
		object.blessingRemoved = BIG_MAX;
		return;
	end

	object.isInFollowRange = IsItemInRange(21519, targetString);

	local maxHealth = UnitHealthMax(targetString);
	local health = UnitHealth(targetString);

	local speed = GetUnitSpeed(targetString);
	
	if raidIndex == FOCUS_INDEX then
		local estimatedFocusHealth = 4500; -- a bit of overhealing
		object.health = (health / 100) * estimatedFocusHealth;
		object.maxHealth = estimatedFocusHealth;
	else 
		object.health = health;
		object.maxHealth = maxHealth;	
	end

	if (speed > 0) then
		object.isOutOfLOS = false;
	end

	if (addon.isPaladin()) then
		addon.updateFriendForPaladin(object);
	elseif (addon.isPriest()) then
		addon.updateFriendForPriest(object);
	end

	return object;
end

addon.onSpellCastFailed = function(message) 
	if (message == SPELL_FAILED_LINE_OF_SIGHT) then
		if (addon.nextCastTarget) then
			local friend = addon.getFriendFromTargetString(addon.nextCastTarget);

			if (friend) then
				friend.isOutOfLOS = true;
				friend.isOutOfLOSTestTime = GetTime();
			end
		end
	end
end

addon.init = function()
	if (addon.initd) then
		return
	end

	-- Set a consistent view
	SetView(3);
	SetView(3);
	
	addon.initLights();
	
	addon.initMacro();

	addon.playerGuid = UnitGUID("player");
	addon.initd = true;
end

addon.processWhisper = function(text, playerName)
	if ((string.match(playerName, "pear") or string.match(playerName, "Pear")) and (not string.match(text, " "))) then
		local bopTarget = string.match(text, "bop:(.+)");
		local followName, tankName = string.match(text, "(.+),(.+)");
		
		if bopTarget then
			-- identify the next thingie
			local bopTargetString = addon.getTargetStringFromName(bopTarget);

			if (bopTargetString) then
				local actionString = (bopTargetString == "player") and "Bubble" or "Protection";
				addon.nextActionBean = addon.getForceActionBean(actionString, bopTargetString);
			end
		elseif followName then
			addon.followBean.targetName = followName;
			addon.tankBean.targetName = tankName;
			print("Loaded: " .. addon.followBean.targetName .. " : " .. addon.tankBean.targetName);
		else
			addon.followBean.targetName = text;
			addon.tankBean.targetName = text;
			print("Loaded: " .. addon.followBean.targetName);
		end
		
		addon.init();
	end
end

-- This should be done last so everything is available to it
addon.eventFrame = CreateFrame("frame", nil, UIParent, nil, 0);
addon.eventFrame:RegisterEvent("ADDON_LOADED");
addon.eventFrame:RegisterEvent("CHAT_MSG_WHISPER");
addon.eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED");
addon.eventFrame:RegisterEvent("UI_ERROR_MESSAGE");
addon.eventFrame:SetScript("OnEvent", 
	function(self, event, ...)
		PlayerFrame:SetFrameStrata("BACKGROUND");
		if (event == "ADDON_LOADED") then
		elseif event == "UI_ERROR_MESSAGE" then
			local  _, message = ...;
	
			addon.onSpellCastFailed(message)
		elseif event == "CHAT_MSG_WHISPER" then
			local text, playerName = ...;

			addon.processWhisper(text, playerName);
		end
	end
);
addon.eventFrame:SetScript("OnUpdate", addon.onUpdateHandler);
-- # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
