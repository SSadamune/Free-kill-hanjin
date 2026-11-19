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
local withClientRoom

--- 公开势力未确定，但保留真实武将牌（用于验证不读取暗将牌面势力）。
local function setUnknown(room, player)
  player.kingdom = "unknown"
  room:setPlayerProperty(player, "kingdom", "unknown")
  room:setPlayerMark(player, "__heg_kingdom", nil)
  room:setPlayerMark(player, "__heg_wild", 0)
end

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
  local mark = "@!!" .. W.BANNER
  lu.assertEquals(p(1):getMark(mark), "旗")
  lu.assertEquals(Fk:translate(":" .. mark), Fk:translate(":" .. W.BANNER))
  inRoom(function() FkTest.room:handleAddLoseSkills(p(1), "-" .. W.BANNER, W.JIANAN, false, true) end)
  lu.assertEquals(p(1):getMark(mark), 0)
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

function Testqiao_em_wei001_caocao:testHuibianDamageDrawThenRecoverSelection()
  local room, lord, first, second = FkTest.room, p(1), p(2), p(3)
  local before, askedTargets, askedAfterResolve
  inRoom(function()
    second.hp = second.maxHp - 1
    first.hp = first.maxHp
    before = #first:getCardIds("h")
    lord.phase = Player.Play
    local skill = Fk.skills[W.HUIBIAN]
    lu.assertEquals(skill.target_num, 1, "首段只预选一名目标")
    lu.assertTrue(skill:targetFilter(lord, first, {}),
      "首段只要求魏势力，不要求受伤或存在另一名可回复者")
  end)
  skill_test.withSkillRequests(room, W.HUIBIAN, {
    askToChoosePlayers = function(self, who, params, original)
      if params.skill_name ~= W.HUIBIAN then return original(self, who, params) end
      askedTargets = table.simpleClone(params.targets)
      -- 进入回复选择时，首段的伤害与摸牌必须已经结算。
      askedAfterResolve = first.hp == first.maxHp - 1
        and #first:getCardIds("h") == before + 2
      return { second }
    end,
  }, function()
    inRoom(function()
      Fk.skills[W.HUIBIAN]:onUse(room, { from = lord, tos = { first } })
    end)
  end)
  lu.assertTrue(askedAfterResolve, "回复目标应在首段伤害与摸牌结算后选择")
  lu.assertNotNil(askedTargets)
  lu.assertFalse(table.contains(askedTargets, first), "回复者不能与受伤者相同")
  lu.assertTrue(table.contains(askedTargets, second), "已受伤的魏角色应进入回复候选")
  lu.assertEquals(first.hp, first.maxHp - 1, "第一名魏角色受到1点伤害")
  lu.assertEquals(#first:getCardIds("h"), before + 2, "受伤者摸两张牌")
  lu.assertEquals(second.hp, second.maxHp, "另一名魏角色回复1点体力")
end

function Testqiao_em_wei001_caocao:testHuibianSoloWeiResolvesOnlyFirstSegment()
  local room, lord = FkTest.room, p(1)
  local askCalls, before = 0, 0
  inRoom(function()
    -- 其他角色均非魏：只有曹操本人可作首段目标，且没有第二段合法对象。
    for index = 2, #room.players do
      local other = room.players[index]
      other.kingdom = "wu"
      room:setPlayerProperty(other, "kingdom", "wu")
      room:setPlayerMark(other, "__heg_kingdom", "wu")
    end
    lord.hp = lord.maxHp
    lord.phase = Player.Play
    before = #lord:getCardIds("h")
    lu.assertTrue(Fk.skills[W.HUIBIAN]:canUse(lord),
      "只有自己为魏时仍可发动首段")
  end)
  skill_test.withSkillRequests(room, W.HUIBIAN, {
    askToChoosePlayers = function(self, who, params, original)
      if params.skill_name == W.HUIBIAN then
        askCalls = askCalls + 1
        return {}
      end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      Fk.skills[W.HUIBIAN]:onUse(room, { from = lord, tos = { lord } })
    end)
  end)
  lu.assertEquals(lord.hp, lord.maxHp - 1, "自己作为首段目标承受1点伤害")
  lu.assertEquals(#lord:getCardIds("h"), before + 2, "自己摸两张牌")
  lu.assertEquals(askCalls, 0, "没有另一名可回复的魏角色时不得发起第二段选择")
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

-- 霸者求贤状的授技属于角色，不附在将牌上。暗将恰好印刷同名技能时：
-- 独立来源仍可实际发动；发动不得明置该暗将；到期只撤本次来源。
local function expireWithoutRevealing(user)
  -- 临时来源先到期，上游随后仍会提供一次普通明置。明确取消以隔离这两个流程。
  FkTest.cleanNextReplies(user)
  FkTest.setNextReplies(user, { { "Cancel" } })
  inRoom(function() FkTest.room.logic:trigger(fk.TurnStart, user, {}) end)
  FkTest.cleanNextReplies(user)
end

function Testqiao_em_wei001_caocao:testBannerSameNameAsHiddenGeneralStaysIndependent()
  local room, user, target = FkTest.room, p(2), p(5)
  local SCOUT = "qiao__skill_wei016_1" -- 骁果：副将乐进印刷
  local basic, junk
  inRoom(function()
    skill_test.installDualGenerals(room, user, {
      main = "qiao_heg__wei005", deputy = "qiao_heg__wei016", kingdom = "wei",
    })
    user:hideGeneral(true) -- 副将乐进暗置，骁果只以 fake 存在
    basic = room:printCard("qiao__slash", Card.Spade, 3)
    junk = room:printCard("qiao__jink", Card.Heart, 4)
    room:obtainCard(user, basic, false, fk.ReasonJustMove)
    room:obtainCard(user, junk, false, fk.ReasonJustMove)
    user.phase = Player.Start
    lu.assertFalse(user:hasSkill(SCOUT), "暗置乐进的同名技能尚未激活")
  end)

  skill_test.withSkillRequests(room, W.BANNER, {
    askToDiscard = function(self, who, params, original)
      if params.skill_name ~= W.BANNER then return original(self, who, params) end
      self:throwCard({ junk.id }, W.BANNER, who, who)
      return { junk.id }
    end,
    askToChoice = function(self, who, params, original)
      if params.skill_name ~= W.BANNER then return original(self, who, params) end
      if table.contains(params.choices, "m") then return "m" end
      lu.assertTrue(table.contains(params.choices, SCOUT),
        "副将乐进暗置后，骁果不在公开场上，应可被选择")
      return SCOUT
    end,
  }, function()
    inRoom(function()
      room.logic:trigger(fk.EventPhaseStart, user, PhaseData:new { who = user, phase = Player.Start })
    end)
  end)

  lu.assertTrue(user:hasSkill(SCOUT), "应取得独立来源的骁果")
  lu.assertTrue(W.isTempProvided(user, SCOUT), "应记录本次授技来源")
  lu.assertEquals(user.general, "anjiang", "主将仍暗置")
  lu.assertEquals(user.deputyGeneral, "anjiang", "暗置乐进保持暗置")

  -- 真实发动骁果：触发入口不应因暗将印刷同名技能而明置乐进。
  local targetHp
  inRoom(function() targetHp = target.hp end)
  FkTest.setNextReplies(user, { FkTest.ReplyDiscard({ basic.id }) })
  inRoom(function()
    room.logic:trigger(fk.EventPhaseStart, target,
      PhaseData:new { who = target, phase = Player.Start, reason = "game_rule" })
  end)
  lu.assertEquals(target.hp, targetHp - 1, "独立来源的骁果应实际造成伤害")
  lu.assertEquals(user.general, "anjiang", "临时来源发动不得明置主将")
  lu.assertEquals(user.deputyGeneral, "anjiang", "同名暗将不得被明置")

  expireWithoutRevealing(user)
  lu.assertFalse(W.isTempProvided(user, SCOUT), "到期应撤销本次来源")
  lu.assertFalse(user:hasSkill(SCOUT), "到期后暗将 fake 不提供可用技能")
  lu.assertEquals(user.deputyGeneral, "anjiang", "到期不改动暗将状态")
end

-- 暗将同名技能已预亮时，预亮不是可代替本次授技的独立来源；到期只撤本次来源。
function Testqiao_em_wei001_caocao:testBannerTempSourceSurvivesPrelightOnlySource()
  local room, user = FkTest.room, p(2)
  local SCOUT = "qiao__skill_wei016_1"
  local junk
  inRoom(function()
    skill_test.installDualGenerals(room, user, {
      main = "qiao_heg__wei005", deputy = "qiao_heg__wei016", kingdom = "wei",
    })
    user:hideGeneral(true)
    user:prelightSkill(Fk.skills[SCOUT], true)
    junk = room:printCard("qiao__jink", Card.Club, 5)
    room:obtainCard(user, junk, false, fk.ReasonJustMove)
    user.phase = Player.Start
  end)
  lu.assertTrue(user:hasSkill(SCOUT), "预亮使暗将同名技能暂时可用")

  skill_test.withSkillRequests(room, W.BANNER, {
    askToDiscard = function(self, who, params, original)
      if params.skill_name ~= W.BANNER then return original(self, who, params) end
      self:throwCard({ junk.id }, W.BANNER, who, who)
      return { junk.id }
    end,
    askToChoice = function(self, who, params, original)
      if params.skill_name ~= W.BANNER then return original(self, who, params) end
      if table.contains(params.choices, "m") then return "m" end
      return SCOUT
    end,
  }, function()
    inRoom(function()
      room.logic:trigger(fk.EventPhaseStart, user, PhaseData:new { who = user, phase = Player.Start })
    end)
  end)
  lu.assertTrue(W.isTempProvided(user, SCOUT),
    "预亮来源不应阻止本次独立授技记账")
  lu.assertTrue(table.contains(user.derivative_skills[Fk.skills[W.SOURCE]] or {},
    Fk.skills[SCOUT]), "预亮之外应实际建立本次导数来源")

  expireWithoutRevealing(user)
  lu.assertFalse(W.isTempProvided(user, SCOUT), "到期撤销本次来源")
  lu.assertTrue(user:hasSkill(SCOUT), "预亮来源作为暗将状态保留")
  lu.assertTrue(table.contains(user.prelighted_skills, Fk.skills[SCOUT]),
    "到期只撤本次来源，不撤销原有预亮")
end

-- 同位置：霸者暗置乐进并取得同名骁果。上游 reveal_prohibited 只因被绑位置
-- 仍印刷同名技能而按名失效；角色持有本次独立来源时应可实际发动，暗将仍禁亮。
function Testqiao_em_wei001_caocao:testBannerSameNameOnBoundPositionBypassesRevealInvalidity()
  local room, user, target = FkTest.room, p(2), p(5)
  local SCOUT = "qiao__skill_wei016_1" -- 骁果：被暗置的主将乐进印刷
  local basic, junk
  inRoom(function()
    skill_test.installDualGenerals(room, user, {
      main = "qiao_heg__wei016", deputy = "qiao_heg__wei005", kingdom = "wei",
    })
    basic = room:printCard("qiao__slash", Card.Spade, 6)
    junk = room:printCard("qiao__jink", Card.Heart, 7)
    room:obtainCard(user, basic, false, fk.ReasonJustMove)
    room:obtainCard(user, junk, false, fk.ReasonJustMove)
    user.phase = Player.Start
  end)

  skill_test.withSkillRequests(room, W.BANNER, {
    askToDiscard = function(self, who, params, original)
      if params.skill_name ~= W.BANNER then return original(self, who, params) end
      self:throwCard({ junk.id }, W.BANNER, who, who)
      return { junk.id }
    end,
    askToChoice = function(self, who, params, original)
      if params.skill_name ~= W.BANNER then return original(self, who, params) end
      if table.contains(params.choices, "m") then return "m" end
      lu.assertTrue(table.contains(params.choices, SCOUT),
        "暗置乐进后，同名骁果仍应作为场上没有的技能进入候选")
      return SCOUT
    end,
  }, function()
    inRoom(function()
      room.logic:trigger(fk.EventPhaseStart, user, PhaseData:new { who = user, phase = Player.Start })
    end)
  end)

  lu.assertTrue(user:hasSkill(SCOUT), "本次独立来源不应被禁亮按名失效误伤")
  lu.assertTrue(user:prohibitReveal(false), "被暗置的乐进仍不能明置")
  lu.assertEquals(user.general, "anjiang")
  lu.assertTrue(table.contains(user.derivative_skills[Fk.skills[W.SOURCE]] or {},
    Fk.skills[SCOUT]), "应实际建立本次导数来源")

  -- ClientPlayer 没有 room 字段；来源按可见玩家标记同步，客户端同样放行。
  withClientRoom(room, function(clients)
    local me = clients[2]
    lu.assertNil(me.room)
    lu.assertTrue(me:hasSkill(SCOUT), "客户端应按同步来源跳过误判")
  end)

  local targetHp
  inRoom(function() targetHp = target.hp end)
  FkTest.setNextReplies(user, { FkTest.ReplyDiscard({ basic.id }) })
  inRoom(function()
    room.logic:trigger(fk.EventPhaseStart, target,
      PhaseData:new { who = target, phase = Player.Start, reason = "game_rule" })
  end)
  lu.assertEquals(target.hp, targetHp - 1, "独立来源的骁果应实际造成伤害")
  lu.assertEquals(user.general, "anjiang", "临时来源发动不得明置乐进")
  lu.assertTrue(user:prohibitReveal(false), "发动后仍不能明置")

  -- 只绕开 reveal_prohibited 的误判；其他 invalidity 仍须生效。
  inRoom(function()
    room:setPlayerMark(user, MarkEnum.InvalidSkills, { [SCOUT] = true })
  end)
  lu.assertFalse(user:hasSkill(SCOUT), "其他 invalidity 不得被本豁免绕过")
  inRoom(function() room:setPlayerMark(user, MarkEnum.InvalidSkills, 0) end)

  expireWithoutRevealing(user)
  lu.assertFalse(W.isTempProvided(user, SCOUT), "到期撤销本次来源")
  lu.assertEquals(user.general, "anjiang")
  lu.assertFalse(user:hasSkill(SCOUT), "到期后禁亮暗将的同名技能不再可用")
  lu.assertFalse(user:prohibitReveal(false), "到期解除禁亮")
  lu.assertNil(W.record(room, user), "到期清除位置记录")
end

-- 到期时已有预亮：M.expire 仍按本次来源撤掉 derivative_skills 记账，
-- 但不撤销暗将自身的预亮状态。
function Testqiao_em_wei001_caocao:testBannerSameNameExpiryRemovesDerivativeWithPrelight()
  local room, user = FkTest.room, p(2)
  local SCOUT = "qiao__skill_wei016_1"
  local junk
  inRoom(function()
    skill_test.installDualGenerals(room, user, {
      main = "qiao_heg__wei016", deputy = "qiao_heg__wei005", kingdom = "wei",
    })
    junk = room:printCard("qiao__jink", Card.Club, 8)
    room:obtainCard(user, junk, false, fk.ReasonJustMove)
    user.phase = Player.Start
  end)
  skill_test.withSkillRequests(room, W.BANNER, {
    askToDiscard = function(self, who, params, original)
      if params.skill_name ~= W.BANNER then return original(self, who, params) end
      self:throwCard({ junk.id }, W.BANNER, who, who)
      return { junk.id }
    end,
    askToChoice = function(self, who, params, original)
      if params.skill_name ~= W.BANNER then return original(self, who, params) end
      if table.contains(params.choices, "m") then return "m" end
      return SCOUT
    end,
  }, function()
    inRoom(function()
      room.logic:trigger(fk.EventPhaseStart, user, PhaseData:new { who = user, phase = Player.Start })
    end)
  end)
  inRoom(function() user:prelightSkill(Fk.skills[SCOUT], true) end)
  lu.assertTrue(table.contains(user.derivative_skills[Fk.skills[W.SOURCE]] or {},
    Fk.skills[SCOUT]), "预亮之外仍应有本次导数来源")

  expireWithoutRevealing(user)
  lu.assertFalse(table.contains(user.derivative_skills[Fk.skills[W.SOURCE]] or {},
    Fk.skills[SCOUT]), "到期应按来源撤掉导数记账")
  lu.assertTrue(table.contains(user.prelighted_skills, Fk.skills[SCOUT]),
    "到期不撤销暗将自身的预亮")
  lu.assertTrue(user:hasSkill(SCOUT), "禁亮解除后预亮仍可用")
end

-- 真实连续回合：自己的准备阶段发动 → 挟天子额外回合（默认阶段表含准备）再次
-- 发动 → 下一次自己的回合开始时到期。两次后两张武将牌都已暗置，第三次没有
-- “可合法暗置的武将牌”，不是整局限次；按常规流程明置后才可再次发动。
function Testqiao_em_wei001_caocao:testBannerExtraTurnExpiresThenThirdNeedsPublicGeneral()
  local room, user = FkTest.room, p(2)
  local THREATEN = "qiao__threaten_emperor_skill"
  local FIRST = "qiao__skill_wei004_1"
  local threat, pay, junk1, junk2
  local discards, secondActivations, thirdAsks, thirdActivations = 0, 0, 0, 0

  inRoom(function()
    skill_test.installDualGenerals(room, user, {
      main = "qiao_heg__wei005", deputy = "qiao_test__wei_2", kingdom = "wei",
    })
    threat = room:printCard("qiao__threaten_emperor", Card.Spade, 1)
    pay = room:printCard("qiao__jink", Card.Heart, 2)
    junk1 = room:printCard("qiao__jink", Card.Club, 3)
    junk2 = room:printCard("qiao__jink", Card.Diamond, 4)
    for _, card in ipairs({ threat, pay, junk1, junk2 }) do
      room:obtainCard(user, card, false, fk.ReasonJustMove)
    end
    user.phase = Player.Start
  end)

  -- 挟天子的 gainAnExtraTurn 未传 phases；TurnData 默认阶段表包含准备阶段。
  -- 不能按“仅出牌阶段的额外回合”假设，否则会误判第二次发动的时机。
  local realExtra = TurnData:new(user, THREATEN)
  lu.assertNotNil(table.find(realExtra.phase_table, function(phase)
    return phase.phase == Player.Start
  end), "挟天子的真实额外回合应包含准备阶段")

  local function bannerHandlers(onDiscard, onChoice)
    return {
      askToDiscard = function(self, who, params, original)
        if onDiscard ~= nil then onDiscard() end
        local id = table.find(who:getCardIds("he"), function(cardId)
          return cardId ~= threat.id and cardId ~= pay.id
        end)
        lu.assertNotNil(id, "霸者求贤状应有可弃置的牌")
        self:throwCard({ id }, W.BANNER, who, who)
        discards = discards + 1
        return { id }
      end,
      askToChoice = function(self, who, params, original)
        if onChoice ~= nil then onChoice(params) end
        if table.contains(params.choices, "m") then return "m" end
        lu.assertTrue(table.contains(params.choices, FIRST),
          "授技候选应包含突袭：" .. table.concat(params.choices, ","))
        return FIRST
      end,
    }
  end

  skill_test.withSkillRequests(room, W.BANNER, bannerHandlers(), function()
    inRoom(function()
      room.logic:trigger(fk.EventPhaseStart, user, PhaseData:new { who = user, phase = Player.Start })
    end)
  end)
  lu.assertEquals(discards, 1, "第一次应支付一张牌")
  lu.assertEquals(user.general, "anjiang", "第一次应暗置主将")
  lu.assertEquals(user.deputyGeneral, "qiao_test__wei_2")
  lu.assertTrue(user:hasSkill(FIRST), "第一次应取得突袭")
  lu.assertTrue(user:prohibitReveal(false), "被暗置的主将不能明置")
  lu.assertFalse(user:prohibitReveal(true), "未被暗置的副将不受本次限制")
  local firstRec = W.record(room, user)
  lu.assertNotNil(firstRec, "第一次暗置应建立限制记录")
  lu.assertFalse(firstRec.isDeputy)
  lu.assertTrue(W.isPositionRestricted(room, user, false), "主将的移除/交换/变更应受限")
  lu.assertFalse(W.isPositionRestricted(room, user, true), "副将不受本次限制")

  -- 用真实挟天子结束本次出牌阶段，并在回合结束时支付、排队额外回合。
  inRoom(function()
    room:setCurrent(user)
    user.phase = Player.Play
  end)
  FkTest.setNextReplies(user, { FkTest.ReplyCard(threat, { user }) })
  inRoom(function()
    GameEvent.Phase:create(PhaseData:new { who = user, phase = Player.Play }):exec()
  end)
  lu.assertEquals(user:getMark("qiao__threaten_emperor-turn"), 1,
    "挟天子应实际结束本次出牌阶段")
  skill_test.withSkillRequests(room, THREATEN, {
    askToDiscard = function(self, who, params, original)
      self:throwCard({ pay.id }, THREATEN, who, who)
      return { pay.id }
    end,
  }, function()
    inRoom(function()
      room.logic:trigger(fk.TurnEnd, user, TurnData:new(user, "game_rule", { Player.Start }))
    end)
  end)
  lu.assertEquals(#room.extra_turn_list, 1, "支付后应排队获得额外回合")
  lu.assertIs(room.extra_turn_list[1].who, user)

  -- 额外回合的回合开始明置询问确定取消：保持主将暗置，使第二次发动暗置副将。
  FkTest.setNextReplies(user, { { "Cancel" } })
  skill_test.withSkillRequests(room, W.BANNER, bannerHandlers(function()
    secondActivations = secondActivations + 1
    lu.assertFalse(user:hasSkill(FIRST), "额外回合开始时上一次授技应先到期")
    lu.assertFalse(user:prohibitReveal(false), "额外回合开始时上一次禁明置应先到期")
    lu.assertFalse(W.isPositionRestricted(room, user, false), "额外回合开始时上一次记录应先解除")
    lu.assertTrue(user:insideExtraTurn(), "第二次发动应发生在真实额外回合")
  end), function()
    inRoom(function() room:actExtraTurn() end)
  end)
  lu.assertEquals(secondActivations, 1, "额外回合的准备阶段应能第二次发动")
  lu.assertEquals(discards, 2, "两次发动各支付一张牌")
  lu.assertEquals(user.general, "anjiang")
  lu.assertEquals(user.deputyGeneral, "anjiang", "第二次应暗置副将")
  lu.assertTrue(user:hasSkill(FIRST))
  lu.assertFalse(user:prohibitReveal(false), "第一次的限制已到期")
  lu.assertTrue(user:prohibitReveal(true), "第二次的限制绑定副将")
  local secondRec = W.record(room, user)
  lu.assertNotNil(secondRec)
  lu.assertTrue(secondRec.isDeputy)
  lu.assertTrue(W.isPositionRestricted(room, user, true), "副将的移除/交换/变更应受限")
  lu.assertFalse(W.isPositionRestricted(room, user, false), "主将的限制已解除")

  -- 下一次自己的回合：两张武将牌都已暗置，没有可合法暗置的武将牌。
  -- 真实回合开始的明置询问确定取消，保证准备阶段两个公开将名仍为 anjiang。
  FkTest.setNextReplies(user, { { "Cancel" } })
  skill_test.withSkillRequests(room, W.BANNER, {
    askToDiscard = function(self, who, params, original)
      thirdAsks = thirdAsks + 1
      error("两个位置均已暗置时不应第三次发动霸者求贤状")
    end,
    askToChoice = function(self, who, params, original)
      thirdAsks = thirdAsks + 1
      error("两个位置均已暗置时不应第三次发动霸者求贤状")
    end,
  }, function()
    inRoom(function()
      GameEvent.Turn:create(TurnData:new(user, "game_rule", { Player.Start })):exec()
    end)
  end)
  lu.assertEquals(thirdAsks, 0, "没有可合法暗置的武将牌时不得发动")
  lu.assertEquals(user.general, "anjiang", "第三个真实回合开始时主将应保持暗置")
  lu.assertEquals(user.deputyGeneral, "anjiang", "第三个真实回合开始时副将应保持暗置")
  lu.assertFalse(user:hasSkill(FIRST), "自己下回合开始应撤销第二次授技")
  lu.assertFalse(user:prohibitReveal(true), "自己下回合开始应解除第二次限制")
  lu.assertFalse(W.isPositionRestricted(room, user, true), "移除/交换/变更限制应同时解除")
  lu.assertFalse(W.isPositionRestricted(room, user, false), "两个位置的限制都应解除")
  lu.assertNil(W.record(room, user), "到期记录应清空")

  -- 到期后按常规流程明置主将（不强制、不自动），下一回合才有第三个候选。
  inRoom(function() user:revealGeneral(false) end)
  lu.assertEquals(user.general, "qiao_heg__wei005", "期限届满后可按常规流程明置")
  -- 主动明置主将后，回合开始的明置询问仍确定取消，保留副将暗置。
  FkTest.setNextReplies(user, { { "Cancel" } })
  skill_test.withSkillRequests(room, W.BANNER, bannerHandlers(function()
    thirdActivations = thirdActivations + 1
  end), function()
    inRoom(function()
      GameEvent.Turn:create(TurnData:new(user, "game_rule", { Player.Start })):exec()
    end)
  end)
  lu.assertEquals(thirdActivations, 1, "无整局限次：常规明置后可第三次发动")
  lu.assertEquals(user.general, "anjiang", "第三次应再次暗置主将")
  lu.assertTrue(user:hasSkill(FIRST))
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

-- 常令：真实准备阶段入口下，非持有者不进入选人/选牌/军令；持有者请求同时
-- 包含公开势力未确定者并排除已公开魏者。注册沿用 handleAddLoseSkills。
function Testqiao_em_wei001_caocao:testChangelingNonHolderAndTargetFilter()
  local room, holder, nonholder, unknown = FkTest.room, p(2), p(4), p(5)
  local card, targetCalls, cardCalls, commandCalls = nil, 0, 0, 0
  local queriedTargets
  inRoom(function()
    skill_test.installDualGenerals(room, holder, {
      main = "qiao_heg__wei005", deputy = "qiao_test__wei_2", kingdom = "wei",
    })
    room:handleAddLoseSkills(holder, "qiao__skill_wei024_1", nil, false, true)
    card = room:printCard("qiao__jink", Card.Heart, 5)
    room:obtainCard(holder, card, false, fk.ReasonJustMove)
    nonholder.phase = Player.Start
  end)

  local originalCommand = H.askToCommand
  H.askToCommand = function(_, params)
    commandCalls = commandCalls + 1
    lu.assertEquals(params.skill_name, "qiao__skill_wei024_1")
    return true, {}
  end

  local ok, err = pcall(function()
    -- 负例：真实准备阶段事件，但当前角色不是常令持有者。
    skill_test.withSkillRequests(room, "trigger", {
      askToChoice = function(self, who, params, original)
        local changling = table.find(params.choices, function(choice)
          return tostring(choice):find("qiao__skill_wei024_1", 1, true) ~= nil
        end)
        lu.assertNil(changling, "非持有者准备阶段不应出现常令触发候选")
        return original(self, who, params)
      end,
    }, function()
      skill_test.withSkillRequests(room, "qiao__skill_wei024_1", {
        askToChoosePlayers = function() targetCalls = targetCalls + 1; return {} end,
        askToCards = function() cardCalls = cardCalls + 1; return {} end,
      }, function()
        inRoom(function()
          room.logic:trigger(fk.EventPhaseStart, nonholder,
            PhaseData:new { who = nonholder, phase = Player.Start })
        end)
      end)
    end)
    lu.assertEquals(targetCalls, 0, "非持有者不应进入常令选人")
    lu.assertEquals(cardCalls, 0, "非持有者不应进入常令选牌")
    lu.assertEquals(commandCalls, 0, "非持有者不应发起军令")
    lu.assertFalse(table.contains(nonholder:getCardIds("h"), card.id),
      "非持有者不应取得常令的牌")

    -- 目标牌面为魏、公开势力未确定，仍应进入候选。先移除旗来源，隔离同一
    -- 准备阶段的授技，避免旗的选人/选牌请求混入本用例。
    inRoom(function()
      room:handleAddLoseSkills(p(1), "-" .. W.BANNER, W.JIANAN, false, true)
      skill_test.installDualGenerals(room, unknown, {
        main = "qiao_test__wei_1", deputy = "qiao_test__wei_2", kingdom = "wei",
      })
      setUnknown(room, unknown)
      holder.phase = Player.Start
    end)
    skill_test.withSkillRequests(room, "trigger", {
      askToChoice = function(self, who, params, original)
        local changling = table.find(params.choices, function(choice)
          return tostring(choice):find("qiao__skill_wei024_1", 1, true) ~= nil
        end)
        if changling ~= nil then return changling end
        return original(self, who, params)
      end,
    }, function()
      skill_test.withSkillRequests(room, "qiao__skill_wei024_1", {
        askToChoosePlayers = function(self, who, params, original)
          if params.skill_name ~= "qiao__skill_wei024_1" then
            return original(self, who, params)
          end
          queriedTargets = table.simpleClone(params.targets)
          return { unknown }
        end,
        askToCards = function(self, who, params, original)
          if params.skill_name ~= "qiao__skill_wei024_1" then
            return original(self, who, params)
          end
          return { card.id }
        end,
      }, function()
        inRoom(function()
          room.logic:trigger(fk.EventPhaseStart, holder,
            PhaseData:new { who = holder, phase = Player.Start })
        end)
      end)
    end)
  end)
  H.askToCommand = originalCommand
  if not ok then error(err, 0) end

  lu.assertNotNil(queriedTargets, "持有者应进入常令选人")
  local function has(player) return table.contains(queriedTargets, player) end
  lu.assertTrue(has(unknown), "公开势力未确定者应进入候选")
  lu.assertTrue(has(nonholder), "其他非魏势力应进入候选")
  lu.assertFalse(has(p(1)), "已公开魏的君主应排除")
  lu.assertFalse(has(p(3)), "其他已公开魏者应排除")
  lu.assertFalse(has(holder), "自己不能通过交给取得自己的牌")
  lu.assertEquals(commandCalls, 1, "持有者发动常令后应发起一次军令")
  lu.assertTrue(table.contains(unknown:getCardIds("h"), card.id),
    "常令应实际交给未确定势力目标")
  lu.assertFalse(table.contains(holder:getCardIds("h"), card.id))
end

-- 常令：霸者求贤状在同一准备阶段事件内授予后即可发动；到期时授予技能与
-- 旗限制同步解除，到期后的真实准备阶段不再发起常令询问。
function Testqiao_em_wei001_caocao:testChangelingBannerSameEventThenExpiry()
  local room, lord, user, target = FkTest.room, p(1), p(2), p(4)
  local discardCard, giveCard
  local commandCalls = 0
  inRoom(function()
    skill_test.installDualGenerals(room, user, {
      main = "qiao_heg__wei005", deputy = "qiao_test__wei_2", kingdom = "wei",
    })
    discardCard = room:printCard("qiao__jink", Card.Heart, 5)
    giveCard = room:printCard("qiao__jink", Card.Club, 6)
    room:obtainCard(user, discardCard, false, fk.ReasonJustMove)
    room:obtainCard(user, giveCard, false, fk.ReasonJustMove)
    user.phase = Player.Start
  end)

  local originalCommand = H.askToCommand
  H.askToCommand = function(_, params)
    commandCalls = commandCalls + 1
    lu.assertEquals(params.skill_name, "qiao__skill_wei024_1")
    return true, {}
  end

  local ok, err = pcall(function()
    skill_test.withSkillRequests(room, "trigger", {
      askToChoice = function(self, who, params, original)
        local changling = table.find(params.choices, function(choice)
          return tostring(choice):find("qiao__skill_wei024_1", 1, true) ~= nil
        end)
        if changling ~= nil then return changling end
        local banner = table.find(params.choices, function(choice)
          return tostring(choice):find("qiao__skill_em_wei001_banner", 1, true) ~= nil
        end)
        if banner ~= nil then return banner end
        return original(self, who, params)
      end,
    }, function()
      skill_test.withSkillRequests(room, W.BANNER, {
        askToDiscard = function(self, who, params, original)
          if params.skill_name ~= W.BANNER then
            return original(self, who, params)
          end
          self:throwCard({ discardCard.id }, W.BANNER, who, who)
          return { discardCard.id }
        end,
        askToChoice = function(self, who, params, original)
          if params.skill_name ~= W.BANNER then
            return original(self, who, params)
          end
          if table.contains(params.choices, "m") then return "m" end
          lu.assertTrue(table.contains(params.choices, "qiao__skill_wei024_1"),
            "授技候选应包含常令")
          return "qiao__skill_wei024_1"
        end,
      }, function()
        skill_test.withSkillRequests(room, "qiao__skill_wei024_1", {
          askToChoosePlayers = function(self, who, params, original)
            if params.skill_name ~= "qiao__skill_wei024_1" then
              return original(self, who, params)
            end
            return { target }
          end,
          askToCards = function(self, who, params, original)
            if params.skill_name ~= "qiao__skill_wei024_1" then
              return original(self, who, params)
            end
            return { giveCard.id }
          end,
        }, function()
          inRoom(function()
            room.logic:trigger(fk.EventPhaseStart, user,
              PhaseData:new { who = user, phase = Player.Start })
          end)
        end)
      end)
    end)
    lu.assertTrue(user:hasSkill("qiao__skill_wei024_1"),
      "旗在同一准备阶段事件内授予后应持有常令")
    lu.assertEquals(commandCalls, 1, "旗同事件授予后常令应能实际发起军令")
    lu.assertTrue(table.contains(target:getCardIds("h"), giveCard.id),
      "旗同事件授予后常令应实际交牌")

    -- 自己下回合开始：授予技能与旗限制同时到期。
    inRoom(function() room.logic:trigger(fk.TurnStart, user, {}) end)
    lu.assertFalse(user:hasSkill("qiao__skill_wei024_1"),
      "自己下回合开始应撤销旗授予的常令")
    lu.assertNil(W.record(room, user), "常令到期应与旗限制记录同步解除")
    lu.assertFalse(user:prohibitReveal(false), "常令到期后不应残留明置限制")

    -- 移除旗来源，避免到期负例再次通过同一准备阶段授予常令。
    inRoom(function()
      room:handleAddLoseSkills(lord, "-" .. W.BANNER, W.JIANAN, false, true)
      user.phase = Player.Start
    end)
    local afterExpiryCommands = commandCalls
    skill_test.withSkillRequests(room, "trigger", {
      askToChoice = function(self, who, params, original)
        local changling = table.find(params.choices, function(choice)
          return tostring(choice):find("qiao__skill_wei024_1", 1, true) ~= nil
        end)
        lu.assertNil(changling, "到期后触发选择不应出现常令")
        return original(self, who, params)
      end,
    }, function()
      skill_test.withSkillRequests(room, "qiao__skill_wei024_1", {
        askToChoosePlayers = function() error("到期后的常令不应再选人") end,
        askToCards = function() error("到期后的常令不应再选牌") end,
      }, function()
        inRoom(function()
          room.logic:trigger(fk.EventPhaseStart, user,
            PhaseData:new { who = user, phase = Player.Start })
        end)
      end)
    end)
    lu.assertEquals(commandCalls, afterExpiryCommands, "到期后的常令不应再发起军令")
  end)
  H.askToCommand = originalCommand
  if not ok then error(err, 0) end
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

withClientRoom = function(current, fn)
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
