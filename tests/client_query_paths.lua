-- 客户端公共查询路径回归：
--   1. 用牌目标策略代理（默认 / 无视距离 / explicit 异势力且 max1）必须通过真实
--      ClientPlayer + ReqPlayCard.setup → selectCard → targetValidity/selectTarget
--      命中，不能只查服务器 candidates。
--   2. 两份同名派生翼从（庐江上甲）必须让客户端按公开 @@qiao_retinue_public 与
--      Z.USED_MARK 判定：仅一个持有者时 X=1，每份限一次；服务端 Z.spend 一份后
--      客户端仍可点确认，两份耗尽后禁用。客户端不得读 room tag / general_pile /
--      logic 等私有回退。
--
-- 客户端夹具见 tests/support/client_room.lua：真实 ClientPlayer、独立 mark 表，
-- 公开 mark 由用例显式同步。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local client_room = __dofile("../../../tests/support/client_room.lua")
local ClientPlayer = require "ltk.client.clientplayer"
local QiaoClient = require "packages.qiao.pkg.qiao_mode.client"
local ReqPlayCard = require "ltk.core.request_type.play_card"
local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"
local ExtraTargets = require "packages.qiao.pkg.qiao_mode.rules.extra_targets"
local R = require "packages.qiao.pkg.qiao_generals.util.retinue_instances"
local Z = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_retinues"

local LUJIANG = "qiao__retinue_skill_lujiang_shangjia"
local LUJIANG_GENERAL = "qiao_test__retinue_lujiang_shangjia"

local function room() return FkTest.room end
local function run(fn) FkTest.runInRoom(fn) end

local function give(player, name, suit, number)
  local card
  run(function()
    card = room():printCard(name, suit, number)
    room():obtainCard(player, card, false, fk.ReasonJustMove)
  end)
  return card
end

local function setup()
  Fk.currentResponsePattern = nil
  local server = support.initQiaoRoom()
  run(function()
    skill_test.installBlankGenerals(server,
      { "wei", "wei", "shu", "shu", "shu", "wu", "qun", "han" })
    for _, player in ipairs(server.players) do
      local ids = player:getCardIds("he")
      if #ids > 0 then room():throwCard(ids, "test", player, player) end
    end
    server.current = server.players[1]
    server.players[1].phase = Player.Play
  end)
  return server
end

Testqiao_client_query_paths = {
  setup = setup,
  tearDown = function()
    Fk.currentResponsePattern = nil
    support.clearRoom()
  end,
}

function Testqiao_client_query_paths:testOnlyOwnDoubleHiddenGeneralFrontsAreAvailable()
  client_room.run(room(), function(players)
    local client = QiaoClient:new(ClientInstance.client)
    client.players = players
    local me, other = players[1], players[2]
    me.general, me.deputyGeneral = "anjiang", "anjiang"
    other.general, other.deputyGeneral = "anjiang", "anjiang"
    other:setMark("__heg_general", "qiao_heg__jin001")
    other:setMark("__heg_deputy", "qiao_heg__jin002")
    local notifications = {}
    function client:notifyUI(command) table.insert(notifications, command) end
    local saved = Self
    Self = me
    local ok, err = pcall(function()
      me:setMark("__heg_general", 0)
      me:setMark("__heg_deputy", 0)
      lu.assertFalse(client:ownHiddenGenerals(me.id))
      client:handleSetPlayerMark { me.id, "__heg_general", "qiao_heg__jin001" }
      client:handleSetPlayerMark { me.id, "__heg_deputy", "qiao_heg__jin002" }
      client:handleSetPlayerMark { other.id, "__heg_deputy", "qiao_heg__jin003" }
      lu.assertEquals(notifications, { "QiaoOwnHiddenGeneralsChanged", "QiaoOwnHiddenGeneralsChanged" })
      lu.assertEquals(client:ownHiddenGenerals(me.id), { "qiao_heg__jin001", "qiao_heg__jin002" })
      lu.assertFalse(client:ownHiddenGenerals(other.id))
      client.observing = true
      lu.assertFalse(client:ownHiddenGenerals(me.id))
      client.observing, client.replaying = false, true
      lu.assertFalse(client:ownHiddenGenerals(me.id))
      client.replaying = false
      me.general = "qiao_heg__jin001"
      lu.assertFalse(client:ownHiddenGenerals(me.id))
    end)
    Self = saved
    if not ok then error(err, 0) end
  end)
