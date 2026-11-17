-- EM(HAN001) 诏书消费：持有者出牌阶段限一次，四花色齐时移去所有牌并取得势力锦囊。
-- 有初平时由刘协选择，失去初平后按房间随机；客户端只读公开同步牌名。
local P = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_han"

local skill = fk.CreateSkill { name = P.CONSUME }
skill.qiaoImplemented = true

local function hasFourSuits(lord)
  local suits = {}
  for _, id in ipairs(lord:getPile(P.PILE)) do
    local card = Fk:getCardById(id, true)
    if card ~= nil and card.suit ~= nil and card.suit >= Card.Spade
      and card.suit <= Card.Diamond then
      suits[card.suit] = true
    end
  end
  local n = 0
  for _ in pairs(suits) do n = n + 1 end
  return n >= 4
end

skill:addEffect(fk.AfterCardsMove, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return player.seat == 1
  end,
  on_refresh = function(self, event, target, player, data)
    P.syncTricks(player.room)
  end,
})

skill:addEffect("active", {
  prompt = "#qiao__han001_zhaoshu-consume",
  target_num = 0,
  card_num = 0,
  max_phase_use_time = 1,
  can_use = function(self, player)
    local room = Fk:currentRoom()
    local lord = P.lord(room)
    return player ~= nil and not player.dead and player.phase == Player.Play
      and lord == player and hasFourSuits(player) and #P.trickNames(room) > 0
  end,
  on_use = function(self, room, effect)
    local lord = effect.from
    if P.lord(room) ~= lord or not hasFourSuits(lord) then return end
    local available = P.availableTricks(room)
    if #available == 0 then return end
    local choice
    if not lord:hasSkill(P.JIANPING) then
      choice = available[room:random(1, #available)]
    elseif #available == 1 then
      choice = available[1]
    else
      local names = table.map(available, function(e) return e.name end)
      local name = room:askToChoice(lord, {
        choices = names, skill_name = skill.name,
        prompt = "#qiao__han001_pick_trick", cancelable = true,
      })
      if name == nil then return end
      choice = table.find(available, function(e) return e.name == name end)
    end
    if choice == nil then return end
    local ids = table.simpleClone(lord:getPile(P.PILE))
    room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile,
      skill.name, nil, true, lord)
    P.obtainTrick(room, lord, choice)
    P.syncTricks(room)
  end,
})

Fk:loadTranslationTable {
  [P.CONSUME] = "诏书·取锦囊",
  [":" .. P.CONSUME] = "出牌阶段限一次，若诏书上的牌包含四种花色，你可以移去所有牌，然后获得一张势力锦囊。",
  ["#qiao__han001_zhaoshu-consume"] = "诏书：四花色齐，移去所有牌并获得势力锦囊",
  ["#qiao__han001_pick_trick"] = "诏书：选择一张势力锦囊",
}

return skill
