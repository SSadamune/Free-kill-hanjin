-- WEI011 曹仁 · 伪溃
--
-- 规则基线：rules/standard-generals.md WEI011。出牌阶段限一次：失去 1 点体力并
-- 观看一名其他角色的手牌；其中有【闪】则视为对其使用一张【杀】，且本回合你
-- 计算与其距离视为 1；否则弃置其中一张牌。
-- 观看只对发动者可见；【杀】由效果指定目标，使用公共显式目标策略，不机械叠加
-- 普通【杀】的距离限制。距离固定只作用在“发动者 → 该目标”方向且本回合有效。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wei011_1",
}

local C = require "packages.hanjin.pkg.hanjin_mode.rules.card_use_targets"
local H = require "packages.hanjin.pkg.hanjin_mode.rules.wei_history"

local function eligible(player)
  return table.find(player.room.alive_players, function(p)
    return p ~= player and p:isAlive() and not p:isRemoved()
  end) ~= nil
end

skill:addEffect("active", {
  prompt = "#hanjin__skill_wei011_1-prompt",
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
    if player.dead then return end

    local hand = target:getCardIds(Player.Hand)
    -- 真实私看：viewCards 只把牌发给发动者，不是 showCards 的全体展示。
    if #hand > 0 then
      room:viewCards(player, {
        cards = hand,
        skill_name = skill.name,
        prompt = "#hanjin__skill_wei011_1-view",
      })
    end
    local hasJink = false
    for _, id in ipairs(hand) do
      local card = Fk:getCardById(id)
      if card ~= nil and card.trueName == "jink" then
        hasJink = true
        break
      end
    end

    if hasJink then
      room:setPlayerMark(player, H.WEIKUI_DISTANCE_MARK, target.id)
      -- 效果指定目标：使用显式目标策略，目标合法性不依赖【杀】的普通距离。
      C.useVirtualCard(room, player, "hanjin__slash", nil, { target }, skill.name, true, nil,
        C.explicit({ other_roles = true }, { names = { "hanjin__slash" } }))
    elseif #hand > 0 then
      local chosen = room:askToChooseCard(player, {
        target = target,
        flag = "h",
        skill_name = skill.name,
        prompt = "#hanjin__skill_wei011_1-discard",
        cancelable = false,
      })
      local id = chosen
      if type(chosen) == "table" then id = chosen.id or chosen[1] end
      if id ~= nil then
        room:throwCard({ id }, skill.name, target, player)
      end
    end
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_wei011_1"] = "伪溃",
  [":hanjin__skill_wei011_1"] = "出牌阶段限一次，你可以失去1点体力并观看一名其他角色的手牌。若其中有【闪】，则你视为对其使用一张【杀】，且本回合你计算与其距离视为1；否则你弃置其中一张牌。",
  ["#hanjin__skill_wei011_1-prompt"] = "伪溃：失去1点体力并观看一名其他角色的手牌",
  ["#hanjin__skill_wei011_1-view"] = "伪溃：观看 %src 的手牌",
  ["#hanjin__skill_wei011_1-discard"] = "伪溃：弃置其一张手牌",
}

skill.hanjinImplemented = true
return skill
