-- EM(HAN001) 诏书入口：同势力角色（含本人）出牌阶段限一次交手牌到诏书。
local P = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_han"
local H = require "packages.hegemony.util"

local skill = fk.CreateSkill {
  name = P.BANNER,
  derived_piles = P.PILE,
}
skill.qiaoImplemented = true

local function maxCards(room, player)
  if room == nil or player == nil then return 1 end
  return H.isSmallKingdomPlayer(player) and 2 or 1
end

skill:addEffect("active", {
  prompt = "#qiao__han001_zhaoshu-entry",
  target_num = 0,
  include_equip = false,
  max_phase_use_time = 1,
  min_card_num = 1,
  max_card_num = function(self, player)
    local room = Fk:currentRoom()
    return room and math.max(1, maxCards(room, player)) or 1
  end,
  card_filter = function(self, player, to_select, selected)
    local room = Fk:currentRoom()
    return room ~= nil and #selected < maxCards(room, player)
      and table.contains(player:getCardIds(Player.Hand), to_select)
  end,
  can_use = function(self, player)
    local room = Fk:currentRoom()
    local holder = P.availableHolder(room)
    return player ~= nil and not player.dead and player.phase == Player.Play
      and holder ~= nil and P.isSameKingdom(holder, player)
      and #player:getCardIds(Player.Hand) > 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local holder = P.availableHolder(room)
    local cards = effect.cards or {}
    if holder == nil or not P.isSameKingdom(holder, player) or #cards == 0 then return end
    if #cards > maxCards(room, player) then return end
    for _, id in ipairs(cards) do
      if not table.contains(player:getCardIds(Player.Hand), id) then return end
    end
    holder:addToPile(P.PILE, cards, true, skill.name)
  end,
})

Fk:loadTranslationTable {
  [P.BANNER] = "诏书",
  [P.PILE] = "诏书",
  [":" .. P.BANNER] = "与你势力相同的角色出牌阶段限一次，其可以将一张（若为小势力则改为至多两张）手牌置于此牌上。",
  ["#qiao__han001_zhaoshu-entry"] = "诏书：将手牌置于诏书上",
}

return skill
