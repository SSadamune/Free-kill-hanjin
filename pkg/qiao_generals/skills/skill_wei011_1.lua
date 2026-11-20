-- WEI011 曹仁 · 伪溃
--
-- 规则基线：docs/rules/standard-generals.md WEI011。出牌阶段限一次：失去 1 点体力并
-- 观看一名其他角色的手牌；其中有【闪】则视为对其使用一张【杀】，且本回合你
-- 计算与其距离视为 1；否则弃置其中一张牌。
-- 观看只对发动者可见；【杀】由效果指定目标，使用公共显式目标策略，不机械叠加
-- 普通【杀】的距离限制。距离固定只作用在“发动者 → 该目标”方向且本回合有效。
local skill = fk.CreateSkill {
  name = "qiao__skill_wei011_1",
}

local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"
local H = require "packages.qiao.pkg.qiao_mode.rules.wei_history"
local DISCARD = "#qiao__skill_wei011_1-discard"

local function eligible(player)
  local room = Fk:currentRoom()
  if room == nil then return false end
  return table.find(room:getPresentPlayers(), function(p)
    return p ~= player and p:isAlive() and not p:isRemoved()
  end) ~= nil
end

skill:addEffect("active", {
  prompt = "#qiao__skill_wei011_1-prompt",
  target_num = 1,
  max_phase_use_time = 1,
  target_filter = function(self, player, to_select, selected)
    return #selected == 0 and to_select ~= player
      and to_select:isAlive() and not to_select:isRemoved()
  end,
  can_use = function(self, player)
    -- 失去 1 点体力是发动消耗：体力不足 1 时不能支付。
    return player.hp >= 1 and self:withinTimesLimit(player, Player.HistoryPhase) and eligible(player)
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos and effect.tos[1]
    if player == nil or target == nil or player.dead or target.dead or target:isRemoved() then return end

    room:loseHp(player, 1, skill.name)
    if player.dead or target.dead or target:isRemoved() then return end

    local hand = target:getCardIds(Player.Hand)
    if #hand == 0 then return end
    local hasJink = table.find(hand, function(id)
      return Fk:getCardById(id).trueName == "jink"
    end) ~= nil
    local candidates = not hasJink and table.filter(hand, function(id)
      return not target:prohibitDiscard(id)
    end) or {}

    local id
    if #candidates > 1 then
      local chosen, choice = room:askToChooseCardsAndChoice(player, {
        cards = candidates,
        all_cards = hand,
        choices = { DISCARD },
        min_num = 1, max_num = 1,
        skill_name = skill.name,
        prompt = "#qiao__skill_wei011_1-panel:" .. target.id,
      })
      if choice == DISCARD and chosen and #chosen == 1 and table.contains(candidates, chosen[1]) then
        id = chosen[1]
      end
    else
      -- 有【闪】、无合法弃牌或只有唯一必弃牌时，只需观看。
      room:viewCards(player, {
        cards = hand,
        skill_name = skill.name,
        prompt = "#qiao__skill_wei011_1-view:" .. target.id,
      })
      id = candidates[1]
    end

    if player.dead or target.dead or target:isRemoved() then return end
    if hasJink then
      room:setPlayerMark(player, H.WEIKUI_DISTANCE_MARK, target.id)
      C.useVirtualCard(room, player, "qiao__slash", nil, { target }, skill.name, true, nil,
        C.explicit({ other_roles = true }, { names = { "qiao__slash" } }))
    elseif id and table.contains(target:getCardIds(Player.Hand), id) and not target:prohibitDiscard(id) then
      room:throwCard({ id }, skill.name, target, player)
    end
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_wei011_1"] = "伪溃",
  [":qiao__skill_wei011_1"] = "出牌阶段限一次，你可以失去1点体力并观看一名其他角色的手牌。若其中有【闪】，则你视为对其使用一张【杀】，且本回合你计算与其距离视为1；否则你弃置其中一张牌。",
  ["#qiao__skill_wei011_1-prompt"] = "伪溃：失去1点体力并观看一名其他角色的手牌",
  ["#qiao__skill_wei011_1-view"] = "伪溃：观看 %src 的手牌",
  ["#qiao__skill_wei011_1-panel"] = "伪溃：观看 %src 的手牌，并弃置其中一张",
  [DISCARD] = "弃置",
}

skill.qiaoImplemented = true
return skill
