-- QUN016 田丰 · 死谏
--
-- 规则基线：rules/standard-generals.md 群区 QUN016、rules/generals/qun016-tianfeng.md。
-- 两个独立时机：
--   1. 失去最后的手牌后：必须在本次移动批次里确实有手牌离开，并且移动结束后
--      自己没有手牌。不能因为「已经是空手」就在别的移动批次重复触发。
--   2. 体力值变化为 1 后：比较变化前后，只有从非 1 变为 1 才触发；维持在 1 或
--      变为 0 都不触发，也不要求这次变化是失去体力。
-- 效果：弃置一名其他角色的一张牌，只含手牌和装备（不含判定区），不附带回复。
local skill = fk.CreateSkill {
  name = "hanjin__skill_qun016_1",
}
skill.hanjinImplemented = true

--- 有牌可弃置的其他角色（手牌或装备区）。
local function discardablePlayers(player)
  return table.filter(player.room:getOtherPlayers(player, false), function(p)
    return not p.dead and not p:isRemoved() and #p:getCardIds("he") > 0
  end)
end

local function onCost(self, event, target, player)
  local room = player.room
  if not room:askToSkillInvoke(player, {
    skill_name = skill.name,
    prompt = "#hanjin__skill_qun016_1-invoke",
  }) then
    return false
  end
  local targets = discardablePlayers(player)
  if #targets == 0 then return false end
  local chosen = room:askToChoosePlayers(player, {
    min_num = 1,
    max_num = 1,
    targets = targets,
    skill_name = skill.name,
    prompt = "#hanjin__skill_qun016_1-target",
    cancelable = true,
  })
  local to = chosen and chosen[1]
  if to == nil or to.dead or to:isRemoved() or #to:getCardIds("he") == 0 then return false end
  event:setCostData(self, { to = to })
  return true
end

local function onUse(self, event, target, player)
  local room = player.room
  local to = (event:getCostData(self) or {}).to
  if to == nil or to.dead or to:isRemoved() then return end
  local ids = to:getCardIds("he")
  if #ids == 0 then return end
  local chosen = room:askToChooseCard(player, {
    target = to,
    flag = "he",
    skill_name = skill.name,
    prompt = "#hanjin__skill_qun016_1-card::" .. to.id,
  })
  local chosenIds = Card:getIdList(chosen)
  if #chosenIds ~= 1 or not table.contains(ids, chosenIds[1]) then return end
  room:throwCard(chosenIds, skill.name, to, player)
end

-- 时机 1：失去最后的手牌后。
skill:addEffect(fk.AfterCardsMove, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(skill.name) or player.dead then return false end
    if not player:isKongcheng() then return false end
    local lost = 0
    for _, move in ipairs(data or {}) do
      if move.from == player then
        for _, info in ipairs(move.moveInfo or {}) do
          if info.fromArea == Card.PlayerHand then lost = lost + 1 end
        end
      end
    end
    if lost == 0 then return false end
    return #discardablePlayers(player) > 0
  end,
  on_cost = onCost,
  on_use = onUse,
})

-- 时机 2：体力值变化为 1 后（前值不是 1）。
-- 证据：ltk/server/events/hp.lua 在触发 HpChanged 前先计算
--   data.shield_lost = math.min(-num, data.who.shield)
--   data.num = num + data.shield_lost
-- 因此 data.num 是护甲抵消之后的实际体力变化量；被护甲吸收的部分不在其中
-- （全被吸收时 num = 0，由下面的 data.num == 0 分支排除）。所以
-- 「player.hp - data.num」就是准确的变化前体力值。
skill:addEffect(fk.HpChanged, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    if data == nil or data.who ~= player then return false end
    if not player:hasSkill(skill.name) or player.dead then return false end
    if data.num == 0 or player.hp ~= 1 then return false end
    if player.hp - data.num == 1 then return false end
    return #discardablePlayers(player) > 0
  end,
  on_cost = onCost,
  on_use = onUse,
})

Fk:loadTranslationTable {
  ["hanjin__skill_qun016_1"] = "死谏",
  [":hanjin__skill_qun016_1"] = "当你失去最后的手牌后，或当你的体力值变化为1后，你可以弃置一名其他角色的一张牌。",
  ["#hanjin__skill_qun016_1-invoke"] = "死谏：是否弃置一名其他角色的一张牌？",
  ["#hanjin__skill_qun016_1-target"] = "死谏：选择一名有牌的其他角色",
  ["#hanjin__skill_qun016_1-card"] = "死谏：选择该角色一张手牌或装备牌弃置",
}

return skill
