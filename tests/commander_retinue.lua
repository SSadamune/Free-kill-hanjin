local support = __dofile("../../../tests/support/hegemony.lua")
local C = require "packages.hanjin.pkg.hanjin_mode.rules.commander_retinue"
local H = require "packages.hegemony.util"

local function setup()
  local room = support.initHanjinRoom()
  local Exchange = require "packages.hanjin.pkg.hanjin_mode.rules.general_exchange"
  -- The exchange suite clears global listeners in its tearDown; re-install ours
  -- for each commander test.  The listener itself is idempotent.
  Exchange.addCompletionListener(C.onExchangeCompleted)
  FkTest.runInRoom(function()
    C.reset(room)
    for _, player in ipairs(room.players) do C.grantAbility(player) end
  end)
  return room
end

local function teardown()
  local Exchange = require "packages.hanjin.pkg.hanjin_mode.rules.general_exchange"
  Exchange.removeCompletionListener(C.onExchangeCompleted)
  support.clearRoom()
end

Testhanjin_commander_retinue = { setup = setup, tearDown = teardown }

local function room() return FkTest.room end

local function setGeneral(player, name, isDeputy, hidden)
  FkTest.runInRoom(function()
    room():changeHero(player, name, false, isDeputy, false, false, false)
    room():setPlayerMark(player, isDeputy and "__heg_deputy" or "__heg_general", name)
    if hidden then player:hideGeneral(isDeputy) end
  end)
end

local function setHidden(player, main, deputy, kingdom)
  FkTest.runInRoom(function()
    if main ~= nil then
      room():changeHero(player, main, false, false, false, false, false)
      room():setPlayerMark(player, "__heg_general", main)
      player:hideGeneral(false)
    end
    if deputy ~= nil then
      room():changeHero(player, deputy, false, true, false, false, false)
      room():setPlayerMark(player, "__heg_deputy", deputy)
      player:hideGeneral(true)
    end
    room():setPlayerMark(player, "__heg_kingdom", kingdom)
    room():setPlayerMark(player, "__heg_wild", 0)
    room():setPlayerProperty(player, "kingdom", "unknown")
  end)
end

local function setBlankDirect(player, isDeputy)
  FkTest.runInRoom(function()
    local name = "blank_shibing"
    if isDeputy then
      room():setDeputyGeneral(player, name)
      room():setPlayerMark(player, "__heg_deputy", name)
    else
      room():setPlayerGeneral(player, name, false)
      room():setPlayerMark(player, "__heg_general", name)
    end
  end)
end

local function setRetinueDirect(player, isDeputy, retinue)
  setGeneral(player, retinue, isDeputy, false)
end

local function reveal(player, isDeputy)
  FkTest.runInRoom(function() player:revealGeneral(isDeputy) end)
end

local function sourceOf(general)
  return C.source(room(), general)
end

function Testhanjin_commander_retinue:testIndependentRetinueContentAndPublicRegistration()
  lu.assertTrue(C.isRetinue("hanjin_test__retinue_alpha"))
  lu.assertTrue(C.isSoldier("hanjin_test__retinue_alpha"))
  lu.assertTrue(C.isSoldier("blank_shibing"))
  lu.assertTrue(C.isSoldier("blank_nvshibing"))
  lu.assertFalse(C.isSoldier("hanjin_test__wei_1"))
  lu.assertFalse(C.isCommander("hanjin_test__retinue_alpha"))
  lu.assertTrue(C.isCommander("hanjin_test__commander_alpha"))
  local general = Fk.generals["hanjin_test__retinue_alpha"]
  lu.assertTrue(general.hidden)
  lu.assertEquals(general.package.extensionName, "hanjin")
  lu.assertTrue(table.contains(general:getSkillNameList(), "hanjin_test__retinue_skill_a"))
  lu.assertNotEquals(Fk:translate("hanjin_test__retinue_alpha"), "hanjin_test__retinue_alpha")
  for _, name in ipairs(room().general_pile) do lu.assertFalse(C.isRetinue(name)) end
end

