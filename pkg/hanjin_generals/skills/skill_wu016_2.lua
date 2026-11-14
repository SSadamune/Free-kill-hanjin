-- WU016 丁奉 · 奋迅
--
-- 出牌阶段限一次，你可以弃置一张牌并指定一名其他角色，你与该角色本回合
-- 的距离视为1。
--
-- 距离效果由模式级技能 wu_distance_effects 读取本回合标记提供，不依赖
-- 丁奉是否仍拥有奋迅；失去技能或换将不会提前结束已经确定的距离状态。
-- 标记在回合结束由引擎清理。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wu016_2",
}
skill.hanjinImplemented = true

local H = require "packages.hanjin.pkg.hanjin_mode.rules.wu_history"
local W = require "packages.hanjin.pkg.hanjin_generals.util.wu_phases"

local function others(player)
  return table.filter(W.currentRoom(player).alive_players, function(p)
    return p ~= player and not p:isRemoved()
  end)
end

skill:addEffect("active", {
  anim_type = "control",
  prompt = "#hanjin__skill_wu016_2-prompt",
  max_phase_use_time = 1,
  min_card_num = 1,
  max_card_num = 1,
  target_num = 1,
  include_equip = true,
  card_filter = function(self, player, to_select, selected)
    if #selected >= 1 then return false end
    return not player:prohibitDiscard(to_select)
  end,
  target_filter = function(self, player, to_select, selected)
    return #selected == 0 and to_select ~= player
      and to_select:isAlive() and not to_select:isRemoved()
  end,
  can_use = function(self, player)
    return self:withinTimesLimit(player, Player.HistoryPhase)
      and #player:getCardIds("he") > 0 and #others(player) > 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos and effect.tos[1]
    local cards = effect.cards or {}
    if player == nil or target == nil or player.dead or target.dead or target:isRemoved() then return end
    if #cards ~= 1 or not table.contains(player:getCardIds("he"), cards[1]) then return end
    room:throwCard(cards, skill.name, player, player)
    if player.dead then return end
    room:setPlayerMark(player, H.FENXUN_MARK, target.id)
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_wu016_2"] = "奋迅",
  ["#hanjin__skill_wu016_2-prompt"] = "奋迅：弃置一张牌并选择一名其他角色，本回合与其距离视为1",
}

return skill
