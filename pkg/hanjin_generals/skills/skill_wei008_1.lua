-- WEI008 夏侯渊 · 神速
--
-- 规则基线：rules/standard-generals.md 魏区 WEI008、
-- rulebook/terms/game-flow-terms/phase.md。原文没有“准备阶段”时机：三项分别
-- 在对应阶段开始前（EventPhaseChanging）询问，而不是准备阶段一次选完：
--   ① 判定阶段开始前：跳过此阶段和摸牌阶段；
--   ② 出牌阶段开始前：跳过此阶段并弃置一张装备牌；
--   ③ 弃牌阶段开始前：跳过此阶段并失去1点体力。
-- 每执行一项视为使用一张无距离限制的【杀】，不计通常出杀次数。
-- 已被跳过的阶段不会触发 EventPhaseChanging；判定项还要求摸牌阶段尚未被
-- 跳过，避免再次消耗。阶段跳过统一走 canSkip/skip。
local C = require "packages.hanjin.pkg.hanjin_mode.rules.card_use_targets"

local skill = fk.CreateSkill {
  name = "hanjin__skill_wei008_1",
}

local SLASH = "hanjin__slash"

local function slashPolicy()
  return C.bypassDistance({ names = { SLASH } })
end

--- 出杀候选：无距离限制，不占通常出杀次数。
---@param room Room
---@param player ServerPlayer
---@return ServerPlayer[]
local function slashTargets(room, player)
  return C.candidates(room, player, Fk:cloneCard(SLASH), slashPolicy(), {
    bypass_times = true,
  })
end

---@param player ServerPlayer
---@return boolean
local function hasEquipmentCard(player)
  for _, id in ipairs(player:getCardIds("he")) do
    if Fk:getCardById(id).type == Card.TypeEquip then return true end
  end
  return false
end

--- 当前阶段是否属于神速的三项之一（准备/摸牌/结束阶段不触发）。
---@param phase Phase
---@return boolean
local function timingPhase(phase)
  return phase == Player.Judge or phase == Player.Play or phase == Player.Discard
end

skill:addEffect(fk.EventPhaseChanging, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    if target ~= player or not player:hasSkill(skill.name) or player.dead then return false end
    if data.skipped or not timingPhase(data.phase) then return false end
    if data.phase == Player.Judge and not player:canSkip(Player.Draw) then return false end
    if data.phase == Player.Play and not hasEquipmentCard(player) then return false end
    if data.phase == Player.Discard and player.hp < 1 then return false end
    return #slashTargets(player.room, player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei008_1-invoke",
    }) then
      return false
    end
    local targets = slashTargets(room, player)
    if #targets == 0 then return false end
    local slack = Fk:cloneCard(SLASH)
    local maxNum = slack.skill:getMaxTargetNum(player, slack)
    if maxNum < 1 then return false end

    if data.phase == Player.Judge then
      local tos = room:askToChoosePlayers(player, {
        targets = targets,
        min_num = 1,
        max_num = math.min(maxNum, #targets),
        prompt = "#hanjin__skill_wei008_1-judge",
        skill_name = skill.name,
        cancelable = true,
      })
      if #tos == 0 then return false end
      event:setCostData(self, { tos = tos })
      return true
    elseif data.phase == Player.Play then
      local tos, cards = room:askToChooseCardsAndPlayers(player, {
        targets = targets,
        min_num = 1,
        max_num = math.min(maxNum, #targets),
        min_card_num = 1,
        max_card_num = 1,
        pattern = ".|.|.|.|.|equip",
        prompt = "#hanjin__skill_wei008_1-play",
        skill_name = skill.name,
        cancelable = true,
        will_throw = true,
      })
      if #tos == 0 or cards == nil or #cards == 0 then return false end
      event:setCostData(self, { tos = tos, cards = cards })
      return true
    elseif data.phase == Player.Discard then
      local tos = room:askToChoosePlayers(player, {
        targets = targets,
        min_num = 1,
        max_num = math.min(maxNum, #targets),
        prompt = "#hanjin__skill_wei008_1-discard",
        skill_name = skill.name,
        cancelable = true,
      })
      if #tos == 0 then return false end
      event:setCostData(self, { tos = tos })
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self) or {}
    local tos = cost.tos or {}
    if #tos == 0 then return end

    data.skipped = true
    if data.phase == Player.Judge then
      player:skip(Player.Draw)
    elseif data.phase == Player.Play then
      if cost.cards ~= nil and #cost.cards > 0 then
        room:throwCard(cost.cards, skill.name, player, player)
      end
    elseif data.phase == Player.Discard then
      room:loseHp(player, 1, skill.name)
    end
    if player.dead then return end
    C.useVirtualCard(room, player, SLASH, nil, tos, skill.name, true,
      { bypass_times = true }, slashPolicy())
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_wei008_1"] = "神速",
  [":hanjin__skill_wei008_1"] = "你可以选择以下任意项：1.跳过判定阶段和摸牌阶段；2.跳过出牌阶段并弃置一张装备牌；3.跳过弃牌阶段并失去1点体力。每执行一项，你视为使用一张无距离限制的【杀】。",
  ["#hanjin__skill_wei008_1-invoke"] = "神速：你可以跳过此阶段，视为使用一张无距离限制的【杀】",
  ["#hanjin__skill_wei008_1-judge"] = "神速：跳过判定阶段和摸牌阶段，视为使用一张无距离限制的【杀】",
  ["#hanjin__skill_wei008_1-play"] = "神速：跳过出牌阶段并弃置一张装备牌，视为使用一张无距离限制的【杀】",
  ["#hanjin__skill_wei008_1-discard"] = "神速：跳过弃牌阶段并失去1点体力，视为使用一张无距离限制的【杀】",
}

skill.hanjinImplemented = true

return skill
