-- WU001 孙权 · 制衡
--
-- 规则基线：rules/standard-generals.md 吴区 WU001。
-- 出牌阶段限一次：弃置至多 X 张牌（X 为体力上限），摸等量的牌；若因此
-- 弃置了所有手牌，多摸一张。牌可来自手牌或装备区；弃置全部手牌指发动前
-- 的手牌均被本次弃置，发动前没有手牌时不视为“弃置了所有手牌”。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wu001_1",
}
skill.hanjinImplemented = true

skill:addEffect("active", {
  anim_type = "drawcard",
  prompt = "#hanjin__skill_wu001_1-prompt",
  max_phase_use_time = 1,
  target_num = 0,
  min_card_num = 1,
  max_card_num = function(self, player)
    return player.maxHp
  end,
  include_equip = true,
  card_filter = function(self, player, to_select, selected)
    if #selected >= player.maxHp then return false end
    return not player:prohibitDiscard(to_select)
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local cards = effect.cards or {}
    if player == nil or player.dead or #cards == 0 then return end

    local hand = player:getCardIds(Player.Hand)
    local discardedAllHand = #hand > 0
    if discardedAllHand then
      for _, id in ipairs(hand) do
        if not table.contains(cards, id) then
          discardedAllHand = false
          break
        end
      end
    end

    room:throwCard(cards, skill.name, player, player)
    if player.dead then return end
    local n = #cards + (discardedAllHand and 1 or 0)
    if n > 0 then player:drawCards(n, skill.name) end
  end,
})

Fk:loadTranslationTable {
  ["#hanjin__skill_wu001_1-prompt"] = "制衡：弃置至多 X 张牌，然后摸等量的牌",
}

return skill
