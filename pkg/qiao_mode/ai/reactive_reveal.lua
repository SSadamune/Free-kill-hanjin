local Cards = require "packages.qiao.pkg.qiao_mode.ai.cards"
local TrickTargets = require "packages.qiao.pkg.qiao_mode.rules.trick_targets"

local M = {}
local QIANXUN = "qiao__skill_wu007_1"
local XIANGLE = "qiao__skill_shu013_1"
local HUOSHOU = "qiao__skill_shu014_1"
local JUXIANG = "qiao__skill_shu015_1"

local function harmfulSlash(_, aim)
  return aim.card.trueName == "slash"
end

local function savageAssault(_, aim)
  return aim.card.trueName == "savage_assault"
end

local reactions = {
  [fk.TargetConfirming] = {
    [QIANXUN] = function(player, aim)
      return aim.qiao_first_trick_target and Cards.isHarmful(aim.card)
        and TrickTargets.hasUnspecifiedLegalTarget(player, aim)
    end,
    qiao__skill_shu048_2 = function(_, aim) -- 舍宴可以直接减去现有目标时才用于此处防守。
      return aim.qiao_first_common_trick_target and Cards.isHarmful(aim.card) and #aim:getAllTargets() > 1
    end,
    qiao__skill_wu006_2 = harmfulSlash, -- 流离复用原选牌、选人和费用策略。
  },
  [fk.TargetConfirmed] = {
    [XIANGLE] = harmfulSlash,
    [HUOSHOU] = savageAssault,
    [JUXIANG] = savageAssault,
  },
}

local revealOnInvoke = { [QIANXUN] = true, [XIANGLE] = true, [HUOSHOU] = true, [JUXIANG] = true }

local function incomingThreat(player, aim)
  return aim and aim.card and aim.from and aim.from ~= player and not aim.cancelled and not aim:isNullified()
    and player:isAlive() and not player:isRemoved() and not player.ai:isFriend(aim.from)
end

-- 与引擎 revealBySkillName 一样先找主将牌，再找副将牌。
local function canReveal(player, name)
  for _, deputy in ipairs({ false, true }) do
    local visible = deputy and player.deputyGeneral or player.general
    if visible == "anjiang" then
      local general = Fk.generals[player:getMark(deputy and "__heg_deputy" or "__heg_general")]
      if general and table.contains(general:getSkillNameList(true), name) then
        return not player:prohibitReveal(deputy)
      end
    end
  end
  return false
end

function M.prepare(room, event, player, aim)
  local candidates = reactions[event]
  if not candidates or not player or player == room.current then return end
  local prepared
  for name, useful in pairs(candidates) do
    if player:isFakeSkill(name) and not player:hasSkill(name) and Fk.skills[name]:isEffectable(player)
      and player.serverplayer:getState() == fk.Player_Robot and incomingThreat(player, aim)
      and canReveal(player, name) and useful(player, aim) then
      player:prelightSkill(name, true)
      prepared = prepared or {}
      table.insert(prepared, Fk.skills[name])
    end
  end
  return prepared
end

function M.restore(player, prepared)
  for _, skill in ipairs(prepared) do
    if table.contains(player.prelighted_skills, skill) then player:prelightSkill(skill, false) end
  end
end

function M.invoke(ai, name, frame)
  if not revealOnInvoke[name] or not frame or not frame.event then return end
  local candidates = reactions[frame.event.class]
  local useful = candidates and candidates[name]
  if useful and frame.target == ai.player then
    return canReveal(ai.player, name) and incomingThreat(ai.player, frame.data) and useful(ai.player, frame.data)
  end
end

return M
