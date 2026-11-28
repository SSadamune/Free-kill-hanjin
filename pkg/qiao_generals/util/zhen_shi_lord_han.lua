-- EM(HAN001) 君刘协的诏书公共入口。诏书是特殊标记/公开旗堆，不是实体牌。
local H = require "packages.hegemony.util"
local Cards = require "packages.qiao.pkg.qiao_mode.rules.cards"
local Ban = require "packages.qiao.pkg.qiao_mode.rules.faction_ban"
local Deck = require "packages.qiao.pkg.qiao_generals.util.jin_deck"

local M = {}
M.LORD = "qiao_heg__em_han001"
M.JIANPING = "qiao__skill_em_han001_1"
M.ZHUANPENG = "qiao__skill_em_han001_2"
M.TIANSHOU = "qiao__skill_em_han001_3"
M.BANNER = "qiao__skill_em_han001_banner"
M.CONSUME = "qiao__skill_em_han001_consume"
M.PILE_MARK = "qiao_edict"
M.PILE = "@[" .. M.PILE_MARK .. "]qiao_em_han001_zhaoshu"
M.MARK = "qiao_em_han001_zhaoshu_mark"
M.TRICK_BANNER = "qiao_han001_tricks"

--- 君刘协本人（君主专用查询；天授等君主身份效果使用）。
function M.lord(room)
  if room == nil then return nil end
  for _, p in ipairs(room.alive_players) do
    if not p.dead and not p:isRemoved() and p.general == M.LORD
      and p:getMark(M.MARK) == 1 then return p end
  end
  return nil
end

--- 诏书持有者：持有诏书标记的角色。初平与【敕令】都通过 M.grant 取得同一
--- 唯一指示物，因此不按武将身份识别。唯一性只排除死者；被【调虎离山】等
--- 暂时移出游戏的角色仍拥有诏书，不能据“不可见/不可用”再发一份。
function M.holder(room)
  if room == nil then return nil end
  for _, p in ipairs(room.alive_players) do
    if not p.dead and p:getMark(M.MARK) == 1 then
      return p
    end
  end
  return nil
end

--- 从操作者的视角定位诏书。若有多份，持有者只操作自己的诏书，
--- 其余角色通过技能入口定位座次列表中首份可用的同势力诏书。
function M.availableHolder(room, player)
  if not room or not player or player.dead or player:isRemoved() then return end
  if player:getMark(M.MARK) == 1 then return player end
  return table.find(room.alive_players, function(holder)
    return not holder.dead and not holder:isRemoved() and holder:getMark(M.MARK) == 1
      and M.isSameKingdom(holder, player)
  end)
end

local function addSkill(room, player, name, source)
  room:handleAddLoseSkills(player, name, source, false, true)
end

local function removeSkill(room, player, name)
  -- 先按初平来源移除；非初平取得的入口以顶层技能形式挂载，再按无来源移除。
  room:handleAddLoseSkills(player, "-" .. name, M.JIANPING, false, true)
  if player:hasSkill(name) then
    room:handleAddLoseSkills(player, "-" .. name, nil, false, true)
  end
end

--- 诏书入口同步：持有者同势力角色（含持有者）获得交牌入口，持有者本人获得
--- 四花色消费入口。来源为君刘协时沿用初平作为技能来源，其余持有者按顶层技能。
function M.sync(room)
  if room == nil then return end
  for _, p in ipairs(room.players) do
    local holder = M.availableHolder(room, p)
    if holder then
      local source = holder:hasSkill(M.JIANPING) and M.JIANPING or nil
      if not p:hasSkill(M.BANNER) then addSkill(room, p, M.BANNER, source) end
      if p == holder and not p:hasSkill(M.CONSUME) then addSkill(room, p, M.CONSUME, source) end
    elseif p:hasSkill(M.BANNER) then
      removeSkill(room, p, M.BANNER)
    end
    if p ~= holder and p:hasSkill(M.CONSUME) then
      removeSkill(room, p, M.CONSUME)
    end
  end
end

--- 令角色获得诏书（特殊标记，唯一指示物）。已有持有者时不重复建立；
--- 先到者保持，不转移已存在的诏书及其上的实体牌。
function M.grant(room, player)
  if room == nil or player == nil or player.dead or player:isRemoved() then
    return false
  end
  local holder = M.holder(room)
  if holder ~= nil then return holder == player end
  room:setPlayerMark(player, M.MARK, 1)
  M.sync(room)
  M.syncTricks(room)
  return true
end

function M.count(lord)
  return lord and #lord:getPile(M.PILE) or 0
end

function M.maxPlacementCards(player)
  return H.isSmallKingdomPlayer(player) and 2 or 1
end

function M.validPlacement(player, cards)
  if #cards == 0 or #cards > M.maxPlacementCards(player) then return false end
  local hand = player:getCardIds(Player.Hand)
  local seen = {}
  for _, id in ipairs(cards) do
    if seen[id] or not table.contains(hand, id) then return false end
    seen[id] = true
  end
  return true
end

function M.pileSuits(ids)
  local suits = {}
  for _, id in ipairs(ids) do
    local card = Fk:getCardById(id, true)
    if card and Deck.validSuit(card.suit) then table.insertIfNeed(suits, card.suit) end
  end
  return suits
end

function M.pileLabelValue(count, visibleCards)
  local symbols = Deck.suitSymbols(M.pileSuits(visibleCards))
  return symbols == "" and tostring(count) or (count .. " " .. symbols)
end

function M.isSameKingdom(lord, player)
  if lord == nil or player == nil then return false end
  if lord == player then return true end
  local kingdom = H.getKingdom(lord)
  if not kingdom or kingdom == "" or kingdom == "wild" or kingdom == "hidden" then return false end
  return H.compareKingdomWith(lord, player)
end

--- 本局不可用的常规势力集合（候选外与禁选合并）。
function M.unavailableKingdoms(room)
  local allowed = room:getBanner("all_kingdoms") or {}
  local unavailable = {}
  for _, kingdom in ipairs(Ban.kingdoms or {}) do
    if not table.contains(allowed, kingdom) then unavailable[kingdom] = true end
  end
  return unavailable
end

--- 现有正式牌堆中被移出游戏的势力锦囊实体；按本模式允许势力与池门槛过滤。
function M.availableTricks(room)
  local unavailable = M.unavailableKingdoms(room)
  local result = {}
  for _, id in ipairs(room.void or {}) do
    local card = Fk:getCardById(id, true)
    if card ~= nil and Cards.tricks[card.name] ~= nil
      and Cards.trickAllowed(card.name, unavailable, room) then
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

--- 取得实际移出游戏的实体牌；不新建同名牌。服务器按与候选相同的过滤复核，
--- 避免过期/伪造候选绕过势力禁选或洛水之誓的池门槛。
function M.obtainTrick(room, player, entry)
  if entry == nil or type(entry.name) ~= "string" then return nil end
  local unavailable = M.unavailableKingdoms(room)
  if Cards.tricks[entry.name] == nil
    or not Cards.trickAllowed(entry.name, unavailable, room) then
    return nil
  end
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
