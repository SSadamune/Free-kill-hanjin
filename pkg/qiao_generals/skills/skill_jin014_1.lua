-- JIN014 文鸯 · 膂力
--
-- 规则基线：rules/generals/jin014-wenyang.md。
-- 每回合限一次，造成一次伤害后选择一项，不按伤害点数重复发动：
--   1. 将手牌补至当前体力值（按差额摸牌）；
--   2. 实际弃置全部手牌，然后将体力回复至实际弃置张数；不超过体力上限，
--      当前体力高于该数值时不降低体力。空手或不能全弃时第二项不可执行；
--      手牌数不小于体力值时第一项不产生摸牌，也不展示。
-- 时机使用 fk.Damage（使用者为事件目标），不是 DamageFinished。
local B = require "packages.qiao.pkg.qiao_generals.util.jin_basic"

local skill = fk.CreateSkill {
  name = "qiao__skill_jin014_1",
}

local OPTION_DRAW = "qiao__skill_jin014_1-draw"
local OPTION_RECOVER = "qiao__skill_jin014_1-recover"

--- 补至体力值只有在手牌数小于当前体力值时才实际产生摸牌；否则不展示。
local function canDrawToHp(player)
  return #player:getCardIds(Player.Hand) < player.hp
end

--- 全弃手牌要求手牌非空且每张都能弃置。
local function canDiscardAll(player)
  return B.canDiscardAllHand(player)
end

-- 规则为“造成伤害后”（fk.Damage，此时使用者为事件目标），不是
-- DamageFinished；后者在濒死、死亡等后续流程之后。
skill:addEffect(fk.Damage, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    if data == nil or data.from ~= player or (data.damage or 0) <= 0 then return false end
    if player.dead or not player:hasSkill(skill.name) then return false end
    if player:usedSkillTimes(skill.name, Player.HistoryTurn) > 0 then return false end
    -- 两项都不能实际执行时不发动、不占次数。
    return canDrawToHp(player) or canDiscardAll(player)
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_jin014_1-invoke",
    }) then
      return false
    end
    local choices = {}
    if canDrawToHp(player) then table.insert(choices, OPTION_DRAW) end
    if canDiscardAll(player) then table.insert(choices, OPTION_RECOVER) end
    if #choices == 0 then return false end
    local choice = room:askToChoice(player, {
      choices = choices,
      skill_name = skill.name,
      prompt = "#qiao__skill_jin014_1-choice",
      cancelable = false,
    })
    if choice == nil or choice == "" then return false end
    event:setCostData(self, { choice = choice })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local choice = (event:getCostData(self) or {}).choice
    if choice == OPTION_DRAW then
      B.drawHandToHp(player, skill.name)
    elseif choice == OPTION_RECOVER then
      local count = B.discardAllHand(room, player, skill.name)
      if count < 1 or player.dead then return end
      B.recoverHpTo(player, count, skill.name)
    end
  end,
})

skill.qiaoImplemented = true

Fk:loadTranslationTable {
  [OPTION_DRAW] = "摸牌至体力值",
  [OPTION_RECOVER] = "弃置所有手牌，然后回复体力至X点（X为以此法弃置的牌数）",
  ["#qiao__skill_jin014_1-invoke"] = "膂力：你可以选择一项",
  ["#qiao__skill_jin014_1-choice"] = "膂力：请选择一项",
}

return skill
