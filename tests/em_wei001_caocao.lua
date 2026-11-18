-- EM(WEI001) 君曹操：正式升变、建安旗、限制、挥鞭与总御核心验收。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local DATA = require "packages.qiao.pkg.qiao_generals.data.zhen_shi_lord_wei"
local W = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wei"
local A = require "packages.qiao.pkg.qiao_mode.rules.ascension"
local ReqPlayCard = require "ltk.core.request_type.play_card"
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
local H = require "packages.hegemony.util"
local Change = require "packages.qiao.pkg.qiao_mode.rules.general_change"

local LORD = "qiao_heg__em_wei001"
local NORMAL = "qiao_heg__wei001"

local function roomProbe(room)
  return string.format(
    "finished=%s co=%s resume_fn=%s current_request=%s last_request=%s",
    tostring(room.game_finished),
    room.main_co and coroutine.status(room.main_co) or "nil",
    tostring(room._resume_fn),
    tostring(room.current_request and room.current_request.command),
    tostring(room.last_request and room.last_request.command))
end

local function inRoom(fn, label)
  local room = FkTest.room
  local entered, completed, result = false, false, nil
  local before = roomProbe(room)
  FkTest.runInRoom(function()
    entered = true
    result = fn()
    completed = true
  end)
  local after = roomProbe(room)
  lu.assertTrue(entered,
    (label or "inRoom") .. " 未进入；before[" .. before .. "] after[" .. after .. "]")
  lu.assertTrue(completed,
    (label or "inRoom") .. " 未完成；before[" .. before .. "] after[" .. after .. "]")
  return result
end
local function p(n) return FkTest.room.players[n] end

local function ascendLord()
  local room = FkTest.room
  inRoom(function()
    skill_test.installBlankGenerals(room, { "wei", "wei", "wei", "wu", "shu", "qun", "jin", "wu" })
    skill_test.installDualGenerals(room, room.players[1], {
      main = NORMAL, deputy = "qiao_test__wei_2", kingdom = "wei",
    })
    room.current = room.players[1]
    A.ascend(room, room.players[1], LORD, "wei", { kind = "lord" })
  end, "setup-ascend")
  lu.assertFalse(FkTest.room.game_finished,
    "setup 结束时房间不应已结束；" .. roomProbe(FkTest.room))
end

Testqiao_em_wei001_caocao = {
  setup = function()
    Fk.currentResponsePattern = nil
    support.initQiaoRoom()
    ascendLord()
  end,
  tearDown = function()
    Fk.currentResponsePattern = nil
    support.clearRoom()
  end,
}

function Testqiao_em_wei001_caocao:testDataAndAscension()
  lu.assertEquals(DATA.generals[1].id, LORD)
  lu.assertEquals(DATA.generals[1].name, "曹操")
  lu.assertEquals(DATA.versions[1].normal, NORMAL)
  local general = assert(Fk.generals[LORD])
  lu.assertTrue(general.hidden)
  lu.assertTrue(general.is_lord)
  lu.assertEquals(general.trueName, "曹操")
  lu.assertEquals(general.prefix, "qiao_prefix_quan")
  lu.assertEquals(Fk:translate(general.prefix), "权")
  lu.assertEquals(Fk:translate(LORD), '<font color="#FFFF00">君</font>曹操')
  lu.assertEquals(p(1).general, LORD)
  lu.assertTrue(p(1):hasSkill(W.JIANAN))
  lu.assertTrue(p(1):hasSkill(W.BANNER), "建安应授予霸者求贤状")
  local banner = Fk.skill_skels["qiao__skill_em_wei001_banner"]
  lu.assertTrue(table.contains(banner.qiaoPools.high, "qiao__skill_wei024_1"), "常令应进入高鱼组")
  lu.assertTrue(table.contains(banner.qiaoPools.low, "qiao__skill_wei020_1"), "奇策应进入低鱼组")
  lu.assertTrue(table.contains(banner.qiaoPools.low, "qiao__skill_wei044_1"), "胆戾应进入低鱼组")
end

