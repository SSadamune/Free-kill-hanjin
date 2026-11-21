-- 汉晋 FAQ 公共硬规则：
-- 1. 10 人（及以上）局同势力上限 4 人（第 5 人起转野），统一明置、效忠与升变预演；
-- 2. 启用后置位补偿时，7 人及以上局的 7 号位起各有 1 次额外手气卡；
-- 3. 4 人及以下局，君主不可普通升变或死亡继位，首亮角色不获得「先驱」标记；
-- 4. 阴阳鱼标记通用获得上限为 5 枚，统一约束所有来源。
--
-- 本模块仅在汉晋模式房间内生效，其他模式透明委托原生行为。
local H = require "packages.hegemony.util"
local Modes = require "packages.qiao.pkg.qiao_mode.modes"
local M = {}

M.MAX_KINGDOM_PLAYERS = 4
M.MIN_LORD_PLAYERS = 5
M.BONUS_LUCK_MIN_PLAYERS = 7
M.BONUS_LUCK_MIN_SEAT = 7
M.MAX_YINYANG_FISH = 5
M.seatLuckSetting = "qiao_late_seat_compensation"
M.seatLuckNone = "qiao_late_seat_none"
M.seatLuckCard = "qiao_late_seat_luck_card"

local revealWasUnknownDepth = setmetatable({}, { __mode = "k" })

local function isUnknown(kingdom)
  return kingdom == nil or kingdom == "" or kingdom == "unknown"
end