function Testhanjin_commander_retinue:testNoSoldierConditionIncludesRetinues()
  local sourceHolder, user = room().players[1], room().players[2]
  setHidden(sourceHolder, "hanjin_test__commander_alpha", nil, "wei")
  reveal(sourceHolder, false)
  setHidden(user, "hanjin_test__wei_1", nil, "wei")
  reveal(user, false)

  setBlankDirect(user, true)
  C.refreshAvailability(room())
  lu.assertTrue(C.hasSoldier(user))
  lu.assertEquals(#C.abilitySources(user), 0)
  lu.assertEquals(user:getMark(C.SOURCE_MARK), 0)

  setRetinueDirect(user, true, "hanjin_test__retinue_alpha")
  C.refreshAvailability(room())
  lu.assertTrue(C.hasSoldier(user))
  lu.assertEquals(#C.abilitySources(user), 0)
  lu.assertEquals(user:getMark(C.SOURCE_MARK), 0)
end

function Testhanjin_commander_retinue:testRevealConvertsExistingBlankSoldierWithChoice()
  local sourceHolder, target = room().players[1], room().players[2]
  setHidden(sourceHolder, "hanjin_test__commander_alpha", nil, "wei")
  setHidden(target, "hanjin_test__wei_1", nil, "wei")
  reveal(target, false)
  setBlankDirect(target, true)
  FkTest.runInRoom(function()
    room():setPlayerProperty(target, "maxHp", 7)
    room():setPlayerProperty(target, "hp", 5)
  end)

  FkTest.setNextReplies(target, { { "hanjin_test__retinue_alpha" } })
  reveal(sourceHolder, false)

  lu.assertEquals(target.deputyGeneral, "hanjin_test__retinue_alpha")
  lu.assertTrue(target:hasSkill("hanjin_test__retinue_skill_a"))
  lu.assertTrue(C.isRetinue(target.deputyGeneral))
  lu.assertTrue(table.contains(C.availableRetinues(room(), "wei"), "hanjin_test__retinue_beta"))
  lu.assertEquals(target.kingdom, "wei")
  lu.assertEquals(target.hp, 5)
  lu.assertEquals(target.maxHp, 7)
end

function Testhanjin_commander_retinue:testBothPositionsConvertAndMayChooseTheSameType()
  local sourceHolder, target = room().players[1], room().players[2]
  setHidden(sourceHolder, "hanjin_test__commander_alpha", nil, "wei")
  setHidden(target, "hanjin_test__wei_1", nil, "wei")
  reveal(target, false)
  FkTest.runInRoom(function()
    H.removeGeneral(target, false)
    H.removeGeneral(target, true)
  end)
  lu.assertTrue(C.isBlankSoldier(target.general))
  lu.assertTrue(C.isBlankSoldier(target.deputyGeneral))

  FkTest.setNextReplies(target, {
    { "hanjin_test__retinue_alpha" },
    { "hanjin_test__retinue_alpha" },
  })
  reveal(sourceHolder, false)

  lu.assertEquals(target.general, "hanjin_test__retinue_alpha")
  lu.assertEquals(target.deputyGeneral, "hanjin_test__retinue_alpha")
  lu.assertTrue(target:hasSkill("hanjin_test__retinue_skill_a"))
end

function Testhanjin_commander_retinue:testDeputyCommanderRevealAlsoProvidesSource()
  local sourceHolder, target = room().players[1], room().players[2]
  setHidden(sourceHolder, "hanjin_test__wei_1", "hanjin_test__commander_alpha", "wei")
  setHidden(target, "hanjin_test__wei_2", nil, "wei")
  reveal(sourceHolder, false)
  reveal(sourceHolder, true)
  reveal(target, false)

  FkTest.setNextReplies(target, { { "hanjin_test__retinue_alpha" } })
  FkTest.runInRoom(function()
    room():changeHero(target, "blank_shibing", false, true, false, false, false)
    room():setPlayerMark(target, "__heg_deputy", "blank_shibing")
  end)
  lu.assertEquals(target.deputyGeneral, "hanjin_test__retinue_alpha")
  lu.assertTrue(sourceOf("hanjin_test__commander_alpha").revealed)
end

function Testhanjin_commander_retinue:testSingleAvailableRetinueConvertsWithoutChoice()
  local sourceHolder, target = room().players[1], room().players[2]
  setHidden(sourceHolder, "hanjin_test__commander_beta", nil, "shu")
  setHidden(target, "hanjin_test__shu_1", nil, "shu")
  reveal(target, false)
  setBlankDirect(target, true)

  reveal(sourceHolder, false)
  lu.assertEquals(target.deputyGeneral, "hanjin_test__retinue_beta")
  lu.assertTrue(target:hasSkill("hanjin_test__retinue_skill_b"))
end

function Testhanjin_commander_retinue:testExistingRetinueIsNotReselected()
  local sourceHolder, target = room().players[1], room().players[2]
  setHidden(sourceHolder, "hanjin_test__commander_alpha", nil, "wei")
  setHidden(target, "hanjin_test__wei_1", nil, "wei")
  reveal(target, false)
  setRetinueDirect(target, true, "hanjin_test__retinue_beta")

  reveal(sourceHolder, false)
  lu.assertEquals(target.deputyGeneral, "hanjin_test__retinue_beta")
  lu.assertTrue(target:hasSkill("hanjin_test__retinue_skill_b"))
end

function Testhanjin_commander_retinue:testHiddenSourceStillProvidesTypesButNotAbility()
  local sourceHolder, target = room().players[1], room().players[2]
  setHidden(sourceHolder, "hanjin_test__commander_alpha", nil, "wei")
  setHidden(target, "hanjin_test__wei_1", nil, "wei")
  reveal(target, false)
  reveal(sourceHolder, false)

  FkTest.runInRoom(function() sourceHolder:hideGeneral(false) end)
  lu.assertEquals(#C.abilitySources(target), 0)
  lu.assertTrue(table.contains(C.availableRetinues(room(), "wei"), "hanjin_test__retinue_alpha"))

  FkTest.setNextReplies(target, { { "hanjin_test__retinue_alpha" } })
  FkTest.runInRoom(function()
    room():changeHero(target, "blank_shibing", false, false, false, false, false)
    room():setPlayerMark(target, "__heg_general", "blank_shibing")
  end)
  lu.assertEquals(target.general, "hanjin_test__retinue_alpha")
end

function Testhanjin_commander_retinue:testRemovedSourceStillProvidesTypes()
  local sourceHolder, target = room().players[1], room().players[2]
  setHidden(sourceHolder, "hanjin_test__commander_alpha", nil, "wei")
  setHidden(target, "hanjin_test__wei_1", nil, "wei")
  reveal(target, false)
  reveal(sourceHolder, false)
  FkTest.runInRoom(function() H.removeGeneral(sourceHolder, false) end)
  lu.assertFalse(sourceOf("hanjin_test__commander_alpha").revealed)
  lu.assertTrue(table.contains(C.availableRetinues(room(), "wei"), "hanjin_test__retinue_beta"))

  FkTest.setNextReplies(target, { { "hanjin_test__retinue_beta" } })
  FkTest.runInRoom(function()
    room():changeHero(target, "blank_shibing", false, true, false, false, false)
    room():setPlayerMark(target, "__heg_deputy", "blank_shibing")
  end)
  lu.assertEquals(target.deputyGeneral, "hanjin_test__retinue_beta")
end

function Testhanjin_commander_retinue:testRevealedFactionChangeTransfersOnlyThatSource()
  local first, second, third, fourth = room().players[1], room().players[2], room().players[3], room().players[4]
  setHidden(first, "hanjin_test__commander_alpha", nil, "wei")
  setHidden(second, "hanjin_test__wei_1", nil, "wei")
  setHidden(third, "hanjin_test__shu_1", nil, "shu")
  setHidden(fourth, "hanjin_test__shu_2", nil, "shu")
  reveal(second, false)
  reveal(third, false)
  reveal(fourth, false)
  setBlankDirect(second, true)
  setBlankDirect(third, true)
  FkTest.setNextReplies(second, { { "hanjin_test__retinue_alpha" } })
  reveal(first, false)
  lu.assertEquals(second.deputyGeneral, "hanjin_test__retinue_alpha")

  FkTest.setNextReplies(third, { { "hanjin_test__retinue_beta" } })
  FkTest.runInRoom(function() room():changeKingdom(first, "shu") end)

  lu.assertTrue(sourceOf("hanjin_test__commander_alpha").factions["shu"])
  lu.assertNil(sourceOf("hanjin_test__commander_alpha").factions["wei"])
  lu.assertEquals(third.deputyGeneral, "hanjin_test__retinue_beta")
  lu.assertEquals(second.deputyGeneral, "hanjin_test__retinue_alpha")
  lu.assertEquals(#C.abilitySources(second), 0)
  lu.assertTrue(#C.abilitySources(fourth) > 0)

  FkTest.runInRoom(function()
    room():changeHero(second, "blank_shibing", false, false, false, false, false)
    room():setPlayerMark(second, "__heg_general", "blank_shibing")
  end)
  lu.assertTrue(C.isBlankSoldier(second.general))
end

function Testhanjin_commander_retinue:testHiddenFactionChangeKeepsOldAndAddsNewOnReveal()
  local holder, oldTarget, newTarget = room().players[1], room().players[2], room().players[3]
  local oldObserver, newObserver = room().players[4], room().players[5]
  setHidden(holder, "hanjin_test__commander_alpha", nil, "wei")
  setHidden(oldTarget, "hanjin_test__wei_1", nil, "wei")
  setHidden(newTarget, "hanjin_test__shu_1", nil, "shu")
  setHidden(oldObserver, "hanjin_test__wei_2", "hanjin_test__wei_3", "wei")
  setHidden(newObserver, "hanjin_test__shu_2", "hanjin_test__shu_3", "shu")
  reveal(oldTarget, false)
  reveal(newTarget, false)
  reveal(oldObserver, false)
  reveal(oldObserver, true)
  reveal(newObserver, false)
  reveal(newObserver, true)
  setBlankDirect(oldTarget, true)
  setBlankDirect(newTarget, true)
  FkTest.setNextReplies(oldTarget, { { "hanjin_test__retinue_alpha" } })
  reveal(holder, false)

  FkTest.runInRoom(function() holder:hideGeneral(false) end)
  FkTest.runInRoom(function()
    room():setPlayerMark(holder, "__heg_kingdom", "shu")
    room():setPlayerProperty(holder, "kingdom", "wei")
  end)
  FkTest.setNextReplies(newTarget, { { "hanjin_test__retinue_beta" } })
  reveal(holder, false)

  lu.assertTrue(sourceOf("hanjin_test__commander_alpha").factions["wei"])
  lu.assertTrue(sourceOf("hanjin_test__commander_alpha").factions["shu"])
  lu.assertEquals(newTarget.deputyGeneral, "hanjin_test__retinue_beta")
  lu.assertTrue(table.contains(C.availableRetinues(room(), "wei"), "hanjin_test__retinue_alpha"))
  lu.assertTrue(table.contains(C.availableRetinues(room(), "shu"), "hanjin_test__retinue_alpha"))
  -- 旧势力仍可取得兵种，但统领能力只对来源当前持有者所在势力开放。
  lu.assertEquals(#C.abilitySources(oldObserver), 0)
  lu.assertTrue(#C.abilitySources(newObserver) > 0)
  lu.assertNil(C.buildViewAsCard(oldObserver, "hanjin_test__commander_alpha"))
  lu.assertFalse(C.payCost(oldObserver, sourceOf("hanjin_test__commander_alpha"), false))
  local forged = C.viewAsCardForClient(oldObserver, "hanjin_test__commander_alpha")
  local ret = Fk.skills[C.ABILITY_SKILL]:beforeUse(oldObserver, { card = forged })
  lu.assertEquals(ret, C.ABILITY_SKILL)

  -- 旧势力仍保有该来源：明置后新增的白板士兵也可转换。
  FkTest.setNextReplies(oldTarget, { { "hanjin_test__retinue_alpha" } })
  FkTest.runInRoom(function()
    room():changeHero(oldTarget, "blank_shibing", false, false, false, false, false)
    room():setPlayerMark(oldTarget, "__heg_general", "blank_shibing")
  end)
  lu.assertEquals(oldTarget.general, "hanjin_test__retinue_alpha")
end

function Testhanjin_commander_retinue:testSharedTypeStaysWithAnotherSourceAfterTransfer()
  local alphaHolder, betaHolder, target = room().players[1], room().players[2], room().players[3]
  setHidden(alphaHolder, "hanjin_test__commander_alpha", nil, "wei")
  setHidden(betaHolder, "hanjin_test__commander_beta", nil, "wei")
  setHidden(target, "hanjin_test__wei_1", nil, "wei")
  reveal(target, false)
  setBlankDirect(target, true)
  reveal(betaHolder, false)
  lu.assertEquals(target.deputyGeneral, "hanjin_test__retinue_beta")
  reveal(alphaHolder, false)
  lu.assertEquals(C.availableRetinues(room(), "wei"),
    { "hanjin_test__retinue_alpha", "hanjin_test__retinue_beta" })

  FkTest.runInRoom(function() room():changeKingdom(alphaHolder, "shu") end)
  lu.assertEquals(C.availableRetinues(room(), "wei"), { "hanjin_test__retinue_beta" })
  lu.assertEquals(C.availableRetinues(room(), "shu"),
    { "hanjin_test__retinue_alpha", "hanjin_test__retinue_beta" })

  FkTest.runInRoom(function() room():changeKingdom(betaHolder, "shu") end)
  lu.assertEquals(C.availableRetinues(room(), "wei"), {})
  lu.assertEquals(target.deputyGeneral, "hanjin_test__retinue_beta")
end

function Testhanjin_commander_retinue:testAbilitySourceCostAndManualViewAs()
  local sourceHolder, user = room().players[1], room().players[2]
  setHidden(sourceHolder, "hanjin_test__commander_alpha", nil, "wei")
  setHidden(user, "hanjin_test__wei_1", "hanjin_test__wei_2", "wei")
  reveal(sourceHolder, false)
  reveal(user, false)
  reveal(user, true)

  local sources = C.abilitySources(user)
  lu.assertEquals(#sources, 1)
  lu.assertEquals(sources[1].general, "hanjin_test__commander_alpha")
  lu.assertEquals(user:getMark(C.SOURCE_MARK), { "hanjin_test__commander_alpha" })

  local skill = Fk.skills[C.ABILITY_SKILL]
  lu.assertTrue(skill:enabledAtPlay(user))
  lu.assertTrue(skill:enabledAtResponse(user, false))
  lu.assertFalse(skill:enabledAtResponse(user, true))
  lu.assertFalse(skill:enabledAtNullification(user))

  local source = C.source(room(), "hanjin_test__commander_alpha")
  lu.assertEquals(C.costCandidates(user, source), { false, true })
  local card = C.buildViewAsCard(user, source.general)
  lu.assertNotNil(card)
  lu.assertEquals(card.trueName, "slash")
  lu.assertEquals(card:getMark(C.CARD_SOURCE_MARK), source.general)
  lu.assertEquals(card.skillName, C.ABILITY_SKILL)
end

function Testhanjin_commander_retinue:testCostExcludesTheProvidingCommander()
  local user = room().players[1]
  setHidden(user, "hanjin_test__commander_alpha", "hanjin_test__wei_1", "wei")
  reveal(user, false)
  reveal(user, true)
  local source = C.source(room(), "hanjin_test__commander_alpha")
  lu.assertEquals(C.costCandidates(user, source), { true })
  lu.assertFalse(C.payCost(user, source, false))
  lu.assertEquals(user.general, "hanjin_test__commander_alpha")
end

function Testhanjin_commander_retinue:testPayCostRemovesGeneralAndUsesMarkedCard()
  local sourceHolder, user, target = room().players[1], room().players[2], room().players[3]
  setHidden(sourceHolder, "hanjin_test__commander_alpha", nil, "wei")
  setHidden(user, "hanjin_test__wei_1", "hanjin_test__wei_2", "wei")
  setHidden(target, "hanjin_test__wei_3", nil, "wei")
  reveal(sourceHolder, false)
  reveal(user, false)
  reveal(user, true)
  reveal(target, false)

  local source = C.source(room(), "hanjin_test__commander_alpha")
  local card = C.buildViewAsCard(user, source.general)
  lu.assertNotNil(card)
  FkTest.setNextReplies(user, { { "hanjin_test__retinue_alpha" } })
  local paid
  FkTest.runInRoom(function() paid = C.payCost(user, source, false) end)
  lu.assertTrue(paid)
  lu.assertTrue(C.isSoldier(user.general))
  lu.assertFalse(user:hasSkill("hs__jianxiong"))

  local hp = target.hp
  FkTest.runInRoom(function()
    room():useCard { from = user, tos = { target }, card = card }
  end)
  lu.assertEquals(target.hp, hp - 1)
end

function Testhanjin_commander_retinue:testCharacterJoiningFactionConvertsCarriedWhiteSoldier()
  local sourceHolder, target = room().players[1], room().players[2]
  setHidden(sourceHolder, "hanjin_test__commander_alpha", nil, "wei")
  setHidden(target, "hanjin_test__wei_1", nil, "wei")
  reveal(sourceHolder, false)
  setBlankDirect(target, true)
  lu.assertTrue(C.isBlankSoldier(target.deputyGeneral))
  FkTest.setNextReplies(target, { { "hanjin_test__retinue_alpha" } })
  reveal(target, false)
  lu.assertEquals(target.deputyGeneral, "hanjin_test__retinue_alpha")
end

function Testhanjin_commander_retinue:testRetinueChoiceOffersIndependentGeneralCards()
  local sourceHolder, target = room().players[1], room().players[2]
  setHidden(sourceHolder, "hanjin_test__commander_alpha", nil, "wei")
  setHidden(target, "hanjin_test__wei_1", nil, "wei")
  reveal(target, false)
  setBlankDirect(target, true)

  local original = room().askToChooseGeneral
  local captured
  room().askToChooseGeneral = function(self, player, params)
    captured = params
    return params.generals[2]
  end
  local ok, err = pcall(reveal, sourceHolder, false)
  room().askToChooseGeneral = original
  assert(ok, err)

  lu.assertNotNil(captured)
  lu.assertEquals(#captured.generals, 2)
  for _, name in ipairs(captured.generals) do
    lu.assertTrue(C.isRetinue(name))
    lu.assertTrue(Fk.generals[name].hidden)
    lu.assertTrue(#Fk.generals[name]:getSkillNameList() > 0)
  end
  lu.assertEquals(target.deputyGeneral, captured.generals[2])
end

function Testhanjin_commander_retinue:testManualViewAsBeforeUsePaysTheChosenCost()
  local user = room().players[1]
  setHidden(user, "hanjin_test__wei_1", "hanjin_test__commander_alpha", "wei")
  reveal(user, false)
  reveal(user, true)
  local skill = Fk.skills[C.ABILITY_SKILL]
  skill.interaction.data = "hanjin_test__commander_alpha"
  local card = skill:viewAs(user, {})
  lu.assertNotNil(card)
  lu.assertEquals(card:getMark(C.CARD_SOURCE_MARK), "hanjin_test__commander_alpha")
  lu.assertEquals(C.costCandidates(user, sourceOf("hanjin_test__commander_alpha")), { false })

  FkTest.setNextReplies(user, { { "hanjin_test__retinue_beta" } })
  local ret
  FkTest.runInRoom(function()
    ret = skill:beforeUse(user, { from = user, tos = {}, card = card })
  end)
  lu.assertNotEquals(ret, skill.name)
  lu.assertTrue(C.isSoldier(user.general))
  lu.assertEquals(user.deputyGeneral, "hanjin_test__commander_alpha")
  skill.interaction.data = nil
end

function Testhanjin_commander_retinue:testAnotherSameFactionSoldierDoesNotBlockPayment()
  local sourceHolder, user, soldierPlayer = room().players[1], room().players[2], room().players[3]
  setHidden(sourceHolder, "hanjin_test__commander_alpha", nil, "wei")
  setHidden(user, "hanjin_test__wei_1", "hanjin_test__wei_2", "wei")
  setHidden(soldierPlayer, "hanjin_test__wei_3", nil, "wei")
  reveal(sourceHolder, false)
  reveal(user, false)
  reveal(user, true)
  reveal(soldierPlayer, false)
  setBlankDirect(soldierPlayer, true)

  lu.assertTrue(#C.abilitySources(user) > 0)
  FkTest.setNextReplies(user, { { "hanjin_test__retinue_alpha" } })
  local paid
  FkTest.runInRoom(function()
    paid = C.payCost(user, sourceOf("hanjin_test__commander_alpha"), true)
  end)
  lu.assertTrue(paid)
end

function Testhanjin_commander_retinue:testDeathStopsAbilityButKeepsRetinueTypes()
  local holder, target = room().players[1], room().players[2]
  setHidden(holder, "hanjin_test__commander_alpha", nil, "wei")
  setHidden(target, "hanjin_test__wei_1", nil, "wei")
  reveal(holder, false)
  reveal(target, false)
  lu.assertTrue(#C.abilitySources(target) > 0)

  FkTest.runInRoom(function()
    room():damage { to = holder, damage = 100, damageType = fk.NormalDamage }
  end)
  lu.assertTrue(holder.dead)
  lu.assertFalse(sourceOf("hanjin_test__commander_alpha").revealed)
  lu.assertTrue(table.contains(C.availableRetinues(room(), "wei"), "hanjin_test__retinue_alpha"))

  FkTest.setNextReplies(target, { { "hanjin_test__retinue_beta" } })
  FkTest.runInRoom(function()
    room():changeHero(target, "blank_shibing", false, true, false, false, false)
    room():setPlayerMark(target, "__heg_deputy", "blank_shibing")
  end)
  lu.assertEquals(target.deputyGeneral, "hanjin_test__retinue_beta")
end

function Testhanjin_commander_retinue:testRetinueSkillActivatesAndCleanupRemovesItFromPile()
  local holder, target = room().players[1], room().players[2]
  setHidden(holder, "hanjin_test__commander_alpha", nil, "wei")
  setHidden(target, "hanjin_test__wei_1", nil, "wei")
  reveal(holder, false)
  reveal(target, false)
  FkTest.setNextReplies(target, { { "hanjin_test__retinue_alpha" } })
  FkTest.runInRoom(function()
    room():changeHero(target, "blank_shibing", false, true, false, false, false)
    room():setPlayerMark(target, "__heg_deputy", "blank_shibing")
  end)
  lu.assertEquals(target.deputyGeneral, "hanjin_test__retinue_alpha")
  lu.assertTrue(target:hasSkill("hanjin_test__retinue_skill_a"))

  FkTest.runInRoom(function()
    room():damage { from = holder, to = target, damage = 1, damageType = fk.NormalDamage }
  end)
  lu.assertEquals(target:getMark("hanjin_test_retinue_damaged"), 1)

  sourceOf("hanjin_test__commander_alpha").factions = {}
  FkTest.runInRoom(function() H.removeGeneral(target, true) end)
  lu.assertFalse(target:hasSkill("hanjin_test__retinue_skill_a"))
  lu.assertFalse(table.contains(room().general_pile, "hanjin_test__retinue_alpha"))
end

function Testhanjin_commander_retinue:testExchangeMigratesRevealedCommanderAndConvertsNewPosition()
  local Exchange = require "packages.hanjin.pkg.hanjin_mode.rules.general_exchange"
  local holder, swapper, observer = room().players[1], room().players[2], room().players[4]
  setHidden(holder, "hanjin_test__commander_alpha", nil, "wei")
  setHidden(swapper, "hanjin_test__shu_1", nil, "shu")
  setHidden(observer, "hanjin_test__shu_2", nil, "shu")
  reveal(holder, false)
  reveal(swapper, false)
  reveal(observer, false)
  setBlankDirect(swapper, true)

  FkTest.setNextReplies(swapper, { { "hanjin_test__retinue_alpha" } })
  local context
  FkTest.runInRoom(function()
    context = Exchange.exchange(room(),
      { player = holder, isDeputy = false },
      { player = swapper, isDeputy = false },
      { cross_kingdom = true })
  end)
  lu.assertNotNil(context)
  lu.assertEquals(swapper.general, "hanjin_test__commander_alpha")
  lu.assertNil(sourceOf("hanjin_test__commander_alpha").factions["wei"])
  lu.assertTrue(sourceOf("hanjin_test__commander_alpha").factions["shu"])
  lu.assertEquals(swapper.deputyGeneral, "hanjin_test__retinue_alpha")
  lu.assertTrue(#C.abilitySources(observer) > 0)
  lu.assertEquals(#C.abilitySources(holder), 0)
  lu.assertNil(C.buildViewAsCard(holder, "hanjin_test__commander_alpha"))
end

function Testhanjin_commander_retinue:testExchangeWhiteSoldierCountsAsObtained()
  local Exchange = require "packages.hanjin.pkg.hanjin_mode.rules.general_exchange"
  local holder, blankOwner, receiver = room().players[1], room().players[2], room().players[3]
  setHidden(holder, "hanjin_test__commander_alpha", nil, "wei")
  setHidden(blankOwner, "hanjin_test__shu_1", nil, "shu")
  setHidden(receiver, "hanjin_test__wei_1", nil, "wei")
  reveal(holder, false)
  reveal(blankOwner, false)
  reveal(receiver, false)
  setBlankDirect(blankOwner, true)
  FkTest.runInRoom(function()
    room():changeHero(receiver, "hanjin_test__wei_2", false, true, false, false, false)
    room():setPlayerMark(receiver, "__heg_deputy", "hanjin_test__wei_2")
  end)

  FkTest.setNextReplies(receiver, { { "hanjin_test__retinue_beta" } })
  FkTest.runInRoom(function()
    local context = Exchange.exchange(room(),
      { player = blankOwner, isDeputy = true },
      { player = receiver, isDeputy = true },
      { cross_kingdom = true })
    lu.assertNotNil(context)
    lu.assertEquals(#context.obtained_soldiers, 1)
  end)
  lu.assertEquals(receiver.deputyGeneral, "hanjin_test__retinue_beta")
end

function Testhanjin_commander_retinue:testClientViewAsBuildsCardWithoutServerSourceTag()
  local skill = Fk.skills[C.ABILITY_SKILL]
  local card
  FkTest.runInClient(function()
    skill.interaction.data = "hanjin_test__commander_alpha"
    card = skill:viewAs(Self, {})
    skill.interaction.data = nil
  end)
  lu.assertNotNil(card)
  lu.assertEquals(card.name, "hanjin__thunder__slash")
  lu.assertEquals(card:getMark(C.CARD_SOURCE_MARK), "hanjin_test__commander_alpha")
end

function Testhanjin_commander_retinue:testServerRejectsSourceCardMismatch()
  local user = room().players[1]
  setHidden(user, "hanjin_test__wei_1", "hanjin_test__wei_2", "wei")
  reveal(user, false)
  reveal(user, true)
  local skill = Fk.skills[C.ABILITY_SKILL]
  local card = C.viewAsCardForClient(user, "hanjin_test__commander_alpha")
  lu.assertNotNil(card)
  -- 伪造客户端标记：牌面是甲的雷杀，却声称来源是乙的测试杀。
  card:setMark(C.CARD_SOURCE_MARK, "hanjin_test__commander_beta")
  local ret = skill:beforeUse(user, { from = user, tos = {}, card = card })
  lu.assertEquals(ret, skill.name)
  lu.assertEquals(user.general, "hanjin_test__wei_1")
end

function Testhanjin_commander_retinue:testNullificationSourceIsUsableButPureResponseStillBlocked()
  local holder, user = room().players[1], room().players[2]
  setHidden(holder, "hanjin_test__commander_gamma", nil, "wu")
  setHidden(user, "hanjin_test__wu_1", "hanjin_test__wu_2", "wu")
  reveal(holder, false)
  reveal(user, false)
  reveal(user, true)

  local oldPattern = Fk.currentResponsePattern
  Fk.currentResponsePattern = "nullification"
  local skill = Fk.skills[C.ABILITY_SKILL]
  lu.assertTrue(C.hasNullificationSource(user))
  lu.assertTrue(skill:enabledAtNullification(user))
  lu.assertFalse(skill:enabledAtResponse(user, true))
  lu.assertTrue(skill:enabledAtResponse(user, false))
  Fk.currentResponsePattern = oldPattern

  local card = C.buildViewAsCard(user, "hanjin_test__commander_gamma")
  lu.assertNotNil(card)
  lu.assertEquals(card.trueName, "nullification")
  lu.assertTrue(card.is_passive)

  local clientCard
  FkTest.runInClient(function()
    skill.interaction.data = "hanjin_test__commander_gamma"
    clientCard = skill:viewAs(Self, {})
    skill.interaction.data = nil
  end)
  lu.assertNotNil(clientCard)
  lu.assertEquals(clientCard.trueName, "nullification")
  lu.assertTrue(clientCard.is_passive)

  FkTest.setNextReplies(user, { { "hanjin_test__retinue_alpha" } })
  local paid
  FkTest.runInRoom(function()
    paid = C.payCost(user, sourceOf("hanjin_test__commander_gamma"), false)
  end)
  lu.assertTrue(paid)
end

function Testhanjin_commander_retinue:testMultipleSourcesMatchTheSelectedSource()
  local alphaHolder, deltaHolder, user = room().players[1], room().players[2], room().players[3]
  setHidden(alphaHolder, "hanjin_test__commander_alpha", nil, "wei")
  setHidden(deltaHolder, "hanjin_test__commander_delta", nil, "wei")
  setHidden(user, "hanjin_test__wei_1", "hanjin_test__wei_2", "wei")
  reveal(alphaHolder, false)
  reveal(deltaHolder, false)
  reveal(user, false)
  reveal(user, true)

  local sources = C.abilitySources(user)
  lu.assertEquals(#sources, 2)
  local names = {}
  for _, source in ipairs(sources) do table.insert(names, source.general) end
  lu.assertTrue(table.contains(names, "hanjin_test__commander_alpha"))
  lu.assertTrue(table.contains(names, "hanjin_test__commander_delta"))

  local skill = Fk.skills[C.ABILITY_SKILL]
  skill.interaction.data = "hanjin_test__commander_delta"
  local card = skill:viewAs({}, {})
  skill.interaction.data = nil
  lu.assertNotNil(card)
  lu.assertEquals(card.name, "hanjin__thunder__slash")
  lu.assertEquals(card:getMark(C.CARD_SOURCE_MARK), "hanjin_test__commander_delta")

  local serverCard = C.buildViewAsCard(user, "hanjin_test__commander_delta")
  lu.assertNotNil(serverCard)
  lu.assertEquals(serverCard:getMark(C.CARD_SOURCE_MARK), "hanjin_test__commander_delta")

  FkTest.setNextReplies(user, { { "hanjin_test__retinue_alpha" } })
  local paid
  FkTest.runInRoom(function()
    paid = C.payCost(user, sourceOf("hanjin_test__commander_delta"), false)
  end)
  lu.assertTrue(paid)
end

return { name = "hanjin_commander_retinue" }