function Testqiao_em_wei001_caocao:testBannerCostHideSkillAndCardBoundRestrictions()
  local room, lord, user = FkTest.room, p(1), p(2)
  local deputyBlockedBefore
  local discardCalls, hideCalls, grantCalls = 0, 0, 0
  inRoom(function()
    skill_test.installDualGenerals(room, user, {
      main = "qiao_heg__wei005", deputy = "qiao_test__wei_2", kingdom = "wei",
    })
    deputyBlockedBefore = user:prohibitReveal(true)
    user.phase = Player.Start
    lu.assertTrue(lord:hasShownSkill(W.JIANAN), "君主保持明置有效")
    lu.assertIs(W.lord(room), lord)
  end)
  local originalHide = user.hideGeneral
  local originalAddTemp = W.addTempSkill
  user.hideGeneral = function(self, isDeputy)
    hideCalls = hideCalls + 1
    return originalHide(self, isDeputy)
  end
  W.addTempSkill = function(...)
    grantCalls = grantCalls + 1
    return originalAddTemp(...)
  end
  local ok, err = pcall(function()
    skill_test.withSkillRequests(room, W.BANNER, {
      askToDiscard = function(self, who, params, original)
        if params.skill_name == W.BANNER then
          discardCalls = discardCalls + 1
          local id = who:getCardIds("he")[1]
          self:throwCard({ id }, W.BANNER, who, who)
          return { id }
        end
        return original(self, who, params)
      end,
      askToChoice = function(self, who, params, original)
        if params.skill_name == W.BANNER then
          if table.contains(params.choices, "m") then
            lu.assertTrue(params.detailed ~= true, "暗置位置选择不应带授技说明")
            return "m"
          end
          lu.assertTrue(params.detailed, "授技选项应在确认前显示技能说明")
          for _, skillName in ipairs(params.choices) do
            lu.assertNotEquals(Fk:translate(":" .. skillName), ":" .. skillName,
              "授技选项应有正式技能说明：" .. skillName)
          end
          return "qiao__skill_wei004_1"
        end
        return original(self, who, params)
      end,
    }, function()
      inRoom(function()
        room.logic:trigger(fk.EventPhaseStart, user, PhaseData:new { who = user, phase = Player.Start })
      end)
    end)
  end)
  user.hideGeneral = originalHide
  W.addTempSkill = originalAddTemp
  if not ok then error(err, 0) end
  lu.assertEquals(discardCalls, 1, "弃牌应只支付一次")
  lu.assertEquals(hideCalls, 1, "暗置应只执行一次")
  lu.assertEquals(grantCalls, 1, "授技应只执行一次")
  lu.assertEquals(user.general, "anjiang", "应实际暗置所选主将")
  lu.assertTrue(user:hasSkill("qiao__skill_wei004_1"), "应取得已实装的突袭")
  lu.assertTrue(user:prohibitReveal(false), "所选主将牌不能明置")
  lu.assertEquals(table.concat(user:getTableMark("RevealProhibited"), ","), "m",
    "单次建安只应禁明置所选主将位置")
  lu.assertEquals(user:prohibitReveal(true), deputyBlockedBefore,
    "另一位置受本次限制影响 mark=" .. table.concat(user:getTableMark("RevealProhibited"), ","))
  lu.assertEquals(lord.general, LORD)
  lu.assertTrue(lord:hasShownSkill(W.JIANAN), "君主仍明置有效")
  lu.assertFalse(Exchange.validate(room,
    { player = user, isDeputy = false },
    { player = p(3), isDeputy = false }, { cross_kingdom = true }))
  inRoom(function()
    lu.assertFalse(H.removeGeneral(user, false), "被限制的将牌不能移除")
    lu.assertEquals(user:getMark("__heg_general"), "qiao_heg__wei005")
    lu.assertFalse(room:changeHero(user, "qiao_heg__wei006", false, false, false, false, false),
      "被限制的将牌不能变更")
    lu.assertEquals(user:getMark("__heg_general"), "qiao_heg__wei005")
  end)
  -- 其他角色与君主回合开始不解除；本人下回合开始才解除。
  inRoom(function() room.logic:trigger(fk.TurnStart, p(3), {}) end)
  lu.assertTrue(user:hasSkill("qiao__skill_wei004_1"))
  lu.assertTrue(user:prohibitReveal(false))
  inRoom(function() room.logic:trigger(fk.TurnStart, lord, {}) end)
  lu.assertTrue(user:hasSkill("qiao__skill_wei004_1"), "君主回合开始不提前解除")
  lu.assertTrue(user:prohibitReveal(false))
  inRoom(function() room.logic:trigger(fk.TurnStart, user, {}) end)
  lu.assertFalse(user:hasSkill("qiao__skill_wei004_1"), "本人下回合开始应撤销本次来源")
  lu.assertFalse(user:prohibitReveal(false), "本人下回合开始应解除限制")
