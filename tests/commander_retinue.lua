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
  -- 偏将（限一翼从）与提供它的统领来源分别登记；普通翼从不限一。
  lu.assertTrue(C.isLimitedRetinue("hanjin_test__retinue_zhoucang"))
  lu.assertFalse(C.isLimitedRetinue("hanjin_test__retinue_alpha"))
  lu.assertTrue(C.commanders["hanjin_test__commander_guanyu"].limited)
  lu.assertFalse(C.commanders["hanjin_test__commander_alpha"].limited)
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
  -- Both positions must be deterministic test generals: a randomly dealt formal
  -- commander would be revealed and registered during H.removeGeneral.
  setHidden(target, "hanjin_test__wei_1", "hanjin_test__wei_2", "wei")
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

local function setCurrent(player)
  FkTest.runInRoom(function() room():setCurrent(player) end)
end

--- 测试房间没有回合流程可依赖。先把势力写到属性上，使 revealGeneral 跳过
--- 「同势力人数过多自动转野心家」的随机分支，保证多势力场景可复现。
local function settleKingdom(player, kingdom)
  FkTest.runInRoom(function() room():setPlayerProperty(player, "kingdom", kingdom) end)
end

local function revealBoth(player)
  reveal(player, false)
  reveal(player, true)
end

--- 白板士兵通过真实的武将变更入口取得，以便触发同一转换流程。
local function gainBlankAt(player, isDeputy)
  FkTest.runInRoom(function()
    room():changeHero(player, "blank_shibing", false, isDeputy, false, false, false)
    room():setPlayerMark(player, isDeputy and "__heg_deputy" or "__heg_general", "blank_shibing")
  end)
end

--- 走引擎真实的 Request→handleUseCardReply 分支（view_as → before_use 支付 →
--- room:useCard），从而真正经过 PreCardUse、使用宣告和 CardUseFinished。
--- 返回 handleUseCardReply 的结果：字符串表示被技能取消，nil 表示已进入使用。
local function useAbilityThroughEngine(player, sourceKey, tos)
  local skill = Fk.skills[C.ABILITY_SKILL]
  local targetIds = {}
  for _, target in ipairs(tos or {}) do table.insert(targetIds, target.id) end
  local result
  FkTest.runInRoom(function()
    result = room():handleUseCardReply(player, {
      card = { skill = C.ABILITY_SKILL, subcards = {} },
      targets = targetIds,
      interaction_data = sourceKey,
    }, nil)
    skill.interaction.data = nil
  end)
  return result
end

local REENTRY_SKILL = "hanjin_test__reentry_probe"
local ABORT_SKILL = "hanjin_test__abort_pre_card_use"

local function addTestSkillOnce(name, build)
  if Fk.skills[name] ~= nil then return end
  local skeleton = fk.CreateSkill { name = name }
  build(skeleton)
  Fk:addSkill(skeleton:createSkill())
end

addTestSkillOnce(REENTRY_SKILL, function(skeleton)
  skeleton:addEffect(H.GeneralRemoving, {
    global = true,
    can_trigger = function(self, event, target, player, data)
      return target == player and player.room:getTag("hanjin_test_reentry_active") == true
    end,
    on_trigger = function(self, event, target, player, data)
      local room = player.room
      local other = room:getPlayerById(room:getTag("hanjin_test_reentry_player") or 0)
      local source = C.source(room, room:getTag("hanjin_test_reentry_source") or "")
      if other == nil or source == nil then return end
      -- 支付/移将回调期间同一来源仍被临时占用，必须拒绝且不扣将。
      room:setTag("hanjin_test_reentry_result", C.payCost(other, source, false))
    end,
  })
end)

addTestSkillOnce(ABORT_SKILL, function(skeleton)
  skeleton:addEffect(fk.PreCardUse, {
    global = true,
    priority = 100,
    can_trigger = function(self, event, target, player, data)
      return target == player and player.room:getTag("hanjin_test_abort_active") == true
        and data.card ~= nil and data.card:getMark(C.CARD_SOURCE_MARK) ~= nil
    end,
    on_trigger = function(self, event, target, player, data)
      return true
    end,
  })
end)

local function grantProbe(player, name)
  FkTest.runInRoom(function()
    room():handleAddLoseSkills(player, name, nil, false, true)
  end)
end

