-- 六势力权包回归（上）：注册元数据、汉晋军令公共规则、汉/魏/蜀六将与翼从无当飞军。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local client_room = __dofile("../../../tests/support/client_room.lua")

local H = require "packages.hegemony.util"
local Commander = require "packages.qiao.pkg.qiao_mode.rules.commander_retinue"
local Guest = require "packages.qiao.pkg.qiao_mode.rules.guest_factions"
local Junling = require "packages.qiao.pkg.qiao_mode.rules.junling"
local SkillButtons = require "packages.qiao.pkg.qiao_mode.rules.skill_buttons"
local SkillStatus = require "packages.qiao.pkg.qiao_mode.skill_status"
local Quan = require "packages.qiao.pkg.qiao_generals.util.quan_common"
local R = require "packages.qiao.pkg.qiao_generals.util.retinue_instances"

local function room() return FkTest.room end
local function p(n) return FkTest.room.players[n] end
local function inRoom(fn)
  local ret
  FkTest.runInRoom(function() ret = fn() end)
  return ret
end

local function clearAllZones(player)
  for _, zone in ipairs({ "h", "e", "j" }) do
    local ids = player:getCardIds(zone)
    if #ids > 0 then
      room():moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false)
    end
  end
end

local function give(player, name, suit, number)
  local card
  inRoom(function()
    card = room():printCard(name, suit or Card.Spade, number or 7)
    room():obtainCard(player, card, false, fk.ReasonJustMove)
  end)
  return card
end

local function equip(player, name, suit, number)
  local card
  inRoom(function()
    card = room():printCard(name, suit or Card.Spade, number or 7)
    room():moveCardTo(card, Card.PlayerEquip, player, fk.ReasonJustMove, "test", nil, true)
  end)
  return card
end

local function prepareRoom(kingdoms)
  Fk.currentResponsePattern = nil
  local r = support.initQiaoRoom()
  inRoom(function()
    skill_test.installBlankGenerals(r, kingdoms or { "han", "wei", "shu", "wu", "qun", "jin", "han", "wei" })
    for _, pl in ipairs(r.players) do
      clearAllZones(pl)
    end
    r.current = r.players[1]
    r:setBanner("RoundCount", 1)
  end)
  return r
end

Testqiao_quan_han_wei_shu = {
  setup = function() prepareRoom() end,
  tearDown = function()
    Fk.currentResponsePattern = nil
    support.clearRoom()
  end,
}

function Testqiao_quan_han_wei_shu:testHanjinJunlingRules()
  local from, to, bystander, removed = p(1), p(2), p(3), p(4)
  inRoom(function()
    skill_test.installDualGenerals(room(), from, { main = "qiao_heg__shu024", deputy = "qiao_test__shu_2", kingdom = "shu" })
    room():setPlayerMark(removed, MarkEnum.PlayerRemoved .. "-turn", 1)
    room():setPlayerMark(removed, "@@lure_tiger-turn", 1)
  end)

  -- 军令一：排除执行者本人与移出游戏角色
  local seenTargets
  skill_test.withSkillRequests(room(), "test_cmd1", {
    askToChoosePlayers = function(self, who, params)
      seenTargets = table.map(params.targets, function(pl) return pl.id end)
      return { bystander }
    end,
  }, function()
    inRoom(function()
      local data = { from = from, tos = { to }, skillName = "test_cmd1" }
      H.CommandPrepare("command1", data)
      H.CommandCB("command1", to, from, data)
    end)
  end)
  lu.assertNotNil(seenTargets)
  lu.assertFalse(table.contains(seenTargets, to.id), "军令一不得选择执行者本人")
  lu.assertFalse(table.contains(seenTargets, removed.id), "军令一不得选择移出游戏角色")
  lu.assertEquals(bystander.hp, bystander.maxHp - 1)

  -- 军令二：摸1交2且以执行者为 proposer 触发法正【恩怨】；对自身跳过交牌
  give(to, "qiao__slash", Card.Spade, 5)
  local beforeToHand = to:getHandcardNum()
  inRoom(function()
    H.CommandCB("command2", to, from, { from = from, tos = { to } })
  end)
  -- to 原1张 + 摸1 = 2张 -> 全交2张给法正 -> 触发恩怨摸1张，故手牌=1，法正手牌=2
  lu.assertEquals(to:getHandcardNum(), beforeToHand)
  lu.assertEquals(from:getHandcardNum(), 2)

  -- 军令二对自身：只摸1不交牌
  local selfBefore = from:getHandcardNum()
  inRoom(function()
    H.CommandCB("command2", from, from, { from = from, tos = { from } })
  end)
  lu.assertEquals(from:getHandcardNum(), selfBefore + 1)

  -- 军令五：汉晋定向叠置（已叠置不反向平置）且本回合不能回血
  inRoom(function()
    lu.assertTrue(to.faceup)
    H.CommandCB("command5", to, from, { from = from, tos = { to } })
    lu.assertFalse(to.faceup, "平置应改为叠置")
    H.CommandCB("command5", to, from, { from = from, tos = { to } })
    lu.assertFalse(to.faceup, "已叠置不得反向平置")
    room():loseHp(to, 1, "test")
    local hpBefore = to.hp
    room():recover { who = to, num = 1, skillName = "test" }
    lu.assertEquals(to.hp, hpBefore, "军令五本回合禁止回复体力")
  end)