end

function Testqiao_em_wei001_caocao:testHuibianDamageDrawAndRecover()
  local room, lord, first, second = FkTest.room, p(1), p(2), p(3)
  local before
  inRoom(function()
    second.hp = second.maxHp - 1
    before = #first:getCardIds("h")
    lord.phase = Player.Play
    Fk.skills[W.HUIBIAN]:onUse(room, { from = lord, tos = { first, second } })
  end)
  lu.assertEquals(first.hp, first.maxHp - 1, "第一名魏角色受到1点伤害")
  lu.assertEquals(#first:getCardIds("h"), before + 2, "受伤者摸两张牌")
  lu.assertEquals(second.hp, second.maxHp, "另一名魏角色回复1点体力")
end

function Testqiao_em_wei001_caocao:testZongyuMovesZhulong()
  local room, lord, other = FkTest.room, p(1), p(2)
  local zhulong
  inRoom(function()
    zhulong = room:printCard("qiao__liulongcanjia", Card.Heart, 5)
    room:moveCardTo(zhulong, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, true, other)
  end)
  skill_test.withSkillRequests(room, W.ZONGYU, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == W.ZONGYU then return true end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      room.logic:trigger(fk.Damaged, lord, { who = lord, from = other, damage = 1 })
    end)
  end)
  lu.assertEquals(room:getCardArea(zhulong), Card.PlayerEquip)
  lu.assertIs(room:getCardOwner(zhulong), lord)
end

function Testqiao_em_wei001_caocao:testZongyuRefusesWhenBothRideSlotsOccupied()
  local room, lord, other = FkTest.room, p(1), p(2)
  local zhulong
  inRoom(function()
    local offensive = room:printCard("qiao__chitu", Card.Spade, 5)
    local defensive = room:printCard("qiao__jueying", Card.Club, 6)
    room:moveCardTo(offensive, Card.PlayerEquip, lord, fk.ReasonJustMove, "test", nil, true, lord)
    room:moveCardTo(defensive, Card.PlayerEquip, lord, fk.ReasonJustMove, "test", nil, true, lord)
    zhulong = room:printCard("qiao__liulongcanjia", Card.Heart, 7)
    room:moveCardTo(zhulong, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, true, other)
  end)
  skill_test.withSkillRequests(room, W.ZONGYU, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == W.ZONGYU then return true end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      room.logic:trigger(fk.Damaged, lord, { who = lord, from = other, damage = 1 })
    end)
  end)
  lu.assertEquals(room:getCardArea(zhulong), Card.DiscardPile, "两个坐骑栏均占用时不得置入")
end

