-- EM(HAN001) 诏书入口：同势力角色（含本人）出牌阶段限一次交手牌到诏书。
local P = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_han"

local skill = fk.CreateSkill {
  name = P.BANNER,
  derived_piles = P.PILE,
}
skill.qiaoImplemented = true

skill:addEffect("active", {
  prompt = "#qiao__han001_zhaoshu-entry",
  target_num = 0,
  include_equip = false,
  max_phase_use_time = 1,
  min_card_num = 1,
  max_card_num = function(self, player)
    return P.maxPlacementCards(player)
  end,
  card_filter = function(self, player, to_select, selected)
    return #selected < P.maxPlacementCards(player)
      and table.contains(player:getCardIds(Player.Hand), to_select)
  end,
  can_use = function(self, player)
    return P.availableHolder(Fk:currentRoom(), player) ~= nil and player.phase == Player.Play
      and #player:getCardIds(Player.Hand) > 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local holder = P.availableHolder(room, player)
    local cards = effect.cards or {}
    if not holder or not P.validPlacement(player, cards) then return end
    holder:addToPile(P.PILE, cards, true, skill.name)
  end,
})

-- GetQmlMark reads the actual pile by name, including during reconnect.
Fk:addQmlMark {
  name = P.PILE_MARK,
  how_to_show = function(_, cards)
    if type(cards) ~= "table" then return "" end
    local visible = table.filter(cards, function(id) return Self:cardVisible(id) end)
    return P.pileLabelValue(#cards, visible)
  end,
  qml = function(_, cards, holder)
    if type(cards) ~= "table" or holder == nil then return nil end
    return {
      url = "packages/qiao/pkg/qiao_mode/qml/EdictPile.qml",
      prop = {
        ids = table.filter(cards, function(id) return Self:cardVisible(id) end),
        holderId = holder.id,
      },
    }
  end,
}

Fk:loadTranslationTable {
  [P.BANNER] = "诏书",
  [P.PILE] = "诏书",
  ["qiao_em_han001_zhaoshu"] = "诏书", -- 旧录像的默认牌堆查看器
  [":" .. P.BANNER] = "与你势力相同的角色出牌阶段限一次，其可以将一张（若为小势力则改为至多两张）手牌置于此牌上。",
  [":" .. P.PILE_MARK] = "与你势力相同的角色出牌阶段限一次，其可以将一张（若为小势力则改为至多两张）手牌置于此牌上。"
    .. "出牌阶段限一次，若此牌上的牌包含四种花色，你可以移去此牌上的所有牌，然后随机获得一张势力锦囊。",
  ["qiao__edict_place_one"] = "放置一张诏书牌",
  ["qiao__edict_place_two"] = "放置至多两张诏书牌",
  ["#qiao__han001_zhaoshu-entry"] = "诏书：将手牌置于诏书上",
}

return skill
