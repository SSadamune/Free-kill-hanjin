-- EM(JIN001) 君司马炎：登记、诸王敕封册与赐、採幸、鼎沸核心验收。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local DATA = require "packages.qiao.pkg.qiao_bingqing.data.bingqing_lord_jin"
local A = require "packages.qiao.pkg.qiao_mode.rules.ascension"
local Versions = require "packages.qiao.pkg.qiao_mode.rules.general_versions"
local Discard = require "packages.qiao.pkg.qiao_mode.rules.general_discard"
local Ci = require "packages.qiao.pkg.qiao_generals.util.jin_ci"
local Guest = require "packages.qiao.pkg.qiao_mode.rules.guest_factions"
local Ban = require "packages.qiao.pkg.qiao_mode.rules.faction_ban"
local content = __dofile("../../../tests/support/ascension_content.lua")

local LORD = "qiao_heg__em_jin001"
local NORMAL = "qiao_heg__jin001"
local TAIKANG = "qiao__skill_em_jin001_1"
local BANNER = "qiao__skill_em_jin001_banner"
local CONSUME = "qiao__skill_em_jin001_consume"
local CI_MARK = "@[qiao_ci]"
local CAIXING = "qiao__skill_em_jin001_2"
local DINGFEI = "qiao__skill_em_jin001_3"
local RESOURCE_MAXCARD = "qiao__jin001_banner-resource-maxcard"
local RESOURCE_DRAW = "qiao__jin001_banner-resource-draw"
local CHANGE = "qiao__jin001_banner-change"

--- 资源分支按所选赐的牌面单独阴阳鱼数二选一，不再使用笼统的 resource 项。
local function resourceChoice(params)
  if table.contains(params.choices, RESOURCE_MAXCARD) then return RESOURCE_MAXCARD end
  if table.contains(params.choices, RESOURCE_DRAW) then return RESOURCE_DRAW end
  return nil
end

local function inRoom(fn, label)
  local room = FkTest.room
  local entered, completed, result = false, false, nil
  local before = tostring(room.game_finished)
  FkTest.runInRoom(function()
    entered = true
    result = fn()
    completed = true
  end)
  local after = tostring(room.game_finished)
  lu.assertTrue(entered, (label or "inRoom") .. " 未进入; finished " .. before .. "->" .. after)
  lu.assertTrue(completed, (label or "inRoom") .. " 未完成; finished " .. before .. "->" .. after)
  return result
end
local function p(n) return FkTest.room.players[n] end

local function setCi(room, holder, names)
  for _, name in ipairs(names) do table.removeOne(room.general_pile, name) end
  Ci.save(room, holder, names)
end

local function assertDiscarded(room, name)
  lu.assertTrue(Discard.contains(room, name), "武将弃牌堆应包含 " .. name)
  room:returnToGeneralPile({ name })
  lu.assertFalse(table.contains(room.general_pile, name), "本局不能再抽到 " .. name)
end

local function setupLord()
  local room = FkTest.room
  inRoom(function()
    skill_test.installBlankGenerals(room, { "jin", "jin", "jin", "wei", "wei", "shu", "wu", "qun" })
    skill_test.installDualGenerals(room, room.players[1], {
      main = NORMAL, deputy = "qiao_test__jin_2", kingdom = "jin",
    })
    room.current = room.players[1]
    A.ascend(room, room.players[1], LORD, "jin", { kind = "lord" })
  end)
end

Testqiao_em_jin001_simayan = {
  setup = function()
    Fk.currentResponsePattern = nil
    support.createRoom { mode = "qiao_heg_mode", realSelection = true, settings = { [Ban.enabledKey] = false } }
    setupLord()
  end,
  tearDown = function()
    Fk.currentResponsePattern = nil
    support.clearRoom()
  end,
}

local function banShuAndHan(room)
  room:setBanner("all_kingdoms", { "wei", "wu", "qun", "jin" })
  Guest.store(room, {}) -- 按新允许集重新解析本用例的将牌。
end

function Testqiao_em_jin001_simayan:testGuestGuanYuAsCiOnFirstDoubleReveal()
  local room, lord, jinShu, jinWei = FkTest.room, p(1), p(3), p(4)
  local guanYu = "qiao_heg__shu002"
  inRoom(function()
    banShuAndHan(room)
    content.setupHidden(room, jinShu, "qiao_heg__jin002", content.generals.jin_shu_deputy.name, "jin")
    content.setupHidden(room, jinWei, "qiao_heg__jin003", content.generals.loyalty_dual.name, "jin")
    room.general_pile = { guanYu }
  end)
  skill_test.withSkillRequests(room, BANNER, { askToSkillInvoke = function() return true end }, function()
    inRoom(function()
      jinShu:revealGeneral(false)
      jinShu:revealGeneral(true)
    end)
    lu.assertEquals(lord:getTableMark(CI_MARK), {}, "晋／蜀副将不能按旧蜀势力抽到魏关羽")
    lu.assertEquals(room.general_pile, { guanYu })
    inRoom(function()
      jinWei:revealGeneral(false)
      jinWei:revealGeneral(true)
    end)
  end)
  lu.assertEquals(lord:getTableMark(CI_MARK), { guanYu }, "晋／魏副将可以按魏抽到关羽")
  lu.assertEquals(room.general_pile, {})