function Testqiao_em_wei001_caocao:testBannerPreservesIndependentRevealAndSkillSources()
  local room, user = FkTest.room, p(2)
  inRoom(function()
    skill_test.installDualGenerals(room, user, {
      main = "qiao_heg__wei005", deputy = "qiao_test__wei_2", kingdom = "wei",
    })
    -- 代表另一独立来源：副将位置本就禁明置。
    room:setPlayerMark(user, "RevealProhibited", { "d" })
    user.phase = Player.Start
  end)
  skill_test.withSkillRequests(room, W.BANNER, {
    askToDiscard = function(self, who, params, original)
      if params.skill_name == W.BANNER then
        local id = who:getCardIds("he")[1]
        self:throwCard({ id }, W.BANNER, who, who)
        return { id }
      end
      return original(self, who, params)
    end,
    askToChoice = function(self, who, params, original)
      if params.skill_name == W.BANNER then
        if table.contains(params.choices, "m") then return "m" end
        return "qiao__skill_wei004_1"
      end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      room.logic:trigger(fk.EventPhaseStart, user, PhaseData:new { who = user, phase = Player.Start })
    end)
  end)
  lu.assertTrue(user:hasSkill("qiao__skill_wei004_1"))
  inRoom(function()
    user:addSkill("qiao__skill_wei004_1", "qiao__skill_wei006_2")
    room.logic:trigger(fk.TurnStart, user, {})
  end)
  lu.assertEquals(table.concat(user:getTableMark("RevealProhibited"), ","), "d",
    "解绑只删本次新增的 m，不删既有来源 d")
  lu.assertTrue(user:prohibitReveal(true), "既有副将禁明置来源保留")
  lu.assertTrue(user:hasSkill("qiao__skill_wei004_1"), "独立同名技能来源不应被到期删除")
end

function Testqiao_em_wei001_caocao:testChangelingCommandBothBranches()
  local room, user, target = FkTest.room, p(2), p(4)
  local card
  inRoom(function()
    skill_test.installDualGenerals(room, user, {
      main = "qiao_heg__wei005", deputy = "qiao_test__wei_2", kingdom = "wei",
    })
    room:handleAddLoseSkills(user, "qiao__skill_wei024_1", nil, false, true)
    card = room:printCard("qiao__jink", Card.Heart, 4)
    room:obtainCard(user, card, false, fk.ReasonJustMove)
    user.phase = Player.Start
  end)
  local originalCommand = H.askToCommand
  local executed = true
  H.askToCommand = function() return executed, {} end
  skill_test.withSkillRequests(room, "qiao__skill_wei024_1", {
    askToChoosePlayers = function(self, who, params, original)
      if params.skill_name == "qiao__skill_wei024_1" then return { target } end
      return original(self, who, params)
    end,
    askToCards = function(self, who, params, original)
      if params.skill_name == "qiao__skill_wei024_1" then return { card.id } end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      room.logic:trigger(fk.EventPhaseStart, user, PhaseData:new { who = user, phase = Player.Start })
    end)
  end)
  H.askToCommand = originalCommand
  lu.assertTrue(table.contains(target:getCardIds("h"), card.id), "常令应把手牌交给目标")
  lu.assertFalse(table.contains(user:getCardIds("h"), card.id))
end

