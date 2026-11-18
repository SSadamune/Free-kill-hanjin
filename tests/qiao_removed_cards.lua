-- 调虎离山移出、玉玺多持有势力与公共查询的真实房间用例。
--
-- 独立套件：不加入 tests/all.lua，集成阶段可用
--   python scripts/test.py --file tests/qiao_removed_cards.lua
-- 运行。 本文件只依赖现有 support 夹具，不修改共享运行时或全局测试配置。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local H = require "packages.hegemony.util"
local Adaptation = require "packages.qiao.pkg.qiao_mode.rules.adaptation"
local client_room = __dofile("../../../tests/support/client_room.lua")

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end
local function p(n) return FkTest.room:getPlayerById(n) end

--- 按玩家 id 安装测试将，避免依赖 room.players 的排列顺序。
local function installById(room, kingdoms)
  for id, kingdom in ipairs(kingdoms) do
    local player = room:getPlayerById(id)
    skill_test.installDualGenerals(room, player, {
      main = "qiao_test__" .. kingdom .. "_1",
      deputy = "qiao_test__" .. kingdom .. "_2",
      kingdom = kingdom,
    })
  end
end

local function equipJade(player, suit, number)
  local room = FkTest.room
  local card = room:printCard("qiao__jade_seal", suit, number)
  room:obtainCard(player, card, false, fk.ReasonJustMove)
  room:moveCardIntoEquip(player, card, "test", false, player)
  return card
end

local function give(player, name, suit, number)
  local room = FkTest.room
  local card = room:printCard(name, suit, number)
  room:obtainCard(player, card, false, fk.ReasonJustMove)
  return card
end

local function useLure(room, from, tos)
  local card = room:printCard("qiao__lure_tiger", Card.Heart, 2)
  room:obtainCard(from, card, false, fk.ReasonJustMove)
  room:useCard(UseCardData:new {
    from = from, tos = tos, card = card, extra_data = {},
  })
  return card
end

Testqiao_removed_cards = {
  setup = function()
    local room = support.initQiaoRoom()
    inRoom(function() room.current = room.players[1] end)
  end,
  tearDown = support.clearRoom,
}

function Testqiao_removed_cards:testJadeSealMultipleHolderKingdomsAreAllBig()
  local room = FkTest.room
  local p1, p2, p3, p4, p5, p6 = p(1), p(2), p(3), p(4), p(5), p(6)
  inRoom(function()
    installById(room, {"wei", "wu", "shu", "qun", "wei", "wu", "shu", "qun"})
    equipJade(p1, Card.Spade, 2)
    equipJade(p2, Card.Heart, 2)
  end)
  inRoom(function()
    lu.assertTrue(H.isBigKingdomPlayer(p1), "魏持有者的势力应为大势力")
    lu.assertTrue(H.isBigKingdomPlayer(p2), "吴持有者的势力也应为大势力")
    lu.assertTrue(H.isBigKingdomPlayer(p5), "同属魏的未持有者也应是大势力角色")
    lu.assertTrue(H.isBigKingdomPlayer(p6), "同属吴的未持有者也应是大势力角色")
    lu.assertFalse(H.isBigKingdomPlayer(p3), "蜀不是玉玺持有势力")
    lu.assertFalse(H.isBigKingdomPlayer(p4), "群不是玉玺持有势力")
    lu.assertTrue(H.isSmallKingdomPlayer(p3))
    lu.assertTrue(H.isSmallKingdomPlayer(p4))
    local mapper = H.getKingdomPlayersNum(room, false)
    lu.assertEquals(mapper.wei, 2)
    lu.assertEquals(mapper.wu, 2)
  end)
end