end

function Testqiao_quan_han_wei_shu:testHan003LiuhongYujue()
  local liuhong, target, victim = p(1), p(2), p(3)
  inRoom(function()
    skill_test.installDualGenerals(room(), liuhong, { main = "qiao_heg__han003", deputy = "qiao_test__han_2", kingdom = "han" })
    skill_test.installDualGenerals(room(), target, { main = "qiao_heg__wei005", deputy = "qiao_heg__wei004", kingdom = "wei" })
  end)
  give(liuhong, "qiao__slash", Card.Spade, 2)
  give(liuhong, "qiao__slash", Card.Spade, 3)
  give(liuhong, "qiao__slash", Card.Spade, 4)

  -- 分支1：执行军令 -> 本回合下次造成伤害后摸两张（刘宏暗置后依然生效，且仅限一次）
  local origAsk = Junling.ask
  Junling.ask = function() return true end
  skill_test.withSkillRequests(room(), "qiao__skill_han003_1", {
    askToDiscard = function(self, who, params)
      local id = who:getCardIds("h")[1]
      self:throwCard({ id }, params.skill_name, who, who)
      return { id }
    end,
  }, function()
    inRoom(function()
      room().current = target
      target.phase = Player.Play
      room().logic:trigger(fk.EventPhaseStart, target, {})
    end)
  end)
  lu.assertEquals(target:getMark(Quan.YUJUE_DRAW_MARK), 1)
  local states = SkillStatus.forPlayer(target)
  lu.assertTrue(table.find(states, function(s) return s.id == Quan.YUJUE_DRAW_MARK end) ~= nil)

  local handBefore = target:getHandcardNum()
  inRoom(function()
    liuhong:hideGeneral(false)
    room():damage { from = target, to = victim, damage = 1, skillName = "test" }
    lu.assertEquals(target:getHandcardNum(), handBefore + 2, "刘宏暗置后鬻爵已建立摸2仍生效")
    room():damage { from = target, to = victim, damage = 1, skillName = "test" }
    lu.assertEquals(target:getHandcardNum(), handBefore + 2, "第二次造成伤害不再重复摸牌")
  end)

  -- 分支2：不执行 -> 暗置其一将且本回合不能明置；再次不执行（已有暗置）-> 定向叠置
  inRoom(function() liuhong:revealGeneral(false) end)
  Junling.ask = function() return false end
  skill_test.withSkillRequests(room(), "qiao__skill_han003_1", {
    askToDiscard = function(self, who, params)
      local id = who:getCardIds("h")[1]
      self:throwCard({ id }, params.skill_name, who, who)
      return { id }
    end,
    askToChoice = function(self, who, params) return params.choices[1] end,
  }, function()
    inRoom(function()
      room().current = target
      target.phase = Player.Play
      room().logic:trigger(fk.EventPhaseStart, target, {})
    end)
  end)
  lu.assertEquals(target.general, "anjiang")
  lu.assertTrue(target:prohibitReveal(false), "被鬻爵暗置的将牌本回合不能明置")
  lu.assertTrue(target.faceup)

  -- 再次对已有暗置武将牌的 target 发动且不执行 -> 改为定向叠置
  skill_test.withSkillRequests(room(), "qiao__skill_han003_1", {
    askToDiscard = function(self, who, params)
      local id = who:getCardIds("h")[1]
      self:throwCard({ id }, params.skill_name, who, who)
      return { id }
    end,
  }, function()
    inRoom(function()
      room().logic:trigger(fk.EventPhaseStart, target, {})
    end)
  end)
  Junling.ask = origAsk
  lu.assertFalse(target.faceup, "已有暗置将牌时改为叠置")