function Testqiao_em_wei001_caocao:testQiceUsesAllHandOnceAsTrick()
  local room, user, target = FkTest.room, p(2), p(4)
  local trick
  for _, id in ipairs(Fk:getAllCardIds()) do
    local c = Fk:getCardById(id)
    if c:isCommonTrick() and c.trueName == "ex_nihilo" then trick = c.name break end
  end
  lu.assertNotNil(trick, "缺少无中生有牌型")
  local first, second
  inRoom(function()
    skill_test.installDualGenerals(room, user, {
      main = "qiao_heg__wei005", deputy = "qiao_test__wei_2", kingdom = "wei",
    })
    room:handleAddLoseSkills(user, "qiao__skill_wei020_1", nil, false, true)
    first = room:printCard("qiao__jink", Card.Heart, 5)
    second = room:printCard("qiao__jink", Card.Club, 6)
    room:obtainCard(user, first, false, fk.ReasonJustMove)
    room:obtainCard(user, second, false, fk.ReasonJustMove)
    user.phase = Player.Play
  end)
  local skill = Fk.skills["qiao__skill_wei020_1"]
  lu.assertTrue(skill:canUse(user))
  inRoom(function()
    skill.interaction = skill.interaction or {}
    skill.interaction.data = trick
    skill:onUse(room, { from = user, tos = {} })
    skill.interaction.data = nil
  end)
  lu.assertEquals(#user:getCardIds("h"), 2, "两张手牌转化为无中生有，只摸两张")
end

function Testqiao_em_wei001_caocao:testDanliDrawUpToFive()
  local room, user, source = FkTest.room, p(2), p(4)
  inRoom(function()
    skill_test.installDualGenerals(room, user, {
      main = "qiao_heg__wei005", deputy = "qiao_test__wei_2", kingdom = "wei",
    })
    room:handleAddLoseSkills(user, "qiao__skill_wei044_1", nil, false, true)
    for i = 1, 8 do
      local c = room:printCard("qiao__jink", Card.Heart, i)
      room:obtainCard(source, c, false, fk.ReasonJustMove)
    end
    while #user:getCardIds("h") > 0 do
      local id = user:getCardIds("h")[1]
      room:moveCardTo(id, Card.DiscardPile, nil, fk.ReasonDiscard, "test", nil, true, user)
    end
  end)
  local before = #user:getCardIds("h")
  skill_test.withSkillRequests(room, "qiao__skill_wei044_1", {
    askToChoice = function(self, who, params, original)
      if params.skill_name == "qiao__skill_wei044_1" then return "1" end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      room.logic:trigger(fk.Damaged, user, { who = user, from = source, damage = 1 })
    end)
  end)
  lu.assertEquals(#user:getCardIds("h") - before, 5, "胆戾选项1至多摸五张")
end

function Testqiao_em_wei001_caocao:testDanliRemoveDeputyRecoverAndSourceDiscard()
  local room, user, source = FkTest.room, p(2), p(4)
  inRoom(function()
    skill_test.installDualGenerals(room, user, {
      main = "qiao_heg__wei005", deputy = "qiao_test__wei_2", kingdom = "wei",
    })
    room:handleAddLoseSkills(user, "qiao__skill_wei044_1", nil, false, true)
    user.hp = user.maxHp - 1
    for i = 1, 5 do
      local c = room:printCard("qiao__jink", Card.Heart, i)
      room:obtainCard(source, c, false, fk.ReasonJustMove)
    end
  end)
  local originalDiscard = room.askToDiscard
  local discarded = 0
  room.askToDiscard = function(self, who, params)
    if params.skill_name == "qiao__skill_wei044_1" then
      local ids = {}
      for i = 1, params.min_num do ids[#ids + 1] = who:getCardIds("h")[i] end
      self:throwCard(ids, params.skill_name, who, who)
      discarded = #ids
      return ids
    end
    return originalDiscard(self, who, params)
  end
  skill_test.withSkillRequests(room, "qiao__skill_wei044_1", {
    askToChoice = function(self, who, params, original)
      if params.skill_name == "qiao__skill_wei044_1" then return "2" end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      room.logic:trigger(fk.Damaged, user, { who = user, from = source, damage = 1 })
    end)
  end)
  room.askToDiscard = originalDiscard
  lu.assertFalse(user:isWounded(), "胆戾选项2应回复1点体力")
  lu.assertNotEquals(user.deputyGeneral, "qiao_test__wei_2", "应实际移除副将")
  lu.assertEquals(discarded, 5, "来源应弃手至与受伤角色相同")
end

function Testqiao_em_wei001_caocao:testChangelingNotExecutedAddsDrawPhaseCards()
  local room, user, target = FkTest.room, p(2), p(4)
  local card
  inRoom(function()
    skill_test.installDualGenerals(room, user, {
      main = "qiao_heg__wei005", deputy = "qiao_test__wei_2", kingdom = "wei",
    })
    room:handleAddLoseSkills(user, "qiao__skill_wei024_1", nil, false, true)
    card = room:printCard("qiao__jink", Card.Heart, 4)
    room:obtainCard(user, card, false, fk.ReasonJustMove)
    user.phase = Player.Start
  end)
  local originalCommand = H.askToCommand
  H.askToCommand = function() return false, {} end
  skill_test.withSkillRequests(room, "qiao__skill_wei024_1", {
    askToChoosePlayers = function(self, who, params, original)
      if params.skill_name == "qiao__skill_wei024_1" then return { target } end
      return original(self, who, params)
    end,
    askToCards = function(self, who, params, original)
      if params.skill_name == "qiao__skill_wei024_1" then return { card.id } end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      room.logic:trigger(fk.EventPhaseStart, user, PhaseData:new { who = user, phase = Player.Start })
    end)
  end)
  H.askToCommand = originalCommand
  local data = { n = 2 }
  inRoom(function() room.logic:trigger(fk.DrawNCards, user, data) end)
  lu.assertEquals(data.n, 5, "未执行军令时本回合摸牌阶段多摸三张")
end

function Testqiao_em_wei001_caocao:testQiceTargetLimitAndFormalPool()
  local room, user = FkTest.room, p(2)
  local card
  inRoom(function()
    skill_test.installDualGenerals(room, user, {
      main = "qiao_heg__wei005", deputy = "qiao_test__wei_2", kingdom = "wei",
    })
    card = room:printCard("qiao__jink", Card.Heart, 7)
    room:obtainCard(user, card, false, fk.ReasonJustMove)
    for _, id in ipairs(table.simpleClone(user:getCardIds("h"))) do
      if id ~= card.id then
        room:moveCardTo(id, Card.DiscardPile, nil, fk.ReasonDiscard, "test", nil, true, user)
      end
    end
    user.phase = Player.Play
    room:handleAddLoseSkills(user, "qiao__skill_wei020_1", nil, false, true)
  end)
  local skill = Fk.skills["qiao__skill_wei020_1"]
  inRoom(function()
    skill.interaction = skill.interaction or {}
    skill.interaction.data = "qiao__collateral"
    lu.assertFalse(skill:feasible(user, { p(3), p(4) }, {}),
      "一张材料不能指定两个目标")
    skill.interaction.data = nil
  end)
  local pool = Fk.skill_skels["qiao__skill_wei020_1"].qiaoTrickNames()
  for _, name in ipairs(pool) do
    lu.assertTrue(name:startsWith("qiao__"), "不得出现上游卡名: " .. name)
    lu.assertNotEquals(name, "qiao__threaten_emperor")
    lu.assertNotNil(Fk.all_card_types[name])
  end
end

function Testqiao_em_wei001_caocao:testQiceDeputyChangePublicEntry()
  local room, user = FkTest.room, p(2)
  local oldDeputy, hpBefore
  inRoom(function()
    skill_test.installDualGenerals(room, user, {
      main = "qiao_heg__wei005", deputy = "qiao_test__wei_2", kingdom = "wei",
    })
    oldDeputy = user.deputyGeneral
    user:hideGeneral(true)
    hpBefore = user.hp
    lu.assertTrue(#Change.candidates(room, user, true) > 0, "应有同势力候选")
  end)
  local chosen
  skill_test.withSkillRequests(room, "qiao__skill_wei020_1", {
    askToChoice = function(self, who, params, original)
      if params.skill_name == "qiao__skill_wei020_1" then
        chosen = params.choices[1]
        return chosen
      end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      local ok, name = Change.changeDeputy(room, user, {
        num = 3, skill_name = "qiao__skill_wei020_1",
      })
      lu.assertTrue(ok, "公共变更入口应成功: " .. tostring(name))
    end)
  end)
  lu.assertNotNil(chosen)
  lu.assertEquals(user.deputyGeneral, chosen, "新副将应明置加入")
  lu.assertEquals(user.hp, hpBefore, "变更副将不重算体力")
  lu.assertTrue(table.contains(room.general_pile, oldDeputy), "原牌应回将池")
  lu.assertFalse(table.contains(room.general_pile, chosen), "候选不应重复留在池中")
  -- 建安锁定位置：不发起变更、不动将池。
  local pileBefore = #room.general_pile
  inRoom(function()
    W.bind(room, user, true, user.deputyGeneral)
    local ok = Change.changeDeputy(room, user, { num = 3, skill_name = "qiao__skill_wei020_1" })
    lu.assertFalse(ok, "被建安锁定的副将位置不能变更")
    lu.assertEquals(#room.general_pile, pileBefore, "拒绝时不得改动将池")
    W.unbind(room, user)
  end)
end


function Testqiao_em_wei001_caocao:testQiceFullUseThenChangeDeputy()
  local room, user = FkTest.room, p(2)
  local trick
  for _, id in ipairs(Fk:getAllCardIds()) do
    local c = Fk:getCardById(id)
    if c:isCommonTrick() and c.trueName == "ex_nihilo" then trick = c.name break end
  end
  lu.assertNotNil(trick)
  local oldDeputy, chosen
  inRoom(function()
    skill_test.installDualGenerals(room, user, {
      main = "qiao_heg__wei005", deputy = "qiao_test__wei_2", kingdom = "wei",
    })
    room:handleAddLoseSkills(user, "qiao__skill_wei020_1", nil, false, true)
    for i = 1, 2 do
      local c = room:printCard("qiao__jink", Card.Heart, i)
      room:obtainCard(user, c, false, fk.ReasonJustMove)
    end
    oldDeputy = user.deputyGeneral
    user.phase = Player.Play
  end)
  local skill = Fk.skills["qiao__skill_wei020_1"]
  skill_test.withSkillRequests(room, "qiao__skill_wei020_1", {
    askToChoice = function(self, who, params, original)
      if params.skill_name == "qiao__skill_wei020_1" then
        if table.contains(params.choices, "changeDeputy") then return "changeDeputy" end
        chosen = params.choices[1]
        return chosen
      end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      skill.interaction = skill.interaction or {}
      skill.interaction.data = trick
      skill:onUse(room, { from = user, tos = {} })
      skill.interaction.data = nil
    end)
  end)
  lu.assertNotNil(chosen)
  lu.assertEquals(user.deputyGeneral, chosen, "奇策使用后变更副将应实际换将")
  lu.assertNotEquals(user.deputyGeneral, oldDeputy)
  lu.assertTrue(table.contains(room.general_pile, oldDeputy), "旧副将应回将池")
  lu.assertFalse(table.contains(room.general_pile, chosen), "新副将不应留在池中")
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

function Testqiao_em_wei001_caocao:testClientQiceCanUse()
  local room, user = FkTest.room, p(2)
  inRoom(function()
    room:handleAddLoseSkills(user, "qiao__skill_wei020_1", nil, false, true)
    user.phase = Player.Play
  end)
  withClientRoom(room, function(clients)
    local me = clients[2]
    lu.assertNil(me.room)
    lu.assertTrue(Fk.skills["qiao__skill_wei020_1"]:canUse(me), "客户端奇策应可用")
  end)
end


function Testqiao_em_wei001_caocao:testQihuClientSkillButtonWithoutPlayerRoom()
  local room, user, target = FkTest.room, p(2), p(3)
  inRoom(function()
    room:handleAddLoseSkills(user, "qiao__skill_wei013_1", nil, false, true)
    for _, who in ipairs({ user, target }) do
      local c = room:printCard("qiao__jink", Card.Heart, 2)
      room:obtainCard(who, c, false, fk.ReasonJustMove)
    end
    user.hp = 2
    target.hp = 4
    user.phase = Player.Play
  end)
  withClientRoom(room, function(clients)
    local me = clients[2]
    lu.assertNil(me.room, "真实 ClientPlayer 不应有 room 字段")
    local handler = ReqPlayCard:new(me)
    handler.skill_name = "qiao__skill_wei013_1"
    handler:setup()
    lu.assertTrue(handler:skillButtonValidity("qiao__skill_wei013_1"), "有体力更高候选时驱虎应可用")
    me:setSkillUseHistory("qiao__skill_wei013_1", 1, Player.HistoryPhase)
    local exhausted = ReqPlayCard:new(me)
    exhausted.skill_name = "qiao__skill_wei013_1"
    exhausted:setup()
    lu.assertFalse(exhausted:skillButtonValidity("qiao__skill_wei013_1"), "本阶段已发动后驱虎应禁用")
    exhausted:_finish()
    me:setSkillUseHistory("qiao__skill_wei013_1", 0, Player.HistoryPhase)
    for index, cp in ipairs(clients) do
      if index ~= 2 then
        cp.player_cards[Player.Hand] = {}
        cp.player_cards[Player.Equip] = {}
      end
    end
    lu.assertFalse(handler:skillButtonValidity("qiao__skill_wei013_1"), "无合法拼点候选时驱虎应禁用")
    handler:_finish()
  end)
end
return { name = "qiao_em_wei001_caocao" }
