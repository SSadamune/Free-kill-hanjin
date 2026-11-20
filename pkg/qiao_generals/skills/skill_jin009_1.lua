-- JIN009 司马懿 · 权变
--
-- 规则基线：docs/rules/generals/jin009-simayi.md。
-- 出牌阶段内，每种花色第一次真实使用手牌时可发动；响应中的实际使用也算。
-- “首次”由本阶段 UseCard 事件历史判断，不用技能局部计数，因此暗将/尚未亮出
-- 时发生的用牌事实不会被抹去。发动后本阶段禁止使用该花色手牌，但不禁止打出，
-- 也不限制非手牌来源；限制由模式级 jin_deck_rule 读取中性标记，失技后保留。
local D = require "packages.qiao.pkg.qiao_generals.util.jin_deck"

local skill = fk.CreateSkill {
  name = D.QIANBIAN,
}

--- 本阶段该角色同一花色的真实手牌使用次数（包含当前事件）。
---@param player ServerPlayer
---@param suit integer
---@return integer
local function handUseCount(player, suit)
  local logic = player.room.logic
  return #logic:getEventsOfScope(GameEvent.UseCard, 2, function(e)
    local data = e.data
    return data ~= nil and data.from == player and data.card ~= nil
      and data.card.suit == suit and data:isUsingHandcard(player)
  end, Player.HistoryPhase)
end

skill:addEffect(fk.AfterCardUseDeclared, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    if target ~= player or player.dead or not player:hasSkill(skill.name) then return false end
    if player.phase ~= Player.Play or data == nil or data.card == nil then return false end
    local suit = data.card.suit
    if not D.validSuit(suit) or not data:isUsingHandcard(player) then return false end
    if table.contains(D.bannedSuits(player), suit) then return false end
    -- 当前阶段首次使用此花色手牌；平局/取消不会在之后补触发。
    return handUseCount(player, suit) == 1
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_jin009_1-invoke:" .. tostring(data.card.suit),
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local suit = data.card.suit
    if not D.validSuit(suit) then return end
    D.banSuit(room, player, suit)
    room:askToGuanxing(player, {
      cards = room:getNCards(3),
      skill_name = skill.name,
    })
    if not player.dead then
      player:drawCards(1, skill.name)
    end
  end,
})

skill.qiaoImplemented = true

Fk:loadTranslationTable {
  [D.BAN_DISPLAY] = "权变",
  ["#qiao__skill_jin009_1-invoke"] = "权变：本阶段首次使用此花色手牌，你可以禁止本阶段使用该花色手牌并卜算3、摸一张牌",
}

return skill
