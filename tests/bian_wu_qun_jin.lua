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

-- QUN009 左慈：化形（首次 3 魂、后续 1 魂、移去/额外变副将、旧副将入弃牌堆、私密标记不泄露、交换随牌）
function Testqiao_bian_wu_qun_jin:testQun009ZuociHuaxingFirstThreeSoulsPrivateAndExchange()
  local room = FkTest.room
  local zuoci, ally, foe = p(1), p(2), p(3)
  inRoom(function()
    skill_test.installBlankGenerals(room, { "qun", "qun", "wei", "shu" })
    skill_test.installDualGenerals(room, zuoci, {
      main = "qiao_heg__qun009", deputy = "qiao_test__qun_2", kingdom = "qun", hp = 3,
    })
    resetGeneralPool(room, {
      "qiao_heg__wei001", "qiao_heg__shu001", "qiao_heg__wu001",
      "qiao_heg__han001", "qiao_heg__jin001", "qiao_heg__qun001",
    }, { "qun", "wei", "shu", "wu", "han", "jin" })
    zuoci.phase = Player.Play
  end)

  -- 首次发动（出牌阶段主动入口）：扣置 3 张「魂」，选选项 2 将副将额外变更为其中 1 张异势力「魂」。
  local pickedSoul
  skill_test.withSkillRequests(room, Bian.ZUOCI_SKILL, {
    askToChoice = function() return "#qiao__skill_qun009_1-opt-change" end,
    askToCustomDialog = function(self, who, params)
      lu.assertEquals(#params.component.prop.candidates, 3, "首次化形应扣置 3 张魂")
      pickedSoul = params.component.prop.candidates[1]
      return { general = pickedSoul }
    end,
  }, function()
    inRoom(function()
      Fk.skills[Bian.ZUOCI_SKILL]:onUse(room, { from = zuoci, tos = {}, cards = {} })
    end)
  end)
  lu.assertEquals(zuoci.deputyGeneral, pickedSoul, "选项 2 应无视势力额外变更副将为所选魂")
  lu.assertEquals(zuoci.kingdom, "qun", "化形额外变更副将不得改变左慈势力")
  lu.assertEquals(#Bian.zuociSouls(room, zuoci), 2, "3 魂消耗 1 张后应剩 2 张魂")
  lu.assertEquals(zuoci:getMark(Bian.ZUOCI_COUNT_MARK), 2, "公开标记仅同步魂数量")
  lu.assertEquals(zuoci:getMark(Bian.ZUOCI_PRIVATE_MARK), 0, "私密列表不写入公开 player.mark 防泄露")
  lu.assertTrue(table.contains(Discard.list(room), "qiao_test__qun_2"), "旧副将应进入武将弃牌堆而非扣回魂")

  -- 第二次发动（受到 1 点伤害后）：改为扣置 1 张「魂」，选选项 1 移去 1 张「魂」入武将弃牌堆。
  local removedSoul
  skill_test.withSkillRequests(room, Bian.ZUOCI_SKILL, {
    askToSkillInvoke = function() return true end,
    askToChoice = function() return "#qiao__skill_qun009_1-opt-remove" end,
    askToCustomDialog = function(self, who, params)
      lu.assertEquals(#params.component.prop.candidates, 3, "原剩 2 魂 + 后续加 1 魂 = 3 魂")
      removedSoul = params.component.prop.candidates[1]
      return { general = removedSoul }
    end,
  }, function()
    inRoom(function()
      room:damage { from = foe, to = zuoci, damage = 1, skillName = "test" }
    end)
  end)
  lu.assertEquals(#Bian.zuociSouls(room, zuoci), 2)
  lu.assertTrue(table.contains(Discard.list(room), removedSoul), "移去的魂应进入武将弃牌堆")

  -- 交换左慈主将到同势力队友 ally：「魂」应随左慈武将牌迁移！
  inRoom(function()
    local ctx = Exchange.exchange(room,
      { player = zuoci, isDeputy = false },
      { player = ally, isDeputy = false })
    lu.assertTrue(ctx ~= false)
  end)
  lu.assertEquals(zuoci:getMark(Bian.ZUOCI_COUNT_MARK), 0, "原持有者数量标记应清空")
  lu.assertEquals(ally:getMark(Bian.ZUOCI_COUNT_MARK), 2, "新持有者应继承全部 2 张魂")
  lu.assertEquals(#Bian.zuociSouls(room, ally), 2)

  -- 副将为士兵牌（含白板士兵或翼从）时，化形不得提供选项 2（直接走选项 1 移去魂）。
  local choiceAsked = 0
  local soldierDeputy
  inRoom(function()
    room:changeHero(ally, "blank_shibing", false, true, false, false, false)
    room:setPlayerMark(ally, "__heg_deputy", ally.deputyGeneral)
    soldierDeputy = ally.deputyGeneral
  end)
  lu.assertTrue(Exchange.isSoldier(soldierDeputy), "测试前置应使副将为士兵牌")
  skill_test.withSkillRequests(room, Bian.ZUOCI_SKILL, {
    askToSkillInvoke = function() return true end,
    askToChoice = function() choiceAsked = choiceAsked + 1; return "#qiao__skill_qun009_1-opt-change" end,
    askToCustomDialog = function(self, who, params)
      return { general = params.component.prop.candidates[1] }
    end,
  }, function()
    inRoom(function()
      room:damage { from = foe, to = ally, damage = 1, skillName = "test" }
    end)
  end)
  lu.assertEquals(choiceAsked, 0, "副将为士兵牌时不能选选项 2，应直接执行选项 1")
  lu.assertEquals(ally.deputyGeneral, soldierDeputy, "士兵副将不得被化形变更")
end

-- QUN022A 李傕：凶算（对自己发动并回合末复原凶算自身循环）+ 挠袭（不同目标复用 / 无新目标禁止发动）
function Testqiao_bian_wu_qun_jin:testQun022aXiongsuanSelfLoopAndNaoxiDisjointTargets()
  local room = FkTest.room
  local lijue, targetA, targetB = p(1), p(2), p(3)
  local handCard, dismantle, foresight
  inRoom(function()
    skill_test.installBlankGenerals(room, { "qun", "wei", "wu", "shu" })
    skill_test.installDualGenerals(room, lijue, {
      main = "qiao_heg__qun022a", deputy = "qiao_test__qun_2", kingdom = "qun", hp = 4,
    })
    for _, who in ipairs(room.players) do who:throwAllCards("he") end
    handCard = room:printCard("qiao__jink", Card.Heart, 2)
    dismantle = room:printCard("qiao__dismantlement", Card.Spade, 3)
    foresight = room:printCard("qiao__foresight", Card.Heart, 7)
    room:obtainCard(lijue, { handCard, dismantle, foresight }, false, fk.ReasonJustMove)
    room:obtainCard(targetA, room:printCard("qiao__slash", Card.Club, 4), false, fk.ReasonJustMove)
    room:obtainCard(targetB, room:printCard("qiao__slash", Card.Club, 5), false, fk.ReasonJustMove)
    lijue.phase = Player.Play
  end)

  -- 凶算对自己发动：弃 1 手牌、自伤 1 点、摸 3 张，回合结束时复原【凶算】自身。
  local handBefore = #lijue:getCardIds("h")
  inRoom(function()
    lijue:addSkillUseHistory("qiao__skill_qun022a_1", 1)
    Fk.skills["qiao__skill_qun022a_1"]:onUse(room, {
      from = lijue, tos = { lijue }, cards = { handCard.id },
    })
  end)
  lu.assertEquals(lijue.hp, 3)
  lu.assertEquals(#lijue:getCardIds("h"), handBefore - 1 + 3)
  lu.assertEquals(lijue:usedSkillTimes("qiao__skill_qun022a_1", Player.HistoryGame), 1)

  inRoom(function()
    room.logic:trigger(fk.TurnEnd, lijue, TurnData:new(lijue, "game_rule", {}))
  end)
  lu.assertEquals(lijue:usedSkillTimes("qiao__skill_qun022a_1", Player.HistoryGame), 0,
    "凶算对自己发动时回合结束应允许复原凶算自身")

  -- 挠袭使用【洞烛先机】（固定目标仅自己）：无不含原目标的新目标，应禁止发动、不扣体力上限。
  local naoxiAsked = 0
  skill_test.withSkillRequests(room, "qiao__skill_qun022a_2", {
    askToSkillInvoke = function() naoxiAsked = naoxiAsked + 1; return true end,
  }, function()
    inRoom(function()
      room:useCard { from = lijue, tos = { lijue }, card = foresight }
    end)
  end)
  lu.assertEquals(naoxiAsked, 0, "固定目标仅自己的洞烛先机无新合法目标，挠袭应禁止发动")
  lu.assertEquals(lijue.maxHp, 4)

  -- 挠袭使用【过河拆桥】拆 targetA 后，减 1 体力上限视为对 targetB 再用【过河拆桥】（exclusive_targets 不含 targetA）。
  local observedExclusive
  skill_test.withSkillRequests(room, "qiao__skill_qun022a_2", {
    askToSkillInvoke = function() return true end,
    askToUseVirtualCard = function(self, who, params)
      observedExclusive = params.extra_data and params.extra_data.exclusive_targets
      local c = Fk:cloneCard(params.name)
      c.skillName = params.skill_name
      self:useCard { from = who, tos = { targetB }, card = c, extraUse = true }
      return true
    end,
  }, function()
    inRoom(function()
      room:useCard { from = lijue, tos = { targetA }, card = dismantle }
    end)
  end)
  lu.assertNotNil(observedExclusive)
  lu.assertFalse(table.contains(observedExclusive, targetA.id), "挠袭新目标不得包含原目标 targetA")
  lu.assertTrue(table.contains(observedExclusive, targetB.id), "targetB 应为合法新目标")
  lu.assertEquals(lijue.maxHp, 3, "挠袭发动应减 1 点体力上限")
  lu.assertEquals(#targetB:getCardIds("h"), 0, "targetB 的手牌应被第二次过河拆桥弃置")
end

-- 飞熊军翼从：同名两份独立限定次数 + 无视距离依次顺手牵羊和杀 + 凶算可复原飞熊军实例
function Testqiao_bian_wu_qun_jin:testFeixiongjunMultiInstanceLimitedAndBypassDistance()
  local room = FkTest.room
  local holder, farEnemy = p(1), p(4)
  local enemyCard
  inRoom(function()
    skill_test.installBlankGenerals(room, { "qun", "wei", "wu", "shu", "han", "jin", "wei", "wu" })
    holder.hp = 3
    farEnemy.hp = 3
    p(2).hp = 4
    farEnemy:throwAllCards("he")
    enemyCard = room:printCard("qiao__peach", Card.Heart, 4)
    room:obtainCard(farEnemy, enemyCard, false, fk.ReasonJustMove)
    -- 授予两份独立飞熊军实例
    Retinues.grant(holder, { general = "qiao_heg__retinue_feixiongjun", skill = Bian.FEIXIONG_SKILL, origin = "granted" })
    Retinues.grant(holder, { general = "qiao_heg__retinue_feixiongjun", skill = Bian.FEIXIONG_SKILL, origin = "granted" })
    holder.phase = Player.Play
  end)

  lu.assertTrue(holder:distanceTo(farEnemy) > 1, "目标距离应大于 1 以验证无视距离")
  lu.assertTrue(Fk.skills[Bian.FEIXIONG_SKILL]:canUse(holder))
  lu.assertTrue(Fk.skills[Bian.FEIXIONG_SKILL]:targetFilter(holder, farEnemy, {}))
  lu.assertFalse(Fk.skills[Bian.FEIXIONG_SKILL]:targetFilter(holder, p(2), {}), "体力值不同者不合法")

  -- 发动第一份实例：无视距离顺走 enemyCard 并出一张无视距离的杀。
  inRoom(function()
    Fk.skills[Bian.FEIXIONG_SKILL]:onUse(room, { from = holder, tos = { farEnemy }, cards = {} })
  end)
  lu.assertTrue(table.contains(holder:getCardIds("h"), enemyCard.id), "飞熊军应无视距离顺走目标牌")
  lu.assertEquals(farEnemy.hp, 2, "飞熊军应无视距离继续对目标使用【杀】造成伤害")
  lu.assertTrue(Fk.skills[Bian.FEIXIONG_SKILL]:canUse(holder), "第二份同名飞熊军实例仍应有独立限定机会")

  -- 发动第二份实例（令同体力=2 且目标无牌：跳过顺手牵羊仍出杀）
  inRoom(function()
    holder.hp = 2
    Fk.skills[Bian.FEIXIONG_SKILL]:onUse(room, { from = holder, tos = { farEnemy }, cards = {} })
  end)
  lu.assertEquals(farEnemy.hp, 1, "目标无牌时跳过顺手牵羊仍应视为使用【杀】")
  lu.assertFalse(Fk.skills[Bian.FEIXIONG_SKILL]:canUse(holder), "两份实例均用尽后按钮不可用")

  -- 验证凶算复位接口可复原一份已用的飞熊军实例
  inRoom(function()
    lu.assertTrue(Bian.resetOneLimitedRetinue(holder, Bian.FEIXIONG_SKILL))
  end)
  lu.assertTrue(Fk.skills[Bian.FEIXIONG_SKILL]:canUse(holder), "复原一份实例后飞熊军应再次可用")
  inRoom(function()
    local unused = Bian.availableLimitedRetinues(holder, Bian.FEIXIONG_SKILL)[1]
    lu.assertTrue(Retinues.loseSkill(holder, unused.id))
    lu.assertFalse(Fk.skills[Bian.FEIXIONG_SKILL]:canUse(holder))
    lu.assertEquals(#Bian.usedLimitedRetinues(holder, Bian.FEIXIONG_SKILL), 1)
  end)
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

-- 审阅回归（第 4、11 项）：暗置副将左慈换走时余下「魂」全部入弃牌堆；重连快照只向本人提供私密「魂」名单。
function Testqiao_bian_wu_qun_jin:testQun009ZuociHiddenChangeDiscardAndReconnectSnapshot()
  local room = FkTest.room
  local zuoci, other = p(1), p(2)
  local ownPrivate, otherPrivate, ownCount, otherCount, okChange, discarded, countAfter
  inRoom(function()
    skill_test.installBlankGenerals(room, { "qun", "wei", "wu", "shu" })
    skill_test.installDualGenerals(room, zuoci, {
      main = "qiao_test__qun_2", deputy = "qiao_heg__qun009", kingdom = "qun", hp = 3,
    })
    resetGeneralPool(room, { "qiao_heg__qun007" })
    Bian.addZuociSouls(room, zuoci, { "qiao_heg__wei004", "qiao_heg__wu003" }, true)

    local snapOwn = cbor.decode(room:serialize(zuoci).players[zuoci.id].mark)
    local snapOther = cbor.decode(room:serialize(other).players[zuoci.id].mark)
    ownPrivate = snapOwn[Bian.ZUOCI_PRIVATE_MARK]
    otherPrivate = snapOther[Bian.ZUOCI_PRIVATE_MARK]
    ownCount = snapOwn[Bian.ZUOCI_COUNT_MARK]
    otherCount = snapOther[Bian.ZUOCI_COUNT_MARK]

    zuoci:hideGeneral(true)
    lu.assertEquals(zuoci:getMark(Bian.ZUOCI_COUNT_MARK), 2, "暗置左慈时「魂」应保留")
    okChange = Change.changeTo(room, zuoci, true, "qiao_heg__qun007")
    discarded = Discard.list(room)
    countAfter = zuoci:getMark(Bian.ZUOCI_COUNT_MARK)
  end)
  lu.assertEquals(ownCount, 2)
  lu.assertEquals(otherCount, 2)
  lu.assertEquals(ownPrivate, { "qiao_heg__wei004", "qiao_heg__wu003" }, "持有者重连快照应恢复私密魂名单")
  lu.assertNil(otherPrivate, "其他座位重连快照不得包含左慈私密魂名单")
  lu.assertTrue(okChange)
  lu.assertTrue(table.contains(discarded, "qiao_heg__wei004"))
  lu.assertTrue(table.contains(discarded, "qiao_heg__wu003"))
  lu.assertEquals(countAfter, 0, "暗置副将左慈被换走后应清空魂数量标记")
end

-- 审阅回归（第 3、5 项）：挠袭排除被【谦逊】取消的原目标；凶算复原【激诏】【鼎沸】独立已用标记后可实际再次发动。
function Testqiao_bian_wu_qun_jin:testQun022aNaoxiCancelledTargetAndXiongsuanCustomLimitedReset()
  local room = FkTest.room
  local lijue, luxun, other = p(1), p(2), p(3)
  local allowedTargets
  inRoom(function()
    skill_test.installBlankGenerals(room, { "qun", "wu", "wei", "shu" })
    skill_test.installDualGenerals(room, lijue, {
      main = "qiao_heg__qun022a", deputy = "qiao_test__qun_2", kingdom = "qun", hp = 4,
    })
    skill_test.installDualGenerals(room, luxun, {
      main = "qiao_heg__wu007", deputy = "qiao_test__wu_2", kingdom = "wu", hp = 3,
    })
    local trick = room:printCard("qiao__dismantlement", Card.Spade, 3)
    room:obtainCard(lijue, trick, false, fk.ReasonJustMove)
    room:obtainCard(luxun, room:printCard("qiao__slash", Card.Spade, 8), false, fk.ReasonJustMove)
    room:obtainCard(other, room:printCard("qiao__slash", Card.Club, 8), false, fk.ReasonJustMove)
    skill_test.withSkillRequests(room, "qiao__skill_qun022a_2", {
      askToSkillInvoke = function() return true end,
      askToUseVirtualCard = function(self, who, params)
        allowedTargets = params.extra_data and params.extra_data.exclusive_targets
      end,
    }, function()
      room:useCard { from = lijue, card = trick, tos = { luxun } }
    end)
  end)
  lu.assertNotNil(allowedTargets)
  lu.assertFalse(table.contains(allowedTargets, luxun.id), "被谦逊取消的原目标仍不得进入挠袭可选列表")
  lu.assertTrue(table.contains(allowedTargets, other.id), "未曾指定过的合法角色应仍可选")

  -- 凶算复原君刘备【激诏】与君司马炎【鼎沸】后，两者独立已用标记清零且实际可再次发动
  local jizhaoRetriggered, dingfeiRetriggered = 0, 0
  inRoom(function()
    local lordShu, lordJin = p(2), p(3)
    skill_test.installDualGenerals(room, lordShu, {
      main = "qiao_heg__em_shu001", deputy = "qiao_test__shu_2", kingdom = "shu", hp = 4,
    })
    skill_test.installDualGenerals(room, lordJin, {
      main = "qiao_heg__em_jin001", deputy = "qiao_test__jin_2", kingdom = "jin", hp = 4,
    })
    lordShu:addSkillUseHistory("qiao__skill_em_shu001_3", 1)
    room:setPlayerMark(lordShu, "qiao__skill_em_shu001_3-used", 1)
    lordJin:addSkillUseHistory("qiao__skill_em_jin001_3", 1)
    room:setPlayerMark(lordJin, "qiao_jin001_dingfei_used", 1)
    room:setTag("qiao_qun022a_xiongsuan_pending", {
      { source_id = lijue.id, target_id = lordShu.id },
      { source_id = lijue.id, target_id = lordJin.id },
    })
    room:setCurrent(lijue)
    room.logic:trigger(fk.TurnEnd, lijue, TurnData:new(lijue, "game_rule", {}))

    lu.assertEquals(lordShu:getMark("qiao__skill_em_shu001_3-used"), 0, "激诏独立已用标记应清零")
    lu.assertEquals(lordJin:getMark("qiao_jin001_dingfei_used"), 0, "鼎沸独立已用标记应清零")

    -- 实测【激诏】再次进入濒死可实际触发
    skill_test.withSkillRequests(room, "qiao__skill_em_shu001_3", {
      askToSkillInvoke = function(self, who, params)
        if params.prompt == "#qiao__skill_em_shu001_3-invoke" then
          jizhaoRetriggered = jizhaoRetriggered + 1
          return true
        end
        return false
      end,
    }, function()
      lordShu.hp = 1
      room:loseHp(lordShu, 1, "test")
    end)

    -- 实测【鼎沸】结束阶段（晋势力已损体力之和 > 体力之和）可实际再次触发
    lordJin.maxHp = 4
    lordJin.hp = 1
    lordJin.phase = Player.Finish
    skill_test.withSkillRequests(room, "qiao__skill_em_jin001_3", {
      askToSkillInvoke = function()
        dingfeiRetriggered = dingfeiRetriggered + 1
        return true
      end,
    }, function()
      room.logic:trigger(fk.EventPhaseStart, lordJin, PhaseData:new { who = lordJin, phase = Player.Finish })
    end)
  end)
  lu.assertEquals(jizhaoRetriggered, 1, "凶算复原后君刘备【激诏】应能实际再次发动")
  lu.assertEquals(dingfeiRetriggered, 1, "凶算复原后君司马炎【鼎沸】应能实际再次发动")
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

-- 复审回归（第 2 项）：首座左慈有「魂」时，旁观者 Observe 包不含私密魂名单，本人重连仍可恢复。
function Testqiao_bian_wu_qun_jin:testQun009ZuociObserverDoesNotLeakPrivateSouls()
  local room = FkTest.room
  local owner, other = p(1), p(2)
  local tieqi = require "packages.qiao.pkg.qiao_mode.rules.tieqi"
  local hiddenSkills = "qiao_shu_tieqi_private-turn"
  local obsReceived, obsCount, obsPrivate, ownPrivate, otherPrivate
  local publicUpdates, observerLists, ownerLists = {}, {}, {}
  local added = "qiao_heg__shu001"
  inRoom(function()
    skill_test.installBlankGenerals(room, { "qun", "wei", "shu", "wu" })
    skill_test.installDualGenerals(room, owner, {
      main = "qiao_heg__qun009", deputy = "qiao_heg__shu001", kingdom = "qun", hp = 4,
    })
    owner:hideGeneral(true)
    tieqi.mark(room, owner, true)
    Bian.addZuociSouls(room, owner, { "qiao_heg__wei004", "qiao_heg__wu003" }, true)

    local observer = {
      getScreenName = function() return "obs" end, getId = function() return 677 end,
      getState = function() return fk.Player_Online end,
    }
    function observer:doNotify(cmd, bytes)
      if cmd == "Observe" then
        local msg = cbor.decode(bytes)
        local marks = cbor.decode(msg.players[owner.id].mark)
        lu.assertNil(marks[hiddenSkills])
        obsReceived = msg.settings.isObserver
        obsCount = marks[Bian.ZUOCI_COUNT_MARK]
        obsPrivate = marks[Bian.ZUOCI_PRIVATE_MARK]
      elseif cmd == "SetPlayerMark" then
        local msg = cbor.decode(bytes)
        if msg[1] == owner.id and msg[2] == Bian.ZUOCI_COUNT_MARK then table.insert(publicUpdates, msg[3]) end
        if msg[1] == owner.id and msg[2] == Bian.ZUOCI_PRIVATE_MARK then table.insert(observerLists, msg[3]) end
      end
    end
    local prevSettings = room.getSettings
    room.getSettings = function(self, key, ...)
      if key == "enableObserverViewCard" then return false end
      return prevSettings(self, key, ...)
    end
    room:tellRoomToObserver(observer)
    -- 测试后端以此旁观者模拟 C++ 房间的已入房名单，通知仍走引擎分发。
    local hasObserver = room.room.hasObserver
    room.room.hasObserver = function(_, who) return who == observer end
    local connection = owner._splayer
    local notify = connection.doNotify
    function connection:doNotify(cmd, bytes)
      if cmd == "SetPlayerMark" then
        local msg = cbor.decode(bytes)
        if msg[1] == owner.id and msg[2] == Bian.ZUOCI_PRIVATE_MARK then table.insert(ownerLists, msg[3]) end
      end
      return notify(self, cmd, bytes)
    end
    Bian.addZuociSouls(room, owner, { added })
    Bian.removeZuociSoul(room, owner, added)
    room:removeObserver(observer:getId())
    connection.doNotify = notify
    room.room.hasObserver = hasObserver
    room.getSettings = prevSettings

    local ownMarks = cbor.decode(room:serialize(owner).players[owner.id].mark)
    lu.assertTrue(table.contains(ownMarks[hiddenSkills], "qiao__skill_shu001_1"))
    ownPrivate = ownMarks[Bian.ZUOCI_PRIVATE_MARK]
    otherPrivate = cbor.decode(room:serialize(other).players[owner.id].mark)[Bian.ZUOCI_PRIVATE_MARK]
  end)
  lu.assertTrue(obsReceived)
  lu.assertEquals(obsCount, 2, "旁观者应可见公开魂数量")
  lu.assertNil(obsPrivate, "旁观者入房包不得包含左慈私密魂名单")
  lu.assertEquals(publicUpdates, { 3, 2 })
  lu.assertEquals(observerLists, {}, "已在房的旁观者也只应收到数量")
  lu.assertEquals(ownerLists, {
    { "qiao_heg__wei004", "qiao_heg__wu003", added }, { "qiao_heg__wei004", "qiao_heg__wu003" },
  })
  lu.assertEquals(ownPrivate, { "qiao_heg__wei004", "qiao_heg__wu003" }, "左慈本人重连仍应恢复私密魂名单")
  lu.assertNil(otherPrivate, "其他玩家快照仍不得包含私密魂名单")
end

function Testqiao_bian_wu_qun_jin:testQun009HuaxingRequiresAnAvailableGeneralBeforeActivation()
  local room, owner = FkTest.room, p(1)
  local name = Bian.ZUOCI_SKILL
  local function checkButton(available)
    room.logic:trigger(fk.StartPlayCard, owner, {}, true)
    client_room.run(room, function(players)
      local client = Fk:getBoardGame("qiao_heg_mode").client_klass:new(ClientInstance.client)
      local handler = client.request_handlers.PlayCard:new(players[1])
      handler:setup()
      lu.assertEquals(handler:skillButtonValidity(name), available)
      if available then
        handler:selectSkill(name, { selected = true })
        lu.assertTrue(handler:feasible())
      end
      handler:_finish()
    end)
  end
  inRoom(function()
    skill_test.installBlankGenerals(room, { "qun", "wei", "shu", "wu" })
    skill_test.installDualGenerals(room, owner, {
      main = "qiao_heg__qun009", deputy = "qiao_test__qun_2", kingdom = "qun", hp = 4,
    })
    room:setCurrent(owner)
    owner.phase = Player.Play
    resetGeneralPool(room, { "qiao_heg__em_wu001" })
    checkButton(false) -- 池中只有君主，也无可取的魂。

    local candidate = "qiao_heg__wei004"
    table.insert(room.general_pile, candidate)
    checkButton(true)
    table.removeOne(room.general_pile, candidate) -- 请求发出后最后一个候选离池。
    local reply = FkTest.ReplyUseSkill(name, {}, {})
    room:handleUseCardReply(owner, reply)
    lu.assertEquals(owner:usedEffectTimes(name, Player.HistoryPhase), 0)
    lu.assertFalse(Bian.zuociFirstUsed(room, owner))
    checkButton(false)

    table.insert(room.general_pile, candidate)
    checkButton(true)
    skill_test.withSkillRequests(room, name, {
      askToChoice = function() return "#qiao__skill_qun009_1-opt-remove" end,
      askToCustomDialog = function() return { general = candidate } end,
    }, function() room:handleUseCardReply(owner, reply) end)
    lu.assertEquals(owner:usedEffectTimes(name, Player.HistoryPhase), 1)
    lu.assertTrue(Bian.zuociFirstUsed(room, owner))
    lu.assertTrue(table.contains(Discard.list(room), candidate))
  end)
end

-- 复审回归（第 4 项）：挠袭对固定目标牌按完整固定集合判重（有重叠整张禁用，完全不重叠才允许复用）。
function Testqiao_bian_wu_qun_jin:testQun022aNaoxiCannotSplitFixedTargetsButAllowsDisjoint()
  local room = FkTest.room
  local li = p(1)
  local first = li:getNextAlive()
  local joining = first:getNextAlive()
  local promptsOverlap, promptsDisjoint = 0, 0
  local repeatTargetsDisjoint = {}
  inRoom(function()
    skill_test.installBlankGenerals(room, { "qun", "wei", "wu", "shu" })
    skill_test.installDualGenerals(room, li, {
      main = "qiao_heg__qun022a", deputy = "qiao_test__qun_2", kingdom = "qun", hp = 4,
    })
    room:changeKingdom(first, "wei")
    room:changeKingdom(joining, "wu")
    for _, who in ipairs(room.players) do who:throwAllCards("he") end
    local trick1 = room:printCard("qiao__burning_camps", Card.Club, 11)
    room:obtainCard(li, trick1, false, fk.ReasonJustMove)
    room:setCurrent(li)
    li.phase = Player.Play
    local initial = trick1:getAvailableTargets(li)

    -- 场景 1：结算期间下家队列扩大为 {first, joining}，与原目标 {first} 重叠 -> 整张禁用，不得拆分只烧 joining。
    local oldTrigger = room.logic.trigger
    room.logic.trigger = function(this, ev, target, data, ...)
      if ev == fk.CardUseFinished and target == li and data.card == trick1 then
        room:changeKingdom(joining, "wei")
      end
      return oldTrigger(this, ev, target, data, ...)
    end
    skill_test.withSkillRequests(room, "qiao__skill_qun022a_2", {
      askToSkillInvoke = function() promptsOverlap = promptsOverlap + 1; return true end,
    }, function()
      room:useCard { from = li, tos = initial, card = trick1 }
    end)
    room.logic.trigger = oldTrigger

    -- 场景 2：下家阵亡后新下家固定目标完全不重叠 -> 允许发动挠袭对新队列使用。
    room:changeKingdom(joining, "wu")
    local trick2 = room:printCard("qiao__burning_camps", Card.Heart, 11)
    room:obtainCard(li, trick2, false, fk.ReasonJustMove)
    local initial2 = trick2:getAvailableTargets(li)
    local prevTrigger = room.logic.trigger
    room.logic.trigger = function(this, ev, target, data, ...)
      if ev == fk.CardUseFinished and target == li and data.card == trick2 then
        first.dead = true
        table.removeOne(room.alive_players, first)
      end
      if ev == fk.CardUsing and target == li and data.card.skillName == "qiao__skill_qun022a_2" then
        repeatTargetsDisjoint = table.map(data.tos, Util.IdMapper)
      end
      return prevTrigger(this, ev, target, data, ...)
    end
    skill_test.withSkillRequests(room, "qiao__skill_qun022a_2", {
      askToSkillInvoke = function() promptsDisjoint = promptsDisjoint + 1; return true end,
    }, function()
      room:useCard { from = li, tos = initial2, card = trick2 }
    end)
    room.logic.trigger = prevTrigger
  end)
  lu.assertEquals(promptsOverlap, 0, "固定目标队列扩大后与原目标重叠时不得拆分使用挠袭")
  lu.assertEquals(promptsDisjoint, 1, "固定目标集合与原目标完全不重叠时仍应允许发动挠袭")
  lu.assertEquals(repeatTargetsDisjoint, { joining.id }, "完全不重叠时应对完整新固定目标生效")
end

function Testqiao_bian_wu_qun_jin:testXiongsuanRestoresRoleGrantedLimitedSkill()
  local room, lijue, recipient = FkTest.room, p(1), p(2)
  local name = "qiao__skill_qun022a_1"
  inRoom(function()
    skill_test.installBlankGenerals(room, "qun")
    room:handleAddLoseSkills(recipient, name)
    lu.assertTrue(recipient:hasShownSkill(name))
    lu.assertFalse(table.contains(recipient.player_skills, Fk.skills[name]))
    recipient:setSkillUseHistory(name, 1, Player.HistoryGame)
    room:setTag("qiao_qun022a_xiongsuan_pending", {
      { source_id = lijue.id, target_id = recipient.id },
    })
    room.logic:trigger(fk.TurnEnd, lijue, TurnData:new(lijue, "game_rule"))
    lu.assertEquals(recipient:usedSkillTimes(name, Player.HistoryGame), 0)
  end)
end

return { name = "qiao_bian_wu_qun_jin" }