function Testqiao_removed_cards:testRemovedJadeHolderExcludedFromKingdomAndMapper()
  local room = FkTest.room
  local p1, p2, p3 = p(1), p(2), p(3)
  inRoom(function()
    -- p1 为唯一的魏；p2 为唯一的吴；其余为蜀/群。
    installById(room, {"wei", "wu", "shu", "qun", "shu", "qun", "shu", "qun"})
    equipJade(p1, Card.Spade, 2)
    equipJade(p2, Card.Heart, 2)
    room:setPlayerMark(p1, MarkEnum.PlayerRemoved .. "-turn", 1)
  end)
  inRoom(function()
    lu.assertTrue(p1:isRemoved())
    -- 移出者仍留在房间列表中：胜负与天然野心家需要继续计入。
    lu.assertTrue(table.contains(room.alive_players, p1),
      "room.alive_players 不能删除移出者")
    lu.assertFalse(table.contains(room:getAlivePlayers(), p1),
      "常规角色查询须排除移出者")

    lu.assertTrue(H.isBigKingdomPlayer(p2), "另一玉玺持有势力仍为大")
    lu.assertFalse(H.isBigKingdomPlayer(p1), "移出者本身不是大势力角色")
    lu.assertFalse(H.isBigKingdomPlayer(p3), "蜀仍不是持有势力")
    lu.assertTrue(H.isSmallKingdomPlayer(p3))

    local mapper = H.getKingdomPlayersNum(room, false)
    -- 扣到 0 也必须保留键：上游存在 mapper[kingdom] < number 的锁定调用。
    lu.assertEquals(mapper.wei, 0)
    lu.assertEquals(mapper.wu, 1)
    lu.assertTrue(mapper.wei < #room.players // 2)
    lu.assertEquals(H.getKingdomPlayersNum(room, true).wei, 0)
    lu.assertEquals(H.getSameKingdomPlayersNum(room, p1), 0)
    lu.assertEquals(H.getSameKingdomPlayersNum(room, p2), 1)
  end)
end

function Testqiao_removed_cards:testLureTigerPreventsCurrentAndDyingThenReturnsBeforePojun()
  local room = FkTest.room
  local p1, p2, p3, p4 = p(1), p(2), p(3), p(4)
  local pojunCard
  inRoom(function()
    installById(room, {"wei", "wei", "shu", "qun", "shu", "qun", "shu", "qun"})
    room.current = p1
    p4.hp = 0
    room:handleAddLoseSkills(p3, "qiao__skill_wu020_2", nil, false, false)
    pojunCard = give(p3, "qiao__slash", Card.Spade, 7)
    -- p1 是当前回合角色；p3 是正常目标；p4 是濒死角色。
    useLure(room, p2, { p1, p3 })
    useLure(room, p2, { p4 })
  end)

  lu.assertFalse(p1:isRemoved(), "当前回合角色不能被移出")
  lu.assertFalse(p4:isRemoved(), "濒死角色不能被移出")
  lu.assertTrue(p3:isRemoved(), "其他目标应真实移出")
  lu.assertEquals(p3:getMark(MarkEnum.PlayerRemoved .. "-turn"), 1)

  inRoom(function()
    lu.assertFalse(p3:hasSkill("qiao__skill_wu020_2"),
      "Skill:isEffectable 应当在扣费/计数前令移出者技能不可发动")
    local slash = Fk:cloneCard("slash")
    lu.assertTrue(p3:prohibitUse(slash), "移出者不能使用牌")
    lu.assertTrue(p3:prohibitResponse(slash), "移出者不能打出牌")
    lu.assertTrue(p2:isProhibited(p3, slash), "移出者不能成为牌的目标")

    local hp = p3.hp
    room:loseHp(p3, 1)
    lu.assertEquals(p3.hp, hp, "移出者不能失去体力")
    room:damage { to = p3, damage = 1 }
    lu.assertEquals(p3.hp, hp, "移出者不能受到伤害")
    p3.hp = p3.maxHp - 1
    room:recover { who = p3, num = 1 }
    lu.assertEquals(p3.hp, p3.maxHp - 1, "移出者不能回复体力")
  end)

  local seen = {}
  inRoom(function()
    room:moveCards {
      ids = { pojunCard.id }, from = p3, toArea = Card.Void,
      moveReason = fk.ReasonJustMove, moveVisible = false,
    }
    room:addSkill("qiao__wu020_pojun_rule")
    local turn = GameEvent.Turn:create(TurnData:new(p1, "game_rule", { Player.Finish }))

    local skel = fk.CreateSkill { name = "#qiao_removed_order_probe" }
    -- TurnStart 时 Turn 事件才完成入栈并取得正式 id，破军待归列表要用这个 id。
    skel:addEffect(fk.TurnStart, {
      global = true,
      priority = -1000,
      mute = true,
      can_trigger = function(self, event, target, player)
        return target == player
      end,
      on_cost = Util.TrueFunc,
      on_use = function()
        local turnEvent = room.logic:getCurrentEvent():findParent(GameEvent.Turn, true)
        room:setTag("qiao_wu020_pojun_pending", {
          { target = p3.id, turn = turnEvent.id, ids = { pojunCard.id } },
        })
      end,
    })
    -- priority -2：晚于移回角色的 -1，早于 Turn exit 中的破军牌移回。
    skel:addEffect(fk.TurnEnd, {
      global = true,
      priority = -2,
      mute = true,
      can_trigger = function(self, event, target, player)
        return target == player
      end,
      on_cost = Util.TrueFunc,
      on_use = function()
        seen.removed = p3:isRemoved()
        seen.cardArea = room:getCardArea(pojunCard.id)
      end,
    })
    local probe = skel:createSkill()
    Fk.skills[probe.name] = probe
    for _, sub in ipairs(probe.related_skills or {}) do
      Fk.skills[sub.name] = sub
    end
    room:addSkill(probe)
    turn:exec()
  end)

  lu.assertFalse(seen.removed, "角色移回应先于破军牌移回")
  lu.assertEquals(seen.cardArea, Card.Void, "角色移回时破军牌仍在游戏外")
  lu.assertFalse(p3:isRemoved(), "回合结束时角色应移回")
  inRoom(function()
    lu.assertTrue(p3:hasSkill("qiao__skill_wu020_2"), "移回后技能恢复")
  end)
  lu.assertEquals(room:getCardArea(pojunCard.id), Card.PlayerHand,
    "破军牌应在角色移回后回到手牌")
  lu.assertTrue(table.contains(p3:getCardIds("h"), pojunCard.id))
end

function Testqiao_removed_cards:testRemovedPlayerSkillEffectIsPrevented()
  local room = FkTest.room
  local p3 = p(3)
  inRoom(function()
    installById(room, {"wei", "wei", "wei", "wei", "wei", "wei", "wei", "wei"})
    room:setPlayerMark(p3, MarkEnum.PlayerRemoved .. "-turn", 1)
  end)
  local called = false
  inRoom(function()
    local skill = assert(Fk.skills["qiao__skill_wu020_2"], "missing probe skill")
    room:useSkill(p3, skill, function() called = true end, {})
  end)
  lu.assertFalse(called, "移出者的技能效果不应执行")
end

function Testqiao_removed_cards:testRemovedPlayerExcludedFromCountsAndHandMaximum()
  local room, player, absent = FkTest.room, p(1), p(3)
  inRoom(function()
    for _ = 1, 12 do
      give(player, "qiao__slash", Card.Club, 2)
      give(absent, "qiao__jink", Card.Heart, 2)
    end
    give(absent, "qiao__jink", Card.Heart, 3)
    lu.assertFalse(Adaptation.conditionSatisfied(room, player, "fujia"))

    room:setPlayerMark(absent, MarkEnum.PlayerRemoved .. "-turn", 1)
    lu.assertEquals(#room:getPresentPlayers(), #room.alive_players - 1)
    lu.assertFalse(table.contains(room:getAlivePlayers(), absent))
    lu.assertFalse(table.contains(room:getOtherPlayers(player, false), absent))
    lu.assertTrue(table.contains(room:getOtherPlayers(player, false, true), absent),
      "引擎明置转野使用的全员查询仍须包含移出角色")
    lu.assertTrue(table.contains(room.alive_players, absent))
    lu.assertTrue(Adaptation.conditionSatisfied(room, player, "fujia"))
    client_room.run(room, function(clients, client)
      local me = client:getPlayerById(player.id)
      lu.assertEquals(#client:getPresentPlayers(), #room.alive_players - 1)
      lu.assertTrue(Adaptation.conditionSatisfied(client, me, "fujia"))
    end)

    room:setPlayerMark(absent, MarkEnum.PlayerRemoved .. "-turn", 0)
    lu.assertFalse(Adaptation.conditionSatisfied(room, player, "fujia"))
  end)
end

function Testqiao_removed_cards:testSharedChooserRejectsRemovedTargetsAndStaleReplies()
  local room, player, present, absent = FkTest.room, p(1), p(2), p(3)
  inRoom(function()
    room:setPlayerMark(absent, MarkEnum.PlayerRemoved .. "-turn", 1)
    local none = room:askToChoosePlayers(player, {
      targets = { absent }, min_num = 1, max_num = 1, cancelable = false,
    })
    lu.assertEquals(none, {})
    local request = Request:new(player, "AskForUseActiveSkill")
    request._asked = true
    request.result[player.id] = FkTest.ReplyChoosePlayer({ absent })
    lu.assertEquals(request:getResult(player), "")
  end)
  inRoom(function()
    local askActive = room.askToUseActiveSkill
    local sentTargets
    room.askToUseActiveSkill = function(_, _, params)
      sentTargets = params.extra_data.targets
      return true, { targets = { present } }
    end
    local chosen = room:askToChoosePlayers(player, {
      targets = { absent, present }, min_num = 1, max_num = 1, cancelable = false,
    })
    room.askToUseActiveSkill = askActive
    lu.assertEquals(sentTargets, { present.id })
    lu.assertEquals(#chosen, 1)
    lu.assertIs(chosen[1], present)
  end)
end

function Testqiao_removed_cards:testClientChooserDoesNotAllowRemovedTarget()
  local room, player, present, absent = FkTest.room, p(1), p(2), p(3)
  inRoom(function()
    room:setPlayerMark(absent, MarkEnum.PlayerRemoved .. "-turn", 1)
    client_room.run(room, function(_, clientRoom)
      local client = Fk:getBoardGame("qiao_heg_mode").client_klass:new(ClientInstance.client)
      local data = {
        targets = { absent.id, present.id }, num = 1, min_num = 1, pattern = "",
      }
      local skill = Fk.skills.choose_players_skill
      local oldData = skill._extra_data
      skill._extra_data = data
      local handler = client.request_handlers.AskForUseActiveSkill:new(
        clientRoom:getPlayerById(player.id), { skill.name, "", true, data })
      handler:setup()
      lu.assertFalse(handler:targetValidity(absent.id))
      lu.assertTrue(handler:targetValidity(present.id))
      handler:update("Photo", present.id, "click", { selected = true })
      lu.assertEquals(handler.selected_targets, { present.id })
      handler:_finish()
      skill._extra_data = oldData
    end)
  end)
end

return { name = "qiao_removed_cards" }
