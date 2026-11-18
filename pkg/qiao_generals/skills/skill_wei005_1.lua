-- WEI005 许褚 · 裸衣
--
-- 摸牌阶段结束时，你可以弃置一张牌，然后本回合你使用【杀】或【决斗】造成的
-- 伤害+1。发动后效果是本回合的独立延时效果：即使许褚随后失去此技能，
-- 本回合的加伤仍然有效。因此效果只读取回合标记，不再检查技能是否仍在；
-- 标记刻意不使用技能名前缀，避免武将交换把它当成来源技能标记迁走。
--
-- 发动确认并入这一次弃牌请求，不再另发 askToSkillInvoke：取消请求即不发动，
-- 请求未返回恰好一张合法牌也不发动。
local skill = fk.CreateSkill {
  name = "qiao__skill_wei005_1",
}
skill.qiaoImplemented = true

local MARK = "qiao_wei005_luoyi-turn"

local function isDamageCard(card)
  if card == nil then return false end
  local names = { card.trueName, card.name }
  return table.contains(names, "slash") or table.contains(names, "duel")
end

skill:addEffect(fk.EventPhaseEnd, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and data.phase == Player.Draw and #player:getCardIds("he") > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    -- 弃牌请求本身即发动确认：取消即不发动，弃牌在 on_use 统一支付。
    local cards = room:askToDiscard(player, {
      min_num = 1,
      max_num = 1,
      include_equip = true,
      skill_name = skill.name,
      prompt = "#qiao__skill_wei005_1-discard",
      cancelable = true,
      skip = true,
    })
    if #cards ~= 1 then return false end
    event:setCostData(self, { cards = cards })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:throwCard(event:getCostData(self).cards, skill.name, player, player)
    room:setPlayerMark(player, MARK, 1)
  end,
})

-- 延时效果：不检查 hasSkill，只检查本回合标记；标记由 -turn 后缀在回合结束时清理。
skill:addEffect(fk.DamageCaused, {
  anim_type = "offensive",
  is_delay_effect = true,
  can_trigger = function(self, event, target, player, data)
    return target == player and player:getMark(MARK) > 0
      and data.by_user and isDamageCard(data.card)
  end,
  on_use = function(self, event, target, player, data)
    data:changeDamage(player:getMark(MARK))
  end,
})

Fk:loadTranslationTable {
  ["#qiao__skill_wei005_1-discard"] =
    "裸衣：弃置一张牌发动，本回合你使用【杀】或【决斗】造成的伤害+1",
}

return skill
