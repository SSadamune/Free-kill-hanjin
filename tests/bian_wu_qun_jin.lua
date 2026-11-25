-- 六势力变包（吴/群/晋 6 将 + 飞熊军翼从多实例）定向回归测试。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local client_room = __dofile("../../../tests/support/client_room.lua")
local A = require "packages.qiao.pkg.qiao_mode.rules.adaptation"
local Visibility = require "packages.qiao.pkg.qiao_mode.rules.card_visibility"
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
local Discard = require "packages.qiao.pkg.qiao_mode.rules.general_discard"
local Change = require "packages.qiao.pkg.qiao_mode.rules.general_change"
local Guest = require "packages.qiao.pkg.qiao_mode.rules.guest_factions"
local Retinues = require "packages.qiao.pkg.qiao_generals.util.retinue_instances"
local Bian = require "packages.qiao.pkg.qiao_generals.util.bian_common"

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function p(i) return FkTest.room.players[i] end

local function resetGeneralPool(room, pile, kingdoms)
  room.disabled_generals = {}
  Discard.reset(room)
  room:setTag(Guest.key, nil)
  room:setBanner("all_kingdoms", kingdoms or { "han", "wei", "shu", "wu", "qun", "jin" })
  room.general_pile = table.simpleClone(pile)
end

Testqiao_bian_wu_qun_jin = {
  setup = function()
    Fk.currentResponsePattern = nil
    support.initQiaoRoom()
  end,
  tearDown = function()
    Fk.currentResponsePattern = nil
    support.clearRoom()
  end,
}

