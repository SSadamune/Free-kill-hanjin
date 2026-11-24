-- HAN015 卢植：用良、备寇、修体定向验收。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local ReqPlayCard = require "ltk.core.request_type.play_card"

local LUZHI = "qiao_heg__han015"
local YONGLIANG = "qiao__skill_han015_1"
local BEIKOU = "qiao__skill_han015_2"
local XIUTI = "qiao__skill_han015_3"
local DRAW = "qiao__skill_han015_2-draw"
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
    mode = "qiao_heg_mode", realSelection = true,
    settings = {
      qiao_faction_ban_enabled = false,
    },
  }
  inRoom(function()
    skill_test.installBlankGenerals(room, { "han", "qun", "han", "han", "han", "han", "han", "han" })
    for _, player in ipairs(room.players) do clearCards(player) end
    skill_test.installDualGenerals(room, room.players[1], {
      main = LUZHI, deputy = "qiao_test__han_2", kingdom = "han",
    })
  end)
  return room
end

Testqiao_han015_luzhi = {
  setup = prepare,
  tearDown = function() Fk.currentResponsePattern = nil; support.clearRoom() end,
}

function Testqiao_han015_luzhi:testFormalRegistration()
  local pack = assert(Fk.packages.qiao_zhenshi)
  local entry = assert(table.find(ZHEN_SHI.generals, function(d) return d.id == LUZHI end))
  lu.assertEquals(entry.number, "HAN015")
  local g = assert(Fk.generals[LUZHI])
  lu.assertIs(g.package, pack)
  lu.assertEquals(g.trueName, "卢植")
  lu.assertEquals(g.kingdom, "han")
  lu.assertEquals(g.maxHp, 4)
  lu.assertEquals(g.mainMaxHpAdjustedValue, -1)
  lu.assertEquals(g.gender, General.Male)
  lu.assertTrue(g:isCompanionWith(Fk.generals["qiao_heg__han012"]))
  lu.assertTrue(g:isCompanionWith(Fk.generals["qiao_heg__han013"]))
  for _, name in ipairs({ YONGLIANG, BEIKOU, XIUTI }) do
    lu.assertTrue(table.contains(g:getSkillNameList(), name))
  end
  inRoom(function() lu.assertTrue(Fk:canUseGeneral(LUZHI)) end)
end

function Testqiao_han015_luzhi:testYongliangUsesImperialOrderOnKnownKingdom()
  local room, player, target = FkTest.room, p(1), p(2)
  local cost = give(player, "qiao__jink", Card.Heart, 2)
  inRoom(function()
    room.current = player; player.phase = Player.Play; room:setBanner("RoundCount", 1)
  end)
  skill_test.withSkillRequests(room, YONGLIANG, {
    askToChoice = function(self, who, params, original)
      if params.skill_name == "qiao__imperial_order_skill" then return "loseHp" end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      room:handleUseCardReply(player, FkTest.ReplyUseSkill(YONGLIANG, { target }, { cost }))
    end)
  end)

  lu.assertEquals(FkTest.room:getCardArea(cost), Card.DiscardPile)
  lu.assertEquals(target.hp, target.maxHp - 1)
end

