
local _, addon = ...;

local TANK_HEALTH = 6000;

addon.getLightScore = function(playerMana, healthMissing, maxHealth, danger)
  if (playerMana < 1200) then return 0; end

  local dangerMissingHealthModifier = ((danger > 0.25) and 500) or 0;
  local healthMissingScore = ((dangerMissingHealthModifier + healthMissing) - 3000) * 1.5;
  local healthScore = (maxHealth / TANK_HEALTH) * 100;
  local totalScore = healthMissingScore + healthScore;

  return math.min(totalScore, 42) + totalScore / 100;
end

addon.getLightCancelScore = function(healthMissing)
  return healthMissing - 1200;
end

addon.getflashScore = function(playerMana, healthMissing, maxHealth, danger)
  if (playerMana < 700) then return 0; end

  local dangerMissingHealthModifier = ((danger > 0.1) and 50) or 0;
  local healthMissingScore = ((dangerMissingHealthModifier + healthMissing) - 1000) * 0.5;
  local healthScore = (1 - (maxHealth / TANK_HEALTH)) * 40;
  local totalScore = healthMissingScore + danger + healthScore;

  return math.min(totalScore, 28) + totalScore / 100;
end

addon.getFlashCancelScore = function(healthMissing)
  return healthMissing - 0;
end

-- PRIEST

addon.getGreaterHealScore = function(playerMana, healthMissing, maxHealth, danger)
  if (playerMana < 350) then return 0; end

  local healthMissingScore = (healthMissing - 800) * 1.5;
  local healthScore = (maxHealth / TANK_HEALTH) * 100;
  local totalScore = healthMissingScore + healthScore;

  return math.min(totalScore, 42) + totalScore / 100;
end

addon.getGreaterHealCancelScore = function(healthMissing)
  return healthMissing - 700;
end

addon.getHealScore = function(playerMana, healthMissing, maxHealth, danger)
  if (playerMana < 300) then return 0; end

  local dangerMissingHealthModifier = ((danger > 0.1) and 50) or 0;
  local healthMissingScore = ((dangerMissingHealthModifier + healthMissing) - 700) * 0.5;
  local healthScore = (1 - (maxHealth / TANK_HEALTH)) * 40;
  local totalScore = healthMissingScore + danger + healthScore;

  return math.min(totalScore, 28) + totalScore / 100;
end

addon.getHealCancelScore = function(healthMissing)
  return healthMissing - 500;
end

addon.getFlashHealScore = function(playerMana, healthMissing, maxHealth, danger)
  if (playerMana < 200) then return 0; end

  local healthMissingScore = (healthMissing - 400) * 0.33;
  local healthScore = (1 - (maxHealth / TANK_HEALTH)) * 10;
  local totalScore = healthMissingScore + healthScore;

  return math.min(totalScore, 22) + totalScore / 100;
end

addon.getFlashHealCancelScore = function(healthMissing)
  return healthMissing - 400;
end
