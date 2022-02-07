local _, addon = ...;

local MOUNT_NAMES = {
  "Gryphon", "Steed", "Charger", "Swift", "Battle Tank", "Felsteed", "Mare"
};
local FORCE_FOLLOW_SCORE = 9999;
local DEFAULT_MOUNT_SCORE = 35;
local DEFAULT_PRIO_FOLLOW_SCORE = 45;
local DEFAULT_FOLLOW_SCORE = 15;
local DEFAULT_INTERACT_SCORE = 15;

local DEFAULT_MOVING_THRESHOLD = 8; -- within 8 seconds, we can start jumpin'.
local SPEED_THRESHOLD = 7;

addon.getShouldMount = function()
  local isMounted = addon.getTargetHasBuff(addon.followBean.target, MOUNT_NAMES);
  local isPlayerMounted = addon.getTargetHasBuff("player", MOUNT_NAMES);

  if (isMounted ~= isPlayerMounted) then
    if (addon.playerBean["isInCombat"] and isMounted) then
      return false
    else
      return true;
    end
  end

  return false;
end

addon.getShouldInteract = function()
	local targetString = addon.followBean.target .. "-target";
	local withinJudgementRange = IsSpellInRange("Judgement", targetString);

	return withinJudgementRange;
end

addon.updateFollow = function() 
  if (addon.playerBean["isMoving"]) then
    addon.followBean.playerLastMoving = GetTime();
  end

	-- logic. never let the target player go outside of follow range
	if not (addon.followBean.targetName and addon.followBean.target) then
		return
	end

	if (UnitIsDeadOrGhost(addon.followBean.target)) then
		return;
	end

  addon.followBean.followAction = "Nothing";
  addon.followBean.followScore = 0;
  addon.followBean.followTarget = -1;

	if LightStatus.followBlock then
		return
	end

	local inTen = CheckInteractDistance(addon.followBean.target, 2); -- 10 yard range
	local inTwenty = IsItemInRange(6450, addon.followBean.target);
	local inThirty = CheckInteractDistance(addon.followBean.target, 4); -- 30 yard range
	local inFourty = IsItemInRange(34471, addon.followBean.target);

	if (inFourty and addon.getShouldMount()) then
		addon.followBean.followAction = "Mount";
		addon.followBean.followScore = DEFAULT_MOUNT_SCORE;
		addon.followBean.followTarget = -1;

		if (LightStatus.onlyFollow) then
			addon.followBean.followScore = FORCE_FOLLOW_SCORE;
		end

		return;
	end

	if (not LightStatus.onlyFollow and (inTen and addon.getShouldInteract())) then
		addon.followBean.followAction = "Interact";
		addon.followBean.followScore = DEFAULT_INTERACT_SCORE;

		local targetString = addon.followBean.target .. "-target";
		local targetStringUnit = UnitGUID(targetString);
		local targetUnit = UnitGUID("target");

		if (targetStringUnit == targetUnit) then
			addon.followBean.followTarget = addon.followBean.target;
		else
			addon.followBean.followTarget = -1;
		end

		return;
	end

	if (not inThirty) then
		addon.followBean.followScore = 0;

		-- find a new follow target
		for k, v in pairs(addon.friendBean) do
			if (v ~= nil) then
				if ((not (k == addon.playerGuid)) and v.isInFollowRange) then
					addon.followBean.followTarget = v.targetString;
					addon.followBean.followAction = "Follow";
					addon.followBean.followScore = DEFAULT_PRIO_FOLLOW_SCORE;
					
					if (LightStatus.onlyFollow) then
						addon.followBean.followScore = FORCE_FOLLOW_SCORE;
					end
					
					break;
				end
			end
		end
	else
		addon.followBean.followTarget = addon.followBean.target;
		addon.followBean.followAction = "Follow";
		addon.followBean.followScore = 0;
		
		if ((not addon.playerBean["isInCombat"]) or (GetUnitSpeed(addon.followBean.target) ~= 0)) then
			if (LightStatus.onlyFollow) then
				addon.followBean.followScore = FORCE_FOLLOW_SCORE;
			elseif (inThirty and not inTwenty) then
				addon.followBean.followScore = DEFAULT_PRIO_FOLLOW_SCORE;
			elseif (inTwenty and not inTen) then
				addon.followBean.followScore = DEFAULT_FOLLOW_SCORE;
			end
		end

		if ((addon.followBean.followScore > 0) and
				(addon.playerBean["speed"] > 0)) then

			if (addon.onlyFollow) then
			-- assume player is moving
				addon.followBean.followAction = "Jump";
			end
		end
	end
end