function Testqiao_han015_luzhi:testBeikouOncePerCharacterOnReveal()
  local room, player, target = FkTest.room, p(1), p(2)
  clearCards(target)
  local invoked = 0
  skill_test.withSkillRequests(room, BEIKOU, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == BEIKOU then invoked = invoked + 1; return true end
      return original(self, who, params)
    end,
    askToChoice = function(self, who, params, original)
      if params.skill_name == BEIKOU then return DRAW end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      target:hideGeneral(false)
      target:revealGeneral(false)
    end)
    inRoom(function()
      target:hideGeneral(false)
      target:revealGeneral(false)
    end)
  end)
  lu.assertEquals(invoked, 1)
  lu.assertEquals(#target:getCardIds(Player.Hand), 2)
end

function Testqiao_han015_luzhi:testXiutiDistinctRevealedCardsAndDrawToMaxHp()
  local room, player = FkTest.room, p(1)
  inRoom(function()
    -- prepare 时 p1 主将已装卢植；先彻底换成白板，清掉旧主将同名技能，
    -- 再装真实卢植副将，避免后一次换主将把刚装上的副将修体一并卸载。
    skill_test.installDualGenerals(room, player, {
      main = "qiao_test__han_1", deputy = "qiao_test__han_2", kingdom = "han",
    })
    skill_test.installDualGenerals(room, player, {
      main = "qiao_test__han_1", deputy = LUZHI, kingdom = "han",
    })
    skill_test.installDualGenerals(room, p(2), {
      main = "qiao_test__han_1", deputy = "qiao_test__han_2", kingdom = "han",
    })
    skill_test.installDualGenerals(room, p(3), {
      main = "qiao_test__han_3", deputy = "qiao_test__han_4", kingdom = "han",
    })
    -- p2 原为唯一的群角色；改为汉后需保留另一势力，否则真实明置会
    -- 提前判定游戏结束，回合无法进入结束阶段。
    skill_test.installDualGenerals(room, p(4), {
      main = "qiao_test__qun_1", deputy = "qiao_test__qun_2", kingdom = "qun",
    })
    clearCards(player); clearCards(p(2)); clearCards(p(3))
    -- 副将卢植必须真实明置，修体才不是暗将假技能。
    player:revealGeneral(true, false)
  end)

  local History = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_history"
  inRoom(function()
    lu.assertTrue(room:hasSkill("qiao__zhen_shi_history_rule"))
    lu.assertTrue(player:hasSkill(XIUTI), "Lu Zhi should still have Xiuti")
  end)

  -- 在同一个真实 Turn 的 Start 阶段完成两次真实明置；重复明置同一张将牌
  -- 不增加 X，第三张不同将牌使 X=2，随后同一 Turn 的 Finish 阶段发修体。
  local revealSkill = fk.CreateSkill { name = "test_han015_reveal_start" }
  revealSkill:addEffect(fk.EventPhaseStart, {
    global = true,
    can_trigger = function(self, event, target, p1, data)
      return target == player and p1 == player and data ~= nil and data.phase == Player.Start
    end,
    on_cost = Util.TrueFunc,
    on_use = function()
      p(2):hideGeneral(false); p(2):revealGeneral(false)
      p(2):hideGeneral(false); p(2):revealGeneral(false)
      p(3):hideGeneral(false); p(3):revealGeneral(false)
    end,
  })
  Fk:addSkill(revealSkill:createSkill())

  local xiutiInvoked = 0
  skill_test.withSkillRequests(room, XIUTI, {
    askToChoosePlayers = function(_, _, params)
      xiutiInvoked = xiutiInvoked + 1
      lu.assertEquals(params.max_num, 2)
      lu.assertTrue(params.cancelable)
      return { player, p(2) }
    end,
  }, function()
    inRoom(function()
      room:addSkill(revealSkill.name)
      GameEvent.Turn:create(TurnData:new(player, "game_rule", {
        Player.Start, Player.Finish,
      })):exec()
    end)
  end)
  inRoom(function()
    lu.assertEquals(History.count(room), 2)
  end)

  lu.assertEquals(xiutiInvoked, 1)
  lu.assertEquals(#player:getCardIds(Player.Hand), player.maxHp)
  lu.assertEquals(#p(2):getCardIds(Player.Hand), p(2).maxHp)
end

function Testqiao_han015_luzhi:testYongliangCanUseOnRealClientPlayer()
  local room, player = FkTest.room, p(1)
  give(player, "qiao__jink", Card.Heart, 2)
  inRoom(function()
    player.phase = Player.Play
    room.current = player
    room:setPlayerProperty(player, "kingdom", "han"); player.kingdom = "han"
    room:setPlayerProperty(p(2), "kingdom", "qun"); p(2).kingdom = "qun"
  end)

  withClientRoom(room, function(clients)
    local me = clients[1]
    lu.assertNil(me.room, "真实 ClientPlayer 不应有 room 字段")
    lu.assertEquals(me.class.name, "ClientPlayer")
    lu.assertTrue(me:hasSkill(YONGLIANG), "客户端应看到用良")
    local handler = ReqPlayCard:new(me)
    handler.skill_name = YONGLIANG
    handler:setup()
    lu.assertTrue(handler:skillButtonValidity(YONGLIANG),
      "有可弃牌且存在未禁止目标时，真实客户端应显示用良可用")
  end)
end

return { name = "qiao_han015_luzhi" }
