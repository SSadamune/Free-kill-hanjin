-- 群势力标准包：断肠（QUN012）的核心来源用例（5 个）。
--
-- 模式级 qun_duanchang_rule 已由 Codex 接入 mode.lua；本套件 setup 仍显式
-- room:addSkill，保证规则本体可在独立房间中验证。测试由唯一执行者运行。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_support = __dofile("../../../tests/support/skill_test.lua")
local Exchange = require "packages.hanjin.pkg.hanjin_mode.rules.general_exchange"
local Q = require "packages.hanjin.pkg.hanjin_mode.rules.qun_duanchang"

local CAIYAN = "hanjin__qun012"
local SIMAYI = "hanjin__wei002"
local XUCHU = "hanjin__wei005"
local PANGDE = "hanjin__qun008"
local MATENG = "hanjin__qun013"
local S_LANGGU = "hanjin__skill_wei002_1"
local S_YINGSHI = "hanjin__skill_wei002_2"
local S_YINGQI = "hanjin__skill_wei002_3"
local S_LUOYI = "hanjin__skill_wei005_1"
local S_MASHU = "hanjin__skill_shu006_1"
local S_MENGHAN = "hanjin__skill_qun008_2"
local S_XIONGYI = "hanjin__skill_qun013_2"
local ZHUGE = "hanjin__shu004"
local S_GUANXING = "hanjin__skill_shu004_1"
local S_KONGCHENG = "hanjin__skill_shu004_2"

Testhanjin_qun_duanchang = {}
Testhanjin_qun_duanchang.tearDown = support.clearRoom

Testhanjin_qun_duanchang.setup = function()
  local room = support.initHanjinRoom()
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

--- 杀死蔡文姬，并由她选择来源的将牌；choice 是玩家可见的选项值。
local function killCaiwenji(room, source, victim, choice)
  FkTest.setNextReplies(victim, { { choice } })
  inRoom(function() room:killPlayer { who = victim, killer = source } end)
  lu.assertTrue(victim.dead)
end

-- 选中一张将牌失技，另一张将牌继续保有其技能 ------------------------------

function Testhanjin_qun_duanchang:testChooseOneCardKeepsTheOther()
  local room = FkTest.room
  local source, victim = p(1), p(2)

  inRoom(function()
    install(room, source, SIMAYI, XUCHU, "wei")
    install(room, victim, CAIYAN, "hanjin_test__qun_2", "qun")
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

function Testhanjin_qun_duanchang:testHiddenCardStaysLostAfterReveal()
  local room = FkTest.room
  local source, victim = p(1), p(2)

  inRoom(function()
    install(room, source, SIMAYI, XUCHU, "wei")
    source:hideGeneral(true)
    install(room, victim, CAIYAN, "hanjin_test__qun_2", "qun")
    lu.assertEquals(source.deputyGeneral, "anjiang")
    lu.assertTrue(source:isFakeSkill(S_LUOYI))
  end)

  -- 暗置时只显示位置：选择副将牌。
  killCaiwenji(room, source, victim, "deputyGeneral")

  inRoom(function()
    lu.assertFalse(source:isFakeSkill(S_LUOYI))
    source:revealGeneral(true)
    lu.assertEquals(source.deputyGeneral, XUCHU)
  end)

  lu.assertFalse(source:hasSkill(S_LUOYI))
  lu.assertTrue(source:hasSkill(S_LANGGU))
  lu.assertTrue(source:hasSkill(S_YINGQI))
end

-- 交换该武将牌后，已失去的技能不得随新位置重新授回 --------------------------

function Testhanjin_qun_duanchang:testExchangeDoesNotRestoreLostSkills()
  local room = FkTest.room
  local source, victim, other = p(1), p(2), p(3)

  inRoom(function()
    install(room, source, SIMAYI, XUCHU, "wei")
    install(room, other, "hanjin_test__wei_1", "hanjin_test__wei_2", "wei")
    install(room, victim, CAIYAN, "hanjin_test__qun_2", "qun")
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
  lu.assertEquals(source.general, "hanjin_test__wei_1")
  lu.assertFalse(other:hasSkill(S_LANGGU))
  lu.assertFalse(other:hasSkill(S_YINGSHI))
  lu.assertFalse(other:hasSkill(S_YINGQI))
  lu.assertTrue(source:hasSkill(S_LUOYI))
end

-- 同名共享马术：断肠一张将牌后，另一将仍是马术的存活来源；该暗将明置时不得
-- 由引擎的 tolose 误删仅剩的一份。庞德/马腾都印马术，使用同一技能 ID。
function Testhanjin_qun_duanchang:testSharedMashuSurvivesOtherCardReveal()
  local room = FkTest.room
  local source, victim = p(1), p(2)

  inRoom(function()
    install(room, source, PANGDE, MATENG, "qun")
    install(room, victim, CAIYAN, "hanjin_test__qun_2", "qun")
    -- 至少保留一个其他势力，避免存活角色全同势力时死亡判定直接终局，
    -- 同时避免胜负判定把暗置武将全部翻开，破坏“明置马腾”的步骤。
    install(room, p(3), "hanjin_test__wei_1", "hanjin_test__wei_2", "wei")
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
function Testhanjin_qun_duanchang:testWrongPositionSkillStaysLostAfterExchange()
  local room = FkTest.room
  local source, victim, other, wei = p(1), p(2), p(3), p(4)

  inRoom(function()
    install(room, source, MATENG, ZHUGE, "qun")
    install(room, other, "hanjin_test__qun_1", "hanjin_test__qun_2", "qun")
    install(room, wei, "hanjin_test__wei_1", "hanjin_test__wei_2", "wei")
    install(room, victim, CAIYAN, "hanjin_test__qun_2", "qun")
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
  lu.assertEquals(source.deputyGeneral, "hanjin_test__qun_1")
  lu.assertFalse(other:hasSkill(S_GUANXING))
  lu.assertFalse(other:hasSkill(S_KONGCHENG))
  lu.assertTrue(source:hasSkill(S_MASHU))
  lu.assertTrue(source:hasSkill(S_XIONGYI))
end

return { name = "hanjin_qun_duanchang" }
