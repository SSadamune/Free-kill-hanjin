-- JIN006 杜预 · 三陈
-- 出牌阶段限一次；本回合所有发动（包括额外发动）不能重复选择同一角色。
-- 目标实际弃足三张且类别各异时，由目标选择摸一张或复原三陈。
local U = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_jin"

local skill = fk.CreateSkill {
  name = U.CHEN_SKILL,
}
skill.qiaoImplemented = true

local function eligibleTargets(player)
  local result = {}
  for _, p in ipairs(player.room.alive_players) do
    if not p.dead and not p:isRemoved() and not U.sanChenTargeted(player, p) then
      table.insert(result, p)
    end
  end
  return result
end

skill:addEffect(fk.TurnStart, {
  global = true,
  can_refresh = function(self, event, target, player)
    return target == player
  end,
  on_refresh = function(self, event, target, player)
    U.resetTurn(player)
  end,
})

skill:addEffect(fk.EventPhaseStart, {
  global = true,
  can_refresh = function(self, event, target, player)
    return target == player and target.phase == Player.Play
  end,
  on_refresh = function(self, event, target, player)
    U.resetPhase(player)
  end,
})

skill:addEffect("active", {
  prompt = "#qiao__skill_jin006_1-prompt",
  target_num = 1,
  can_use = function(self, player)
    return U.sanChenRemaining(player) > 0 and #eligibleTargets(player) > 0
  end,
  target_filter = function(self, player, to_select, selected)
    return to_select ~= nil and not to_select.dead and not to_select:isRemoved()
      and not U.sanChenTargeted(player, to_select)
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos and effect.tos[1]
    if player == nil or target == nil or player.dead or target.dead then return end
    if U.sanChenRemaining(player) <= 0 or U.sanChenTargeted(player, target) then return end

    U.consumeSanChen(player)
    U.markSanChenTarget(player, target)
    target:drawCards(3, skill.name)
    if target.dead then return end

    local total = math.min(3, #target:getCardIds("he"))
    if total <= 0 then return end
    local ids = room:askToDiscard(target, {
      min_num = total,
      max_num = total,
      include_equip = true,
      skill_name = skill.name,
      prompt = "#qiao__skill_jin006_1-discard",
      cancelable = false,
    })
    if #ids ~= 3 then return end

    local categories = {}
    for _, id in ipairs(ids) do
      local card = Fk:getCardById(id)
      if card == nil or categories[card.type] then return end
      categories[card.type] = true
    end

    local choice = room:askToChoice(target, {
      choices = { "draw", "restore" },
      skill_name = skill.name,
      prompt = "#qiao__skill_jin006_1-choice",
      cancelable = false,
    })
    if choice == "draw" then
      if not target.dead then target:drawCards(1, skill.name) end
    elseif choice == "restore" then
      U.restoreSanChen(player)
    end
  end,
})

Fk:loadTranslationTable {
  [U.CHEN_SKILL] = "三陈",
  ["#qiao__skill_jin006_1-prompt"] = "三陈：令一名本回合尚未选择过的角色摸三张牌并弃三张牌",
  ["#qiao__skill_jin006_1-discard"] = "三陈：弃置三张牌",
  ["#qiao__skill_jin006_1-choice"] = "三陈：弃置牌类别各异，选择摸一张牌或复原三陈",
  ["draw"] = "摸一张牌",
  ["restore"] = "复原三陈",
}

return skill
