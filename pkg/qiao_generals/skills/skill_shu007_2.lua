-- SHU007 黄月英 · 藏机
--
-- 规则基线：docs/rules/standard-generals.md 蜀区 SHU007。
-- 每回合限一次，当你因弃置而失去装备区的牌时，你可以防止其中一张非坐骑牌的移动。
-- 只处理 moveReason == 弃置、来源为本人装备区、且牌不是进攻/防御坐骑的移动；
-- 取消移动后不补回手牌或其他区域（不是取回）。
local skill = fk.CreateSkill {
  name = "qiao__skill_shu007_2",
}
skill.qiaoImplemented = true

local USED = "qiao__skill_shu007_2-used-turn"

local function isRide(card)
  if card == nil then return false end
  if card.sub_type == Card.SubtypeOffensiveRide or card.sub_type == Card.SubtypeDefensiveRide then
    return true
  end
  for _, subtype in ipairs(card.subtypes or {}) do
    if subtype == Card.SubtypeOffensiveRide or subtype == Card.SubtypeDefensiveRide then
      return true
    end
  end
  return false
end

local function cardOf(move, info)
  local id = info.cardId
  if move.virtualEquip and move.virtualEquip:getEffectiveId() == id then
    return move.virtualEquip
  end
  return Fk:getCardById(id)
end

--- 本次移动中从本人装备区因弃置离开的非坐骑牌。
local function candidates(player, data)
  local result = {}
  for _, move in ipairs(data or {}) do
    if move.from == player and move.moveReason == fk.ReasonDiscard then
      for _, info in ipairs(move.moveInfo or {}) do
        if info.fromArea == Card.PlayerEquip and not isRide(cardOf(move, info)) then
          table.insert(result, { move = move, info = info, id = info.cardId })
        end
      end
    end
  end
  return result
end

skill:addEffect(fk.BeforeCardsMove, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(skill.name) and player:getMark(USED) == 0
      and #candidates(player, data) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local list = candidates(player, data)
    if #list == 0 then return false end
    local chosen = list[1].id
    if #list == 1 then
      if not room:askToSkillInvoke(player, {
        skill_name = skill.name,
        prompt = "#qiao__skill_shu007_2-invoke",
      }) then return false end
    else
      local ids = table.map(list, function(entry) return entry.id end)
      local picked = room:askToCards(player, {
        min_num = 1,
        max_num = 1,
        include_equip = true,
        pattern = tostring(Exppattern { id = ids }),
        skill_name = skill.name,
        prompt = "#qiao__skill_shu007_2-card",
        cancelable = true,
      })
      if picked == nil or picked[1] == nil then return false end
      chosen = picked[1]
    end
    if not table.find(list, function(entry) return entry.id == chosen end) then return false end
    event:setCostData(self, { card = chosen })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local chosen = (event:getCostData(self) or {}).card
    if chosen == nil then return end
    local cancelled = false
    room:cancelMove(data, nil, function(move, info)
      if not cancelled and info.cardId == chosen then
        cancelled = true
        return true
      end
      return false
    end)
    if cancelled then
      room:addPlayerMark(player, USED, 1)
    end
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_shu007_2"] = "藏机",
  [":qiao__skill_shu007_2"] = "每回合限一次，当你因弃置而失去装备区的牌时，你可以防止其中一张非坐骑牌的移动。",
  ["#qiao__skill_shu007_2-invoke"] = "藏机：防止一张非坐骑装备牌的弃置移动",
  ["#qiao__skill_shu007_2-card"] = "藏机：选择一张非坐骑装备牌",
}

return skill
