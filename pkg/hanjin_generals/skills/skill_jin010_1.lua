-- JIN010 张春华 · 伤逝
--
-- 任一角色结束阶段，张春华选择：1. 若其手牌数大于张春华，将任意张张春华自己
-- 的手牌当一张冰【杀】对其使用；2. 摸牌至张春华已损失的体力值。目标由效果
-- 明确指定，使用显式目标策略，不叠加默认攻击距离。两项均不可执行时不发动。
local C = require "packages.hanjin.pkg.hanjin_mode.rules.card_use_targets"

local skill = fk.CreateSkill {
  name = "hanjin__skill_jin010_1",
}
skill.hanjinImplemented = true

local ICE = "hanjin__ice__slash"

local function lostHp(player)
  return math.max(0, player.maxHp - player.hp)
end

local function canSlashTarget(room, player, target)
  if target == nil or target.dead or target:isRemoved() then return false end
  local card = Fk:cloneCard(ICE)
  if player:prohibitUse(card) then return false end
  return not player:isProhibited(target, card)
end

local function canSlash(player, target)
  return #target:getCardIds("h") > #player:getCardIds("h")
    and canSlashTarget(player.room, player, target)
end

local function canDraw(player)
  return lostHp(player) > #player:getCardIds("h")
end

skill:addEffect(fk.EventPhaseStart, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return target ~= nil and not target.dead and not player.dead
      and target.phase == Player.Finish
      and player:hasSkill(skill.name)
      and (canSlash(player, target) or canDraw(player))
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_jin010_1-invoke:" .. target.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    if target == nil or target.dead or player.dead then return end
    local slashOk = canSlash(player, target)
    local drawOk = canDraw(player)
    if not slashOk and not drawOk then return end

    local choices = {}
    if slashOk then table.insert(choices, "#hanjin__skill_jin010_1-slash") end
    if drawOk then table.insert(choices, "#hanjin__skill_jin010_1-draw") end
    local choice
    if #choices == 1 then
      choice = choices[1]
    else
      choice = room:askToChoice(player, {
        choices = choices,
        skill_name = skill.name,
        prompt = "#hanjin__skill_jin010_1-choice",
      })
    end
    if choice == "#hanjin__skill_jin010_1-draw" then
      local need = lostHp(player) - #player:getCardIds("h")
      if need > 0 then player:drawCards(need, skill.name) end
      return
    end
    if choice ~= "#hanjin__skill_jin010_1-slash" or not canSlash(player, target) then
      return
    end

    local hand = player:getCardIds("h")
    local cards = room:askToChooseCards(player, {
      target = player,
      flag = "h",
      min = 0,
      max = #hand,
      skill_name = skill.name,
      prompt = "#hanjin__skill_jin010_1-cards:" .. target.id,
      cancelable = false,
    })
    if cards == nil then return end
    for _, id in ipairs(cards) do
      if not table.contains(player:getCardIds("h"), id) then return end
    end
    C.useVirtualCard(room, player, ICE, cards, { target }, skill.name, true,
      { bypass_times = true }, C.explicit({}, { names = { ICE }, min_targets = 1, max_targets = 1 }))
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_jin010_1"] = "伤逝",
  ["#hanjin__skill_jin010_1-invoke"] = "伤逝：你可以对 %dest 发动伤逝",
  ["#hanjin__skill_jin010_1-choice"] = "伤逝：选择一项",
  ["#hanjin__skill_jin010_1-slash"] = "将任意张手牌当冰【杀】对其使用",
  ["#hanjin__skill_jin010_1-draw"] = "摸牌至已损失的体力值",
  ["#hanjin__skill_jin010_1-cards"] = "伤逝：选择合成冰【杀】的手牌",
}

return skill
