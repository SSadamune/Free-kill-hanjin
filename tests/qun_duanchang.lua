-- 群势力标准包：断肠（QUN012）的核心来源用例（5 个）。
--
-- 模式级 qun_duanchang_rule 已由 Codex 接入 mode.lua；本套件 setup 仍显式
-- room:addSkill，保证规则本体可在独立房间中验证。测试由唯一执行者运行。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_support = __dofile("../../../tests/support/skill_test.lua")
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
local Q = require "packages.qiao.pkg.qiao_mode.rules.qun_duanchang"
local SkillStatus = require "packages.qiao.pkg.qiao_mode.skill_status"
local clientRoom = __dofile("../../../tests/support/client_room.lua")
local Cards = require "packages.qiao.pkg.qiao_mode.rules.general_card_skills"
local SameName = require "packages.qiao.pkg.qiao_mode.rules.same_name_skills"
local client_room = __dofile("../../../tests/support/client_room.lua")

local CAIYAN = "qiao_heg__qun012"
local SIMAYI = "qiao_heg__wei002"
local XUCHU = "qiao_heg__wei005"
local PANGDE = "qiao_heg__qun008"
local MATENG = "qiao_heg__qun013"
local S_LANGGU = "qiao__skill_wei002_1"
local S_YINGSHI = "qiao__skill_wei002_2"
local S_YINGQI = "qiao__skill_wei002_3"
local S_LUOYI = "qiao__skill_wei005_1"
local S_MASHU = "qiao__skill_shu006_1"
local S_MENGHAN = "qiao__skill_qun008_2"
local S_XIONGYI = "qiao__skill_qun013_2"
local ZHUGE = "qiao_heg__shu004"
local S_GUANXING = "qiao__skill_shu004_1"
local S_KONGCHENG = "qiao__skill_shu004_2"

Testqiao_qun_duanchang = {}
Testqiao_qun_duanchang.tearDown = support.clearRoom

Testqiao_qun_duanchang.setup = function()
  local room = support.initQiaoRoom()
  FkTest.runInRoom(function()
    skill_support.installBlankGenerals(room, "qun")
    for _, player in ipairs(room.players) do
      room:setPlayerProperty(player, "hp", player.maxHp)
    end
    -- 模式 init 的接线由 Codex 完成；这里直接安装规则以验证规则本体。
    room:addSkill(Q.RULE_SKILL)
  end)
end

local function p(index) return FkTest.room.players[index] end

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function install(room, player, main, deputy, kingdom)
  skill_support.installDualGenerals(room, player, {
    main = main, deputy = deputy, kingdom = kingdom,
  })
end

function Testqiao_qun_duanchang:testPangDeAndHanSuiEachReduceDistance()
  local room, user, distant = FkTest.room, p(1), p(5)
  inRoom(function()
    local distance = user:distanceTo(distant)
    install(room, user, PANGDE, "qiao_heg__qun027", "qun")
    lu.assertEquals(user:distanceTo(distant), distance - 2)
    user:hideGeneral(true)
    lu.assertEquals(user:distanceTo(distant), distance - 1)
    user:revealGeneral(true)
    lu.assertEquals(user:distanceTo(distant), distance - 2)
    user:hideGeneral(false)
    lu.assertEquals(user:distanceTo(distant), distance - 1)
    user:revealGeneral(false)
    lu.assertEquals(user:distanceTo(distant), distance - 2)
    lu.assertEquals(p(2):distanceTo(distant), 3, "已注册的额外马术不影响其他角色")
  end)
end