--- 每张偏将全场只能实际取得一次，且跨势力、离场与重新明置都不刷新。
function Testhanjin_commander_retinue:testLimitedRetinueIsTakenOnceAndNeverRefreshes()
  local holder, first, second, migrant = room().players[1], room().players[2], room().players[3], room().players[5]
  setHidden(holder, "hanjin_test__commander_guanyu", "hanjin_test__shu_1", "shu")
  setHidden(first, "hanjin_test__shu_2", "hanjin_test__shu_3", "shu")
  setHidden(second, "hanjin_test__shu_4", "hanjin_test__shu_5", "shu")
  setHidden(migrant, "hanjin_test__wei_1", "hanjin_test__wei_2", "wei")
  settleKingdom(holder, "shu")
  settleKingdom(first, "shu")
  settleKingdom(second, "shu")
  settleKingdom(migrant, "wei")
  revealBoth(first)
  revealBoth(second)
  revealBoth(migrant)
  setBlankDirect(first, true)
  setBlankDirect(second, true)
  setCurrent(first)

  -- 只有一张偏将可得时，最先处理的角色自动取得。
  reveal(holder, false)
  lu.assertEquals(first.deputyGeneral, "hanjin_test__retinue_zhoucang")
  lu.assertTrue(C.limitedRetinueTaken(room(), "hanjin_test__retinue_zhoucang"))
  lu.assertTrue(C.isBlankSoldier(second.deputyGeneral))
  lu.assertEquals(C.availableRetinues(room(), "shu"), {})

  -- 偏将离场（被移除成白板）不刷新取得记录。
  FkTest.runInRoom(function() H.removeGeneral(first, true) end)
  lu.assertTrue(C.isBlankSoldier(first.deputyGeneral))
  lu.assertTrue(C.limitedRetinueTaken(room(), "hanjin_test__retinue_zhoucang"))
  lu.assertEquals(C.availableRetinues(room(), "shu"), {})

  -- 来源迁移到另一势力后，新势力也不能再取得同一张偏将。
  FkTest.runInRoom(function() room():changeKingdom(holder, "wei") end)
  lu.assertTrue(sourceOf("hanjin_test__commander_guanyu").factions["wei"])
  lu.assertNil(sourceOf("hanjin_test__commander_guanyu").factions["shu"])
  lu.assertEquals(C.availableRetinues(room(), "wei"), {})
  lu.assertEquals(C.availableRetinues(room(), "shu"), {})

  -- 重新明置来源仍不重置。
  FkTest.runInRoom(function() holder:hideGeneral(false) end)
  reveal(holder, false)
  lu.assertTrue(C.limitedRetinueTaken(room(), "hanjin_test__retinue_zhoucang"))
  lu.assertEquals(C.availableRetinues(room(), "wei"), {})

  -- 迁移后的新势力角色取得白板士兵时保留白板。
  gainBlankAt(migrant, true)
  lu.assertTrue(C.isBlankSoldier(migrant.deputyGeneral))
end

--- 多名角色及同一角色的两个位置从当前回合角色起按逆时针逐位结算。
function Testhanjin_commander_retinue:testLimitedRetinuesFollowActionOrderAndBothPositions()
  local guanyuHolder, caorenHolder = room().players[1], room().players[2]
  local target5, target7, target3 = room().players[5], room().players[7], room().players[3]
  setHidden(guanyuHolder, "hanjin_test__commander_guanyu", "hanjin_test__shu_1", "shu")
  setHidden(caorenHolder, "hanjin_test__commander_caoren", "hanjin_test__shu_2", "shu")
  setHidden(target5, "hanjin_test__shu_3", "hanjin_test__shu_4", "shu")
  setHidden(target7, "hanjin_test__shu_5", "hanjin_test__shu_6", "shu")
  setHidden(target3, "hanjin_test__shu_7", "hanjin_test__shu_8", "shu")
  settleKingdom(guanyuHolder, "shu")
  settleKingdom(caorenHolder, "shu")
  settleKingdom(target5, "shu")
  settleKingdom(target7, "shu")
  settleKingdom(target3, "shu")
  -- 先让关羽来源登记，再让目标角色明置并取得白板。
  reveal(guanyuHolder, false)
  revealBoth(target5)
  revealBoth(target7)
  revealBoth(target3)
  setBlankDirect(target5, false)
  setBlankDirect(target5, true)
  setBlankDirect(target7, true)
  setBlankDirect(target3, false)
  setCurrent(target5)
  -- 引擎行动顺序（当前回合角色起、下家即逆时针）应为 5 → 7 → 3。
  local ordered = C.orderedAlivePlayers(room())
  local rank = {}
  for index, player in ipairs(ordered) do rank[player.id] = index end
  lu.assertTrue(rank[target5.id] < rank[target7.id])
  lu.assertTrue(rank[target7.id] < rank[target3.id])

  -- 明置曹仁来源时，两个限一来源同时有效，一次性结算全部白板位置。
  FkTest.cleanNextReplies(target5)
  FkTest.setNextReplies(target5, { { "hanjin_test__retinue_zhoucang" } })
  reveal(caorenHolder, false)

  lu.assertEquals(target5.general, "hanjin_test__retinue_zhoucang")
  lu.assertEquals(target5.deputyGeneral, "hanjin_test__retinue_niujin")
  lu.assertTrue(C.isBlankSoldier(target7.deputyGeneral))
  lu.assertTrue(C.isBlankSoldier(target3.general))
  lu.assertTrue(C.limitedRetinueTaken(room(), "hanjin_test__retinue_zhoucang"))
  lu.assertTrue(C.limitedRetinueTaken(room(), "hanjin_test__retinue_niujin"))
  lu.assertEquals(C.availableRetinues(room(), "shu"), {})
