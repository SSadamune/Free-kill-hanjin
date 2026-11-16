-- WU005 周瑜 · 反间
--
-- 规则基线：rules/standard-generals.md 吴区 WU005、
-- rules/generals/wu005-zhouyu.md。
-- 主将技。出牌阶段限一次：展示一张手牌并交给一名其他角色；该角色可以
-- 展示手牌并弃置其手牌区和装备区中与展示牌花色相同的所有牌（至少两张），
-- 否则失去 1 点体力。展示手牌不等于展示装备区，弃牌范围则包含装备区。
-- 主将条件由 Skill.MainPlace 标签交给引擎的国战主副将接线处理。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wu005_2",
  tags = { Skill.MainPlace },
}
skill.hanjinImplemented = true

local ACCEPT = "#hanjin__skill_wu005_2-accept"
local LOSE = "#hanjin__skill_wu005_2-lose"

skill:addEffect("active", {
  anim_type = "offensive",
  prompt = "#hanjin__skill_wu005_2-prompt",
  max_phase_use_time = 1,
  target_num = 1,
  min_card_num = 1,
  max_card_num = 1,
  card_filter = function(self, player, to_select, selected)
    return table.contains(player:getCardIds(Player.Hand), to_select)
  end,
  target_filter = function(self, player, to_select, selected)
    return #selected == 0 and to_select ~= player
      and to_select:isAlive() and not to_select:isRemoved()
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos and effect.tos[1]
    local cards = effect.cards or {}
    if player == nil or target == nil or player.dead or target.dead then return end
    local card = cards[1]
    if card == nil or not table.contains(player:getCardIds(Player.Hand), card) then return end

    -- “你展示花色”在交牌前快照；收牌后目标的红颜等转化不得改变它。
    local suit = Fk:getCardById(card).suit

    -- 先公开展示，再交给目标；此后目标的手牌中已包含这张牌。
    room:showCards({ card }, player)
    if not table.contains(player:getCardIds(Player.Hand), card) then return end
    room:obtainCard(target, card, true, fk.ReasonGive, player, skill.name)
    if target.dead then return end

    local sameSuit = table.filter(target:getCardIds("he"), function(id)
      return Fk:getCardById(id).suit == suit
    end)
    -- 响应要求弃置该花色的“所有牌”：不足两张，或其中有禁止弃置的牌，
    -- 都无法完成响应，只能失去体力；不强行移动禁弃牌。
    local canRespond = #sameSuit >= 2
    if canRespond then
      for _, id in ipairs(sameSuit) do
        if target:prohibitDiscard(id) then
          canRespond = false
          break
        end
      end
    end
    if not canRespond then
      room:loseHp(target, 1, skill.name)
      return
    end

    local choice = room:askToChoice(target, {
      choices = { ACCEPT, LOSE },
      skill_name = skill.name,
      prompt = "#hanjin__skill_wu005_2-choice",
    })
    if choice == ACCEPT then
      -- 只展示手牌；随后由目标自己弃置手牌与装备区中该花色的所有牌。
      room:showCards(target:getCardIds(Player.Hand), target)
      room:throwCard(sameSuit, skill.name, target, target)
    else
      room:loseHp(target, 1, skill.name)
    end
  end,
})

Fk:loadTranslationTable {
  ["#hanjin__skill_wu005_2-prompt"] = "反间：展示一张手牌并交给一名其他角色",
  ["#hanjin__skill_wu005_2-choice"] = "反间：展示手牌并弃置同花色的所有牌（至少两张），或失去1点体力",
  [ACCEPT] = "展示手牌并弃置同花色所有牌",
  [LOSE] = "失去1点体力",
}

return skill
