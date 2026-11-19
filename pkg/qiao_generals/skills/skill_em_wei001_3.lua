-- EM(WEI001) 曹操 · 总御
-- 受到伤害后，可将【六龙骖驾】从场上或弃牌堆置入装备区；按空栏与双坐骑
-- 合法性判断，不替换已有坐骑，也不在使用坐骑牌时触发。
local W = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wei"

local skill = fk.CreateSkill { name = W.ZONGYU }
skill.qiaoImplemented = true

local ZHULONG = "qiao__liulongcanjia"

local function isZhulong(id)
  local card = Fk:getCardById(id, true)
  return card ~= nil and card.name == ZHULONG
end

local function candidates(room)
  local list = {}
  for _, id in ipairs(room.discard_pile) do
    if isZhulong(id) then table.insert(list, id) end
  end
  for _, p in ipairs(room:getPresentPlayers()) do
    for _, id in ipairs(p:getCardIds(Player.Equip)) do
      if isZhulong(id) then table.insert(list, id) end
    end
  end
  return list
end

--- 六龙骖驾双副类别占两个栏：非使用置入不能顶掉任一已有坐骑，
--- 必须两个对应栏都空且未封印。
local function hasRideSlots(player)
  return player:hasEmptyEquipSlot(Card.SubtypeOffensiveRide)
    and player:hasEmptyEquipSlot(Card.SubtypeDefensiveRide)
end

skill:addEffect(fk.Damaged, {
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and player:hasSkill(skill.name)
      and #candidates(player.room) > 0 and hasRideSlots(player)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__em_wei001_zongyu-ask",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local list = candidates(room)
    if #list == 0 or not hasRideSlots(player) then return end
    local chosen = list[1]
    if #list > 1 then
      chosen = room:askToChooseCard(player, {
        flag = { card_data = { { "e", list } } },
        skill_name = skill.name,
        prompt = "#qiao__em_wei001_zongyu-card",
      }) or list[1]
    end
    local area = room:getCardArea(chosen)
    if area ~= Card.DiscardPile and area ~= Card.PlayerEquip then return end
    room:moveCardIntoEquip(player, chosen, skill.name, false, player)
  end,
})

Fk:loadTranslationTable {
  [W.ZONGYU] = "总御",
  [":" .. W.ZONGYU] = "当你受到伤害后，你可以将【六龙骖驾】从场上或弃牌堆置入装备区。",
  ["#qiao__em_wei001_zongyu-ask"] = "总御：是否将【六龙骖驾】置入装备区",
  ["#qiao__em_wei001_zongyu-card"] = "总御：选择一张场上的【六龙骖驾】",
}

return skill