end

local function pushPolicy(policy)
  local rec
  run(function() rec = C.push(room(), room().players[1], { "qiao__slash" }, policy) end)
  return rec
end

local function popPolicy(rec)
  run(function() C.pop(room(), room().players[1], rec) end)
end

--- 建立真实 ClientPlayer 房间并显式同步公开的策略 mark。
local function inClientPolicy(policy, fn)
  local rec = pushPolicy(policy)
  local ok, err = pcall(function()
    local server = room()
    client_room.run(server, function(clients, clientRoom)
      local me = clients[1]
      me.mark[C.POLICY_MARK] = server.players[1]:getMark(C.POLICY_MARK)
      fn(clients, clientRoom, me, server)
    end)
  end)
  popPolicy(rec)
  if not ok then error(err, 0) end
end

local function targetMap(handler, clients)
  local map = {}
  for _, client in ipairs(clients) do
    map[client.id] = handler:targetValidity(client.id) and true or false
  end
  return map
end

-- 真实出牌请求：setup → 点牌 → 目标可用性 / 点目标。
local function playCardHandler(me, cardId)
  local handler = ReqPlayCard:new(me)
  handler:setup()
  lu.assertIs(handler.room, Fk:currentRoom(), "handler 必须绑定当前客户端房间")
  lu.assertTrue(handler:cardValidity(cardId), "实体【杀】应在客户端可点亮")
  handler:selectCard(cardId, { selected = true })
  return handler
end

function Testqiao_client_query_paths:testClientTargetProxyPoliciesThroughRealPlayCardRequest()
  local card = give(room().players[1], "qiao__slash", Card.Spade, 2)

  -- 默认：保留牌面条件，近目标可、远目标不可，自身不可。
  inClientPolicy(C.default(), function(clients, _, me, server)
    local handler = playCardHandler(me, card.id)
    local map = targetMap(handler, clients)
    lu.assertFalse(map[server.players[1].id], "自身不得成为【杀】目标")
    lu.assertTrue(map[server.players[2].id], "距离 1 的默认目标应可用")
    lu.assertFalse(map[server.players[5].id], "距离 4 的远目标在默认策略下不可用")
    handler:_finish()
  end)

  -- bypass_distance：仅取消距离，远目标可。
  inClientPolicy(C.bypassDistance(), function(clients, _, me, server)
    local handler = playCardHandler(me, card.id)
    local map = targetMap(handler, clients)
    lu.assertTrue(map[server.players[2].id])
    lu.assertTrue(map[server.players[5].id], "bypass_distance 下远目标应可用")
    lu.assertFalse(map[server.players[1].id], "bypass_distance 不得放开自身")
    handler:_finish()
  end)

  -- explicit different_kingdom：同势力不可、异势力可，且 max_targets=1。
  local original = ExtraTargets.matchesTarget
  local probeCalls = 0
  ExtraTargets.matchesTarget = function(room_arg, player, card_arg, target, condition)
    probeCalls = probeCalls + 1
    lu.assertIs(room_arg, Fk:currentRoom(), "条件查询必须使用当前客户端房间")
    lu.assertEquals(player.class, ClientPlayer)
    lu.assertEquals(target.class, ClientPlayer)
    return original(room_arg, player, card_arg, target, condition)
  end
  local ok, err = pcall(function()
    inClientPolicy(C.explicit({ different_kingdom = true }), function(clients, _, me, server)
      local handler = playCardHandler(me, card.id)
      local p2, p3, p5 = server.players[2], server.players[3], server.players[5]
      lu.assertEquals(
        { handler:targetValidity(p2.id), handler:targetValidity(p3.id),
          handler:targetValidity(p5.id) },
        { false, true, true },
        "explicit 异势力应排除同势力目标并允许远距离异势力目标")

      handler:selectTarget(p3.id, { selected = true })
      lu.assertFalse(handler:targetValidity(p5.id),
        "max_targets=1 时第二个异势力目标应被拒绝")
      handler:selectTarget(p3.id, { selected = false })
      lu.assertTrue(handler:targetValidity(p5.id),
        "取消已选目标后，另一个异势力目标应重新可选")

      handler:selectTarget(p5.id, { selected = true })
      lu.assertTrue(handler:feasible(), "选中一个异势力目标后确认应可用")
      handler:_finish()
    end)
  end)
  ExtraTargets.matchesTarget = original
  if not ok then error(err, 0) end
  lu.assertTrue(probeCalls > 0, "explicit 策略必须真的走到 ExtraTargets.matchesTarget")