end

function Testqiao_em_jin001_simayan:testKilledGuestDeputyUsesActiveKingdomForCi()
  local room, victim, killer = FkTest.room, p(4), p(2)
  local weiGeneral = "qiao_heg__wei003"
  inRoom(function()
    banShuAndHan(room)
    content.setupRevealed(room, victim, "qiao_heg__wei001", "qiao_heg__shu002", "wei")
    room.general_pile = { weiGeneral }
  end)
  skill_test.withSkillRequests(room, BANNER, { askToSkillInvoke = function() return true end }, function()
    inRoom(function() room:killPlayer { who = victim, killer = killer } end)
  end)
  lu.assertEquals(p(1):getTableMark(CI_MARK), { weiGeneral }, "死者的副将关羽本局按魏取赐")
end

function Testqiao_em_jin001_simayan:testTransferCannotChooseBannedKingdomAfterFreeAssignment()
  local room, lord, source = FkTest.room, p(1), p(2)
  local jinShu, guanYu = content.generals.jin_shu_deputy.name, "qiao_heg__shu002"
  inRoom(function()
    banShuAndHan(room)
    Guest.ensureFree(room, { jinShu, guanYu })
    setCi(room, lord, { jinShu, guanYu })
  end)
  local function give(reply)
    skill_test.withSkillRequests(room, BANNER, { askToChoices = function(_, _, params)
      lu.assertItemsEquals(params.choices, { "jin", "wei" })
      return { reply }
    end }, function()
      inRoom(function() room:damage { from = source, to = p(5), damage = 1 } end)
    end)
  end
  give("shu")
  lu.assertEquals(lord:getTableMark(CI_MARK), { jinShu, guanYu })
  lu.assertEquals(source:getTableMark(CI_MARK), {})
  give("wei")
  lu.assertEquals(lord:getTableMark(CI_MARK), { jinShu })
  lu.assertEquals(source:getTableMark(CI_MARK), { guanYu })
end

function Testqiao_em_jin001_simayan:testDamageTransfersAllCiOfChosenKingdom()
  local room, lord, source, victim = FkTest.room, p(1), p(2), p(4)
  local kept, single, guest, previous = "qiao_heg__wu001", "qiao_heg__wei003", "qiao_heg__shu001", "qiao_heg__jin005"
  inRoom(function()
    setCi(room, lord, { single, kept, guest })
    setCi(room, source, { previous })
    -- 本局将池已解析的双势力客将。按其可用魏、汉判组，不按原蜀势力。
    Guest.store(room, {
      [guest] = { name = guest, source = "guest", kingdoms = { "wei", "han" }, guest = true },
      [kept] = { name = kept, source = "original", kingdoms = { "wu" } },
      [single] = { name = single, source = "original", kingdoms = { "wei" } },
    })
  end)
  local asks = 0
  FkTest.setRoomBreakpoint(lord, "AskForChoices", function(data)
    if data[5] == BANNER then
      asks = asks + 1
      lu.assertItemsEquals(data[1], { "wei", "wu", "han" })
      lu.assertTrue(data[4], "只有一个势力也应可以放弃")
      lu.assertStrContains(data[6], tostring(source.id))
    end
    return false
  end)
  FkTest.setNextReplies(lord, { { "wei" } })
  inRoom(function() room:damage{ from = source, to = victim, damage = 1 } end)
  lu.assertEquals(asks, 1)
  lu.assertEquals(lord:getTableMark(CI_MARK), { kept })
  lu.assertEquals(source:getTableMark(CI_MARK), { previous, single, guest })
  lu.assertFalse(source:hasSkill(BANNER))
  for _, name in ipairs({single, guest}) do
    lu.assertFalse(Discard.contains(room, name))
    lu.assertFalse(table.contains(room.general_pile, name))
  end

  inRoom(function() room:killPlayer { who = lord } end)
  assertDiscarded(room, kept)
  lu.assertEquals(lord:getMark(CI_MARK), 0)
  lu.assertEquals(source:getTableMark(CI_MARK), { previous, single, guest })
  for _, name in ipairs({ previous, single, guest }) do lu.assertFalse(Discard.contains(room, name)) end
  inRoom(function() room:killPlayer { who = source } end)
  for _, name in ipairs({ previous, single, guest }) do assertDiscarded(room, name) end
  lu.assertEquals(source:getMark(CI_MARK), 0)
end

function Testqiao_em_jin001_simayan:testTransferCanDeclineAndOnlyOtherJinDamageQualifies()
  local room, lord, jin, wei = FkTest.room, p(1), p(2), p(4)
  local name, asks = "qiao_heg__jin005", 0
  inRoom(function()
    setCi(room, lord, { name })
    Guest.store(room, { [name] = { name = name, source = "original", kingdoms = { "jin" } } })
  end)
  skill_test.withSkillRequests(room, BANNER, {
    askToChoices = function(_, who, params)
      lu.assertIs(who, lord)
      lu.assertEquals(params.choices, { "jin" })
      lu.assertTrue(params.cancelable)
      asks = asks + 1
      return {}
    end,
  }, function()
    inRoom(function()
      room:damage{ from = wei, to = jin, damage = 1 }
      room:damage{ from = lord, to = wei, damage = 1 }
      room:damage{ to = p(5), damage = 1 }
      lu.assertEquals(asks, 0)
      room:damage{ from = jin, to = wei, damage = 1 }
    end)
  end)
  lu.assertEquals(asks, 1)
  lu.assertEquals(lord:getTableMark(CI_MARK), { name })
  lu.assertEquals(jin:getTableMark(CI_MARK), {})
  lu.assertFalse(Discard.contains(room, name))
