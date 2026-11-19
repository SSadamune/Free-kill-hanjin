-- WU023 陈武&董袭：奋命、断绁定向验收。
-- 规则依据：docs/rules/generals/wu023-chenwu-dongxi.md。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local ReqPlayCard = require "ltk.core.request_type.play_card"

local CHEN = "qiao_heg__wu023"
local FENGMING = "qiao__skill_wu023_1"
local DUANXIE = "qiao__skill_wu023_2"
local OPT_CHAIN = "qiao__skill_wu023_1-chain"
local OPT_DISCARD = "qiao__skill_wu023_1-discard-all"
local USED_CHAIN = "qiao__skill_wu023_1-chain-phase"
local USED_DISCARD = "qiao__skill_wu023_1-discard-phase"

local ZHEN_SHI = require "packages.qiao.pkg.qiao_generals.data.zhen_shi"

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function p(n) return FkTest.room.players[n] end

local function clearCards(player)
  local ids = player:getCardIds("he")
  if #ids > 0 then
    FkTest.room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove,
      "test", nil, false)
  end
end

local function give(player, name, suit, number)
  local id
  inRoom(function()
    local card = FkTest.room:printCard(name, suit or Card.Spade, number or 7)
    FkTest.room:obtainCard(player, card, false, fk.ReasonJustMove)
    id = card.id
  end)
  return id
end

