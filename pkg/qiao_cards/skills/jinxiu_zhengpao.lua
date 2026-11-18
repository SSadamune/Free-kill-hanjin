-- 锦绣征袍：成为其他角色使用伤害牌的目标后，来牌本次须有标准花色、装备者
-- 有手牌且没有该花色，并能取得本次来牌对应的实体材料。展示手牌后取得材料，
-- 再以取得后的手牌检查四种花色；齐备时仅令该牌对装备者无效。
local J = require "packages.qiao.pkg.qiao_generals.util.jin_adaptation"

local skill = fk.CreateSkill {
  name = "qiao__jinxiu_zhengpao_skill",
  attached_equip = "qiao__jinxiu_zhengpao",
}

local STANDARD_SUITS = {
  [Card.Spade] = true,
  [Card.Heart] = true,
  [Card.Club] = true,
  [Card.Diamond] = true,
}

local function isStandardSuit(card)
  return card ~= nil and STANDARD_SUITS[card.suit] == true
end

local function handSuits(player)
  local suits = {}
  for _, id in ipairs(player:getCardIds(Player.Hand)) do
    local card = Fk:getCardById(id)
    if card ~= nil and STANDARD_SUITS[card.suit] then suits[card.suit] = true end
  end
  return suits
end

--- 本次来牌仍可获得、具有实体牌的对应材料。
local function availableMaterials(room, card)
  local ids = {}
  for _, id in ipairs(room:getSubcardsByRule(card)) do
    local area = room:getCardArea(id)
    if area == Card.Processing or area == Card.PlayerHand or area == Card.PlayerEquip then
      table.insert(ids, id)
    end
  end
  return ids
end

local function missingSuit(player, suit)
  return #player:getCardIds(Player.Hand) > 0 and handSuits(player)[suit] ~= true
end

skill:addEffect(fk.TargetConfirmed, {
  can_trigger = function(self, event, target, player, data)
    if target ~= player or player.dead or not player:hasSkill(skill.name) then return false end
    if data.from == player or data.card == nil then return false end
    if not J.isDamageCard(data.card) or not isStandardSuit(data.card) then return false end
    if not missingSuit(player, data.card.suit) then return false end
    return #availableMaterials(player.room, data.card) > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__jinxiu_zhengpao-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    player:showCards(player:getCardIds(Player.Hand))
    local materials = availableMaterials(room, data.card)
    if #materials == 0 then return end
    room:obtainCard(player, materials, false, fk.ReasonPrey)
    local suits = handSuits(player)
    for _, suit in ipairs({ Card.Spade, Card.Heart, Card.Club, Card.Diamond }) do
      if not suits[suit] then return end
    end
    data.use.nullifiedTargets = data.use.nullifiedTargets or {}
    table.insertIfNeed(data.use.nullifiedTargets, player)
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "锦绣征袍",
  ["#qiao__jinxiu_zhengpao-invoke"] = "锦绣征袍：是否展示手牌并获得本次来牌的实体牌",
}

return skill