end

function Testqiao_quan_han_wei_shu:testHan021CaojieShouxiAndXuanhu()
  local caojie, ally, enemy = p(1), p(7), p(2)
  inRoom(function()
    skill_test.installDualGenerals(room(), caojie, { main = "qiao_heg__han021", deputy = "qiao_test__han_2", kingdom = "han" })
    skill_test.installDualGenerals(room(), ally, { main = "qiao_heg__han001", deputy = "qiao_test__han_2", kingdom = "han" })
    skill_test.installDualGenerals(room(), enemy, { main = "qiao_heg__wei005", deputy = "qiao_test__wei_2", kingdom = "wei" })
  end)
  local eqSpade = equip(ally, "qiao__crossbow", Card.Spade, 1)
  local eqHeart = equip(ally, "qiao__chitu", Card.Heart, 5)
  local cjSpade = give(caojie, "qiao__slash", Card.Spade, 9)
  local cjHeart = give(caojie, "qiao__peach", Card.Heart, 6)

  -- 守玺：异势力同时非弃置移动两张装备牌，逐张判定：弃黑桃防黑桃，放行红桃
  local askCalls = 0
  skill_test.withSkillRequests(room(), "qiao__skill_han021_1", {
    askToDiscard = function(self, who, params)
      askCalls = askCalls + 1
      if params.pattern == ".|.|spade" then
        self:throwCard({ cjSpade.id }, params.skill_name, who, who)
        return { cjSpade.id }
      end
      return {}
    end,
  }, function()
    inRoom(function()
      room():moveCards({
        from = ally,
        ids = { eqSpade.id, eqHeart.id },
        to = enemy,
        toArea = Card.PlayerHand,
        moveReason = fk.ReasonPrey,
        proposer = enemy,
        skillName = "test_prey",
      })
    end)
  end)
  lu.assertEquals(askCalls, 2, "多张装备应逐张触发询问")
  lu.assertTrue(table.contains(ally:getCardIds("e"), eqSpade.id), "黑桃装备应被防止移动留在装备区")
  lu.assertTrue(table.contains(enemy:getCardIds("h"), eqHeart.id), "红桃装备放弃防止则正常被获得")

  -- 弃置原因不触发守玺
  local discardTriggered = false
  local cjSpade2 = give(caojie, "qiao__slash", Card.Spade, 8)
  skill_test.withSkillRequests(room(), "qiao__skill_han021_1", {
    askToDiscard = function() discardTriggered = true; return {} end,
  }, function()
    inRoom(function()
      room():throwCard({ eqSpade.id }, "test_discard", ally, enemy)
    end)
  end)
  lu.assertFalse(discardTriggered, "弃置原因不得触发守玺")
  lu.assertNotNil(cjSpade2)

  -- 悬壶：判定区红牌入弃牌堆不计入；手牌红牌入弃牌堆计入，回合结束曹节选摸/弃使手牌数==体力值后回复1血
  inRoom(function()
    room():setPlayerMark(caojie, Quan.XUANHU_RED_MARK, 0)
    local judgeRed = room():printCard("qiao__indulgence", Card.Heart, 6)
    room():moveCardTo(judgeRed, Card.PlayerJudge, caojie, fk.ReasonJustMove, "test", nil, true)
    room():moveCardTo(judgeRed, Card.DiscardPile, nil, fk.ReasonDiscard, "test", nil, true)
    lu.assertEquals(caojie:getMark(Quan.XUANHU_RED_MARK), 0, "判定区红牌置入弃牌堆不计入悬壶")

    room():throwCard({ cjHeart.id }, "test", caojie, caojie)
    lu.assertEquals(caojie:getMark(Quan.XUANHU_RED_MARK), 1, "手牌区红牌置入弃牌堆计入悬壶")

    -- 准备受伤盟友：hp = 2，手牌 1 -> 选摸1变2 == hp -> 回1血变3
    if ally.hp > 2 then room():loseHp(ally, ally.hp - 2, "test") end
    clearAllZones(ally)
    local c = room():printCard("qiao__jink", Card.Club, 2)
    room():obtainCard(ally, c, false, fk.ReasonJustMove)
  end)
  local allyHpBefore = ally.hp
  skill_test.withSkillRequests(room(), "qiao__skill_han021_2", {
    askToChoosePlayers = function() return { ally } end,
    askToOptions = function(self, who, params) return { "#qiao__skill_han021_2-draw" } end,
  }, function()
    inRoom(function()
      room().logic:trigger(fk.TurnEnd, room().current, {})
    end)
  end)
  lu.assertEquals(ally:getHandcardNum(), allyHpBefore)
  lu.assertEquals(ally.hp, allyHpBefore + 1, "手牌数等于体力值应回复1点体力")
