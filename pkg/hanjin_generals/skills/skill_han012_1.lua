-- HAN012 蔡邕 · 铸典
--
-- 规则基线：rules/standard-generals.md 汉区、rulebook/terms/card-op-terms/recast.md、
-- rulebook/terms/card-op-terms/showCards.md。你成为其他角色使用黑色牌的目标后，
-- 可以重铸一张自己的牌；随后若因重铸摸到的牌为黑色，可以展示之并摸一张牌。
--
-- 重铸是「置入弃牌堆，然后摸一张牌」，不是弃置：不能以禁止弃置为由排除
-- 可重铸的牌，也不能额外套用弃牌的消耗校验。
local skill = fk.CreateSkill {
  name = "hanjin__skill_han012_1",
}
skill.hanjinImplemented = true

--- 取一张实体牌在指定角色处的有效黑色结果。重铸摸到的牌按该角色的有效
--- 花色/颜色判断，避免把 card.color 当作永远原始。
---@param room Room
---@param player ServerPlayer
---@param id integer
---@return boolean
local function isBlackAt(room, player, id)
  local card = room:filterCard(id, player) or Fk:getCardById(id, true)
  return card ~= nil and card.color == Card.Black
end

--- 可重铸的自己的牌：手牌区或装备区，不受「禁止弃置」限制。
---@param player ServerPlayer | ClientPlayer
---@return integer[]
local function ownCards(player)
  return player:getCardIds("he")
end

skill:addEffect(fk.TargetConfirmed, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    return target == player
      and player:hasSkill(skill.name)
      and data.card ~= nil
      and data.from ~= nil and data.from ~= player
      and data.card.color == Card.Black
      and #ownCards(player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    -- 选牌本身就是发动消耗：取消选牌即不发动，不先明置再询问一次可取消
    -- 的消耗。
    local chosen = room:askToCards(player, {
      min_num = 1,
      max_num = 1,
      include_equip = true,
      skill_name = skill.name,
      prompt = "#hanjin__skill_han012_1-recast",
      cancelable = true,
    })
    local id = chosen and chosen[1]
    if id == nil or not table.contains(ownCards(player), id) then return false end
    event:setCostData(self, { cards = { id } })
    return true
  end,
  on_use = function(self, event, target, player)
    local room = player.room
    local cost = event:getCostData(self) or {}
    local id = (cost.cards or {})[1]
    if id == nil or not table.contains(ownCards(player), id) or player.dead then return end

    local drawn = room:recastCard(id, player, skill.name)
    if player.dead or #drawn == 0 then return end
    local drawnId = drawn[1]
    if not isBlackAt(room, player, drawnId) then return end

    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_han012_1-black",
    }) then
      return
    end
    -- 展示前复核该牌仍由自己持有且仍在可展示区域；中途转手则不展示。
    if player.dead or not table.contains(ownCards(player), drawnId) then return end
    room:showCards({ drawnId }, player)
    if player.dead then return end
    player:drawCards(1, skill.name)
  end,
})


Fk:loadTranslationTable {
  ["hanjin__skill_han012_1"] = "铸典",
  [":hanjin__skill_han012_1"] = "当你成为其他角色使用黑色牌的目标后，你可以重铸一张牌，然后若你摸到的牌为黑色，你可以展示之并摸一张牌。",
  ["#hanjin__skill_han012_1-invoke"] = "铸典：你可以重铸一张牌",
  ["#hanjin__skill_han012_1-recast"] = "铸典：请选择一张要重铸的牌",
  ["#hanjin__skill_han012_1-black"] = "铸典：你摸到了黑色牌，可以展示之并摸一张牌",
}

return skill
