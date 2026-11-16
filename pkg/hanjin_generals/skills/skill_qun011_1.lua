-- 改编锁定hegemony/formation/qianhuan：不限花色、上限为体力上限。
local qianhuan = fk.CreateSkill{
  name = "hanjin__skill_qun011_1",
  derived_piles = "hanjin_yuji_sorcery",
}
local H = require "packages.hegemony.util"
qianhuan:addEffect(fk.Damaged, {
  anim_type = "masochism",
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(qianhuan.name) and not target.dead and H.compareKingdomWith(target, player)
      and not player:isNude() and #player:getPile("hanjin_yuji_sorcery") < player.maxHp
  end,
  on_cost = function(self, event, target, player, data)
    local card = {}
    local room = player.room
    card = room:askToCards(player, {
      min_num = 1,
      max_num = 1,
      include_equip = true,
      skill_name = qianhuan.name,
      pattern = ".",
      prompt = "#hanjin__qun011-dmg",
      cancelable = true,
      expand_pile = "hanjin_yuji_sorcery",
    })
    if #card > 0 then
      event:setCostData(self, {cards = card})
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    player:addToPile("hanjin_yuji_sorcery", event:getCostData(self).cards, true, qianhuan.name)
  end,
})
qianhuan:addEffect(fk.TargetConfirming, {
  anim_type = "defensive",
  can_trigger = function (self, event, target, player, data)
    return player:hasSkill(qianhuan.name) and H.compareKingdomWith(target, player) and #player:getPile("hanjin_yuji_sorcery") > 0 and
      data.card.type ~= Card.TypeEquip and data:isOnlyTarget(target)
  end,
  on_cost = function (self, event, target, player, data)
    local room = player.room
    local card = room:askToCards(player, {
      min_num = 1,
      max_num = 1,
      include_equip = false,
      skill_name = qianhuan.name,
      pattern = ".|.|.|hanjin_yuji_sorcery",
      prompt = "#hanjin__qun011-def::" .. target.id .. ":" .. data.card:toLogString(),
      cancelable = true,
      expand_pile = "hanjin_yuji_sorcery",
    })
    if #card > 0 then
      event:setCostData(self, {cards = card})
      return true
    end
  end,
  on_use = function (self, event, target, player, data)
    local room = player.room
    room:moveCardTo(event:getCostData(self).cards, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile, qianhuan.name, nil, true, player)
    data:cancelTarget(target)
  end
})

-- 失技和暗置时清理置将牌上的实体牌；不增加上游移入判定区的额外拦截。
local function clearPile(player)
  local ids = player:getPile("hanjin_yuji_sorcery")
  if #ids > 0 then player.room:moveCardTo(ids, Card.DiscardPile, nil,
    fk.ReasonPutIntoDiscardPile, qianhuan.name, nil, true, player) end
end
qianhuan:addLoseEffect(function(self, player) clearPile(player) end)
qianhuan:addEffect(fk.GeneralHidden, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    local general = type(data) == "string" and Fk.generals[data] or nil
    return target == player and general ~= nil
      and table.contains(general:getSkillNameList(), qianhuan.name)
      and #player:getPile("hanjin_yuji_sorcery") > 0
  end,
  on_refresh = function(self, event, target, player) clearPile(player) end,
})
qianhuan.hanjinImplemented = true
Fk:loadTranslationTable {
  ["hanjin__skill_qun011_1"] = "千幻",
  [":hanjin__skill_qun011_1"] = "与你势力相同的角色受到伤害后，你可以将一张牌置于武将牌上（数量至多为体力上限）；与你势力相同的角色成为非装备牌的唯一目标时，你可以移去一张“千幻”牌，取消之。",
  ["hanjin_yuji_sorcery"] = "千幻",
  ["#hanjin__qun011-dmg"] = "千幻：你可以将一张牌置于武将牌上",
  ["#hanjin__qun011-def"] = "千幻：移去一张千幻牌，取消 %dest 这个目标",
}
return qianhuan