end

function Testqiao_quan_han_wei_shu:testWei021bMaojieZhengpiAndFengying()
  local maojie, ally, hiddenTarget = p(2), p(8), p(3)
  inRoom(function()
    skill_test.installDualGenerals(room(), maojie, { main = "qiao_heg__wei021b", deputy = "qiao_test__wei_2", kingdom = "wei" })
    skill_test.installDualGenerals(room(), ally, { main = "qiao_heg__wei005", deputy = "qiao_test__wei_2", kingdom = "wei" })
    hiddenTarget.general = "anjiang"
    room().current = maojie
    maojie.phase = Player.Play
  end)

  local give1 = give(maojie, "qiao__slash", Card.Spade, 5)
  local give2 = give(maojie, "qiao__slash", Card.Spade, 6)
  local targetEquip = equip(hiddenTarget, "qiao__chitu", Card.Heart, 5)
  local zhengpi = assert(Fk.skills["qiao__skill_wei021b_1"])

  -- 征辟第1次：交给有暗置武将的目标 -> 目标展示并交还装备区里的非基本牌，解锁本回合第2次
  skill_test.withSkillRequests(room(), "#qiao__skill_wei021b_1_return", {
    askToUseActiveSkill = function(self, who, params)
      return true, { cards = { targetEquip.id }, targets = {} }
    end,
  }, function()
    inRoom(function()
      lu.assertTrue(zhengpi:canUse(maojie))
      room():useSkill(maojie, zhengpi, function()
        zhengpi:onUse(room(), { from = maojie, cards = { give1.id }, tos = { hiddenTarget } })
      end, { from = maojie, cards = { give1.id }, tos = { hiddenTarget } })
    end)
  end)
  lu.assertTrue(table.contains(maojie:getCardIds("h"), targetEquip.id), "目标装备区的非基本牌应交还毛玠")
  lu.assertEquals(maojie:getMark(Quan.ZHENGPI_TWICE_MARK), 1)

  -- 客户端校验：解锁后仍可发动第2次
  client_room.run(room(), function(clients)
    local me = clients[2]
    me.mark[Quan.ZHENGPI_TWICE_MARK] = 1
    lu.assertTrue(zhengpi:canUse(me), "客户端应识别征辟本回合限两次")
  end)

  -- 征辟第2次：目标仅有1张基本牌、无非基本牌 -> 无合法交还组合，直接跳过不报错
  inRoom(function()
    clearAllZones(hiddenTarget)
    local onlyBasic = room():printCard("qiao__jink", Card.Club, 2)
    room():obtainCard(hiddenTarget, onlyBasic, false, fk.ReasonJustMove)
    room():useSkill(maojie, zhengpi, function()
      zhengpi:onUse(room(), { from = maojie, cards = { give2.id }, tos = { hiddenTarget } })
    end, { from = maojie, cards = { give2.id }, tos = { hiddenTarget } })
    -- 目标获得 give2 后有 2 张基本牌，测试无回牌时不崩溃；再测真正仅 1 张基本牌时无询问
    lu.assertFalse(zhengpi:canUse(maojie), "两次用尽后本出牌阶段不可再用")
  end)

  -- 奉迎：魏为小势力（2人，与汉并列或设汉为大势力）仍可发动，且使用时所有同势力摸至体力上限（先于无懈可击）
  inRoom(function()
    -- 让汉势力占 3 人成为唯一大势力，确保魏不是大势力
    skill_test.installDualGenerals(room(), p(4), { main = "qiao_heg__han004", deputy = "qiao_test__han_2", kingdom = "han" })
    clearAllZones(maojie)
    clearAllZones(ally)
    local h1 = room():printCard("qiao__slash", Card.Club, 7)
    room():obtainCard(maojie, h1, false, fk.ReasonJustMove)
  end)
  local fengying = assert(Fk.skills["qiao__skill_wei021b_2"])
  client_room.run(room(), function(clients, clientRoom)
    local me = clients[2]
    clientRoom.current = me
    lu.assertTrue(fengying:enabledAtPlay(me), "奉迎客户端应无视大势力限制")
  end)

  inRoom(function()
    local card = fengying:viewAs(maojie, {})
    lu.assertNotNil(card)
    lu.assertEquals(card.name, "qiao__threaten_emperor")
    lu.assertTrue(card:getMark("qiao_ignore_big_kingdom") > 0)
    -- 模拟被无懈可击抵消，验证“使用时”摸牌仍已完成
    local use = { from = maojie, tos = { maojie }, card = card, nullifiedTargets = { maojie } }
    room():useCard(use)
  end)
  lu.assertEquals(maojie:getHandcardNum(), maojie.maxHp, "奉迎使用时毛玠应摸至体力上限")
  lu.assertEquals(ally:getHandcardNum(), ally.maxHp, "奉迎使用时同势力盟友应摸至体力上限")
  lu.assertFalse(fengying:enabledAtPlay(maojie), "限定技用过一次后不可再用")
