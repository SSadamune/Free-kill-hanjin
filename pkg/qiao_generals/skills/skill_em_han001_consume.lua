-- EM(HAN001) 诏书消费：持有者出牌阶段限一次，四花色齐时移去所有牌并取得势力锦囊。
-- 有初平时由刘协选择，失去初平后按房间随机；客户端只读公开同步牌名。
local P = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_han"

local skill = fk.CreateSkill { name = P.CONSUME }
skill.qiaoImplemented = true

local function hasFourSuits(holder)
  return #P.pileSuits(holder:getPile(P.PILE)) == 4
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
    local holder = P.availableHolder(room, player)
    return holder ~= nil and player.phase == Player.Play
      and holder == player and hasFourSuits(player) and #P.trickNames(room) > 0
  end,
  on_use = function(self, room, effect)
    local holder = effect.from
    if P.availableHolder(room, holder) ~= holder or not hasFourSuits(holder) then return end
    local available = P.availableTricks(room)
    if #available == 0 then return end
    local choice
    if not holder:hasSkill(P.JIANPING) then
      choice = available[room:random(1, #available)]
    elseif #available == 1 then
      choice = available[1]
    else
      local names = table.map(available, function(e) return e.name end)
      -- detailed：确认前按牌名显示当前正式牌面（':'..name）；选项仍是实体牌名。
      local name = room:askToChoice(holder, {
        choices = names, skill_name = skill.name,
        prompt = "#qiao__han001_pick_trick", cancelable = true,
        detailed = true,
      })
      if name == nil then return end
      choice = table.find(available, function(e) return e.name == name end)
    end
    if choice == nil then return end
    local ids = table.simpleClone(holder:getPile(P.PILE))
    room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile,
      skill.name, nil, true, holder)
    P.obtainTrick(room, holder, choice)
    P.syncTricks(room)
  end,
})

-- The mark popup invokes the ordinary active skill. Hide its separate
-- dashboard button both on acquisition and when the dashboard is rebuilt.
Fk:addPostLoadFunc(function()
  Fk.skills[P.CONSUME].visible = false
end)

Fk:loadTranslationTable {
  [P.CONSUME] = "诏书·获得势力锦囊",
  ["qiao__edict_take_trick"] = "获得势力锦囊",
  [":" .. P.CONSUME] = "出牌阶段限一次，若诏书上的牌包含四种花色，你可以移去所有牌，然后获得一张势力锦囊。",
  ["#qiao__han001_zhaoshu-consume"] = "诏书：四花色齐，移去所有牌并获得势力锦囊",
  ["#qiao__han001_pick_trick"] = "诏书：选择一张势力锦囊",
}

return skill