end

--- 先取得周仓，另一名无士兵角色仍可借关羽使用【酒】。
function Testhanjin_commander_retinue:testBorrowingCardAfterRetinueTaken()
  local holder, target, borrower, other = room().players[1], room().players[2], room().players[3], room().players[4]
  local weiUser = room().players[5]
  setHidden(holder, "hanjin_test__commander_guanyu", "hanjin_test__shu_1", "shu")
  setHidden(target, "hanjin_test__shu_2", "hanjin_test__shu_3", "shu")
  setHidden(borrower, "hanjin_test__shu_4", "hanjin_test__shu_5", "shu")
  setHidden(other, "hanjin_test__shu_6", "hanjin_test__shu_7", "shu")
  setHidden(weiUser, "hanjin_test__wei_3", "hanjin_test__wei_4", "wei")
  settleKingdom(holder, "shu")
  settleKingdom(target, "shu")
  settleKingdom(borrower, "shu")
  settleKingdom(other, "shu")
  settleKingdom(weiUser, "wei")
  reveal(holder, false)
  revealBoth(target)
  revealBoth(borrower)
  revealBoth(other)
  revealBoth(weiUser)
  gainBlankAt(target, true)
  lu.assertEquals(target.deputyGeneral, "hanjin_test__retinue_zhoucang")
  lu.assertTrue(C.limitedRetinueTaken(room(), "hanjin_test__retinue_zhoucang"))
  lu.assertFalse(C.limitedAbilityUsed(room(), "hanjin_test__commander_guanyu"))

  local skill = Fk.skills[C.ABILITY_SKILL]
  FkTest.setNextReplies(borrower, { { "mainGeneral" } })
  local use = useAbilityThroughEngine(borrower, "hanjin_test__commander_guanyu")
  lu.assertNotEquals(type(use), "string")
  lu.assertTrue(C.limitedAbilityUsed(room(), "hanjin_test__commander_guanyu"))
  lu.assertFalse(C.abilityReserved(room(), "hanjin_test__commander_guanyu"))
  lu.assertTrue(C.isBlankSoldier(borrower.general))
  lu.assertTrue(C.limitedRetinueTaken(room(), "hanjin_test__retinue_zhoucang"))

  -- 已用尽的来源对所有人立即禁用，且再次尝试不会误扣武将。
  lu.assertNil(C.buildViewAsCard(other, "hanjin_test__commander_guanyu"))
  local before = { other.general, other.deputyGeneral }
  local paid
  FkTest.runInRoom(function()
    paid = C.payCost(other, sourceOf("hanjin_test__commander_guanyu"), false)
  end)
  lu.assertFalse(paid)
  lu.assertEquals(other.general, before[1])
  lu.assertEquals(other.deputyGeneral, before[2])
  lu.assertEquals(#C.abilitySources(other), 0)
  lu.assertEquals(other:getMark(C.SOURCE_MARK), 0)

  -- 伪造牌面或被取消的旧牌在 before_use 被拒，同样不消耗次数。
  local forged = Fk:cloneCard("hanjin_test__slash")
  forged.skillName = C.ABILITY_SKILL
  forged:setMark(C.CARD_SOURCE_MARK, "hanjin_test__commander_guanyu")
  local forgedBefore = { other.general, other.deputyGeneral }
  local rejected, staleRejected
  FkTest.runInRoom(function()
    rejected = skill:beforeUse(other, { from = other, card = forged })
    staleRejected = skill:beforeUse(other, { from = other, card = card })
  end)
  lu.assertEquals(rejected, C.ABILITY_SKILL)
  lu.assertEquals(staleRejected, C.ABILITY_SKILL)
  lu.assertEquals(other.general, forgedBefore[1])
  lu.assertEquals(other.deputyGeneral, forgedBefore[2])

  -- 来源迁移势力、重新明置也不重置已用记录；新势力角色同样不能再借。
  FkTest.runInRoom(function() room():changeKingdom(holder, "wei") end)
  lu.assertTrue(C.limitedAbilityUsed(room(), "hanjin_test__commander_guanyu"))
  lu.assertNil(C.buildViewAsCard(weiUser, "hanjin_test__commander_guanyu"))
  local weiBefore = { weiUser.general, weiUser.deputyGeneral }
  local weiPaid
  FkTest.runInRoom(function()
    weiPaid = C.payCost(weiUser, sourceOf("hanjin_test__commander_guanyu"), false)
  end)
  lu.assertFalse(weiPaid)
  lu.assertEquals(weiUser.general, weiBefore[1])
  lu.assertEquals(weiUser.deputyGeneral, weiBefore[2])

  FkTest.runInRoom(function() holder:hideGeneral(false) end)
  reveal(holder, false)
  lu.assertTrue(C.limitedAbilityUsed(room(), "hanjin_test__commander_guanyu"))
end

--- 首次借酒选择其他翼从时，周仓仍留待之后取得。
function Testhanjin_commander_retinue:testBorrowingCardMayChooseOtherThenTakeRetinueLater()
  local holder, betaHolder, user, latecomer = room().players[1], room().players[2], room().players[3], room().players[4]
  setHidden(holder, "hanjin_test__commander_guanyu", "hanjin_test__shu_1", "shu")
  setHidden(betaHolder, "hanjin_test__commander_beta", "hanjin_test__shu_2", "shu")
  setHidden(user, "hanjin_test__shu_3", "hanjin_test__shu_4", "shu")
  setHidden(latecomer, "hanjin_test__shu_5", "hanjin_test__shu_6", "shu")
  settleKingdom(holder, "shu")
  settleKingdom(betaHolder, "shu")
  settleKingdom(user, "shu")
  settleKingdom(latecomer, "shu")
  reveal(holder, false)
  reveal(betaHolder, false)
  revealBoth(user)
  revealBoth(latecomer)
  lu.assertEquals(C.availableRetinues(room(), "shu"),
    { "hanjin_test__retinue_beta", "hanjin_test__retinue_zhoucang" })

  FkTest.setNextReplies(user, {
    { "mainGeneral" },
    { "hanjin_test__retinue_beta" },
  })
  local use = useAbilityThroughEngine(user, "hanjin_test__commander_guanyu")
  lu.assertNotEquals(type(use), "string")
  lu.assertEquals(user.general, "hanjin_test__retinue_beta")
  lu.assertTrue(C.limitedAbilityUsed(room(), "hanjin_test__commander_guanyu"))
  lu.assertFalse(C.abilityReserved(room(), "hanjin_test__commander_guanyu"))
  lu.assertFalse(C.limitedRetinueTaken(room(), "hanjin_test__retinue_zhoucang"))
  lu.assertTrue(table.contains(C.availableRetinues(room(), "shu"), "hanjin_test__retinue_zhoucang"))

  -- 之后取得白板士兵的角色仍可选择周仓。
  FkTest.setNextReplies(latecomer, { { "hanjin_test__retinue_zhoucang" } })
  gainBlankAt(latecomer, true)
  lu.assertEquals(latecomer.deputyGeneral, "hanjin_test__retinue_zhoucang")
  lu.assertTrue(C.limitedRetinueTaken(room(), "hanjin_test__retinue_zhoucang"))
end

--- 同名牌不同来源独立；正常使用同名牌不消耗限一能力。
function Testhanjin_commander_retinue:testSameCardNameSourcesAreIndependent()
  local guanyuHolder, caorenHolder = room().players[1], room().players[2]
  local normalUser, guanyuUser, caorenUser = room().players[3], room().players[4], room().players[5]
  setHidden(guanyuHolder, "hanjin_test__commander_guanyu", "hanjin_test__shu_1", "shu")
  setHidden(caorenHolder, "hanjin_test__commander_caoren", "hanjin_test__shu_2", "shu")
  setHidden(normalUser, "hanjin_test__shu_3", "hanjin_test__shu_4", "shu")
  setHidden(guanyuUser, "hanjin_test__shu_5", "hanjin_test__shu_6", "shu")
  setHidden(caorenUser, "hanjin_test__shu_7", "hanjin_test__shu_8", "shu")
  settleKingdom(guanyuHolder, "shu")
  settleKingdom(caorenHolder, "shu")
  settleKingdom(normalUser, "shu")
  settleKingdom(guanyuUser, "shu")
  settleKingdom(caorenUser, "shu")
  reveal(guanyuHolder, false)
  reveal(caorenHolder, false)
  revealBoth(normalUser)
  revealBoth(guanyuUser)
  revealBoth(caorenUser)

  -- 正常使用一张真实的【酒】不影响任何统领来源。
  FkTest.runInRoom(function()
    room():useCard { from = normalUser, card = Fk:cloneCard("hanjin__analeptic") }
  end)
  lu.assertNil(C.usedLimitedAbilities(room())["hanjin_test__commander_guanyu"])
  lu.assertNil(C.usedLimitedAbilities(room())["hanjin_test__commander_caoren"])
  lu.assertTrue(#C.abilitySources(normalUser) >= 2)

  FkTest.setNextReplies(guanyuUser, {
    { "mainGeneral" },
    { "hanjin_test__retinue_zhoucang" },
  })
  local use = useAbilityThroughEngine(guanyuUser, "hanjin_test__commander_guanyu")
  lu.assertNotEquals(type(use), "string")
  lu.assertTrue(C.limitedAbilityUsed(room(), "hanjin_test__commander_guanyu"))
  lu.assertFalse(C.limitedAbilityUsed(room(), "hanjin_test__commander_caoren"))

  -- 曹仁来源的同名牌【酒】仍可独立使用；此时只剩牛金可选，自动取得。
  FkTest.setNextReplies(caorenUser, { { "mainGeneral" } })
  local second = useAbilityThroughEngine(caorenUser, "hanjin_test__commander_caoren")
  lu.assertNotEquals(type(second), "string")
  lu.assertTrue(C.limitedAbilityUsed(room(), "hanjin_test__commander_caoren"))
  lu.assertEquals(caorenUser.general, "hanjin_test__retinue_niujin")
  lu.assertTrue(C.limitedAbilityUsed(room(), "hanjin_test__commander_guanyu"))
end

--- 限一来源的响应路径：无懈可击的“使用”窗口开放，用掉后全场立即失效。
function Testhanjin_commander_retinue:testLimitedNullificationSourceConsumesChance()
  local holder, user, other = room().players[1], room().players[2], room().players[3]
  setHidden(holder, "hanjin_test__commander_taishici", "hanjin_test__shu_1", "shu")
  setHidden(user, "hanjin_test__shu_2", "hanjin_test__shu_3", "shu")
  setHidden(other, "hanjin_test__shu_4", "hanjin_test__shu_5", "shu")
  settleKingdom(holder, "shu")
  settleKingdom(user, "shu")
  settleKingdom(other, "shu")
  reveal(holder, false)
  revealBoth(user)
  revealBoth(other)

  local skill = Fk.skills[C.ABILITY_SKILL]
  local oldPattern = Fk.currentResponsePattern
  Fk.currentResponsePattern = "nullification"
  lu.assertTrue(C.hasNullificationSource(user))
  lu.assertTrue(skill:enabledAtNullification(user))
  lu.assertFalse(skill:enabledAtResponse(user, true))
  Fk.currentResponsePattern = oldPattern

  local card = C.buildViewAsCard(user, "hanjin_test__commander_taishici")
  lu.assertNotNil(card)
  lu.assertEquals(card.trueName, "nullification")
  lu.assertTrue(card.is_passive)
  FkTest.setNextReplies(user, { { "mainGeneral" } })
  local use = useAbilityThroughEngine(user, "hanjin_test__commander_taishici")
  lu.assertNotEquals(type(use), "string")
  lu.assertTrue(C.limitedAbilityUsed(room(), "hanjin_test__commander_taishici"))
  lu.assertFalse(C.abilityReserved(room(), "hanjin_test__commander_taishici"))
  lu.assertTrue(C.limitedRetinueTaken(room(), "hanjin_test__retinue_quaxiaojiang"))
  lu.assertEquals(user.general, "hanjin_test__retinue_quaxiaojiang")

  Fk.currentResponsePattern = "nullification"
  lu.assertFalse(C.hasNullificationSource(other))
  lu.assertFalse(skill:enabledAtNullification(other))
  Fk.currentResponsePattern = oldPattern
  lu.assertNil(C.buildViewAsCard(other, "hanjin_test__commander_taishici"))
  local before = { other.general, other.deputyGeneral }
  local paid
  FkTest.runInRoom(function()
    paid = C.payCost(other, sourceOf("hanjin_test__commander_taishici"), false)
  end)
  lu.assertFalse(paid)
  lu.assertEquals(other.general, before[1])
  lu.assertEquals(other.deputyGeneral, before[2])
end

--- 使用已宣告后被无懈可击抵消：次数不返还。
function Testhanjin_commander_retinue:testNullifiedAbilityUseStaysConsumed()
  local holder, user, victim, nullifier = room().players[1], room().players[2], room().players[3], room().players[4]
  setHidden(holder, "hanjin_test__commander_duel", "hanjin_test__shu_1", "shu")
  setHidden(user, "hanjin_test__shu_2", "hanjin_test__shu_3", "shu")
  setHidden(victim, "hanjin_test__shu_4", "hanjin_test__shu_5", "shu")
  setHidden(nullifier, "hanjin_test__wei_1", "hanjin_test__wei_2", "wei")
  settleKingdom(holder, "shu")
  settleKingdom(user, "shu")
  settleKingdom(victim, "shu")
  settleKingdom(nullifier, "wei")
  reveal(holder, false)
  revealBoth(user)
  revealBoth(victim)
  revealBoth(nullifier)

  local nullification
  FkTest.runInRoom(function()
    nullification = room():printCard("nullification")
    room():obtainCard(nullifier, nullification)
  end)
  lu.assertNotNil(nullification)
  lu.assertTrue(table.contains(nullifier:getCardIds("h"), nullification.id))
  local hp = victim.hp
  FkTest.setNextReplies(nullifier, { { card = nullification.id } })
  FkTest.setNextReplies(user, { { "mainGeneral" } })
  local use = useAbilityThroughEngine(user, "hanjin_test__commander_duel", { victim })
  lu.assertNotEquals(type(use), "string")

  -- 效果已被抵消，但使用已宣告，限一机会保持已用。
  lu.assertTrue(C.limitedAbilityUsed(room(), "hanjin_test__commander_duel"))
  lu.assertFalse(C.abilityReserved(room(), "hanjin_test__commander_duel"))
  lu.assertEquals(victim.hp, hp)
  lu.assertFalse(table.contains(nullifier:getCardIds("h"), nullification.id))
end

--- before_use 支付、PreCardUse 中止：释放临时占用，不永久扣一次。
function Testhanjin_commander_retinue:testPreCardUseAbortReleasesReservation()
  local holder, user, backup = room().players[1], room().players[2], room().players[3]
  setHidden(holder, "hanjin_test__commander_guanyu", "hanjin_test__shu_1", "shu")
  setHidden(user, "hanjin_test__shu_2", "hanjin_test__shu_3", "shu")
  setHidden(backup, "hanjin_test__shu_4", "hanjin_test__shu_5", "shu")
  settleKingdom(holder, "shu")
  settleKingdom(user, "shu")
  settleKingdom(backup, "shu")
  reveal(holder, false)
  revealBoth(user)
  revealBoth(backup)
  grantProbe(user, ABORT_SKILL)
  FkTest.runInRoom(function() room():setTag("hanjin_test_abort_active", true) end)

  FkTest.setNextReplies(user, { { "mainGeneral" } })
  local use = useAbilityThroughEngine(user, "hanjin_test__commander_guanyu")
  lu.assertNotEquals(type(use), "string")
  lu.assertFalse(C.limitedAbilityUsed(room(), "hanjin_test__commander_guanyu"))
  lu.assertFalse(C.abilityReserved(room(), "hanjin_test__commander_guanyu"))
  -- 移将代价已支付（新白板按当时可得兵种转换），但本局机会未被永久消耗。
  lu.assertTrue(C.isSoldier(user.general))
  lu.assertNotNil(C.buildViewAsCard(backup, "hanjin_test__commander_guanyu"))
  FkTest.runInRoom(function() room():setTag("hanjin_test_abort_active", false) end)

  FkTest.setNextReplies(backup, { { "mainGeneral" } })
  local second = useAbilityThroughEngine(backup, "hanjin_test__commander_guanyu")
  lu.assertNotEquals(type(second), "string")
  lu.assertTrue(C.limitedAbilityUsed(room(), "hanjin_test__commander_guanyu"))
  lu.assertFalse(C.abilityReserved(room(), "hanjin_test__commander_guanyu"))
end

--- 支付/移将回调期间同一来源被临时占用，重入被拒绝且不误扣武将。
function Testhanjin_commander_retinue:testPaymentCallbackReentryIsBlocked()
  local holder, user, other = room().players[1], room().players[2], room().players[3]
  setHidden(holder, "hanjin_test__commander_guanyu", "hanjin_test__shu_1", "shu")
  setHidden(user, "hanjin_test__shu_2", "hanjin_test__shu_3", "shu")
  setHidden(other, "hanjin_test__shu_4", "hanjin_test__shu_5", "shu")
  settleKingdom(holder, "shu")
  settleKingdom(user, "shu")
  settleKingdom(other, "shu")
  reveal(holder, false)
  revealBoth(user)
  revealBoth(other)
  grantProbe(user, REENTRY_SKILL)
  FkTest.runInRoom(function()
    room():setTag("hanjin_test_reentry_active", true)
    room():setTag("hanjin_test_reentry_player", other.id)
    room():setTag("hanjin_test_reentry_source", "hanjin_test__commander_guanyu")
  end)

  FkTest.setNextReplies(user, { { "mainGeneral" } })
  local use = useAbilityThroughEngine(user, "hanjin_test__commander_guanyu")
  lu.assertNotEquals(type(use), "string")
  lu.assertFalse(room():getTag("hanjin_test_reentry_result"))
  lu.assertEquals(other.general, "hanjin_test__shu_4")
  lu.assertEquals(other.deputyGeneral, "hanjin_test__shu_5")
  lu.assertTrue(C.limitedAbilityUsed(room(), "hanjin_test__commander_guanyu"))
  lu.assertFalse(C.abilityReserved(room(), "hanjin_test__commander_guanyu"))
  FkTest.runInRoom(function() room():setTag("hanjin_test_reentry_active", false) end)
end

--- 用正式关羽/周仓数据走完整引擎入口用一次【酒】。
function Testhanjin_commander_retinue:testFormalGuanyuZhoucangEndToEnd()
  local holder, target, borrower = room().players[1], room().players[2], room().players[3]
  setHidden(holder, "hanjin__shu002", "hanjin__shu001", "shu")
  setHidden(target, "hanjin__shu007", "hanjin__shu008", "shu")
  setHidden(borrower, "hanjin__shu003", "hanjin__shu004", "shu")
  settleKingdom(holder, "shu")
  settleKingdom(target, "shu")
  settleKingdom(borrower, "shu")
  reveal(holder, false)
  revealBoth(target)
  revealBoth(borrower)

  lu.assertTrue(C.commanders["hanjin__shu002"].limited)
  gainBlankAt(target, true)
  lu.assertEquals(target.deputyGeneral, "hanjin__retinue_zhoucang")
  lu.assertTrue(C.limitedRetinueTaken(room(), "hanjin__retinue_zhoucang"))

  FkTest.setNextReplies(borrower, { { "mainGeneral" } })
  local use = useAbilityThroughEngine(borrower, "hanjin__shu002")
  lu.assertNotEquals(type(use), "string")
  lu.assertEquals(C.commanders["hanjin__shu002"].card, "hanjin__analeptic")
  lu.assertTrue(C.limitedAbilityUsed(room(), "hanjin__shu002"))
  lu.assertFalse(C.abilityReserved(room(), "hanjin__shu002"))
  lu.assertTrue(C.isBlankSoldier(borrower.general))
end

--- 普通翼从仍可被多次取得，不受偏将的全场唯一限制影响。
function Testhanjin_commander_retinue:testOrdinaryRetinuesStayUnlimited()
  local holder, first, second = room().players[1], room().players[2], room().players[3]
  setHidden(holder, "hanjin_test__commander_alpha", "hanjin_test__shu_1", "shu")
  setHidden(first, "hanjin_test__shu_2", "hanjin_test__shu_3", "shu")
  setHidden(second, "hanjin_test__shu_4", "hanjin_test__shu_5", "shu")
  settleKingdom(holder, "shu")
  settleKingdom(first, "shu")
  settleKingdom(second, "shu")
  revealBoth(first)
  revealBoth(second)
  setBlankDirect(first, true)
  setBlankDirect(second, true)
  FkTest.setNextReplies(first, { { "hanjin_test__retinue_alpha" } })
  FkTest.setNextReplies(second, { { "hanjin_test__retinue_alpha" } })
  reveal(holder, false)

  lu.assertEquals(first.deputyGeneral, "hanjin_test__retinue_alpha")
  lu.assertEquals(second.deputyGeneral, "hanjin_test__retinue_alpha")
  lu.assertFalse(C.limitedRetinueTaken(room(), "hanjin_test__retinue_alpha"))
  lu.assertTrue(table.contains(C.availableRetinues(room(), "shu"), "hanjin_test__retinue_alpha"))
end

function Testhanjin_commander_retinue:testVisibleFormalMaTengEntryPaysZhenJiAndUsesSlash()
  local user, target = room().players[1], room().players[2]
  setHidden(user, "hanjin__qun013", "hanjin__wei007", "qun")
  reveal(user, false)
  reveal(user, true)

  local skill = Fk.skills[C.ABILITY_SKILL]
  lu.assertTrue(skill.visible, "统领共享视为技必须是可见技能入口")
  lu.assertEquals(skill.name, C.ABILITY_SKILL)
  lu.assertEquals(Fk:translate(C.ABILITY_SKILL), "统领")
  lu.assertEquals(Fk:translate("mainGeneral"), "主将")
  lu.assertEquals(Fk:translate("deputyGeneral"), "副将")
  lu.assertTrue(user:hasSkill(C.ABILITY_SKILL))
  lu.assertTrue(skill:enabledAtPlay(user))
  lu.assertEquals(C.markSources(user), { "hanjin__qun013" })
  lu.assertEquals(Fk:translate("hanjin__qun013"), "马腾")
  lu.assertEquals(C.SOURCE_MARK:sub(1, 2), "@[")
  local sourceSpec = Fk.qml_marks["hanjin_commander_sources"]
  lu.assertNotNil(sourceSpec)
  local beforeHide = C.markSources(user)
  lu.assertEquals(sourceSpec.how_to_show(C.SOURCE_MARK, beforeHide, user), "#hidden")
  lu.assertEquals(C.markSources(user), beforeHide)
  local clientPlayer = ClientInstance:getPlayerById(user.id)
  if clientPlayer then
    ClientInstance:handleSetPlayerMark({ user.id, C.SOURCE_MARK, beforeHide })
    lu.assertEquals(clientPlayer:getMark(C.SOURCE_MARK), beforeHide)
  end

  local source = C.source(room(), "hanjin__qun013")
  lu.assertEquals(C.costCandidates(user, source), { true })
  -- 提供来源的马腾本人不能作为代价；主将位置必须保持不变。
  lu.assertFalse(C.payCost(user, source, false))
  lu.assertEquals(user.general, "hanjin__qun013")

  local card
  skill.interaction.data = "hanjin__qun013"
  FkTest.runInRoom(function() card = skill:viewAs(user, {}) end)
  lu.assertNotNil(card)
  lu.assertEquals(card.trueName, "slash")
  lu.assertEquals(card.skillName, C.ABILITY_SKILL)
  lu.assertEquals(card:getMark(C.CARD_SOURCE_MARK), "hanjin__qun013")

  local hp = target.hp
  FkTest.setNextReplies(user, { { "hanjin__retinue_xiliang_jingqi" } })
  FkTest.setNextReplies(target, { "" })
  local accepted
  FkTest.runInRoom(function()
    accepted = skill:beforeUse(user, { from = user, tos = { target }, card = card })
    lu.assertNil(accepted)
    room():useCard { from = user, tos = { target }, card = card }
  end)
  skill.interaction.data = nil
  lu.assertEquals(user.general, "hanjin__qun013")
  lu.assertTrue(C.isSoldier(user.deputyGeneral))
  lu.assertEquals(user.deputyGeneral, "hanjin__retinue_xiliang_jingqi")
  lu.assertEquals(target.hp, hp - 1)
end

return { name = "hanjin_commander_retinue" }
