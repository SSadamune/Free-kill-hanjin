-- QUN005 颜良&文丑 · 双雄
--
-- 规则基线：rules/standard-generals.md 群区 QUN005、群包审阅
-- docs/development/implementation/generals/qun-standard.md。
-- 摸牌阶段结束：弃置自己一张牌（手牌或装备），本回合可将一张与其颜色不同的
-- 牌当【决斗】使用。权限由随包加载的独立状态骨架 qun_cards_state 提供，故失去
-- 双雄本体后本回合已建立的权限仍可执行；范围不额外缩小为手牌。
-- 结束阶段的后半段独立检查本回合实际造成过伤害的牌，不以是否发动前半段为
-- 条件；只取得仍在弃牌堆的实体牌，已被其他效果移走的牌不收回。
local STATE = "qiao__qun_cards_state"
local COLOR_MARK = "qiao_shuangxiong_color"

local skill = fk.CreateSkill {
  name = "qiao__skill_qun005_1",
}
skill.qiaoImplemented = true

local function discardColor(room, cards)
  if cards == nil or #cards == 0 then return nil end
  local card = Fk:getCardById(cards[1])
  if card == nil then return nil end
  if card.color == Card.Red then return "red" end
  if card.color == Card.Black then return "black" end
  return nil
end

-- 摸牌阶段结束时弃一张自己的牌，取得本回合异色当【决斗】的权限。
skill:addEffect(fk.EventPhaseEnd, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and data.phase == Player.Draw
      and #player:getCardIds("he") > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_qun005_1-invoke",
    }) then
      return false
    end
    local cards = room:askToDiscard(player, {
      min_num = 1,
      max_num = 1,
      include_equip = true,
      skill_name = skill.name,
      prompt = "#qiao__skill_qun005_1-discard",
      cancelable = false,
    })
    if cards == nil or #cards == 0 then return false end
    event:setCostData(self, { color = discardColor(room, cards) })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    if player.dead then return end
    local color = event:getCostData(self) and event:getCostData(self).color
    if color == nil then return end
    room:setPlayerMark(player, COLOR_MARK, color)
    room:handleAddLoseSkills(player, STATE, STATE, false, true)
  end,
})

-- 本回合所有实际对 player 造成过伤害的牌的实体牌。
local function damageCardIds(player)
  local logic = player.room.logic
  local events = logic:getEventsOfScope(GameEvent.Damage, math.huge, function(event)
    local damage = event.data
    return damage ~= nil and damage.to == player and damage.card ~= nil
      and not damage.prevented and (damage.damage or 0) > 0
  end, Player.HistoryTurn)
  local ids, seen = {}, {}
  for _, event in ipairs(events) do
    for _, id in ipairs(Card:getIdList(event.data.card)) do
      if not seen[id] then
        seen[id] = true
        table.insert(ids, id)
      end
    end
  end
  return ids
end

local function retrievableCards(player)
  local room = player.room
  return table.filter(damageCardIds(player), function(id)
    return Fk:getCardById(id) ~= nil and room:getCardArea(id) == Card.DiscardPile
  end)
end

-- 结束阶段（阶段开始时）：获得本回合对你造成过伤害且仍在弃牌堆的牌。
skill:addEffect(fk.EventPhaseStart, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and data.phase == Player.Finish
      and #retrievableCards(player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_qun005_1-retrieve",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    if player.dead then return end
    local ids = retrievableCards(player)
    if #ids == 0 then return end
    room:obtainCard(player, ids, true, fk.ReasonJustMove, player, skill.name)
  end,
})

Fk:loadTranslationTable {
  ["#qiao__skill_qun005_1-invoke"] = "双雄：你可以弃置一张牌，本回合将一张与其颜色不同的牌当【决斗】使用",
  ["#qiao__skill_qun005_1-discard"] = "双雄：弃置一张自己的手牌或装备牌",
  ["#qiao__skill_qun005_1-retrieve"] = "双雄：获得本回合对你造成过伤害且仍在弃牌堆的牌",
}

return skill
