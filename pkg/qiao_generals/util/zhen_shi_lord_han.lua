-- EM(HAN001) 君刘协的诏书公共入口。诏书是特殊标记/公开旗堆，不是实体牌。
local Cards = require "packages.qiao.pkg.qiao_mode.rules.cards"
local Ban = require "packages.qiao.pkg.qiao_mode.rules.faction_ban"

local M = {}
M.LORD = "qiao_heg__em_han001"
M.JIANPING = "qiao__skill_em_han001_1"
M.ZHUANPENG = "qiao__skill_em_han001_2"
M.TIANSHOU = "qiao__skill_em_han001_3"
M.BANNER = "qiao__skill_em_han001_banner"
M.CONSUME = "qiao__skill_em_han001_consume"
M.PILE = "qiao_em_han001_zhaoshu"
M.MARK = "qiao_em_han001_zhaoshu_mark"
M.TRICK_BANNER = "qiao_han001_tricks"

function M.lord(room)
  if room == nil then return nil end
  for _, p in ipairs(room.alive_players) do
    if not p.dead and not p:isRemoved() and p.general == M.LORD
      and p:getMark(M.MARK) == 1 then return p end
  end
  return nil
end

function M.count(lord)
  return lord and #lord:getPile(M.PILE) or 0
end

function M.isSameKingdom(lord, player)
  if lord == nil or player == nil then return false end
  local kingdom = lord.kingdom
  if kingdom ~= "unknown" then return player.kingdom == kingdom end
  kingdom = lord:getMark("__heg_kingdom")
  return type(kingdom) == "string" and player.kingdom == kingdom
end

--- 现有正式牌堆中被移出游戏的势力锦囊实体；按本模式允许势力过滤。
function M.availableTricks(room)
  local allowed = room:getBanner("all_kingdoms") or {}
  local unavailable = {}
  for _, kingdom in ipairs(Ban.kingdoms or {}) do
    if not table.contains(allowed, kingdom) then unavailable[kingdom] = true end
  end
  local result = {}
  for _, id in ipairs(room.void or {}) do
    local card = Fk:getCardById(id, true)
    if card ~= nil and Cards.tricks[card.name] ~= nil
      and Cards.trickAllowed(card.name, unavailable) then
      result[#result + 1] = { id = id, name = card.name, kingdom = Cards.tricks[card.name] }
    end
  end
  table.sort(result, function(a, b) return a.id < b.id end)
  return result
end

--- 公开同步可用势力锦囊牌名；客户端只读该 banner，不读服务端 void。
function M.syncTricks(room)
  if room == nil then return end
  local names = {}
  for _, entry in ipairs(M.availableTricks(room)) do
    table.insertIfNeed(names, entry.name)
  end
  local old = room:getBanner(M.TRICK_BANNER) or {}
  if #old == #names and table.every(names, function(n) return table.contains(old, n) end) then return end
  room:setBanner(M.TRICK_BANNER, names)
end

function M.trickNames(room)
  return room and room:getBanner(M.TRICK_BANNER) or {}
end

--- 取得实际移出游戏的实体牌；不新建同名牌。
function M.obtainTrick(room, player, entry)
  if entry == nil then return nil end
  local id = table.find(room.void or {}, function(candidate)
    local card = Fk:getCardById(candidate, true)
    return card ~= nil and card.name == entry.name
  end)
  if id == nil then return nil end
  room:moveCardTo(id, Card.PlayerHand, player, fk.ReasonJustMove,
    M.JIANPING, nil, true, player)
  return id
end

return M