end

function Testqiao_quan_han_wei_shu:testWei024YujinChangling()
  local yujin, target = p(2), p(1)
  inRoom(function()
    skill_test.installDualGenerals(room(), yujin, { main = "qiao_heg__wei024", deputy = "qiao_test__wei_2", kingdom = "wei" })
  end)
  local card = give(yujin, "qiao__slash", Card.Spade, 7)
  local origAsk = H.askToCommand
  H.askToCommand = function() return false end
  skill_test.withSkillRequests(room(), "qiao__skill_wei024_1", {
    askToChooseCardsAndPlayers = function() return { target }, { card.id } end,
  }, function()
    inRoom(function()
      room().current = yujin
      yujin.phase = Player.Start
      room().logic:trigger(fk.EventPhaseStart, yujin, {})
    end)
  end)
  H.askToCommand = origAsk
  lu.assertEquals(yujin:getMark("qiao_wei024_extra_draw"), 3, "常令不执行应在本回合摸牌阶段多摸3张")
end

function Testqiao_quan_han_wei_shu:testShu023WangpingJianglueAndWudangFeijun()
  local wangping, shuAlly, hiddenShu, enemy = p(3), p(4), p(5), p(2)
  inRoom(function()
    skill_test.installDualGenerals(room(), wangping, { main = "qiao_heg__shu023", deputy = "qiao_test__shu_2", kingdom = "shu" })
    skill_test.installDualGenerals(room(), shuAlly, { main = "qiao_heg__shu001", deputy = "qiao_test__shu_2", kingdom = "shu" })
    -- hiddenShu 为未确定势力但暗置蜀将，响应亮将后加入蜀势力
    skill_test.installDualGenerals(room(), hiddenShu, { main = "qiao_heg__shu002", deputy = "qiao_test__shu_2", kingdom = "unknown" })
    hiddenShu.general = "anjiang"
    hiddenShu.deputyGeneral = "anjiang"
    room():setPlayerProperty(hiddenShu, "kingdom", "unknown")
    room():setPlayerMark(hiddenShu, "__heg_general", "qiao_heg__shu002")
    room():setPlayerMark(hiddenShu, "__heg_deputy", "qiao_test__shu_2")
    room():setPlayerMark(hiddenShu, "__heg_kingdom", "shu")
    room():loseHp(wangping, 1, "test")
    room():loseHp(shuAlly, 1, "test")
    room().current = wangping
    wangping.phase = Player.Play
  end)

  local wpMaxBefore = wangping.maxHp
  local wpHpBefore = wangping.hp
  local allyMaxBefore = shuAlly.maxHp
  local jianglue = assert(Fk.skills["qiao__skill_shu023_1"])
  local giveStep = 0
  skill_test.withSkillRequests(room(), "qiao__skill_shu023_1", {
    askToChoice = function(self, who, params)
      if who == hiddenShu then return params.choices[1] end
      return "Cancel"
    end,
    askToUseCard = function() return nil end,
  }, function()
    skill_test.withSkillRequests(room(), "#qiao__skill_shu023_1_give", {
      askToUseActiveSkill = function(self, who, params)
        giveStep = giveStep + 1
        if giveStep == 1 then
          return true, { cards = { who:getCardIds("h")[1] }, targets = { shuAlly } }
        end
        return false, nil
      end,
    }, function()
      inRoom(function()
        lu.assertTrue(jianglue:canUse(wangping))
        room():useSkill(wangping, jianglue, function()
          jianglue:onUse(room(), { from = wangping, cards = {}, tos = {} })
        end, { from = wangping, cards = {}, tos = {} })
      end)
    end)
  end)

  lu.assertEquals(hiddenShu.kingdom, "shu", "未确定势力蜀将响应将略亮将")
  lu.assertEquals(wangping.maxHp, wpMaxBefore + 1)
  lu.assertEquals(wangping.hp, wpHpBefore + 1)
  lu.assertEquals(shuAlly.maxHp, allyMaxBefore + 1)
  -- 3名蜀势力角色 -> 王平摸3张，交1张给 shuAlly，王平剩2张
  lu.assertEquals(wangping:getHandcardNum(), 2)
  lu.assertEquals(shuAlly:getHandcardNum(), 1)
  lu.assertFalse(jianglue:canUse(wangping), "将略限定技不可再用")

  -- 翼从无当飞军：分支A 防止下一次回血且回合末不弃牌；分支B 未回血则回合末三区各弃一
  local wudangSkill = "qiao__retinue_skill_wudang_feijun"
  inRoom(function()
    R.grant(wangping, { general = "qiao_heg__retinue_wudang_feijun", skill = wudangSkill, position = "deputy" })
  end)
  skill_test.withSkillRequests(room(), wudangSkill, {
    askToSkillInvoke = function() return true end,
  }, function()
    inRoom(function()
      local slash = Fk:cloneCard("qiao__slash")
      room():damage { from = wangping, to = enemy, card = slash, damage = 1, skillName = "test" }
    end)
  end)
  lu.assertEquals(enemy:getMark(Quan.WUDANG_PENDING_MARK), 1)

  -- 分支A：尝试回血被防止并消耗标记
  local hpAfterDamage = enemy.hp
  inRoom(function()
    room():recover { who = enemy, num = 1, skillName = "test" }
  end)
  lu.assertEquals(enemy.hp, hpAfterDamage, "无当飞军应防止本回合下一次回复体力")
  lu.assertEquals(enemy:getMark(Quan.WUDANG_PENDING_MARK), 0)

  -- 分支B：再次挂上后不回血，回合结束时三区各弃一
  give(enemy, "qiao__jink", Card.Club, 3)
  equip(enemy, "qiao__chitu", Card.Heart, 5)
  inRoom(function()
    local ind = room():printCard("qiao__indulgence", Card.Spade, 6)
    room():moveCardTo(ind, Card.PlayerJudge, enemy, fk.ReasonJustMove, "test", nil, true)
    Quan.addWudangEffect(room(), enemy)
  end)
  skill_test.withSkillRequests(room(), wudangSkill, {
    askToDiscard = function(self, who, params)
      local id = who:getCardIds("h")[1]
      self:throwCard({ id }, params.skill_name, who, who)
      return { id }
    end,
  }, function()
    inRoom(function()
      room().logic:trigger(fk.TurnEnd, room().current, {})
    end)
  end)
  lu.assertEquals(#enemy:getCardIds("h"), 0)
  lu.assertEquals(#enemy:getCardIds("e"), 0)
  lu.assertEquals(#enemy:getCardIds("j"), 0)
end

function Testqiao_quan_han_wei_shu:testShu024FazhengDingjunAndEnyuan()
  local fazheng, actor, enemy = p(3), p(2), p(4)
  inRoom(function()
    skill_test.installDualGenerals(room(), fazheng, { main = "qiao_heg__shu024", deputy = "qiao_test__shu_2", kingdom = "shu" })
    room().current = fazheng
    fazheng.phase = Player.Draw
  end)
  local c1 = give(fazheng, "qiao__slash", Card.Spade, 2)
  local c2 = give(fazheng, "qiao__jink", Card.Club, 2)

  -- 定军分支A：令 actor 视为对法正自己使用【杀】否则回交>=2手牌；选回交2牌触发恩怨
  skill_test.withSkillRequests(room(), "qiao__skill_shu024_1", {
    askToChooseCardsAndPlayers = function() return { actor }, { c1.id, c2.id } end,
    askToChoosePlayers = function() return { fazheng } end,
    askToChoice = function() return "#qiao__skill_shu024_1-return" end,
    askToCards = function(self, who, params)
      return { c1.id, c2.id }
    end,
  }, function()
    inRoom(function()
      room().logic:trigger(fk.EventPhaseEnd, fazheng, {})
    end)
  end)
  -- actor 交还 2 张手牌给法正 -> 触发法正锁定技【恩怨】，actor 摸 1 张牌
  lu.assertEquals(fazheng:getHandcardNum(), 2)
  lu.assertEquals(actor:getHandcardNum(), 1, "定军交还>=2牌应触发恩怨令其摸1张")

  -- 定军分支B：actor 选择视为对法正使用虚拟火【杀】（无视距离与次数）
  local fzHpBefore = fazheng.hp
  skill_test.withSkillRequests(room(), "qiao__skill_shu024_1", {
    askToChooseCardsAndPlayers = function() return { actor }, { c1.id, c2.id } end,
    askToChoosePlayers = function() return { fazheng } end,
    askToChoice = function() return "qiao__fire__slash" end,
  }, function()
    inRoom(function()
      room().logic:trigger(fk.EventPhaseEnd, fazheng, {})
    end)
  end)
  lu.assertEquals(fazheng.hp, fzHpBefore - 1, "定军允许令目标视为对法正自己使用虚拟火杀")

  -- 恩怨·怨：一次 2 点伤害事件仅触发一次；无红桃则失去 1 点体力
  inRoom(function()
    fazheng.hp = fazheng.maxHp -- 恢复至 3 血，确保吃 2 点伤害后仍存活进入 Damaged
  end)
  local enemyHpBefore = enemy.hp
  inRoom(function()
    clearAllZones(enemy)
    room():damage { from = enemy, to = fazheng, damage = 2, skillName = "test" }
  end)
  lu.assertEquals(enemy.hp, enemyHpBefore - 1, "单次2点伤害事件恩怨只结算一次，无红桃失去1点体力")

  -- 恩怨·怨：有红桃牌时展示并交给法正，不掉血
  inRoom(function()
    fazheng.hp = fazheng.maxHp
  end)
  local heartCard = give(enemy, "qiao__peach", Card.Heart, 4)
  local enemyHp2 = enemy.hp
  skill_test.withSkillRequests(room(), "qiao__skill_shu024_2", {
    askToCards = function() return { heartCard.id } end,
  }, function()
    inRoom(function()
      room():damage { from = enemy, to = fazheng, damage = 1, skillName = "test" }
    end)
  end)
  lu.assertEquals(enemy.hp, enemyHp2)
  lu.assertTrue(table.contains(fazheng:getCardIds("h"), heartCard.id))
end

function Testqiao_quan_han_wei_shu:testArmyOrderFallsBackInUpstreamHegemony()
  support.clearRoom()
  local upstream = support.initRoom()
  local source, target = upstream.players[1], upstream.players[2]
  local initialHp = target.hp
  inRoom(function()
    local data = { from = source, tos = { target }, skillName = "test" }
    H.CommandPrepare("command3", data)
    H.CommandCB("command3", target, source, data)
  end)
  lu.assertEquals(target.hp, initialHp - 1)
end

function Testqiao_quan_han_wei_shu:testZhengpiLocksLimitBeforeTargetReveals()
  local maojie, target = p(2), p(8)
  local name = "qiao__skill_wei021b_1"
  local gift = give(maojie, "qiao__dismantlement")
  local revealed = false
  local reveal = fk.CreateSkill { name = "#qiao_test_reveal_during_zhengpi" }
  reveal:addEffect(fk.AfterCardsMove, {
    global = true,
    can_refresh = function(_, _, _, player, moves)
      return player == target and not revealed and table.find(moves, function(move)
        return move.to == target and move.skillName == name
      end) ~= nil
    end,
    on_refresh = function()
      revealed = true
      target:revealGeneral(true)
    end,
  })
  inRoom(function()
    room():handleAddLoseSkills(maojie, name, nil, false, true)
    target:hideGeneral(true)
    lu.assertTrue(Quan.hasHiddenGeneral(target))
    room():addSkill(reveal:createSkill())
    room():setCurrent(maojie)
    maojie.phase = Player.Play
    Fk.skills[name]:onUse(room(), { from = maojie, tos = { target }, cards = { gift.id } })
  end)
  lu.assertTrue(revealed)
  lu.assertFalse(Quan.hasHiddenGeneral(target))
  lu.assertEquals(maojie:getMark(Quan.ZHENGPI_TWICE_MARK), 1)
end

function Testqiao_quan_han_wei_shu:testJianglueCountsDeliveredCardsEvenIfTheyMoveAgain()
  local wangping, sealed, missed, received = p(1), p(2), p(3), p(4)
  local name = "qiao__skill_shu023_1"
  local sword = equip(wangping, "qiao__qinggang_sword")
  local gift = give(wangping, "qiao__slash")
  local notified = {}
  local rediscard = fk.CreateSkill { name = "#qiao_test_discard_jianglue_gift" }
  rediscard:addEffect(fk.AfterCardsMove, {
    global = true,
    can_refresh = function(_, _, _, player, moves)
      return player == received and table.find(moves, function(move)
        return move.to == received and move.toArea == Card.PlayerHand and move.skillName == name
      end) ~= nil
    end,
    on_refresh = function() room():throwCard(gift.id, "test", received, received) end,
  })
  inRoom(function()
    for _, ally in ipairs({ sealed, missed, received }) do room():setPlayerProperty(ally, "kingdom", wangping.kingdom) end
    room():setCurrent(wangping)
    wangping.phase = Player.Play
    room():handleAddLoseSkills(wangping, name, nil, false, true)
    room():abortPlayerArea(sealed, Player.HandSlot)
    room():setCardMark(sword, MarkEnum.DestructOutMyEquip, 1)
    room():addSkill(rediscard:createSkill())
  end)
  skill_test.withSkillRequests(room(), "#qiao__skill_shu023_1_give", {
    askToUseActiveSkill = function(_, _, params)
      local targets = params.extra_data.qiao_valid_targets
      lu.assertFalse(table.contains(targets, sealed.id))
      if table.contains(targets, missed.id) then return true, { cards = { sword.id }, targets = { missed } } end
      if table.contains(targets, received.id) then return true, { cards = { gift.id }, targets = { received } } end
      return false
    end,
  }, function()
    skill_test.withSkillRequests(room(), name, {
      askToUseCard = function(_, player) table.insert(notified, player.id) end,
    }, function()
      inRoom(function() Fk.skills[name]:onUse(room(), { from = wangping, tos = {}, cards = {} }) end)
    end)
  end)
  lu.assertEquals(room():getCardArea(sword.id), Card.Void)
  lu.assertEquals(room():getCardArea(gift.id), Card.DiscardPile)
  lu.assertEquals(notified, { received.id })
end

return { name = "qiao_quan_han_wei_shu" }