end

local function syncPublicMarks(me, serverPlayer)
  me.mark[R.PUBLIC_MARK] = serverPlayer:getMark(R.PUBLIC_MARK)
  me.mark[Z.USED_MARK] = serverPlayer:getMark(Z.USED_MARK)
end

local function inClientRetinue(server, fn)
  client_room.run(server, function(clients, clientRoom)
    local me = clients[1]
    local serverPlayer = server.players[1]
    lu.assertNil(me.room, "真实 ClientPlayer 不应有 room 字段")
    syncPublicMarks(me, serverPlayer)
    -- 客户端不得退回任何服务端私有字段。
    lu.assertFalse(pcall(function() return clientRoom:getTag("x") end))
    lu.assertFalse(pcall(function() return clientRoom.general_pile end))
    lu.assertFalse(pcall(function() return clientRoom.logic end))
    fn(clients, clientRoom, me, serverPlayer)
  end)
end

-- 真实按钮：技能可用 → 点技能 → 确认可用。
local function assertSkillButtonAndConfirm(me, skillName)
  local handler = ReqPlayCard:new(me)
  handler:setup()
  lu.assertTrue(handler:skillButtonValidity(skillName), "客户端应点亮翼从技能按钮")
  handler:selectSkill(skillName, { selected = true })
  lu.assertTrue(handler:feasible(), "点击翼从技能后进入确认应可用")
  handler:_finish()
end

function Testqiao_client_query_paths:testClientDerivedRetinueInstancesUsePublicMarks()
  local server = room()
  local p1 = server.players[1]
  give(p1, "qiao__jink", Card.Heart, 2)
  give(p1, "qiao__jink", Card.Heart, 3)

  local first, second
  run(function()
    first = R.grant(p1, { general = LUJIANG_GENERAL, skill = LUJIANG, position = "main" })
    second = R.grant(p1, { general = LUJIANG_GENERAL, skill = LUJIANG, position = "deputy" })
    lu.assertEquals(R.countForSkill(p1, LUJIANG), 2)
    lu.assertEquals(Z.characterCount(server, LUJIANG), 1, "仅一名角色持有，X=1")
    lu.assertEquals(#p1:getCardIds("h"), 2)
    lu.assertEquals(#p1:getCardIds("e"), 0)
  end)

  -- 两份实例各限一次；初始客户端按公开 mark 看到 2 份、0 次已用。
  inClientRetinue(server, function(_, clientRoom, me)
    lu.assertEquals(R.countForSkill(me, LUJIANG), 2)
    lu.assertEquals(Z.characterCount(clientRoom, LUJIANG), 1)
    lu.assertEquals(Z.publicUsedList(me, LUJIANG), { 0, 0 })
    lu.assertTrue(Z.canUse(me, LUJIANG, 1))
    assertSkillButtonAndConfirm(me, LUJIANG)
  end)

  -- 服务端用正式实例 API 消耗第一份，同步后客户端仍可点确认。
  run(function() Z.spend(p1, first, LUJIANG) end)
  inClientRetinue(server, function(clients, _, me)
    lu.assertEquals(Z.publicUsedList(me, LUJIANG), { 1, 0 })
    lu.assertTrue(Z.canUse(me, LUJIANG, 1), "剩一份实例时客户端应仍可用")
    assertSkillButtonAndConfirm(me, LUJIANG)
  end)

  -- 两份都耗尽后客户端按钮与确认均禁用。
  run(function() Z.spend(p1, second, LUJIANG) end)
  inClientRetinue(server, function(_, _, me)
    lu.assertEquals(Z.publicUsedList(me, LUJIANG), { 1, 1 })
    lu.assertFalse(Z.canUse(me, LUJIANG, 1), "两份实例耗尽后客户端不得再判定可用")
    local skill = assert(Fk.skills[LUJIANG])
    lu.assertFalse(skill:canUse(me), "客户端技能按钮应禁用")

    local handler = ReqPlayCard:new(me)
    handler:setup()
    lu.assertFalse(handler:skillButtonValidity(LUJIANG), "耗尽后必须点亮失败")
    handler:_finish()
  end)
end

return { name = "qiao_client_query_paths" }