--- 真实 ClientPlayer 没有 room 字段；临时替换 Fk.currentRoom 并在结束后恢复。
local function withClientRoom(current, fn)
  local ClientPlayer = require "ltk.client.clientplayer"
  local clients = {}
  for _, original in ipairs(current.players) do
    local copy = ClientPlayer:new(original._splayer)
    for key, value in pairs(original) do
      if key ~= "room" and key ~= "class" and key ~= "serverplayer" then copy[key] = value end
    end
    local cards = {}
    for area, ids in pairs(copy.player_cards or {}) do cards[area] = table.simpleClone(ids) end
    copy.player_cards = cards
    table.insert(clients, copy)
  end
  for index, player in ipairs(clients) do
    player.next = clients[index % #clients + 1]
  end
  local clientRoom = setmetatable(
    { players = clients, alive_players = clients, current = clients[1] },
    { __index = current })
  local originalRoom = Fk.currentRoom
  Fk.currentRoom = function() return clientRoom end
  local ok, err = pcall(function() fn(clients, clientRoom) end)
  Fk.currentRoom = originalRoom
  if not ok then error(err) end
end

local function prepare()
  Fk.currentResponsePattern = nil
  local room = support.createRoom {
    mode = "qiao_heg_mode",
    realSelection = true,
    settings = {
      qiao_faction_ban_enabled = false,
    },
  }
  inRoom(function()
    skill_test.installBlankGenerals(room, {
      "wu", "wu", "wu", "wu", "wu", "wu", "wu", "wu",
    })
    for _, player in ipairs(room.players) do clearCards(player) end
    skill_test.installDualGenerals(room, room.players[1], {
      main = CHEN,
      deputy = "qiao_test__wu_2",
      kingdom = "wu",
    })
  end)
  return room
end

Testqiao_wu023_chenwu_dongxi = {
  setup = prepare,
  tearDown = function()
    Fk.currentResponsePattern = nil
    support.clearRoom()
  end,
}

function Testqiao_wu023_chenwu_dongxi:testFormalRegistration()
  local pack = assert(Fk.packages.qiao_zhenshi)
  local entry = assert(table.find(ZHEN_SHI.generals, function(data)
    return data.id == CHEN
  end), "missing Chen Wu & Dong Xi data entry")
  lu.assertEquals(entry.number, "WU023")
  local general = assert(Fk.generals[CHEN])
  lu.assertIs(general.package, pack)
  lu.assertEquals(general.trueName, "陈武&董袭")
  lu.assertEquals(general.kingdom, "wu")
  lu.assertEquals(general.maxHp, 4)
  lu.assertEquals(general.gender, General.Male)
  lu.assertTrue(table.contains(general:getSkillNameList(), FENGMING))
  lu.assertTrue(table.contains(general:getSkillNameList(), DUANXIE))
  inRoom(function()
    lu.assertTrue(Fk:canUseGeneral(CHEN))
  end)
end

function Testqiao_wu023_chenwu_dongxi:testFengmingTwoOptionsEachOnce()
  local room, player, second, third = FkTest.room, p(1), p(2), p(3)
  inRoom(function()
    player.hp = 2
    room.current = player
    player.phase = Player.Play
    room:setBanner("RoundCount", 1)
  end)
  local own = give(player, "qiao__jink", Card.Heart, 2)
  local secondCard = give(second, "qiao__jink", Card.Heart, 3)
  local thirdCard = give(third, "qiao__jink", Card.Heart, 4)

  local skill = assert(Fk.skills[FENGMING])
  local choiceCount, discards = 0, {}
  local function useFengming()
    inRoom(function()
      lu.assertTrue(skill:canUse(player))
      room:useSkill(player, skill, function()
        skill:onUse(room, { from = player, cards = {}, tos = {} })
      end, { from = player, cards = {}, tos = {} })
    end)
  end

  skill_test.withSkillRequests(room, FENGMING, {
    askToChoice = function(self, who, params, original)
      if params.skill_name ~= FENGMING then
        return original(self, who, params)
      end
      choiceCount = choiceCount + 1
      return choiceCount == 1 and OPT_CHAIN or OPT_DISCARD
    end,
    askToChoosePlayers = function(self, who, params, original)
      if params.skill_name ~= FENGMING then
        return original(self, who, params)
      end
      -- 第一项可选自己。
      lu.assertTrue(table.contains(params.targets, player))
      return { player, second }
    end,
    askToChooseCard = function(self, who, params, original)
      if params.skill_name ~= FENGMING then
        return original(self, who, params)
      end
      -- 选择权在技能持有者，不是被弃牌角色。
      lu.assertIs(who, player)
      local hand = params.target:getCardIds(Player.Hand)
      local id = hand[1]
      table.insert(discards, { player = params.target, id = id })
      return id
    end,
  }, function()
    useFengming()
    lu.assertTrue(player.chained)
    lu.assertTrue(second.chained)
    lu.assertFalse(third.chained)
    useFengming()
  end)

  lu.assertEquals(choiceCount, 2)
  lu.assertEquals(player:getMark(USED_CHAIN), 1)
  lu.assertEquals(player:getMark(USED_DISCARD), 1)
  lu.assertFalse(skill:canUse(player))
  lu.assertEquals(#discards, 2)
  lu.assertIs(discards[1].player, player)
  lu.assertIs(discards[2].player, second)
  lu.assertEquals(FkTest.room:getCardArea(own), Card.DiscardPile)
  lu.assertEquals(FkTest.room:getCardArea(secondCard), Card.DiscardPile)
  lu.assertEquals(FkTest.room:getCardArea(thirdCard), Card.PlayerHand)
end

function Testqiao_wu023_chenwu_dongxi:testDuanxieDrawsOnActualReset()
  local room, player, other = FkTest.room, p(1), p(2)
  inRoom(function()
    room.current = player
    player.phase = Player.Play
    player:setChainState(true)
  end)

  inRoom(function() player:setChainState(false) end)
  lu.assertEquals(#player:getCardIds(Player.Hand), 2) -- 自己回合内重置摸2。

  inRoom(function()
    player:setChainState(true)
    room.current = other
    player:setChainState(false)
  end)
  lu.assertEquals(#player:getCardIds(Player.Hand), 3) -- 回合外重置摸1。

  -- 已重置者再次要求重置不产生新的状态变化，不再摸牌。
  inRoom(function()
    room.current = player
    player:setChainState(false)
  end)
  lu.assertEquals(#player:getCardIds(Player.Hand), 3)
end

function Testqiao_wu023_chenwu_dongxi:testFengmingCanUseOnRealClientPlayer()
  local room, player = FkTest.room, p(1)
  inRoom(function()
    player.phase = Player.Play
    player.chained = true
    room:setPlayerMark(player, USED_CHAIN, 1)
  end)

  withClientRoom(room, function(clients)
    local me = clients[1]
    lu.assertNil(me.room, "真实 ClientPlayer 不应有 room 字段")
    lu.assertEquals(me.class.name, "ClientPlayer")
    local handler = ReqPlayCard:new(me)
    handler.skill_name = FENGMING
    handler:setup()
    lu.assertTrue(handler:skillButtonValidity(FENGMING),
      "已横置且第一项已用时，真实客户端应仍显示第二项可用")
  end)
end

return { name = "qiao_wu023_chenwu_dongxi" }