-- WU021 凌统：旋略（一次失多装备仅触发 1 次）+ 勇进（至多 3 张各不同装备 + 双坐骑空栏校验 + 联动旋略）
function Testqiao_bian_wu_qun_jin:testWu021XuanlueAndYongjinThreeDistinctAndDualMount()
  local room = FkTest.room
  local lingtong, ally, foe = p(1), p(2), p(3)
  local w1, a1, dual, foeHorse, foeHand1, foeHand2
  inRoom(function()
    skill_test.installBlankGenerals(room, { "wu", "wu", "wei", "shu" })
    skill_test.installDualGenerals(room, lingtong, {
      main = "qiao_heg__wu021", deputy = "qiao_test__wu_2", kingdom = "wu", hp = 4,
    })
    for _, who in ipairs(room.players) do who:throwAllCards("he") end
    w1 = room:printCard("qiao__qinggang_sword", Card.Spade, 6)
    a1 = room:printCard("qiao__eight_diagram", Card.Spade, 2)
    dual = room:printCard("qiao__liulongcanjia", Card.Heart, 13)
    foeHorse = room:printCard("qiao__chitu", Card.Heart, 5)
    foeHand1 = room:printCard("qiao__jink", Card.Diamond, 2)
    foeHand2 = room:printCard("qiao__jink", Card.Diamond, 3)
    room:moveCardTo({ w1, a1 }, Player.Equip, lingtong, fk.ReasonJustMove, "test", nil, true, lingtong)
    room:moveCardTo(foeHorse, Player.Equip, foe, fk.ReasonJustMove, "test", nil, true, foe)
    room:obtainCard(foe, { foeHand1, foeHand2 }, false, fk.ReasonJustMove)
  end)

  -- 一次同时弃置凌统 2 张装备，旋略只触发 1 次。
  local xuanlueCount = 0
  skill_test.withSkillRequests(room, "qiao__skill_wu021_1", {
    askToChoosePlayers = function() xuanlueCount = xuanlueCount + 1; return { foe } end,
    askToChooseCard = function() return foeHand1.id end,
  }, function()
    inRoom(function()
      room:throwCard({ w1.id, a1.id }, "test", lingtong, foe)
    end)
  end)
  lu.assertEquals(xuanlueCount, 1, "单次移动同时失去多张装备牌时旋略只触发一次")
  lu.assertEquals(#foe:getCardIds("h"), 1)

  -- 勇进：给凌统装双坐骑 dual 与武器 w1；foe 有进攻坐骑（双坐骑不能移给 foe），ally 空栏可接收。
  inRoom(function()
    room:moveCardTo({ w1, dual }, Player.Equip, lingtong, fk.ReasonJustMove, "test", nil, true, lingtong)
    lingtong.phase = Player.Play
  end)

  -- 校验双坐骑空栏 helper：foe 已有单坐骑不可接收 dual，ally 双空栏可接收。
  lu.assertFalse(Bian.canMoveEquipTo(lingtong, foe, dual.id), "已有单坐骑的角色不能接收双副类别坐骑")
  lu.assertTrue(Bian.canMoveEquipTo(lingtong, ally, dual.id), "双坐骑栏均空时可接收双副类别坐骑")

  local stepFrom, stepCard, stepTo = 0, 0, 0
  xuanlueCount = 0
  skill_test.withSkillRequests(room, "qiao__skill_wu021_1", {
    askToChoosePlayers = function() xuanlueCount = xuanlueCount + 1; return {} end,
  }, function()
    skill_test.withSkillRequests(room, "qiao__skill_wu021_2", {
      askToChoosePlayers = function(self, who, params)
        if params.prompt:find("-from", 1, true) then
          stepFrom = stepFrom + 1
          if stepFrom == 1 then return { lingtong } end
          if stepFrom == 2 then
            -- 第二次移牌时，已移到 ally 的 w1 不能再成为可移动源！
            lu.assertFalse(table.contains(params.targets, ally), "已移动过的同一张装备牌不能再移")
            return { lingtong }
          end
          return {}
        else
          stepTo = stepTo + 1
          if stepTo == 1 then return { ally } end
          if stepTo == 2 then
            lu.assertFalse(table.contains(params.targets, foe), "双坐骑候选接收者应排除已有单坐骑的 foe")
            return { ally }
          end
          return {}
        end
      end,
      askToChooseCards = function(self, who, params)
        stepCard = stepCard + 1
        return { w1.id }
      end,
    }, function()
      inRoom(function()
        Fk.skills["qiao__skill_wu021_2"]:onUse(room, { from = lingtong, tos = {}, cards = {} })
      end)
    end)
  end)
  lu.assertTrue(table.contains(ally:getCardIds("e"), w1.id), "第1张武器应移至 ally")
  lu.assertTrue(table.contains(ally:getCardIds("e"), dual.id), "第2张双坐骑应移至 ally")
  lu.assertEquals(xuanlueCount, 2, "依次移动凌统自己的两件装备应分别即时触发旋略")
end

-- WU022 吕范：调度（准备收回/移动 + 同势力每回合首次入装备摸牌）+ 典财（不计判定区 + 摸0张仍可变副将）
function Testqiao_bian_wu_qun_jin:testWu022DiaoduAndDiancaiZeroDrawStillChanges()
  local room = FkTest.room
  local lvfan, ally, foe = p(1), p(2), p(3)
  local eq1, eq2, eq3, judgeCard
  inRoom(function()
    skill_test.installBlankGenerals(room, { "wu", "wu", "wei", "shu" })
    skill_test.installDualGenerals(room, lvfan, {
      main = "qiao_heg__wu022", deputy = "qiao_test__wu_2", kingdom = "wu", hp = 1,
    })
    lvfan.maxHp = 3
    for _, who in ipairs(room.players) do who:throwAllCards("he") end
    eq1 = room:printCard("qiao__chitu", Card.Heart, 5)
    eq2 = room:printCard("qiao__eight_diagram", Card.Spade, 2)
    eq3 = room:printCard("qiao__qinggang_sword", Card.Spade, 6)
    judgeCard = room:printCard("qiao__indulgence", Card.Heart, 7)
    room:moveCardTo(eq1, Player.Equip, lvfan, fk.ReasonJustMove, "test", nil, true, lvfan)
    resetGeneralPool(room, { "qiao_heg__wu001", "qiao_heg__wu002", "qiao_heg__wu003" }, { "wu", "wei", "shu", "han" })
  end)

  -- 调度效果一：准备阶段选择把自己的 eq1 移动到 ally 装备区；同时触发调度效果二令 ally 首次入装备摸 1 张。
  local allyHandBefore = #ally:getCardIds("h")
  skill_test.withSkillRequests(room, "qiao__skill_wu022_1", {
    askToChoosePlayers = function(self, who, params)
      if params.prompt == "#qiao__skill_wu022_1-choose" then return { lvfan } end
      return { ally }
    end,
    askToChooseCard = function() return eq1.id end,
    askToChoice = function() return "#qiao__skill_wu022_1-move" end,
  }, function()
    inRoom(function()
      local turn = GameEvent.Turn:create(TurnData:new(lvfan, "game_rule", {}))
      function turn:main()
        lvfan.phase = Player.Start
        room.logic:trigger(fk.EventPhaseStart, lvfan, PhaseData:new { who = lvfan, phase = Player.Start })
        -- 同回合 ally 第二次置入装备 eq2 不应再摸牌
        room:moveCardTo(eq2, Player.Equip, ally, fk.ReasonJustMove, "test", nil, true, ally)
      end
      turn:exec()
    end)
  end)
  lu.assertTrue(table.contains(ally:getCardIds("e"), eq1.id))
  lu.assertEquals(#ally:getCardIds("h"), allyHandBefore + 1, "同势力角色每回合仅首次置入装备区摸 1 张")

  -- 典财：1 体力仅拆判定区牌不触发；再拆 1 张手牌（即使此时手牌数已 >= maxHp 摸 0 张）仍允许发动并变更副将！
  local diancaiAsked = 0
  inRoom(function()
    room:moveCardTo(judgeCard, Player.Judge, lvfan, fk.ReasonJustMove, "test", nil, true, lvfan)
  end)
  skill_test.withSkillRequests(room, "qiao__skill_wu022_2", {
    askToSkillInvoke = function() diancaiAsked = diancaiAsked + 1; return true end,
  }, function()
    inRoom(function()
      local phase = GameEvent.Phase:create(PhaseData:new { who = foe, phase = Player.Play })
      function phase:main()
        foe.phase = Player.Play
        room:throwCard({ judgeCard.id }, "test", lvfan, foe)
      end
      phase:exec()
    end)
  end)
  lu.assertEquals(diancaiAsked, 0, "仅失去判定区牌不计入典财失牌数")

  inRoom(function()
    for i = 1, 4 do
      room:obtainCard(lvfan, room:printCard("qiao__jink", Card.Diamond, i), false, fk.ReasonJustMove)
    end
    room:obtainCard(lvfan, eq3, false, fk.ReasonJustMove)
  end)
  skill_test.withSkillRequests(room, "qiao__skill_wu022_2", {
    askToSkillInvoke = function() diancaiAsked = diancaiAsked + 1; return true end,
    askToChoice = function() return "changeDeputy" end,
    askToCustomDialog = function(self, who, params)
      return { general = params.component.prop.candidates[1] }
    end,
  }, function()
    inRoom(function()
      local phase = GameEvent.Phase:create(PhaseData:new { who = foe, phase = Player.Play })
      function phase:main()
        foe.phase = Player.Play
        -- 手牌移入装备区不算失去，另丢弃 1 张手牌算 1 张（满足 hp=1），且剩余手牌 3 >= maxHp 3。
        room:moveCardTo(eq3, Player.Equip, lvfan, fk.ReasonJustMove, "test", nil, true, lvfan)
        room:throwCard({ lvfan:getCardIds("h")[1] }, "test", lvfan, foe)
      end
      phase:exec()
    end)
  end)
  lu.assertEquals(diancaiAsked, 1, "手牌数已 >= 体力上限时仍允许发动典财")
  lu.assertNotEquals(lvfan.deputyGeneral, "qiao_test__wu_2", "典财摸 0 张后仍可执行变更副将")
end

-- JIN018 陈骞：忽辱（全权挑牌同花色且同类别双生效 + 自伤不重问）+ 武督（可选自己 + 叠置跳过回合顺延清除）
function Testqiao_bian_wu_qun_jin:testJin018HuruSelfDamageAndWuduTurnEndSkip()
  local room = FkTest.room
  local chenqian, foe = p(1), p(2)
  local c1, c2, f1, eq1
  inRoom(function()
    skill_test.installBlankGenerals(room, { "jin", "wei", "wu", "shu" })
    skill_test.installDualGenerals(room, chenqian, {
      main = "qiao_heg__jin018", deputy = "qiao_test__jin_2", kingdom = "jin", hp = 3,
    })
    chenqian:throwAllCards("he")
    foe:throwAllCards("he")
    c1 = room:printCard("qiao__slash", Card.Heart, 4)
    c2 = room:printCard("qiao__jink", Card.Spade, 5)
    f1 = room:printCard("qiao__peach", Card.Heart, 9) -- 同红桃 + 同基本牌
    eq1 = room:printCard("qiao__chitu", Card.Heart, 5)
    room:obtainCard(chenqian, { c1 }, false, fk.ReasonJustMove)
    room:moveCardTo(eq1, Player.Equip, chenqian, fk.ReasonJustMove, "test", nil, true, chenqian)
    room:obtainCard(foe, { f1 }, false, fk.ReasonJustMove)
    chenqian.phase = Player.Play
  end)

  -- 武督：陈骞仅 1 手牌 + 1 装备时，弃唯一手牌不能选自己，弃装备可以选自己！
  client_room.run(room, function(clients)
    local sk = Fk.skills["qiao__skill_jin018_2"]
    lu.assertFalse(sk:feasible(clients[1], { clients[1] }, { c1.id }), "弃唯一手牌时不能选自己")
    lu.assertTrue(sk:feasible(clients[1], { clients[1] }, { eq1.id }), "弃装备保留手牌时可选自己")
  end)

  -- 对 foe 发动武督，foe 选选项 1 公开手牌；叠置跳过回合不清除，真正 TurnEnd 才清除。
  skill_test.withSkillRequests(room, "qiao__skill_jin018_2", {
    askToChoice = function() return "#qiao__skill_jin018_2-open" end,
  }, function()
    inRoom(function()
      Fk.skills["qiao__skill_jin018_2"]:onUse(room, {
        from = chenqian, tos = { foe }, cards = { eq1.id },
      })
    end)
  end)
  lu.assertEquals(foe:getMark(Visibility.WUDU_OPEN), 1, "武督选项 1 应立明牌标记")
  lu.assertTrue(chenqian:cardVisible(f1.id), "明牌期间其他角色应可见目标手牌")

  -- 忽辱：同时展示红桃基本牌 c1 与红桃基本牌 f1 -> 同时获得 f1 且此 2 点伤害 -1 为 1。
  local foeHpBefore = foe.hp
  skill_test.withSkillRequests(room, "qiao__skill_jin018_1", {
    askToSkillInvoke = function() return true end,
    askToCards = function() return { c1.id } end,
    askToChooseCard = function() return f1.id end,
  }, function()
    inRoom(function()
      room:damage { from = chenqian, to = foe, damage = 2, skillName = "test" }
    end)
  end)
  lu.assertTrue(table.contains(chenqian:getCardIds("h"), f1.id), "花色相同应获得对方展示的手牌")
  lu.assertEquals(foe.hp, foeHpBefore - 1, "类别相同应令 2 点伤害减为 1 点")

  -- 模拟 foe 回合被叠置跳过（不触发 TurnEnd）：明牌标记顺延保留；下一个真正 TurnEnd 清除。
  inRoom(function()
    room.logic:trigger(fk.TurnEnd, chenqian, TurnData:new(chenqian, "game_rule", {}))
  end)
  lu.assertEquals(foe:getMark(Visibility.WUDU_OPEN), 1, "他人回合结束不清除 foe 的明牌")
  inRoom(function()
    room.logic:trigger(fk.TurnEnd, foe, TurnData:new(foe, "game_rule", {}))
  end)
  lu.assertEquals(foe:getMark(Visibility.WUDU_OPEN), 0, "目标真正回合结束时应清除明牌")

  -- 忽辱自伤验证：开启新回合刷新每回合限一次，陈骞持有 2 张基本牌对自己造成 1 点伤害，仅询问 1 次并防止此伤害。
  local selfAskCount = 0
  local selfHpBefore = chenqian.hp
  inRoom(function()
    chenqian:throwAllCards("he")
    local sA = room:printCard("qiao__slash", Card.Spade, 2)
    local sB = room:printCard("qiao__jink", Card.Club, 3)
    room:obtainCard(chenqian, { sA, sB }, false, fk.ReasonJustMove)
    local turn = GameEvent.Turn:create(TurnData:new(chenqian, "game_rule", {}))
    function turn:main()
      skill_test.withSkillRequests(room, "qiao__skill_jin018_1", {
        askToSkillInvoke = function() selfAskCount = selfAskCount + 1; return true end,
        askToCards = function() return { sA.id, sB.id } end,
      }, function()
        room:damage { from = chenqian, to = chenqian, damage = 1, skillName = "test" }
      end)
    end
    turn:exec()
  end)
  lu.assertEquals(selfAskCount, 1, "自伤时忽辱仅应询问一次")
  lu.assertEquals(chenqian.hp, selfHpBefore, "自伤展示两张同类别基本牌应将 1 点伤害减为 0")
end

-- JIN020 荀勖：拨律（覆写多条目应变条件 + 重复覆盖 + 跨回合消耗）+ 应政（同势力自选交牌 + 触发应变由荀勖令变副将）
function Testqiao_bian_wu_qun_jin:testJin020YingzhengAndBoluOverrideAllEntries()
  local room = FkTest.room
  local xunxu, ally, foe = p(1), p(2), p(3)
  local heartCard, spadeCard, adaptSlash
  inRoom(function()
    skill_test.installBlankGenerals(room, { "jin", "jin", "wei", "wu" })
    skill_test.installDualGenerals(room, xunxu, {
      main = "qiao_heg__jin020", deputy = "qiao_test__jin_2", kingdom = "jin", hp = 3,
    })
    ally.hp = 1 -- 满足残躯（恰好 1 体力）
    xunxu:throwAllCards("he")
    ally:throwAllCards("he")
    foe:throwAllCards("he")
    spadeCard = room:printCard("qiao__jink", Card.Spade, 2)
    heartCard = room:printCard("qiao__jink", Card.Heart, 3)
    adaptSlash = room:printCard("qiao__slash", Card.Club, 7)
    -- 给杀挂两条原条件均不满足的应变条目（原条件：空巢+孤军），验证拨律红桃（残躯）一次性全部改写！
    A.setCardEntries(adaptSlash, {
      { condition = "kongchao", effect = "draw" },
      { condition = "gujun", effect = "damage" },
    })
    room:obtainCard(xunxu, { spadeCard, heartCard }, false, fk.ReasonJustMove)
    room:obtainCard(ally, { adaptSlash, room:printCard("qiao__jink", Card.Diamond, 9) }, false, fk.ReasonJustMove)
    resetGeneralPool(room, { "qiao_heg__jin001", "qiao_heg__jin002", "qiao_heg__jin003" }, { "jin", "wei", "wu", "han" })
    xunxu.phase = Player.Play
  end)

  -- 先重铸黑桃（富甲），再重铸红桃（残躯）验证新条件覆盖旧条件。
  inRoom(function()
    Fk.skills["qiao__skill_jin020_2"]:onUse(room, { from = xunxu, tos = { ally }, cards = { spadeCard.id } })
  end)
  lu.assertEquals(A.boluCondition(ally), "fujia")
  inRoom(function()
    Fk.skills["qiao__skill_jin020_2"]:onUse(room, { from = xunxu, tos = { ally }, cards = { heartCard.id } })
  end)
  lu.assertEquals(A.boluCondition(ally), "canqu", "未消耗前重复施加拨律应覆盖旧条件")

  -- 跨回合到 ally 回合内使用双条目应变杀：两条均改为残躯并全部触发（摸 1 + 伤害+1），拨律被消耗，
  -- 且应政由 ally 决定令荀勖获得此杀，再由荀勖决定令 ally 变更副将！
  local foeHpBefore = foe.hp
  local allyHandBefore = #ally:getCardIds("h")
  local invokedBy = {}
  skill_test.withSkillRequests(room, "qiao__skill_jin020_1", {
    askToSkillInvoke = function(self, who, params)
      table.insert(invokedBy, who.id)
      return true
    end,
    askToCustomDialog = function(self, who, params)
      return { general = params.component.prop.candidates[1] }
    end,
  }, function()
    inRoom(function()
      room:setCurrent(ally)
      room:useCard { from = ally, tos = { foe }, card = adaptSlash }
    end)
  end)
  lu.assertNil(A.boluCondition(ally), "使用下一张应变牌后应消耗拨律标记")
  lu.assertEquals(foe.hp, foeHpBefore - 2, "两条被拨律统一改为残躯的应变条目均应触发（含伤害+1）")
  lu.assertEquals(#ally:getCardIds("h"), allyHandBefore, "用掉 1 张杀并因第 1 条残躯摸 1 张")
  lu.assertEquals(invokedBy, { ally.id, xunxu.id }, "应政先由同势力使用者决定给牌，再由荀勖决定是否令其变更副将")
  lu.assertTrue(table.contains(xunxu:getCardIds("h"), adaptSlash.id), "荀勖应获得该应变牌")
  lu.assertNotEquals(ally.deputyGeneral, "qiao_test__jin_2", "触发应变后应政应令同势力角色成功变更副将")
end

-- 审阅回归（第 9 项）：凌统勇进排除已明置【聚宝】保护的宝物牌，避免无合法装备仍可发动消耗限定技。
function Testqiao_bian_wu_qun_jin:testWu021YongjinSkipsRevealedJubaoTreasure()
  local room = FkTest.room
  local lingtong, lordSun = p(1), p(2)
  local canServer, canClient
  inRoom(function()
    skill_test.installBlankGenerals(room, { "wu", "wu", "han", "wei" })
    skill_test.installDualGenerals(room, lingtong, {
      main = "qiao_heg__wu021", deputy = "qiao_test__wu_2", kingdom = "wu", hp = 4,
    })
    skill_test.installDualGenerals(room, lordSun, {
      main = "qiao_heg__em_wu001", deputy = "qiao_test__wu_2", kingdom = "wu", hp = 4,
    })
    for _, who in ipairs(room.players) do who:throwAllCards("e") end
    local pearl = room:printCard("qiao__luminous_pearl", Card.Heart, 6)
    room:moveCardTo(pearl, Player.Equip, lordSun, fk.ReasonPut, "test", nil, true, lordSun)
    lingtong.phase = Player.Play
    canServer = Fk.skills["qiao__skill_wu021_2"]:canUse(lingtong)
  end)
  client_room.run(room, function(clients)
    canClient = Fk.skills["qiao__skill_wu021_2"]:canUse(clients[1])
  end)
  lu.assertFalse(canServer, "场上仅有明置聚宝保护的宝物时勇进不可发动（服务端）")
  lu.assertFalse(canClient, "场上仅有明置聚宝保护的宝物时勇进不可发动（客户端）")
end

-- 审阅回归（第 12 项）：陈骞忽辱双方各亮一张手牌时合并为单次 fk.CardShown({2}) 且各自牌主准确。
function Testqiao_bian_wu_qun_jin:testJin018HuruSimultaneousSingleCardShown()
  local room = FkTest.room
  local chenqian, foe = p(1), p(2)
  local showCounts = {}
  local cOwn, cFoe
  inRoom(function()
    skill_test.installBlankGenerals(room, { "jin", "wu", "shu", "han" })
    skill_test.installDualGenerals(room, chenqian, {
      main = "qiao_heg__jin018", deputy = "qiao_test__jin_2", kingdom = "jin", hp = 3,
    })
    cOwn = room:printCard("qiao__jink", Card.Heart, 8)
    cFoe = room:printCard("qiao__jink", Card.Heart, 9)
    room:obtainCard(chenqian, cOwn, false, fk.ReasonJustMove)
    room:obtainCard(foe, cFoe, false, fk.ReasonJustMove)
    local oldTrigger = room.logic.trigger
    room.logic.trigger = function(this, ev, target, data, ...)
      if ev == fk.CardShown then
        table.insert(showCounts, #(data.cardIds or {}))
      end
      return oldTrigger(this, ev, target, data, ...)
    end
    skill_test.withSkillRequests(room, "qiao__skill_jin018_1", {
      askToSkillInvoke = function() return true end,
      askToCards = function() return { cOwn.id } end,
      askToChooseCard = function() return cFoe.id end,
    }, function()
      room:damage { from = chenqian, to = foe, damage = 1, skillName = "test" }
    end)
    room.logic.trigger = oldTrigger
  end)
  lu.assertEquals(showCounts, { 2 }, "忽辱同时展示双方各一张手牌应合并为单次 CardShown 事件")
end

-- 复审回归（第 6 项）：吕范调度排除仅有受【聚宝】保护宝物的君孙权，且混有其他装备时仅保留合法装备。
function Testqiao_bian_wu_qun_jin:testWu022DiaoduSkipsProtectedTreasureKeepsOtherEquip()
  local room = FkTest.room
  local lvfan, lordSun = p(1), p(2)
  local offeredOnlyTreasure, offeredWithWeapon, offeredFlag = false, false, nil
  local pearl, sword
  inRoom(function()
    skill_test.installBlankGenerals(room, { "wu", "wu", "shu", "wei" })
    skill_test.installDualGenerals(room, lvfan, {
      main = "qiao_heg__wu022", deputy = "qiao_test__wu_2", kingdom = "wu", hp = 4,
    })
    skill_test.installDualGenerals(room, lordSun, {
      main = "qiao_heg__em_wu001", deputy = "qiao_test__wu_2", kingdom = "wu", hp = 4,
    })
    for _, who in ipairs(room.players) do who:throwAllCards("e") end
    pearl = room:printCard("qiao__luminous_pearl", Card.Heart, 5)
    sword = room:printCard("qiao__qinggang_sword", Card.Spade, 6)
    room:moveCardTo(pearl, Player.Equip, lordSun, fk.ReasonPut, "test", nil, true, lordSun)
    lvfan.phase = Player.Start

    -- 仅有受保护宝物时，不询问选择君孙权
    skill_test.withSkillRequests(room, "qiao__skill_wu022_1", {
      askToChoosePlayers = function(_, _, params)
        offeredOnlyTreasure = table.contains(params.targets, lordSun)
        return {}
      end,
    }, function()
      room.logic:trigger(fk.EventPhaseStart, lvfan, PhaseData:new { who = lvfan, phase = Player.Start })
    end)

    -- 君孙权同时装有宝物和青釭剑时，允许选君孙权且装备候选仅保留青釭剑
    room:moveCardTo(sword, Player.Equip, lordSun, fk.ReasonPut, "test", nil, true, lordSun)
    skill_test.withSkillRequests(room, "qiao__skill_wu022_1", {
      askToChoosePlayers = function(_, _, params)
        offeredWithWeapon = table.contains(params.targets, lordSun)
        return { lordSun }
      end,
      askToChooseCard = function(_, _, params)
        offeredFlag = params.flag
        return sword.id
      end,
      askToChoice = function() return "#qiao__skill_wu022_1-obtain" end,
    }, function()
      room.logic:trigger(fk.EventPhaseStart, lvfan, PhaseData:new { who = lvfan, phase = Player.Start })
    end)
  end)
  lu.assertFalse(offeredOnlyTreasure, "君孙权仅有受聚宝保护的宝物时，调度不得提供其为目标")
  lu.assertTrue(offeredWithWeapon, "君孙权同时有其他合法装备时，调度应允许选择君孙权")
  lu.assertEquals(type(offeredFlag), "table", "混有受保护宝物时应使用过滤后的装备候选表")
  lu.assertEquals(offeredFlag.card_data[1][2], { sword.id }, "过滤候选应排除宝物、保留普通武器")
  lu.assertTrue(table.contains(lvfan:getCardIds("h"), sword.id), "应成功获得合法武器青釭剑")
end

return { name = "qiao_bian_wu_qun_jin" }
