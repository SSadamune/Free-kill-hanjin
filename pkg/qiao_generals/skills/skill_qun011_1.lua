-- 改编锁定hegemony/formation/qianhuan：不限花色、上限为体力上限。
local qianhuan = fk.CreateSkill{
  name = "qiao__skill_qun011_1",
}
local H = require "packages.hegemony.util"
local Markers = require "packages.qiao.pkg.qiao_mode.rules.marker_cards"
local pile = "qiao_yuji_sorcery"
Markers.register(qianhuan.name, pile)

local function sources(event, effect, player, placing)
  return Markers.available(event, effect, player, qianhuan.name, function(source)
    local n = #Markers.cards(player, source, pile)
    if placing then return n < player.maxHp end
    return n > 0
  end)
end

local function limit(self, event, target, player)
  return Markers.limit(event, self, player, qianhuan.name)
end

qianhuan:addEffect(fk.Damaged, {
  anim_type = "masochism",
  trigger_times = limit,
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(qianhuan.name) and not target.dead and H.compareKingdomWith(target, player)
      and not player:isNude() and #sources(event, self, player, true) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local source = Markers.choose(room, sources(event, self, player, true), qianhuan.name, player)
    if not source then return false end
    local card = room:askToCards(player, {
      min_num = 1,
      max_num = 1,
      include_equip = true,
      skill_name = qianhuan.name,
      pattern = ".",
      prompt = "#qiao__qun011-dmg",
      cancelable = true,
    })
    if #card > 0 and table.contains(player:getCardIds("he"), card[1]) then
      event:setCostData(self, {cards = card, source = source})
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local cost = event:getCostData(self)
    Markers.used(event, self, cost.source)
    Markers.put(player, cost.source, qianhuan.name, cost.cards, true)
  end,
})
qianhuan:addEffect(fk.TargetConfirming, {
  anim_type = "defensive",
  trigger_times = limit,
  can_trigger = function (self, event, target, player, data)
    return player:hasSkill(qianhuan.name) and H.compareKingdomWith(target, player) and #sources(event, self, player, false) > 0 and
      data.card.type ~= Card.TypeEquip and data:isOnlyTarget(target)
  end,
  on_cost = function (self, event, target, player, data)
    local room = player.room
    local source = Markers.choose(room, sources(event, self, player, false), qianhuan.name, player)
    if not source then return false end
    local ids = Markers.cards(player, source, pile)
    local card = room:askToCards(player, {
      min_num = 1,
      max_num = 1,
      include_equip = false,
      skill_name = qianhuan.name,
      pattern = tostring(Exppattern { id = ids }),
      prompt = "#qiao__qun011-def::" .. target.id .. ":" .. data.card:toLogString(),
      cancelable = true,
      expand_pile = ids,
    })
    if table.contains(ids, card[1]) then
      event:setCostData(self, {cards = card, source = source})
      return true
    end
  end,
  on_use = function (self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self)
    Markers.used(event, self, cost.source)
    if not table.contains(Markers.cards(player, cost.source, pile), cost.cards[1]) then return end
    room:moveCardTo(cost.cards, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile, qianhuan.name, nil, true, player)
    data:cancelTarget(target)
  end
})

qianhuan.qiaoImplemented = true
Fk:loadTranslationTable {
  ["qiao__skill_qun011_1"] = "千幻",
  [":qiao__skill_qun011_1"] = "与你势力相同的角色受到伤害后，你可以将一张牌置于武将牌上（数量至多为体力上限）；与你势力相同的角色成为非装备牌的唯一目标时，你可以移去一张“千幻”牌，取消之。",
  ["qiao_yuji_sorcery"] = "千幻",
  ["#qiao__qun011-dmg"] = "千幻：你可以将一张牌置于武将牌上",
  ["#qiao__qun011-def"] = "千幻：移去一张千幻牌，取消 %dest 这个目标",
}
return qianhuan