function M.max_kingdom_players(room)
  local total = room and room.players and #room.players or 0
  return math.min(total // 2, M.MAX_KINGDOM_PLAYERS)
end

function M.allows_lord_ascension(room)
  local total = room and room.players and #room.players or 0
  return total >= M.MIN_LORD_PLAYERS
end

function M.allows_first_show_vanguard(room)
  local total = room and room.players and #room.players or 0
  return total >= M.MIN_LORD_PLAYERS
end

--- 在 fk.GeneralShown 最早期强制执行汉晋同势力人数上限（10 人局第 5 人起转野）。
--- 仅对本次 revealGeneral 之前仍为 unknown 的角色生效，避免已属该势力的角色再亮
--- 另一张将牌时被误判转野；死亡同势力角色计入名额，君主在场不豁免。
function M.enforce_reveal_overflow(room, player)
  if room == nil or player == nil or not Modes.inRoom(room) then return false end
  local stack = revealWasUnknownDepth[player]
  if stack == nil or #stack == 0 or not stack[#stack] then return false end
  local kingdom = player.kingdom
  if isUnknown(kingdom) or kingdom == "wild" then return false end
  local count = 0
  for _, other in ipairs(room.players) do
    if other ~= player and other.kingdom == kingdom then
      count = count + 1
    end
  end
  if count >= M.max_kingdom_players(room) then
    room:setPlayerProperty(player, "kingdom", "wild")
    return true
  end
  return false
end

local function installYinyangCap()
  local original = H.addHegMark
  H.addHegMark = function(player, markName, number)
    local room = player and player.room
    if not Modes.inRoom(room) or markName ~= "yinyangfish" then
      return original(player, markName, number)
    end
    local req = number or 1
    if req <= 0 then return end
    local current = player:getMark("@!!yinyangfish") or 0
    local allowed = math.max(0, M.MAX_YINYANG_FISH - current)
    local actual = math.min(req, allowed)
    if actual <= 0 then return end
    return original(player, markName, actual)
  end
end

local function installRevealOverflowGuard()
  local spClass = ServerPlayer
  if spClass == nil then
    local ok, mod = pcall(require, "ltk.server.serverplayer")
    if ok then spClass = mod end
  end
  if spClass == nil or type(spClass.revealGeneral) ~= "function" then return end
  local original = spClass.revealGeneral
  spClass.revealGeneral = function(self, isDeputy, no_trigger)
    local room = self and self.room
    if not Modes.inRoom(room) then
      return original(self, isDeputy, no_trigger)
    end
    local stack = revealWasUnknownDepth[self]
    if stack == nil then
      stack = {}
      revealWasUnknownDepth[self] = stack
    end
    stack[#stack + 1] = isUnknown(self.kingdom)
    local ok, result = pcall(original, self, isDeputy, no_trigger)
    stack[#stack] = nil
    if #stack == 0 then revealWasUnknownDepth[self] = nil end
    if not ok then error(result, 0) end
    return result
  end
end

-- 与锁定引擎 ltk/server/events/gameflow.lua 保持一致的初始发牌与重抽辅助。
local function drawInit(room, player, n, fix_ids)
  local cardIds = room:tableRandomPick(room.draw_pile, n)
  if fix_ids then
    cardIds = room:tableRandomPick(fix_ids, n)
    if #cardIds < n then
      table.insertTable(cardIds, room:tableRandomPick(room.draw_pile, n - #cardIds))
    end
  end
  player:addCards(Player.Hand, cardIds)
  for _, id in ipairs(cardIds) do
    Fk:filterCard(id, player)
  end

  local move_to_notify = {
    moveInfo = {},
    to = player,
    toArea = Card.PlayerHand,
    moveReason = fk.ReasonDraw,
  }
  for _, id in ipairs(cardIds) do
    table.insert(move_to_notify.moveInfo, {
      cardId = id,
      fromArea = room:getCardArea(id),
    })
  end
  room:notifyMoveCards(nil, { move_to_notify })

  for _, id in ipairs(cardIds) do
    table.removeOne(room.draw_pile, id)
    room:setCardArea(id, Card.PlayerHand, player.id)
  end
  room:syncDrawPile()
  return cardIds
end

local function discardInit(room, player)
  local cardIds = player:getCardIds(Player.Hand)
  player:removeCards(Player.Hand, cardIds)

  local move_to_notify = {
    moveInfo = {},
    from = player,
    toArea = Card.DrawPile,
    moveReason = fk.ReasonJustMove,
  }
  local move_to_void_notify = {
    moveInfo = {},
    from = player,
    toArea = Card.Void,
    moveReason = fk.ReasonJustMove,
  }
  for _, id in ipairs(cardIds) do
    if id > 0 then
      table.insert(move_to_notify.moveInfo, {
        cardId = id,
        fromArea = Card.PlayerHand,
      })
      table.insert(room.draw_pile, id)
    else
      table.insert(move_to_void_notify.moveInfo, {
        cardId = id,
        fromArea = Card.PlayerHand,
      })
      table.insert(room.void, id)
    end
  end

  for _, id in ipairs(cardIds) do
    Fk:filterCard(id, nil)
  end

  local moves = {}
  if #move_to_notify.moveInfo > 0 then table.insert(moves, move_to_notify) end
  if #move_to_void_notify.moveInfo > 0 then table.insert(moves, move_to_void_notify) end
  room:notifyMoveCards(nil, moves)

  for _, id in ipairs(cardIds) do
    room:setCardArea(id, table.contains(room.draw_pile, id) and Card.DrawPile or Card.Void, nil)
  end
  room:syncDrawPile()
end

local function installSeatLuckCard()
  if GameEvent == nil or GameEvent.DrawInitial == nil or type(GameEvent.DrawInitial.main) ~= "function" then
    return
  end
  local original = GameEvent.DrawInitial.main
  GameEvent.DrawInitial.main = function(self)
    local room = self.room
    local data = self.data
    if not Modes.inRoom(room) or data == nil or data.disable_luck then
      return original(self)
    end

    data.who = data.who or room.alive_players
    local mode = room:getGameMode()
    local collection = mode.name == Modes.collection
    local seatLuckEnabled = #room.players >= M.BONUS_LUCK_MIN_PLAYERS
      and (collection or room:getSettings(M.seatLuckSetting) == M.seatLuckCard)
    local baseLuck = collection and 0 or math.max(0, room:getSettings("luckTime") or 0)
    local luck_data = {
      discardInit = discardInit,
      playerList = table.map(data.who, Util.IdMapper),
    }
    -- Request 重抽时不使用返回值，在这里记录每次实际发出的牌。
    function luck_data.drawInit(room, player, n, fix_ids)
      luck_data[player.id].cards = drawInit(room, player, n, fix_ids)
    end

    local luckPlayers = {}
    for _, player in ipairs(data.who) do
      local adjusted = mode:getAdjustedProperty(player)
      local draw_data = DrawInitialData:new { num = 4 + (adjusted.draw_init or 0) }
      room.logic:trigger(fk.DrawInitialCards, player, draw_data)
      luck_data[player.id] = draw_data
      local extra = tonumber(draw_data.extra_luck_time) or 0
      local seatLuck = seatLuckEnabled and player.seat >= M.BONUS_LUCK_MIN_SEAT and 1 or 0
      local totalLuck = baseLuck + seatLuck + math.max(0, extra)
      if player.id < 0 then
        totalLuck = 0
      end
      luck_data[player.id].luckTime = totalLuck
      if totalLuck > 0 then
        table.insert(luckPlayers, player)
      end
      if draw_data.num > 0 then
        luck_data.drawInit(room, player, draw_data.num, draw_data.fix_ids)
      else
        draw_data.cards = Util.DummyTable
      end
    end

    if #luckPlayers > 0 then
      local request = Request:new(luckPlayers, "AskForSkillInvoke")
      for _, p in ipairs(luckPlayers) do
        local times = luck_data[p.id].luckTime
        request:setData(p, { "AskForLuckCard", "#AskForLuckCard:::" .. times })
      end
      request.focus_text = "AskForLuckCard"
      request.luck_data = luck_data
      request.accept_cancel = true
      request:ask()
    end

    room:shuffleTable(room.draw_pile)
    for _, id in ipairs(room.draw_pile) do
      room:setCardArea(id, Card.DrawPile, nil)
    end
    room:syncDrawPile()
    for _, player in ipairs(data.who) do
      local draw_data = luck_data[player.id]
      draw_data.luckTime = nil
      room.logic:trigger(fk.AfterDrawInitialCards, player, draw_data)
    end
  end
end

function M.install()
  if M._installed then return end
  M._installed = true
  installYinyangCap()
end

function M.installServer(room)
  if room == nil or not Modes.inRoom(room) then return end
  if M._serverInstalled then return end
  M._serverInstalled = true
  installRevealOverflowGuard()
  installSeatLuckCard()
end

return M
