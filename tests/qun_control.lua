-- QUN015 纪灵·双刃、QUN018 邹氏·祸水的核心行为定向验收。
--
-- 规则依据：docs/rules/generals/qun015-jiling.md、
-- docs/development/implementation/generals/qun-standard.md、
-- docs/rules/only-as.md、docs/rules/card-use-targets.md。
-- 本文件已加入 tests/all.lua，纳入默认国战套件。
--
-- 验收重点：双刃真实拼点两分支、借刀杀人的真实主/副目标、本回合结束清理；
-- 祸水按来源维护的即时禁明置、真实暗置与收牌、无“限一次”。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local O = require "packages.qiao.pkg.qiao_mode.rules.only_as"
local Q = require "packages.qiao.pkg.qiao_generals.util.qun_control"

local SR = "qiao__skill_qun015_1"
local STATE = "qiao__qun_shuangren_state"
local HS = "qiao__skill_qun018_1"

local DEFAULT_KINGDOMS = { "qun", "qun", "wei", "wei", "shu", "shu", "wu", "wu" }

local function room() return FkTest.room end
local function p(n) return room().players[n] end

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function grant(player, name)
  inRoom(function() player.room:handleAddLoseSkills(player, name, nil, false, true) end)
end

local function clearCards(player)
  inRoom(function()
    local ids = player:getCardIds("he")
    if #ids > 0 then
      room():moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false)
    end
  end)
end

local function give(player, name, suit, number)
  local id
  inRoom(function()
    local card = room():printCard(name, suit or Card.Spade, number or 7)
    room():obtainCard(player, card, false, fk.ReasonJustMove)
    id = card.id
  end)
  return id
end

local function equip(player, name, suit, number)
  local id
  inRoom(function()
    local card = room():printCard(name, suit or Card.Spade, number or 7)
    room():moveCardTo({ card.id }, Card.PlayerEquip, player, fk.ReasonJustMove, "test", nil, false)
    id = card.id
  end)
  return id
end

local function setPlayPhase(player)
  inRoom(function()
    room().current = player
    player.phase = Player.Play
  end)
end

--- 在房间协程内运行，并把内部抛出的运行时错误带回测试线程。
--- runInRoom 的协程若报错会被房间以 qCritical + gameOver 吞掉，测试只会看到
--- 后续断言失败；用 pcall 包住同一段代码即可让真实错误信息成为断言证据。
local function inRoomCaptured(fn)
  local err
  inRoom(function()
    local ok, msg = pcall(fn)
    if not ok then err = msg end
  end)
  return err
end

--- 与 withStubs 相同的局部替换，但允许测试中途按次替换（例如两次发动给不同牌）。
local function stubRequests(overrides, fn)
  local originals = {}
  for name, override in pairs(overrides) do
    originals[name] = room()[name]
    room()[name] = function(self, player, params, ...)
      return override(player, params, originals[name], ...)
    end
  end
  local ok, err = pcall(fn)
  for name, original in pairs(originals) do
    room()[name] = original
  end
  if not ok then error(err, 0) end
end

--- 记录真正进入房间使用入口的用牌数据，用于区分“效果没有产出用牌”与
--- “产出后被 PreCardUse 中止”。
local function captureUseCard(attempts, fn)
  local original = room().useCard
  room().useCard = function(self, useData)
    table.insert(attempts, useData)
    return original(self, useData)
  end
  local ok, err = pcall(fn)
  room().useCard = original
  if not ok then error(err, 0) end
end

local function grantHuoshui(player)
  grant(player, HS)
  -- 房间级规则由 mode.lua 接线；本套件自行安装，与正式接线按技能名去重。
  inRoom(function() room():addSkill(Q.RULE_SKILL) end)
end

--- 记录一次真实用牌（CardUsing 时目标结构已完成）。
local probeSerial = 0
local function installUseProbe()
  probeSerial = probeSerial + 1
  local name = "#qun_control_use_probe_" .. probeSerial
  local seen = {}
  local skel = fk.CreateSkill { name = name }
  skel:addEffect(fk.CardUsing, {
    global = true,
    can_trigger = function(self, event, target, player, data)
      return target == player and data ~= nil and data.card ~= nil
    end,
    on_cost = Util.TrueFunc,
    on_use = function(self, event, target, player, data)
      table.insert(seen, {
        trueName = data.card.trueName,
        skillName = data.card.skillName,
        from = data.from and data.from.id,
        tos = table.map(data.tos or {}, Util.IdMapper),
        subTos = table.map(data.subTos and data.subTos[1] or {}, Util.IdMapper),
      })
    end,
  })
  local skill = skel:createSkill()
  Fk.skills[name] = skill
  inRoom(function() room():addSkill(skill) end)
  return seen
