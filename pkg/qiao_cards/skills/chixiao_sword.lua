-- 赤霄剑：使用【杀】指定目标后，按当时双方的大／小势力类别判断；一个大势力、
-- 一个小势力时，该目标须交给装备者一张红色手牌。未交出时只令该目标不能
-- 抵消此次【杀】对自己的结算，其他目标仍分别响应。
local Heg = require "packages.hegemony.util"

local skill = fk.CreateSkill {
  name = "qiao__chixiao_sword_skill",
  tags = { Skill.Compulsory },
  attached_equip = "qiao__chixiao_sword",
}

local function isRedHandCard(id)
  local card = Fk:getCardById(id)
  return card ~= nil and card.color == Card.Red
end

--- 一个大势力、另一个小势力；双方同为一个大／小类别时不成立。
local function opposedCategories(source, target)
  local sourceBig = Heg.isBigKingdomPlayer(source)
  local targetBig = Heg.isBigKingdomPlayer(target)
  if sourceBig == targetBig then return false end
  return (sourceBig and Heg.isSmallKingdomPlayer(target))
    or (targetBig and Heg.isSmallKingdomPlayer(source))
end

local function markUnableToOffset(data, target)
  data.use.unoffsetableList = data.use.unoffsetableList or {}
  table.insertIfNeed(data.use.unoffsetableList, target)
end

skill:addEffect(fk.TargetSpecified, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and data.card ~= nil and data.card.trueName == "slash"
      and data.to ~= nil and data.to ~= player
      and opposedCategories(player, data.to)
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local to = data.to
    local red = table.filter(to:getCardIds(Player.Hand), isRedHandCard)
    local card
    if #red > 0 then
      card = room:askToChooseCard(to, {
        target = to,
        flag = { card_data = { { "$Hand", red } } },
        skill_name = skill.name,
        prompt = "#qiao__chixiao_sword-give",
      })
    end
    if card ~= nil and room:getCardOwner(card) == to
      and room:getCardArea(card) == Card.PlayerHand then
      room:obtainCard(player, card, false, fk.ReasonGive, to, skill.name)
    end
    -- 以真实移动结果为准；目标取消/被阻止给牌时，本次目标才不能抵消。
    if card == nil or room:getCardOwner(card) ~= player
      or room:getCardArea(card) ~= Card.PlayerHand then
      markUnableToOffset(data, to)
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "赤霄剑",
  ["#qiao__chixiao_sword-give"] = "赤霄剑：交给使用【杀】的角色一张红色手牌",
}

return skill
