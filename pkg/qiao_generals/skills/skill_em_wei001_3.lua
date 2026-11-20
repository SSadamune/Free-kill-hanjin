-- EM(WEI001) 曹操 · 总御
-- 受到伤害后，可将【六龙骖驾】从场上或弃牌堆置入装备区，允许替换原坐骑。
local W = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wei"
local Placement = require "packages.qiao.pkg.qiao_mode.rules.mount_placement"

local skill = fk.CreateSkill { name = W.ZONGYU }
skill.qiaoImplemented = true

local ZHULONG = "qiao__liulongcanjia"

local function isZhulong(id)
  local card = Fk:getCardById(id, true)
  return card ~= nil and card.name == ZHULONG
end

local function candidates(room, player)
  local list = {}
  for _, id in ipairs(room.discard_pile) do
    if isZhulong(id) and Placement.canPut(player, id) then table.insert(list, id) end
  end
  for _, p in ipairs(room:getPresentPlayers()) do
    for _, id in ipairs(p:getCardIds(Player.Equip)) do
      if isZhulong(id) and Placement.canPut(player, id) then table.insert(list, id) end
    end
  end
  return list
end

skill:addEffect(fk.Damaged, {
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and player:hasSkill(skill.name)
      and #candidates(player.room, player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__em_wei001_zongyu-ask",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local list = candidates(room, player)
    if #list == 0 then return end
    local chosen = list[1]
    if #list > 1 then
      chosen = room:askToChooseCard(player, {
        target = player,
        flag = { card_data = { { "e", list } } },
        skill_name = skill.name,
        prompt = "#qiao__em_wei001_zongyu-card",
      }) or list[1]
    end
    if not table.contains(list, chosen) or not table.contains(candidates(room, player), chosen) then return end
    Placement.put(room, player, chosen, skill.name)
  end,
})

Fk:loadTranslationTable {
  [W.ZONGYU] = "总御",
  [":" .. W.ZONGYU] = "当你受到伤害后，你可以将【六龙骖驾】从场上或弃牌堆置入装备区。",
  ["#qiao__em_wei001_zongyu-ask"] = "总御：是否将【六龙骖驾】置入装备区",
  ["#qiao__em_wei001_zongyu-card"] = "总御：选择一张场上的【六龙骖驾】",
}

return skill