end

Testqiao_qun_control = { tearDown = support.clearRoom }

Testqiao_qun_control.setup = function()
  local r = support.initQiaoRoom()
  inRoom(function() skill_test.installBlankGenerals(r, DEFAULT_KINGDOMS) end)
end

-- 双刃：赢 → 一次多目标【杀】，拼点对手必须包含。
function Testqiao_qun_control:testShuangrenWinUsesOneSlashWithOpponent()
  local p1, p2, p3 = p(1), p(2), p(3)
  clearCards(p1)
  clearCards(p2)
  clearCards(p3)
  grant(p1, SR)
  local mine = give(p1, "qiao__jink", Card.Spade, 13)
  local slash = give(p1, "qiao__slash", Card.Spade, 5)
  local theirs = give(p2, "qiao__jink", Card.Heart, 2)
  local seen = installUseProbe()

  FkTest.setNextReplies(p1, {
    FkTest.ReplyChoosePlayer({ p2 }),
    FkTest.ReplyChooseCards({ mine }),
    FkTest.ReplyChoosePlayer({ p3 }),
  })
  FkTest.setNextReplies(p2, { FkTest.ReplyChooseCards({ theirs }) })
  local attempts = {}
  -- runInRoom 会吞掉房间协程内的运行时错误，这里把错误带回断言，
  -- 以便区分“没触发/没赢/用牌被拒/内部报错”。
  local err = inRoomCaptured(function()
    room().current = p1
    p1.phase = Player.Play
    captureUseCard(attempts, function()
      room().logic:trigger(fk.EventPhaseStart, p1, PhaseData:new {
        who = p1, reason = "game_rule", phase = Player.Play,
      })
    end)
  end)
  lu.assertNil(err)
  lu.assertEquals(p1:usedSkillTimes(SR, Player.HistoryGame), 1)
  -- 拼点真实发生：双方拼点牌进入弃牌堆。
  lu.assertEquals(room():getCardArea(mine), Card.DiscardPile)
  lu.assertEquals(room():getCardArea(theirs), Card.DiscardPile)
  lu.assertFalse(O.isForbidden(p1, Fk:getCardById(slash)))
  -- 效果确实产出了一次用牌请求；若以下 seen 仍为 0，则问题在 PreCardUse 复核。
  lu.assertEquals(#attempts, 1)

  lu.assertEquals(#seen, 1)
  lu.assertEquals(seen[1].trueName, "slash")
  lu.assertEquals(seen[1].skillName, SR)
  lu.assertEquals(seen[1].from, p1.id)
  lu.assertEquals(seen[1].tos, { p2.id, p3.id })
end

-- 双刃：没赢 → 手牌【杀】只能当【借刀杀人】使用至回合结束，含之后得到的杀。
function Testqiao_qun_control:testShuangrenLoseRestrictsHandSlashUntilTurnEnd()
  local p1, p2, p3 = p(1), p(2), p(3)
  clearCards(p1)
  clearCards(p2)
  clearCards(p3)
  grant(p1, SR)
  local low = give(p1, "qiao__jink", Card.Spade, 2)
  local slash = give(p1, "qiao__slash", Card.Spade, 5)
  local high = give(p2, "qiao__jink", Card.Heart, 13)

  FkTest.setNextReplies(p1, {
    FkTest.ReplyChoosePlayer({ p2 }),
    FkTest.ReplyChooseCards({ low }),
  })
  FkTest.setNextReplies(p2, { FkTest.ReplyChooseCards({ high }) })
  local triggerErr = inRoomCaptured(function()
    room().current = p1
    p1.phase = Player.Play
    room().logic:trigger(fk.EventPhaseStart, p1, PhaseData:new {
      who = p1, reason = "game_rule", phase = Player.Play,
    })
  end)
  lu.assertNil(triggerErr)

  lu.assertEquals(p1:usedSkillTimes(SR, Player.HistoryGame), 1)
  -- 拼点真实发生且 p1 没赢：双方拼点牌进入弃牌堆，来源同时包含限制与入口。
  lu.assertEquals(room():getCardArea(low), Card.DiscardPile)
  lu.assertEquals(room():getCardArea(high), Card.DiscardPile)
  -- 直接使用原【杀】被公共 only-as 复核拒绝：目标不受伤，牌仍在手。
  local hp = p2.hp
  inRoom(function()
    room():useCard(UseCardData:new {
      from = p1, tos = { p2 }, card = Fk:getCardById(slash), extra_data = {},
    })
  end)
  lu.assertEquals(p2.hp, hp)
  lu.assertTrue(table.contains(p1:getCardIds("h"), slash))

  -- 受限于当前手牌范围：之后得到的【杀】同样只能当借刀，牌名不改。
  local later = give(p1, "qiao__slash", Card.Spade, 8)
  lu.assertTrue(O.isForbidden(p1, Fk:getCardById(slash)))
  lu.assertTrue(O.isForbidden(p1, Fk:getCardById(later)))
  lu.assertTrue(table.contains(O.availableTargets(room(), p1, later, "use"), "qiao__collateral"))
  lu.assertEquals(Fk:getCardById(later).trueName, "slash")

  -- 借刀杀人转换：真实主目标 + 副目标，结算后武器移交使用者。
  -- 转换入口属于独立状态骨架（失去双刃后仍在），不是双刃本体。
  local weapon = equip(p2, "qiao__spear")
  local seen = installUseProbe()
  local use
  FkTest.setNextReplies(p1, { {
    card = { skill = STATE, subcards = { slash } },
    targets = { p2.id, p3.id },
    interaction_data = "qiao__collateral",
  } })
  inRoom(function()
    use = room():askToUseCard(p1, {
      pattern = "collateral", skill_name = "qun_control_test", cancelable = true,
    })
  end)
  lu.assertNotNil(use)
  lu.assertEquals(use.card.trueName, "collateral")
  lu.assertEquals(use.card.subcards, { slash })
  local attempts = {}
  local useErr = inRoomCaptured(function()
    captureUseCard(attempts, function() room():useCard(use) end)
  end)
  lu.assertNil(useErr)
  lu.assertEquals(#attempts, 1)
  lu.assertEquals(#seen, 1)
  lu.assertEquals(seen[1].trueName, "collateral")
  lu.assertEquals(seen[1].tos, { p2.id })
  lu.assertEquals(seen[1].subTos, { p3.id })
  lu.assertTrue(table.contains(p1:getCardIds("h"), weapon))

  -- 来源建立时挂上独立转换入口；本回合结束两者一并撤销。
  lu.assertTrue(p1:hasSkill(STATE))
  inRoom(function() room().logic:trigger(fk.TurnEnd, p1, {}) end)
  lu.assertFalse(O.isForbidden(p1, Fk:getCardById(later)))
  lu.assertFalse(table.contains(O.availableTargets(room(), p1, later, "use"), "qiao__collateral"))
  lu.assertFalse(p1:hasSkill(STATE))
end

-- 双刃：真实失去技能本体后，已建立的转换权限仍可用【杀】当借刀，
-- 且借刀杀人仍能真实选择主目标与副目标。
function Testqiao_qun_control:testShuangrenConversionSurvivesLosingTheSkillBody()
  local p1, p2, p3 = p(1), p(2), p(3)
  clearCards(p1)
  clearCards(p2)
  clearCards(p3)
  grant(p1, SR)
  local low = give(p1, "qiao__jink", Card.Spade, 2)
  local slash = give(p1, "qiao__slash", Card.Spade, 5)
  local high = give(p2, "qiao__jink", Card.Heart, 13)

  FkTest.setNextReplies(p1, {
    FkTest.ReplyChoosePlayer({ p2 }),
    FkTest.ReplyChooseCards({ low }),
  })
  FkTest.setNextReplies(p2, { FkTest.ReplyChooseCards({ high }) })
  local triggerErr = inRoomCaptured(function()
    room().current = p1
    p1.phase = Player.Play
    room().logic:trigger(fk.EventPhaseStart, p1, PhaseData:new {
      who = p1, reason = "game_rule", phase = Player.Play,
    })
  end)
  lu.assertNil(triggerErr)
  lu.assertTrue(p1:hasSkill(STATE))

  -- 真实失去双刃本体：EventLoseSkill 之后限制与转换都仍须存在。
  inRoom(function() room():handleAddLoseSkills(p1, "-" .. SR, nil, false, false) end)
  lu.assertFalse(p1:hasSkill(SR))
  lu.assertTrue(p1:hasSkill(STATE))
  lu.assertTrue(O.isForbidden(p1, Fk:getCardById(slash)))
  lu.assertTrue(table.contains(O.availableTargets(room(), p1, slash, "use"), "qiao__collateral"))

  local weapon = equip(p2, "qiao__spear")
  local seen = installUseProbe()
  local use
  FkTest.setNextReplies(p1, { {
    card = { skill = STATE, subcards = { slash } },
    targets = { p2.id, p3.id },
    interaction_data = "qiao__collateral",
  } })
  inRoom(function()
    use = room():askToUseCard(p1, {
      pattern = "collateral", skill_name = "qun_control_test", cancelable = true,
    })
  end)
  lu.assertNotNil(use)
  lu.assertEquals(use.card.trueName, "collateral")
  local attempts = {}
  local useErr = inRoomCaptured(function()
    captureUseCard(attempts, function() room():useCard(use) end)
  end)
  lu.assertNil(useErr)
  lu.assertEquals(#attempts, 1)
  lu.assertEquals(#seen, 1)
  lu.assertEquals(seen[1].tos, { p2.id })
  lu.assertEquals(seen[1].subTos, { p3.id })
  lu.assertTrue(table.contains(p1:getCardIds("h"), weapon))

  -- 回合结束：独立入口与限制一并撤销，新的手牌【杀】不再受限。
  local later = give(p1, "qiao__slash", Card.Spade, 9)
  lu.assertTrue(O.isForbidden(p1, Fk:getCardById(later)))
  inRoom(function() room().logic:trigger(fk.TurnEnd, p1, {}) end)
  lu.assertFalse(p1:hasSkill(STATE))
  lu.assertFalse(O.isForbidden(p1, Fk:getCardById(later)))
  lu.assertFalse(table.contains(O.availableTargets(room(), p1, later, "use"), "qiao__collateral"))
end

-- 祸水被动段：只在祸水持有者自己的回合、且只撤销自己的来源。
function Testqiao_qun_control:testHuoshuiRevealProhibitionFollowsItsOwnSource()
  local p1, p2, p3 = p(1), p(2), p(3)
  grantHuoshui(p1)
  -- room:getCurrent() 只在 current 的 phase 不是 NotActive 时返回角色；
  -- 这是引擎回合内的真实状态（TurnStart 为 PhaseNone，出牌阶段为 Play）。
  setPlayPhase(p1)
  -- 回合中途明置祸水：GeneralRevealed 后即时生效。
  inRoom(function() room().logic:trigger(fk.GeneralRevealed, p1, { m = p1.general }) end)
  lu.assertTrue(p2:prohibitReveal())
  lu.assertTrue(p2:prohibitReveal(true))
  lu.assertFalse(p1:prohibitReveal())

  local key = Q.KEY_PREFIX .. Q.uid(p1, HS)
  lu.assertNotEquals(p2:getMark(key), 0)

  -- 其他来源直接写在 RevealProhibited 上的记录与祸水互不影响。
  inRoom(function() room():setPlayerMark(p3, "RevealProhibited", { "m" }) end)
  inRoom(function() room():handleAddLoseSkills(p1, "-" .. HS, nil, false, false) end)
  lu.assertFalse(p2:prohibitReveal())
  lu.assertEquals(p2:getMark(key), 0)
  lu.assertTrue(p3:prohibitReveal())
  inRoom(function() room():setPlayerMark(p3, "RevealProhibited", 0) end)
end

-- 祸水主动段：真实暗置（统领/翼从迁移走公共流程）后收牌，且不限一次。
function Testqiao_qun_control:testHuoshuiActiveHidesGeneralAndTakesCardTwice()
  local p1, p2, p3 = p(1), p(2), p(3)
  clearCards(p1)
  clearCards(p2)
  clearCards(p3)
  grant(p1, HS)
  -- 黑色装备牌也是合法消耗（open equipment），且必须真实被弃置。
  local black = equip(p1, "qiao__spear", Card.Spade, 5)
  local red = give(p1, "qiao__jink", Card.Heart, 6)
  local give2 = give(p2, "qiao__jink", Card.Heart, 7)
  local give3 = give(p3, "qiao__jink", Card.Club, 4)
  inRoom(function()
    p2:revealGeneral(false, true)
    p2:revealGeneral(true, true)
    p3:revealGeneral(false, true)
    p3:revealGeneral(true, true)
  end)
  lu.assertTrue(Q.allGeneralsRevealed(p2))
  lu.assertTrue(Q.allGeneralsRevealed(p3))
  setPlayPhase(p1)

  local U = require "packages.utility.utility"
  local original = U.askToChooseGeneralsAndChoice
  -- 由祸水发动者选择被暗置的位置（取主将）。
  local hideMain = function(player, params)
    return { params.generals[1] }, "OK"
  end
  -- “其交给你一张牌”由目标自选。AskForCardChosen 在测试夹具里没有标准回复
  -- 格式（本项目其他套件同样用 stub 提供选择结果），这里返回目标自己的牌。
  local chooseCard = {
    askToChooseCards = function(player, params)
      return { params.target:getCardIds("he")[1] }
    end,
  }

  local err1 = inRoomCaptured(function()
    U.askToChooseGeneralsAndChoice = hideMain
    stubRequests(chooseCard, function()
      room():handleUseCardReply(p1, {
        card = { skill = HS, subcards = { black } },
        targets = { p2.id },
      }, nil)
    end)
    U.askToChooseGeneralsAndChoice = original
  end)
  U.askToChooseGeneralsAndChoice = original
  lu.assertNil(err1)
  lu.assertEquals(room():getCardArea(black), Card.DiscardPile)
  lu.assertEquals(room():getCardArea(red), Card.PlayerHand)
  lu.assertEquals(p2.general, "anjiang")
  lu.assertFalse(Q.allGeneralsRevealed(p2))
  lu.assertTrue(table.contains(p1:getCardIds("h"), give2))
  lu.assertEquals(p1:usedSkillTimes(HS, Player.HistoryGame), 1)

  -- 不限一次：同一出牌阶段可以再次发动，换另一名仍双将明置的角色；
  -- 祸水仍在生效，因此这里不重新明置目标（那属于被禁止的动作）。
  local black2 = give(p1, "qiao__jink", Card.Spade, 9)
  local err2 = inRoomCaptured(function()
    U.askToChooseGeneralsAndChoice = hideMain
    stubRequests(chooseCard, function()
      room():handleUseCardReply(p1, {
        card = { skill = HS, subcards = { black2 } },
        targets = { p3.id },
      }, nil)
    end)
    U.askToChooseGeneralsAndChoice = original
  end)
  U.askToChooseGeneralsAndChoice = original
  lu.assertNil(err2)

  lu.assertEquals(p1:usedSkillTimes(HS, Player.HistoryGame), 2)
  lu.assertTrue(table.contains(p1:getCardIds("h"), give3))
  lu.assertEquals(p3.general, "anjiang")
end

-- 祸水主动段：弃黑牌是消耗，服务端复核只接受属于自己 he 且可弃的牌；
-- 伪造用别人的牌支付时不弃牌、不暗置。
function Testqiao_qun_control:testHuoshuiCannotPayWithAnotherPlayersCard()
  local p1, p2 = p(1), p(2)
  clearCards(p1)
  clearCards(p2)
  grant(p1, HS)
  local ownBlack = give(p1, "qiao__jink", Card.Spade, 5)
  local stolen = give(p2, "qiao__jink", Card.Club, 3)
  inRoom(function()
    p2:revealGeneral(false, true)
    p2:revealGeneral(true, true)
  end)
  lu.assertTrue(Q.allGeneralsRevealed(p2))
  setPlayPhase(p1)

  inRoom(function()
    room():handleUseCardReply(p1, {
      card = { skill = HS, subcards = { stolen } },
      targets = { p2.id },
    }, nil)
  end)

  lu.assertEquals(room():getCardArea(stolen), Card.PlayerHand)
  lu.assertTrue(table.contains(p2:getCardIds("h"), stolen))
  lu.assertTrue(Q.allGeneralsRevealed(p2))
  lu.assertTrue(table.contains(p1:getCardIds("h"), ownBlack))
end

return { name = "qiao_qun_control" }