function Testqiao_qun_duanchang:testRepeatedActiveAndTriggerUseIndependentHistory()
  local room, user, victim = FkTest.room, p(1), p(2)
  local zhiheng, jianxiong = "qiao__skill_wu001_1", "qiao__skill_wei001_1"
  inRoom(function()
    install(room, user, PANGDE, "qiao_heg__qun027", "qun")
    install(room, victim, CAIYAN, "qiao_test__qun_2", "qun")
    for _, general in ipairs({ user.general, user.deputyGeneral }) do
      Cards.grant(room, general, zhiheng)
      Cards.grant(room, general, jianxiong)
    end
    Cards.grant(room, victim.general, jianxiong)
    room.current, user.phase = user, Player.Play
    local board = assert(Fk:getBoardGame("qiao_heg_mode"))
    local ClientPlay = board.client_klass:new(ClientInstance.client).request_handlers.PlayCard
    local zhiheng2 = SameName.instanceName(zhiheng)
    local function buttons(first, second)
      client_room.run(room, function(clients)
        local handler = ClientPlay:new(clients[1])
        handler:setup()
        lu.assertEquals(handler:skillButtonValidity(zhiheng), first)
        lu.assertEquals(handler:skillButtonValidity(zhiheng2), second)
        handler:_finish()
      end)
    end
    local function useZhiheng(name)
      local card = room:printCard("qiao__jink", Card.Heart, 2)
      room:obtainCard(user, card, false, fk.ReasonJustMove)
      local material = card.id
      room:handleUseCardReply(user, FkTest.ReplyUseSkill(name, {}, { material }), nil)
      lu.assertEquals(user:usedSkillTimes(name, Player.HistoryPhase), 1)
    end
    buttons(true, true)
    useZhiheng(zhiheng)
    buttons(false, true)
    user:hideGeneral(false)
    lu.assertTrue(user:hasSkill(zhiheng), "另一张明置武将牌保有自己的制衡")
    lu.assertFalse(user:hasSkill(zhiheng2))
    lu.assertEquals(user:usedSkillTimes(zhiheng, Player.HistoryPhase), 0)
    user:revealGeneral(false)
    buttons(true, false)
    useZhiheng(zhiheng)
    buttons(false, false)

    local asked = {}
    skill_support.withSkillRequests(room, jianxiong, {
      askToSkillInvoke = function(_, player)
        asked[player] = (asked[player] or 0) + 1
        return true
      end,
    }, function()
      local before = #user:getCardIds("h")
      room:damage { from = victim, to = user, damage = 1 }
      lu.assertEquals(#user:getCardIds("h"), before + 2)
      room:damage { from = user, to = victim, damage = 1 }
    end)
    lu.assertEquals(asked[user], 2)
    lu.assertEquals(asked[victim], 1)

    local other = p(3)
    lu.assertTrue(Exchange.exchange(room, { player = user, isDeputy = false },
      { player = other, isDeputy = false }) ~= false)
    lu.assertEquals(other.general, PANGDE)
    lu.assertTrue(other:hasSkill(zhiheng))
    lu.assertEquals(other:usedSkillTimes(zhiheng, Player.HistoryPhase), 1)
    lu.assertEquals(user:usedSkillTimes(zhiheng, Player.HistoryPhase), 1)
    lu.assertFalse(user:hasSkill(zhiheng2))
  end)
end

--- 杀死蔡文姬，并由她选择来源的将牌；choice 是玩家可见的选项值。
local function killCaiwenji(room, source, victim, choice)
  FkTest.setNextReplies(victim, { { choice } })
  inRoom(function() room:killPlayer { who = victim, killer = source } end)
  lu.assertTrue(victim.dead)
end

local function duanchangLabel(player, own)
  return table.find(SkillStatus.forPlayer(player, own), function(state) return state.id == Q.DISPLAY_MARK end)
end

-- 选中一张将牌失技，另一张将牌继续保有其技能 ------------------------------

function Testqiao_qun_duanchang:testChooseOneCardKeepsTheOther()
  local room = FkTest.room
  local source, victim = p(1), p(2)

  inRoom(function()
    install(room, source, SIMAYI, XUCHU, "wei")
    install(room, victim, CAIYAN, "qiao_test__qun_2", "qun")
    lu.assertTrue(source:hasSkill(S_LANGGU))
    lu.assertTrue(source:hasSkill(S_LUOYI))
  end)

  killCaiwenji(room, source, victim, SIMAYI)

  -- 司马懿整张将牌的技能（含锁定技应期）全部失去；许褚的裸衣不受影响。
  lu.assertFalse(source:hasSkill(S_LANGGU))
  lu.assertFalse(source:hasSkill(S_YINGSHI))
  lu.assertFalse(source:hasSkill(S_YINGQI))
  lu.assertTrue(source:hasSkill(S_LUOYI))
  inRoom(function()
    lu.assertTrue(Q.isLost(room, SIMAYI, S_LANGGU))
    lu.assertTrue(Q.isLost(room, SIMAYI, S_YINGQI))
    lu.assertFalse(Q.isLost(room, XUCHU, S_LUOYI))
  end)
end

-- 暗将牌失去技能后，明置不得重新授回；另一张明置将牌保留 --------------------

function Testqiao_qun_duanchang:testHiddenCardStaysLostAfterReveal()
  local room = FkTest.room
  local source, victim = p(1), p(2)

  inRoom(function()
    install(room, source, SIMAYI, XUCHU, "wei")
    source:hideGeneral(true)
    install(room, victim, CAIYAN, "qiao_test__qun_2", "qun")
    lu.assertEquals(source.deputyGeneral, "anjiang")
    lu.assertTrue(source:isFakeSkill(S_LUOYI))
  end)

  -- 暗置时只显示位置：选择副将牌。
  killCaiwenji(room, source, victim, "deputyGeneral")

  local private = cbor.decode(room:serialize(source).players[source.id].mark)
  local public = cbor.decode(room:serialize(victim).players[source.id].mark)
  lu.assertEquals(private[Q.PRIVATE_MARK], { XUCHU })
  lu.assertNil(public[Q.PRIVATE_MARK])
  lu.assertEquals(public[Q.DISPLAY_MARK], { shown = {}, hidden = 1 })
  clientRoom.run(room, function(players)
    local client = players[source.seat]
    client:setMark(Q.PRIVATE_MARK, private[Q.PRIVATE_MARK])
    lu.assertEquals(duanchangLabel(client).value, "暗置武将牌")
    lu.assertEquals(duanchangLabel(client, true).value, Fk:translate(XUCHU))
  end)

  inRoom(function()
    lu.assertFalse(source:isFakeSkill(S_LUOYI))
    source:revealGeneral(true)
    lu.assertEquals(source.deputyGeneral, XUCHU)
  end)

  lu.assertFalse(source:hasSkill(S_LUOYI))
  lu.assertTrue(source:hasSkill(S_LANGGU))
  lu.assertTrue(source:hasSkill(S_YINGQI))
  lu.assertEquals(duanchangLabel(source).value, Fk:translate(XUCHU))
  lu.assertNil(cbor.decode(room:serialize(source).players[source.id].mark)[Q.PRIVATE_MARK])
end

-- 交换该武将牌后，已失去的技能不得随新位置重新授回 --------------------------

function Testqiao_qun_duanchang:testExchangeDoesNotRestoreLostSkills()
  local room = FkTest.room
  local source, victim, other = p(1), p(2), p(3)

  inRoom(function()
    install(room, source, SIMAYI, XUCHU, "wei")
    install(room, other, "qiao_test__wei_1", "qiao_test__wei_2", "wei")
    install(room, victim, CAIYAN, "qiao_test__qun_2", "qun")
  end)

  killCaiwenji(room, source, victim, SIMAYI)
  lu.assertFalse(source:hasSkill(S_LANGGU))

  inRoom(function()
    local context = Exchange.exchange(room,
      { player = source, isDeputy = false },
      { player = other, isDeputy = false })
    lu.assertNotEquals(context, false)
  end)

  -- 司马懿的牌换到另一名角色主将位置，记录随牌保留；许褚的裸衣留在原角色。
  lu.assertEquals(other.general, SIMAYI)
  lu.assertEquals(source.general, "qiao_test__wei_1")
  lu.assertNil(duanchangLabel(source))
  lu.assertEquals(duanchangLabel(other).value, Fk:translate(SIMAYI))
  lu.assertStrContains(duanchangLabel(other).description, "永久失去")
  lu.assertFalse(other:hasSkill(S_LANGGU))
  lu.assertFalse(other:hasSkill(S_YINGSHI))
  lu.assertFalse(other:hasSkill(S_YINGQI))
  lu.assertTrue(source:hasSkill(S_LUOYI))
end

-- 同名共享马术：断肠一张将牌后，另一将仍是马术的存活来源；该暗将明置时不得
-- 由引擎的 tolose 误删仅剩的一份。庞德/马腾都印马术，使用同一技能 ID。
function Testqiao_qun_duanchang:testSharedMashuSurvivesOtherCardReveal()
  local room = FkTest.room
  local source, victim = p(1), p(2)

  inRoom(function()
    install(room, source, PANGDE, MATENG, "qun")
    install(room, victim, CAIYAN, "qiao_test__qun_2", "qun")
    -- 至少保留一个其他势力，避免存活角色全同势力时死亡判定直接终局，
    -- 同时避免胜负判定把暗置武将全部翻开，破坏“明置马腾”的步骤。
    install(room, p(3), "qiao_test__wei_1", "qiao_test__wei_2", "wei")
    -- 复现真实开局：双将先暗置（同名马术只留一份 fake），再只明置庞德。
    -- 之后明置马腾时引擎缺少马术 fake，会把马术放进 tolose。
    source:hideGeneral(false)
    source:hideGeneral(true)
    source:revealGeneral(false)
    lu.assertFalse(room.game_finished)
    lu.assertFalse(victim.dead)
    lu.assertTrue(source:hasSkill(S_MASHU))
    lu.assertFalse(source:isFakeSkill(S_MASHU))
  end)

  killCaiwenji(room, source, victim, PANGDE)

  -- 庞德的马术记录为失去，但马腾的印刷马术是独立来源，当前马术应保留。
  inRoom(function()
    lu.assertTrue(source:hasSkill(S_MASHU))
    lu.assertFalse(source:hasSkill(S_MENGHAN))
    lu.assertTrue(Q.isLost(room, PANGDE, S_MASHU))
    lu.assertFalse(Q.isLost(room, MATENG, S_MASHU))
  end)

  -- 明置马腾：tolose 会尝试删除马术；规则技能在 GeneralShown 补回存活来源。
  inRoom(function()
    source:revealGeneral(true)
    lu.assertEquals(source.deputyGeneral, MATENG)
  end)
  lu.assertTrue(source:hasSkill(S_MASHU))
  lu.assertTrue(source:hasSkill(S_XIONGYI))
  lu.assertFalse(source:hasSkill(S_MENGHAN))
end

-- 失去记录按整张牌的印刷技能保存：处于副将位、当前不可用的主将技也要记入，
-- 交换到主将位后不能恢复。诸葛亮（观星+主将技空城）装在副将位验证。
function Testqiao_qun_duanchang:testWrongPositionSkillStaysLostAfterExchange()
  local room = FkTest.room
  local source, victim, other, wei = p(1), p(2), p(3), p(4)

  inRoom(function()
    install(room, source, MATENG, ZHUGE, "qun")
    install(room, other, "qiao_test__qun_1", "qiao_test__qun_2", "qun")
    install(room, wei, "qiao_test__wei_1", "qiao_test__wei_2", "wei")
    install(room, victim, CAIYAN, "qiao_test__qun_2", "qun")
    lu.assertFalse(victim.dead)
    lu.assertTrue(source:hasSkill(S_GUANXING))
    -- 空城是主将技，副将位当前不可用，但仍是这张牌的印刷技能。
    lu.assertFalse(source:hasSkill(S_KONGCHENG))
  end)

  killCaiwenji(room, source, victim, ZHUGE)

  inRoom(function()
    lu.assertFalse(source:hasSkill(S_GUANXING))
    lu.assertFalse(source:hasSkill(S_KONGCHENG))
    lu.assertTrue(Q.isLost(room, ZHUGE, S_GUANXING))
    lu.assertTrue(Q.isLost(room, ZHUGE, S_KONGCHENG))
    -- 与另一名同势力角色的主将交换：诸葛亮到主将位，空城的位置条件满足了，
    -- 但失败记录已按整张牌保存，不得重新授予。
    local context = Exchange.exchange(room,
      { player = source, isDeputy = true },
      { player = other, isDeputy = false })
    lu.assertNotEquals(context, false)
  end)

  lu.assertEquals(other.general, ZHUGE)
  lu.assertEquals(source.deputyGeneral, "qiao_test__qun_1")
  lu.assertFalse(other:hasSkill(S_GUANXING))
  lu.assertFalse(other:hasSkill(S_KONGCHENG))
  lu.assertTrue(source:hasSkill(S_MASHU))
  lu.assertTrue(source:hasSkill(S_XIONGYI))
end

return { name = "qiao_qun_duanchang" }