end

function Testqiao_em_jin001_simayan:testRegistrationAndAscension()
  local general = assert(Fk.generals[LORD])
  lu.assertEquals(DATA.generals[1].name, "司马炎")
  lu.assertTrue(general.hidden)
  lu.assertTrue(general.is_lord)
  lu.assertEquals(general.trueName, "司马炎")
  lu.assertEquals(general.prefix, "qiao_prefix_nu")
  lu.assertEquals(Fk:translate(LORD), '<font color="#FFFF00">君</font>司马炎')
  lu.assertTrue(Versions.is_lord(LORD))
  lu.assertEquals(p(1).general, LORD)
  lu.assertTrue(p(1):hasSkill(TAIKANG))
  lu.assertTrue(p(1):hasSkill(BANNER), "太康应授予诸王敕封册")
  lu.assertEquals(p(1):getMark(CI_MARK), 1, "持旗者应能打开空列表")
end

function Testqiao_em_jin001_simayan:testFirstDoubleRevealMakesCiAndChangeBranch()
  local room, lord, target = FkTest.room, p(1), p(3)
  local pileBefore
  inRoom(function()
    -- 晋角色配魏／晋双势力副将：合格剩余牌可来自两个牌面势力。
    content.setupHidden(room, target, "qiao_heg__jin002", content.generals.loyalty_dual.name, "jin")
    room.general_pile = { "qiao_heg__jin004", "qiao_heg__wei001", LORD, "qiao_heg__jin005",
      "qiao_heg__shu001", "qiao_heg__jin006" }
    room.disabled_generals = { "qiao_heg__jin006" }
    pileBefore = #room.general_pile
  end)
  local invokes, picks, drawRange = 0, 0, nil
  local random = room.random
  skill_test.withSkillRequests(room, BANNER, {
    askToSkillInvoke = function(self)
      invokes = invokes + 1
      self.random = function(_, lo, hi)
        self.random = random
        drawRange = { lo, hi }
        return 3
      end
      return true
    end,
    askToChoice = function(_, _, params)
      picks = picks + 1
      return params.choices[1]
    end,
  }, function()
    inRoom(function()
      target:revealGeneral(false)
      target:revealGeneral(true)
    end)
  end)
  room.random = random
  local ci = lord:getTableMark(CI_MARK) or {}
  lu.assertEquals(ci, { "qiao_heg__jin005" })
  lu.assertEquals(drawRange, { 1, 3 }, "从两张晋将和一张魏将中随机抽取")
  lu.assertEquals(invokes, 1, "旗确认应一次")
  lu.assertEquals(picks, 0, "取得赐时不询问玩家选将")
  lu.assertEquals(#room.general_pile, pileBefore - 1, "该将牌应占用剩余将池")
  -- 羊祜为四鱼，用刚取得的赐摸至四张。
  local ciName = ci[1]
  lu.assertFalse(Discard.contains(room, ciName))
  inRoom(function()
    room:throwCard(lord:getCardIds("h"), "test", lord, lord)
    lord.phase = Player.Play
  end)
  lu.assertEquals(#lord:getCardIds("h"), 0)
  skill_test.withSkillRequests(room, BANNER, {
    askToChoices = function(_, _, params)
      lu.assertTrue(params.single)
      lu.assertFalse(params.detailed == true)
      lu.assertEquals(params.all_choices, { resourceChoice(params), CHANGE })
      return { resourceChoice(params) }
    end,
  }, function()
    inRoom(function()
      room:useSkill(lord, Fk.skills[CONSUME], function()
        Fk.skills[CONSUME]:onUse(room, { from = lord, interaction_data = ciName })
      end)
    end)
  end)
  lu.assertEquals(#(lord:getTableMark(CI_MARK) or {}), 0, "执行分支应消耗赐")
  lu.assertEquals(lord:getMark(CI_MARK), 1, "消耗最后一张后仍可打开列表")
  lu.assertEquals(#lord:getCardIds("h"), 4)
  assertDiscarded(room, ciName)
end

function Testqiao_em_jin001_simayan:testFirstDoubleWithoutBannerDoesNotBackfill()
  local room, lord, target = FkTest.room, p(1), p(3)
  inRoom(function()
    content.setupHidden(room, target, "qiao_heg__jin002", "qiao_heg__jin003", "jin")
    room:handleAddLoseSkills(lord, "-" .. TAIKANG, nil)
    lu.assertFalse(lord:hasSkill(BANNER), "先撤掉旗")
  end)
  inRoom(function()
    target:revealGeneral(false)
    target:revealGeneral(true)
  end)
  lu.assertEquals(target:getMark("qiao_jin001_first_double"), 1, "无旗时也应记录首次双亮")
  lu.assertEquals(#(lord:getTableMark(CI_MARK) or {}), 0, "无旗时不产生赐")
  inRoom(function()
    room:handleAddLoseSkills(lord, TAIKANG, nil, false, true)
    room.logic:trigger(fk.GeneralRevealed, target, { m = target.general, d = target.deputyGeneral })
  end)
  lu.assertEquals(#(lord:getTableMark(CI_MARK) or {}), 0, "后来获得旗不补领首次双亮")
end

function Testqiao_em_jin001_simayan:testCiChangeAndResourceAfterUsed()
  local room, lord, target = FkTest.room, p(1), p(3)
  local oldDeputy, chosen
  inRoom(function()
    content.setupHidden(room, target, "qiao_heg__jin002", "qiao_heg__jin003", "jin")
    room.general_pile = { "qiao_heg__jin005" }
    room.disabled_generals = {}
    oldDeputy = lord.deputyGeneral
    lord.phase = Player.Play
  end)
  local handler = function(self, who, params, original)
    if params.skill_name ~= BANNER then return original(self, who, params) end
    if table.contains(params.choices, "main") and table.contains(params.choices, "deputy") then
      return "deputy"
    end
    local resource = resourceChoice(params)
    if resource ~= nil then return resource end
    chosen = params.choices[1]
    return chosen
  end
  -- 通过真实首次双亮生成赐，确保该将牌已从剩余池占用。
  skill_test.withSkillRequests(room, BANNER, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == BANNER then return true end
      return original(self, who, params)
    end,
    askToChoice = handler,
  }, function()
    inRoom(function()
      target:revealGeneral(false)
      target:revealGeneral(true)
    end)
  end)
  local ci = lord:getTableMark(CI_MARK) or {}
  lu.assertEquals(#ci, 1, "真实首次双亮应生成一枚赐")
  lu.assertEquals(ci[1], "qiao_heg__jin005", "固定池后首张赐应可确定")
  lu.assertFalse(table.contains(room.general_pile, ci[1]), "生成的赐不应仍留在剩余池")
  inRoom(function()
    room.general_pile = { "qiao_heg__jin004", "qiao_heg__jin006" }
    local factions = {}
    for _, name in ipairs(room.general_pile) do factions[name] = Guest.resolve(name, { "jin" }, true) end
    Guest.store(room, factions)
  end)
  skill_test.withSkillRequests(room, BANNER, {
    askToChoice = handler,
    askToChoices = function(_, _, params)
      lu.assertTrue(table.contains(params.choices, CHANGE))
      return { CHANGE }
    end,
  }, function()
    inRoom(function()
      room:useSkill(lord, Fk.skills[CONSUME], function()
        Fk.skills[CONSUME]:onUse(room, { from = lord, interaction_data = ci[1] })
      end)
    end)
  end)
  lu.assertNotNil(chosen)
  lu.assertEquals(lord.deputyGeneral, chosen, "赐变更应通过公共 changeHero 换上所选副将")
  assertDiscarded(room, oldDeputy)
  assertDiscarded(room, ci[1])
  lu.assertFalse(Discard.contains(room, chosen))
  lu.assertFalse(table.contains(room.general_pile, chosen), "新武将不应重复留在池中")
  lu.assertTrue(lord:getMark("qiao_jin001_change_used") > 0, "变更分支应记录整局已用")
  lu.assertEquals(#(lord:getTableMark(CI_MARK) or {}), 0, "变更应消耗赐")
  local branches
  inRoom(function()
    lord.phase = Player.Play
    -- 进入另一出牌阶段，整局变更次数保持。
    room:setPlayerMark(lord, "qiao_jin001_ci_spent-phase", 0)
    setCi(room, lord, { "qiao_heg__jin007" })
  end)
  skill_test.withSkillRequests(room, BANNER, {
    askToChoices = function(_, _, params)
      branches = table.simpleClone(params.choices)
      lu.assertFalse(params.detailed == true)
      lu.assertEquals(params.all_choices, { resourceChoice(params), CHANGE })
      return { resourceChoice(params) }
    end,
  }, function()
    inRoom(function()
      Fk.skills[CONSUME]:onUse(room, { from = lord, interaction_data = "qiao_heg__jin007" })
    end)
  end)
  lu.assertNotNil(branches)
  lu.assertTrue(table.contains(branches, RESOURCE_MAXCARD))
  lu.assertEquals(lord:getMark(MarkEnum.AddMaxCardsInTurn), 3)
  assertDiscarded(room, "qiao_heg__jin007")
  lu.assertFalse(table.contains(branches, CHANGE), "整局限一次后变更按钮不可用")
  lu.assertEquals(#(lord:getTableMark(CI_MARK) or {}), 0, "资源分支应消耗赐")
end

function Testqiao_em_jin001_simayan:testCiAtFourCardsStillPaysForDraw()
  local room, lord, name = FkTest.room, p(1), "qiao_heg__jin005"
  inRoom(function()
    lord.phase = Player.Play
    setCi(room, lord, { name })
  end)
  local hand = table.simpleClone(lord:getCardIds("h"))
  lu.assertEquals(#hand, 4, "以四张起始手牌验证可以摸零张")
  skill_test.withSkillRequests(room, BANNER, {
    askToChoices = function() return { RESOURCE_DRAW } end,
  }, function()
    inRoom(function() Fk.skills[CONSUME]:onUse(room, { from = lord, interaction_data = name }) end)
  end)
  lu.assertEquals(lord:getCardIds("h"), hand)
  lu.assertEquals(lord:getTableMark(CI_MARK), {})
  assertDiscarded(room, name)
end

function Testqiao_em_jin001_simayan:testCiKeptOnCancelOrNoChangeCandidate()
  local room, lord, name = FkTest.room, p(1), "qiao_heg__jin005"
  inRoom(function()
    lord.phase = Player.Play
    room.general_pile = {}
    setCi(room, lord, { name })
  end)
  local request = FkTest.ReplyUseSkill(CONSUME, {}, {})
  request.interaction_data = name
  for _, reply in ipairs({ {}, { CHANGE } }) do
    skill_test.withSkillRequests(room, BANNER, {
      askToChoices = function(_, _, params)
        lu.assertFalse(table.contains(params.choices, CHANGE), "没有候选的变更应置灰")
        return reply
      end,
    }, function()
      inRoom(function() room:handleUseCardReply(lord, request) end)
    end)
    lu.assertEquals(lord:getTableMark(CI_MARK), { name })
    lu.assertFalse(Discard.contains(room, name))
    lu.assertTrue(Fk.skills[CONSUME]:canUse(lord), "取消和未成功变更均保留本阶段的机会")
    lu.assertEquals(lord:getMark("qiao_jin001_change_used"), 0)
  end
end

function Testqiao_em_jin001_simayan:testCiPreventsOwnSkippedDrawPhase()
  local room, lord = FkTest.room, p(1)
  local spent, kept = "qiao_heg__jin005", "qiao_heg__jin004"
  inRoom(function() setCi(room, lord, { kept, spent }) end)
  local phase = PhaseData:new { who = lord, phase = Player.Draw, reason = "game_rule", skipped = true }
  local hand, asks = #lord:getCardIds("h"), 0
  FkTest.setRoomBreakpoint(lord, "AskForChoices", function(data)
    if data[5] == BANNER then
      lu.assertEquals(data[1], { kept, spent })
      lu.assertEquals(data[3], { 1, 1 })
      lu.assertTrue(data[4])
      lu.assertStrContains(data[6], "phase_draw")
      lu.assertFalse(data[8], "此请求需显示阶段标题和取消按钮")
      asks = asks + 1
    end
    return false
  end)
  FkTest.setNextReplies(lord, { { spent } })
  inRoom(function() GameEvent.Phase:create(phase):exec() end)
  lu.assertEquals(asks, 1)
  lu.assertFalse(phase.skipped)
  lu.assertEquals(#lord:getCardIds("h"), hand + 2)
  lu.assertEquals(lord:getTableMark(CI_MARK), { kept })
  lu.assertFalse(Discard.contains(room, kept))
  assertDiscarded(room, spent)
end

function Testqiao_em_jin001_simayan:testPreventSkippingPlayLeavesActiveCiUseAvailable()
  local room, lord = FkTest.room, p(1)
  local prevent, resource = "qiao_heg__jin005", "qiao_heg__jin004"
  local phase = PhaseData:new { who = lord, phase = Player.Play, reason = "game_rule" }
  local active = FkTest.ReplyUseSkill(BANNER, {}, {})
  active.interaction_data = resource
  inRoom(function() setCi(room, lord, { prevent, resource }) end)
  skill_test.withSkillRequests(room, CAIXING, {
    askToSkillInvoke = function() return true end,
  }, function()
    FkTest.setNextReplies(lord, { { prevent }, active, { RESOURCE_MAXCARD } })
    inRoom(function() GameEvent.Phase:create(phase):exec() end)
  end)
  lu.assertFalse(phase.skipped, "可以防止採幸产生的出牌阶段跳过")
  lu.assertEquals(lord:getTableMark(CI_MARK), {}, "恢复的出牌阶段仍能另行消耗一枚赐")
  assertDiscarded(room, prevent)
  assertDiscarded(room, resource)
end

function Testqiao_em_jin001_simayan:testCiSkipDeclinedOrUnavailable()
  local room, lord, other = FkTest.room, p(1), p(2)
  local name, asks = "qiao_heg__jin005", 0
  local function skippedDraw(who)
    local phase = PhaseData:new { who = who, phase = Player.Draw, reason = "game_rule", skipped = true }
    local hand = #who:getCardIds("h")
    inRoom(function() GameEvent.Phase:create(phase):exec() end)
    lu.assertTrue(phase.skipped)
    lu.assertEquals(#who:getCardIds("h"), hand)
  end
  skill_test.withSkillRequests(room, BANNER, {
    askToChoices = function(_, who)
      lu.assertIs(who, lord)
      asks = asks + 1
      return {}
    end,
  }, function()
    skippedDraw(lord)
    lu.assertEquals(asks, 0, "没有赐时不询问")
    inRoom(function()
      setCi(room, lord, { name })
      setCi(room, other, { "qiao_heg__jin004" })
    end)
    skippedDraw(other)
    lu.assertEquals(asks, 0, "他人的阶段不询问持旗者")
    skippedDraw(lord)
  end)
  lu.assertEquals(asks, 1)
  lu.assertEquals(lord:getTableMark(CI_MARK), { name })
  lu.assertFalse(Discard.contains(room, name))
end

function Testqiao_em_jin001_simayan:testCaixingMultipleMountsOpensClientCardChooser()
  local room, lord, other = FkTest.room, p(1), p(2)
  local field, discarded, oldOffensive, oldDefensive
  inRoom(function()
    room.current = lord
    lord.hp = lord.maxHp - 1
    field = room:printCard("qiao__chitu", Card.Heart, 5)
    discarded = room:printCard("qiao__linxiao_yuyu", Card.Spade, 5)
    oldOffensive = room:printCard("qiao__chitu", Card.Club, 5)
    oldDefensive = room:printCard("qiao__jueying", Card.Club, 6)
    room:moveCardIntoEquip(lord, oldOffensive.id, CAIXING, false, lord)
    room:moveCardIntoEquip(lord, oldDefensive.id, CAIXING, false, lord)
    room:moveCardIntoEquip(other, field.id, CAIXING, false, lord)
    room:moveCardTo(discarded.id, Card.DiscardPile, nil, fk.ReasonJustMove, CAIXING)
  end)

  local handBefore = lord:getHandcardNum()
  local wire
  FkTest.setRoomBreakpoint(lord, "AskForCardChosen", function(data)
    wire = cbor.encode(data)
    return false
  end)
  FkTest.setNextReplies(lord, { discarded.id })
  local phase = { phase = Player.Play, skipped = false }
  skill_test.withSkillRequests(room, CAIXING, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == CAIXING then return true end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function() room.logic:trigger(fk.EventPhaseChanging, lord, phase) end)
  end)

  lu.assertNotNil(wire, "两张合法坐骑应发出真实选牌请求")
  FkTest.runInClient(function()
    local client = ClientInstance
    local data = cbor.decode(wire)
    lu.assertIs(data[1], client:getPlayerById(lord.id))
    local shown
    local notify = client.notifyUI
    client.notifyUI = function(_, name, payload)
      if name == "AskForCardChosen" then shown = payload end
    end
    local ok, err = pcall(client.askForCardChosen, client, data)
    client.notifyUI = notify
    lu.assertTrue(ok, tostring(err))
    lu.assertEquals(shown.card_data, { { "$Equip", { field.id } }, { "弃牌堆", { discarded.id } } })
  end)
  lu.assertTrue(phase.skipped)
  lu.assertEquals(room:getCardArea(discarded.id), Card.PlayerEquip)
  lu.assertIs(room:getCardOwner(discarded.id), lord)
  lu.assertIs(room:getCardOwner(field.id), other)
  lu.assertEquals(room:getCardArea(oldOffensive.id), Card.DiscardPile)
  lu.assertEquals(room:getCardArea(oldDefensive.id), Card.DiscardPile)
  lu.assertEquals(lord.hp, lord.maxHp, "採幸置入临筱玉舆并替换两张坐骑时只回复一次")
  lu.assertEquals(lord:getHandcardNum(), handBefore)

  inRoom(function() lord.hp = lord.maxHp - 1 end)
  local nextPhase = { phase = Player.Play, skipped = false }
  skill_test.withSkillRequests(room, CAIXING, {
    askToSkillInvoke = function() return true end,
  }, function()
    inRoom(function() room.logic:trigger(fk.EventPhaseChanging, lord, nextPhase) end)
  end)
  lu.assertTrue(nextPhase.skipped)
  lu.assertEquals(room:getCardArea(discarded.id), Card.DiscardPile)
  lu.assertIs(room:getCardOwner(field.id), lord)
  lu.assertEquals(room:getCardArea(field.id), Card.PlayerEquip)
  lu.assertEquals(lord.hp, lord.maxHp, "採幸以单栏坐骑替换临筱玉舆也回复")
  lu.assertEquals(lord:getHandcardNum(), handBefore)
  lu.assertEquals(Fk:translate("qiao__dual_mount_rule"), "坐骑替换")
end

function Testqiao_em_jin001_simayan:testResourceCiAndCaixingAndDingfei()
  local room, lord = FkTest.room, p(1)
  inRoom(function()
    -- 旧房间把将牌存在旗名下，下一次支付后应只剩新版标记。
    room:setPlayerMark(lord, BANNER, { "qiao_heg__jin004" })
    room:setPlayerMark(lord, CI_MARK, 2)
    lord.phase = Player.Play
  end)
  local fish = Fk.generals["qiao_heg__jin004"].maxHp
  local beforeHand
  skill_test.withSkillRequests(room, BANNER, {
    askToChoices = function(_, _, params)
      return { resourceChoice(params) }
    end,
  }, function()
    inRoom(function()
      beforeHand = #lord:getCardIds("h")
      Fk.skills[CONSUME]:onUse(room, { from = lord, interaction_data = "qiao_heg__jin004" })
    end)
  end)
  lu.assertEquals(lord:getMark(BANNER), 0)
  lu.assertEquals(Ci.cards(lord), {})
  if fish <= 3 then
    lu.assertTrue(lord:getMark(MarkEnum.AddMaxCardsInTurn) >= 3, "≤3 应本回合手牌上限+3")
  else
    lu.assertTrue(#lord:getCardIds("h") >= math.min(4, beforeHand + 4), "≥4 应补手至四张")
  end
  -- 採幸：跳过出牌阶段并置入弃牌堆临筱玉舆。
  local linxiao
  inRoom(function()
    linxiao = room:printCard("qiao__linxiao_yuyu", Card.Heart, 9)
    room:moveCardTo(linxiao, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, true, lord)
  end)
  local data = { phase = Player.Play, skipped = false }
  local oldInvoke = room.askToSkillInvoke
  room.askToSkillInvoke = function(self, who, params)
    if params.skill_name == CAIXING then return true end
    return oldInvoke(self, who, params)
  end
  inRoom(function() room.logic:trigger(fk.EventPhaseChanging, lord, data) end)
  room.askToSkillInvoke = oldInvoke
  lu.assertTrue(data.skipped, "採幸应跳过出牌阶段")
  lu.assertEquals(room:getCardArea(linxiao.id), Card.PlayerEquip, "临筱玉舆应置入空坐骑栏")
  -- 鼎沸：晋角色合计已损 > 体力。
  inRoom(function()
    lord.hp = 1
    p(2).hp = 1
    p(3).hp = 1
    lord.phase = Player.Finish
  end)
  local oldInvoke2 = room.askToSkillInvoke
  room.askToSkillInvoke = function(self, who, params)
    if params.skill_name == DINGFEI then return true end
    return oldInvoke2(self, who, params)
  end
  local handBefore
  inRoom(function()
    handBefore = #lord:getCardIds("h")
    room.logic:trigger(fk.EventPhaseStart, lord, PhaseData:new { who = lord, phase = Player.Finish })
  end)
  room.askToSkillInvoke = oldInvoke2
  lu.assertEquals(#lord:getCardIds("h") >= handBefore + 2, true, "鼎沸应摸两张")
  lu.assertFalse(lord:hasSkill(TAIKANG), "鼎沸应失去太康")
  lu.assertTrue(lord:hasSkill("qiao__skill_jin001_2"), "鼎沸应获得兴图")
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
  for index, player in ipairs(clients) do player.next = clients[index % #clients + 1] end
  local clientRoom = setmetatable({ players = clients, alive_players = clients, current = clients[1] },
    { __index = current })
  local originalRoom = Fk.currentRoom
  Fk.currentRoom = function() return clientRoom end
  local ok, err = pcall(function() fn(clients, clientRoom) end)
  Fk.currentRoom = originalRoom
  if not ok then error(err, 0) end
  return clients, clientRoom
end

local function useTransferredCiAfter(changeLord)
  local room, lord, recipient = FkTest.room, p(1), p(2)
  local otherCi, stored = "qiao_heg__jin005", "qiao_heg__jin004"
  inRoom(function()
    setCi(room, lord, { otherCi, stored })
    Guest.store(room, {
      [otherCi] = { name = otherCi, source = "original", kingdoms = { "jin" } },
      [stored] = { name = stored, source = "original", kingdoms = { "jin" } },
    })
  end)
  FkTest.setNextReplies(lord, { { "jin" } })
  inRoom(function()
    room:damage{ from = recipient, to = p(4), damage = 1 }
    changeLord(room, lord)
    room.current = recipient
    recipient.phase = Player.Play
  end)
  lu.assertFalse(recipient:hasSkill(BANNER))
  lu.assertEquals(lord:getTableMark(CI_MARK), {})
  lu.assertEquals(recipient:getMark(BANNER), 0, "受赠者的将牌独立保存在赐标记上")
  local beforeMax = recipient:getMark(MarkEnum.AddMaxCardsInTurn)
  local reply
  withClientRoom(room, function(clients)
    local me = clients[2]
    lu.assertNil(me.room)
    lu.assertFalse(Fk.skills[CONSUME].visible, "消费按钮应只放在赐列表内")
    local board = assert(Fk:getBoardGame("qiao_heg_mode"))
    local client = board.client_klass:new(ClientInstance.client)
    client.players = clients
    lu.assertEquals(client:ciCardsForDisplay(me.id), { otherCi, stored })
    lu.assertFalse(client:ciCardsForDisplay(clients[4].id))
    local play = client.request_handlers.PlayCard:new(me)
    client.current_request_handler = play
    lu.assertFalse(client:canConsumeCi(clients[1].id, stored))
    me.phase = Player.Finish
    lu.assertFalse(client:canConsumeCi(me.id, stored))
    me.phase = Player.Play
    lu.assertFalse(client:canConsumeCi(me.id))
    lu.assertFalse(client:canConsumeCi(me.id, "qiao_heg__wei001"))
    lu.assertTrue(client:canConsumeCi(me.id, stored))

    local originalNotify = ClientInstance.notifyUI
    ClientInstance.notifyUI = function(_, cmd, data)
      if cmd == "ReplyToServer" then reply = data end
    end
    local ok, err = pcall(function()
      lu.assertFalse(play:update("QiaoCi", me.id, "click", {}))
      lu.assertNil(reply)
      play:update("QiaoCi", me.id, "click", { general = stored })
    end)
    ClientInstance.notifyUI = originalNotify
    if not ok then error(err, 0) end
    lu.assertNotNil(reply, "点击列表按钮应产生标准技能回包")
    lu.assertEquals(reply.card.skill, CONSUME)
    lu.assertEquals(reply.card.subcards, {})
    lu.assertEquals(reply.targets, {})
    lu.assertEquals(reply.interaction_data, stored)
    lu.assertFalse(client:canConsumeCi(me.id, stored), "提交后不可重复点击")
    play:_finish()
  end)
  inRoom(function()
    local stale = table.simpleClone(reply)
    stale.interaction_data = "qiao_heg__wei001"
    room:handleUseCardReply(recipient, stale)
    lu.assertEquals(recipient:usedSkillTimes(CONSUME, Player.HistoryPhase), 0)
  end)
  local asks = 0
  skill_test.withSkillRequests(room, BANNER, {
    askToChoice = function() error("consume should not ask which Ci to choose") end,
    askToChoices = function(_, _, params)
      asks = asks + 1
      lu.assertTrue(params.single)
      lu.assertFalse(params.detailed == true)
      return { resourceChoice(params) }
    end,
  }, function()
    inRoom(function()
      room:handleUseCardReply(recipient, reply)
      local second = table.simpleClone(reply)
      second.interaction_data = otherCi
      room:handleUseCardReply(recipient, second)
    end)
  end)
  lu.assertEquals(asks, 1)
  lu.assertEquals(recipient:getMark(MarkEnum.AddMaxCardsInTurn), beforeMax + 3)
  lu.assertEquals(recipient:getTableMark(CI_MARK), { otherCi })
  lu.assertEquals(recipient:usedSkillTimes(CONSUME, Player.HistoryPhase), 1)
  assertDiscarded(room, stored)
  lu.assertFalse(Discard.contains(room, otherCi))
end

function Testqiao_em_jin001_simayan:testRecipientCanSpendAfterTaikangLost()
  useTransferredCiAfter(function(room, lord)
    room:handleAddLoseSkills(lord, "-" .. TAIKANG)
    lu.assertFalse(lord:hasSkill(TAIKANG, true))
    lu.assertFalse(lord:hasSkill(BANNER))
  end)
end

function Testqiao_em_jin001_simayan:testRecipientCanSpendWhileTaikangInvalid()
  useTransferredCiAfter(function(room, lord)
    room:invalidateSkill(lord, TAIKANG, "", "test")
    lu.assertTrue(lord:hasSkill(TAIKANG, true))
    lu.assertFalse(lord:hasSkill(TAIKANG))
  end)
end

function Testqiao_em_jin001_simayan:testRecipientCanSpendAfterLordBuried()
  useTransferredCiAfter(function(room, lord)
    room:killPlayer { who = lord }
    lu.assertTrue(lord.dead)
    lu.assertEquals(lord:getMark(CI_MARK), 0)
  end)
end

function Testqiao_em_jin001_simayan:testTransferredCiChangesDeputyAfterLordDeathTurnsRecipientWild()
  local room, lord, recipient = FkTest.room, p(1), p(2)
  local gift, oldDeputy = "qiao_heg__jin005", "qiao_heg__jin006"
  local jin, wei = "qiao_heg__jin004", "qiao_heg__wei005"
  inRoom(function()
    skill_test.installDualGenerals(room, recipient, {
      main = "qiao_test__jin_1", deputy = oldDeputy, kingdom = "jin",
    })
    -- 即使开局身份与当前晋势力不同，转野时脱离的仍是晋。
    room:setPlayerMark(recipient, "__heg_init_kingdom", "wei")
    setCi(room, lord, {gift})
    room.general_pile = {jin, wei}
    FkTest.setNextReplies(lord, {{"jin"}})
    room:damage {from = recipient, to = p(4), damage = 1}
    lu.assertEquals(recipient:getTableMark(CI_MARK), {gift})
    room:killPlayer {who = lord}
    lu.assertTrue(lord.dead)
    lu.assertEquals(recipient.kingdom, "wild")
    lu.assertEquals(recipient:getMark("__heg_kingdom"), "wild")
    lu.assertEquals(Fk.generals[oldDeputy].maxHp, Fk.generals[gift].maxHp)
    room.current, recipient.phase = recipient, Player.Play
    skill_test.withSkillRequests(room, BANNER, {
      askToChoices = function(_, _, params)
        lu.assertTrue(table.contains(params.choices, CHANGE), "转野后仍可用赐换将")
        return {CHANGE}
      end,
      askToChoice = function(_, _, params)
        lu.assertTrue(table.contains(params.choices, "deputy"))
        return "deputy"
      end,
    }, function()
      local reply = FkTest.ReplyUseSkill(CONSUME, {}, {})
      reply.interaction_data = gift
      room:handleUseCardReply(recipient, reply)
    end)
    lu.assertEquals(recipient.deputyGeneral, jin)
    lu.assertEquals(recipient.kingdom, "wild")
    lu.assertTrue(table.contains(room.general_pile, wei))
    lu.assertFalse(table.contains(room.general_pile, jin))
    lu.assertEquals(recipient:getTableMark(CI_MARK), {})
    lu.assertEquals(recipient:getMark("qiao_jin001_change_used"), 1)
    assertDiscarded(room, gift)
    assertDiscarded(room, oldDeputy)
  end)
end

return { name = "qiao_em_jin001_simayan" }
