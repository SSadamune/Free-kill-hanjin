local support = __dofile("../../../tests/support/hegemony.lua")
local C = require "packages.hanjin.pkg.hanjin_mode.rules.card_use_targets"
local O = require "packages.hanjin.pkg.hanjin_mode.rules.only_as"
local CR = require "packages.hanjin.pkg.hanjin_mode.rules.commander_retinue"

local function setup()
  Fk.currentResponsePattern = nil
  return support.initHanjinRoom()
end

Testhanjin_card_use_targets = { setup = setup, tearDown = support.clearRoom }

local function room() return FkTest.room end
local function run(fn) FkTest.runInRoom(fn) end

local function give(player, name, suit, number)
  local card
  run(function()
    card = room():printCard(name, suit, number)
    room():obtainCard(player, card, true)
  end)
  return card
end

local function hasTarget(list, player)
  return table.contains(list, player)
end

local function snatch(player, suit, number)
  return give(player, "hanjin__snatch", suit, number)
end

local function equip(player, name, suit, number)
  local card = give(player, name, suit, number)
  run(function()
    room():moveCardTo(card, Card.PlayerEquip, player, fk.ReasonPut, "test", nil, true)
  end)
  return card
end

local function emptyHand(player)
  run(function()
    local ids = player:getCardIds("h")
    if #ids > 0 then room():throwCard(ids, "test", player, player) end
  end)
end

local function setKingdoms(kingdoms)
  run(function()
    for index, kingdom in ipairs(kingdoms) do
      room():setPlayerProperty(room().players[index], "kingdom", kingdom)
    end
  end)
end

local probeSerial = 0
--- Observe the real use pipeline (not a mirror of the target policy).
local function cardProbe(cardName)
  probeSerial = probeSerial + 1
  local counts, effects = {}, {}
  local skel = fk.CreateSkill {
    name = "#hanjin_use_targets_probe_" .. probeSerial .. "_" .. cardName:gsub("[^%w_]", "_"),
  }
  for _, event in ipairs({ fk.CardUsing, fk.CardEffecting, fk.CardUseFinished }) do
    skel:addEffect(event, {
      global = true,
      can_refresh = function(self, ev, target, player, data)
        return target == player and data.card ~= nil and data.card.name == cardName
      end,
      on_refresh = function(self, ev, target, player, data)
        counts[event] = (counts[event] or 0) + 1
        if event == fk.CardEffecting then table.insert(effects, data.to) end
      end,
    })
  end
  run(function() room():addSkill(skel:createSkill()) end)
  return counts, effects
end

local groupKingdoms = { "wei", "wei", "shu", "shu", "wu", "wu", "qun", "han" }

local function setHiddenGeneral(player, main, deputy, kingdom)
  run(function()
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

local function revealGeneral(player, isDeputy)
  run(function() player:revealGeneral(isDeputy) end)
end

-- Test-only only-as source: a hand jink can be used as 顺手牵羊.
O.define("hanjin_test_snatch_conversion", {
  match = { names = { "jink" } },
  conversions = {
    { name = "hanjin__snatch", modes = { "use" }, order = 1 },
  },
  direct_zones = "any",
  view_zones = { "hand", "handly" },
})

local conversionSkill = fk.CreateSkill { name = "hanjin_test__snatch_conversion" }
O.addViewAsEffect(conversionSkill, "hanjin_test_snatch_conversion")
Fk:addSkill(conversionSkill:createSkill())

-- Test-only direct prohibition source for physical 顺手牵羊.
O.define("hanjin_test_forbid_snatch", {
  match = { names = { "snatch" } },
  conversions = {
    { name = "hanjin__jink", modes = { "use" }, order = 1 },
  },
  direct_zones = "any",
  view_zones = { "hand" },
})

function Testhanjin_card_use_targets:testDefaultPhysicalSnatchKeepsDistanceAndArea()
  local p1, p2, p5 = room().players[1], room().players[2], room().players[5]
  local card = snatch(p1, Card.Spade, 3)
  local nearCard = give(p2, "hanjin__jink", Card.Heart, 2)
  local farCard = give(p5, "hanjin__jink", Card.Heart, 3)
  local candidates
  run(function() candidates = C.candidates(room(), p1, card, C.default()) end)
  lu.assertTrue(hasTarget(candidates, p2))
  lu.assertFalse(hasTarget(candidates, p5))

  FkTest.setNextReplies(p1, { { card = card.id, targets = { p5.id } } })
  local use
  run(function()
    use = C.askToUseCard(room(), p1, {
      pattern = "snatch", names = { "hanjin__snatch" },
      policy = C.default(), skill_name = "hanjin_test_default",
    })
  end)
  lu.assertNil(use)
  lu.assertTrue(table.contains(p1:getCardIds("h"), card.id))
  lu.assertTrue(table.contains(p2:getCardIds("h"), nearCard.id))
  lu.assertTrue(table.contains(p5:getCardIds("h"), farCard.id))
end

function Testhanjin_card_use_targets:testDefaultPhysicalSnatchResolvesNearTarget()
  local p1, p2 = room().players[1], room().players[2]
  local card = snatch(p1, Card.Spade, 3)
  local targetCard = give(p2, "hanjin__jink", Card.Heart, 2)
  FkTest.setNextReplies(p1, { { card = card.id, targets = { p2.id } } })
  local use
  run(function()
    use = C.askToUseCard(room(), p1, {
      pattern = "snatch", names = { "hanjin__snatch" },
      policy = C.default(), skill_name = "hanjin_test_default_near",
    })
  end)
  lu.assertNotNil(use)
  run(function()
    local original = room().askToChooseCard
    room().askToChooseCard = function() return targetCard.id end
    room():useCard(use)
    room().askToChooseCard = original
  end)
  lu.assertTrue(table.contains(p1:getCardIds("h"), targetCard.id))
end

function Testhanjin_card_use_targets:testBypassDistanceAllowsFarTargetWithCards()
  local p1, p5 = room().players[1], room().players[5]
  local card = snatch(p1, Card.Spade, 3)
  local farCard = give(p5, "hanjin__jink", Card.Heart, 2)
  local candidates
  run(function() candidates = C.candidates(room(), p1, card, C.bypassDistance()) end)
  lu.assertTrue(hasTarget(candidates, p5))

  FkTest.setNextReplies(p1, { { card = card.id, targets = { p5.id } } })
  local use
  run(function()
    use = C.askToUseCard(room(), p1, {
      pattern = "snatch", names = { "hanjin__snatch" },
      policy = C.bypassDistance(), skill_name = "hanjin_test_bypass",
    })
  end)
  lu.assertNotNil(use)
  run(function()
    local original = room().askToChooseCard
    room().askToChooseCard = function() return farCard.id end
    room():useCard(use)
    room().askToChooseCard = original
  end)
  lu.assertTrue(table.contains(p1:getCardIds("h"), farCard.id))
end

function Testhanjin_card_use_targets:testBypassDistanceStillRejectsSelfAndEmptyTarget()
  local p1, p5 = room().players[1], room().players[5]
  local card = snatch(p1, Card.Spade, 3)
  emptyHand(p5)
  local candidates
  run(function() candidates = C.candidates(room(), p1, card, C.bypassDistance()) end)
  lu.assertFalse(hasTarget(candidates, p1))
  lu.assertFalse(hasTarget(candidates, p5)) -- far, but nude

  for _, target in ipairs({ p1, p5 }) do
    FkTest.setNextReplies(p1, { { card = card.id, targets = { target.id } } })
    local use
    run(function()
      use = C.askToUseCard(room(), p1, {
        pattern = "snatch", names = { "hanjin__snatch" },
        policy = C.bypassDistance(), skill_name = "hanjin_test_bypass_reject",
      })
    end)
    lu.assertNil(use)
  end
  lu.assertTrue(table.contains(p1:getCardIds("h"), card.id))
end

function Testhanjin_card_use_targets:testExplicitOtherRolesAllowsFarNudeTarget()
  local p1, p5 = room().players[1], room().players[5]
  local card = snatch(p1, Card.Spade, 3)
  emptyHand(p5)
  local policy = C.explicit({ other_roles = true })
  local candidates
  run(function() candidates = C.candidates(room(), p1, card, policy) end)
  lu.assertTrue(hasTarget(candidates, p5))
  lu.assertFalse(hasTarget(candidates, p1))

  FkTest.setNextReplies(p1, { { card = card.id, targets = { p5.id } } })
  local use
  run(function()
    use = C.askToUseCard(room(), p1, {
      pattern = "snatch", names = { "hanjin__snatch" },
      policy = policy, skill_name = "hanjin_test_explicit",
    })
  end)
  lu.assertNotNil(use)
  -- Target is nude: the original snatch effect returns without obtaining a card.
  run(function() room():useCard(use) end)
  lu.assertEquals(#p5:getCardIds("h"), 0)
  lu.assertFalse(table.contains(p1:getCardIds("h"), card.id))
end

function Testhanjin_card_use_targets:testExplicitOtherRolesRejectsSelf()
  local p1 = room().players[1]
  local card = snatch(p1, Card.Spade, 3)
  FkTest.setNextReplies(p1, { { card = card.id, targets = { p1.id } } })
  local use
  run(function()
    use = C.askToUseCard(room(), p1, {
      pattern = "snatch", names = { "hanjin__snatch" },
      policy = C.explicit({ other_roles = true }), skill_name = "hanjin_test_explicit_self",
    })
  end)
  lu.assertNil(use)
  lu.assertTrue(table.contains(p1:getCardIds("h"), card.id))
end

function Testhanjin_card_use_targets:testCountOnlyPolicyDoesNotRelaxConditions()
  local p1, p2, p5 = room().players[1], room().players[2], room().players[5]
  local card = snatch(p1, Card.Spade, 3)
  give(p2, "hanjin__jink", Card.Heart, 2)
  give(p5, "hanjin__jink", Card.Heart, 3)
  local policy = C.default({ max_targets = 2 })
  local candidates
  run(function() candidates = C.candidates(room(), p1, card, policy) end)
  lu.assertTrue(hasTarget(candidates, p2))
  lu.assertFalse(hasTarget(candidates, p5))
  local invalid
  run(function()
    local use = UseCardData:new { from = p1, tos = { p2, p5 }, card = card, extra_data = {} }
    invalid = C.validateUse(room(), p1, use, policy)
  end)
  lu.assertFalse(invalid)
end

function Testhanjin_card_use_targets:testDuplicateTargetsAreRejected()
  local p1, p2 = room().players[1], room().players[2]
  local card = snatch(p1, Card.Spade, 3)
  give(p2, "hanjin__jink", Card.Heart, 2)
  local valid
  run(function()
    local use = UseCardData:new { from = p1, tos = { p2, p2 }, card = card, extra_data = {} }
    valid = C.validateUse(room(), p1, use, C.default({ max_targets = 2 }))
  end)
  lu.assertFalse(valid)
end

function Testhanjin_card_use_targets:testCandidatesAndValidationShareTheSameSet()
  local p1, p2, p5 = room().players[1], room().players[2], room().players[5]
  local card = snatch(p1, Card.Spade, 3)
  emptyHand(p5)
  give(p2, "hanjin__jink", Card.Heart, 2)
  local policy = C.explicit({ other_roles = true })
  local candidates
  run(function() candidates = C.candidates(room(), p1, card, policy) end)
  lu.assertTrue(hasTarget(candidates, p2))
  lu.assertTrue(hasTarget(candidates, p5))
  run(function()
    for _, target in ipairs(candidates) do
      local use = UseCardData:new { from = p1, tos = { target }, card = card, extra_data = {} }
      lu.assertTrue(C.validateUse(room(), p1, use, policy))
    end
    local selfUse = UseCardData:new { from = p1, tos = { p1 }, card = card, extra_data = {} }
    lu.assertFalse(C.validateUse(room(), p1, selfUse, policy))
  end)
end

function Testhanjin_card_use_targets:testVirtualNoSubcardUsesTheSamePolicy()
  local p1, p5 = room().players[1], room().players[5]
  local policy = C.explicit({ other_roles = true })
  FkTest.setNextReplies(p1, { {
    card = { skill = "virtual_viewas", subcards = {} },
    targets = { p5.id },
    interaction_data = "hanjin__snatch",
  } })
  local use
  run(function()
    use = C.askToUseVirtualCard(room(), p1, {
      name = "hanjin__snatch", policy = policy, names = { "hanjin__snatch" },
      skill_name = "hanjin_test_virtual", cancelable = true,
    })
  end)
  lu.assertNotNil(use)
  lu.assertTrue(use.card:isVirtual())
  lu.assertEquals(#Card:getIdList(use.card), 0)
  lu.assertNotNil(use.extra_data.hanjin_use_targets)
  -- The token is released at CardUseFinished; the automatically-performed use
  -- must not leave a reusable token behind.
  lu.assertNil(C.trustedPolicy(room(), use))
  -- askToUseVirtualCard owns the single actual use; callers must not use it again.
end

function Testhanjin_card_use_targets:testVirtualDefaultRejectsFarAndBypassAllowsIt()
  local p1, p5 = room().players[1], room().players[5]
  emptyHand(p5)
  give(p5, "hanjin__jink", Card.Heart, 2)
  local card = Fk:cloneCard("hanjin__snatch")
  local defaultCandidates, bypassCandidates
  run(function()
    defaultCandidates = C.candidates(room(), p1, card, C.default())
    bypassCandidates = C.candidates(room(), p1, card, C.bypassDistance())
  end)
  lu.assertFalse(hasTarget(defaultCandidates, p5))
  lu.assertTrue(hasTarget(bypassCandidates, p5))

  local farCard = p5:getCardIds("h")[1]
  local use
  run(function()
    local original = room().askToChooseCard
    room().askToChooseCard = function() return farCard end
    use = C.useVirtualCard(room(), p1, "hanjin__snatch", nil, { p5 },
      "hanjin_test_virtual_bypass", nil, nil, C.bypassDistance())
    room().askToChooseCard = original
  end)
  lu.assertNotNil(use)
  lu.assertTrue(table.contains(p1:getCardIds("h"), farCard))
end

function Testhanjin_card_use_targets:testConvertedSubcardUsePreservesPolicy()
  local p1, p5 = room().players[1], room().players[5]
  local material = give(p1, "hanjin__jink", Card.Heart, 4)
  run(function()
    O.addSource(room(), {
      def = "hanjin_test_snatch_conversion", holder = p1, duration = "game",
    })
  end)
  local policy = C.explicit({ other_roles = true })
  local originalChoice = room().askToChoice
  FkTest.setNextReplies(p1, {
    {
      card = { skill = "virtual_viewas", subcards = {} },
      targets = { p5.id },
      interaction_data = "hanjin__snatch",
    },
  })
  local use
  run(function()
    room().askToChoice = function(self, player, params)
      local choice = table.find(params.choices or {}, function(c)
        return type(c) == "string" and c:find("当【顺手牵羊】", 1, true) ~= nil
      end)
      if choice then return choice end
      return originalChoice(self, player, params)
    end
    use = O.askRestricted(room(), p1, {
      cards = { material.id }, pattern = "snatch", policy = policy,
      skill_name = "hanjin_test_only_as_policy", cancelable = true,
    })
    room().askToChoice = originalChoice
  end)
  lu.assertNotNil(use)
  lu.assertEquals(use.card.name, "hanjin__snatch")
  lu.assertEquals(use.card.subcards, { material.id })
  lu.assertNotNil(use.extra_data and use.extra_data.hanjin_use_targets)
  lu.assertNotNil(C.trustedPolicy(room(), use))
  run(function() room():useCard(use) end)
  lu.assertFalse(table.contains(p1:getCardIds("h"), material.id))
end

function Testhanjin_card_use_targets:testNormalOnlyAsConversionValidationPreservesPolicy()
  local p1, p5 = room().players[1], room().players[5]
  local material = give(p1, "hanjin__jink", Card.Heart, 4)
  emptyHand(p5)
  run(function()
    O.addSource(room(), {
      def = "hanjin_test_snatch_conversion", holder = p1, duration = "game",
    })
  end)
  local policy = C.explicit({ other_roles = true })
  run(function()
    local card = O.buildCard(p1, material.id, "hanjin__snatch", conversionSkill.name)
    local use = {
      from = p1, tos = { p5 }, card = card,
      extra_data = {},
    }
    local rec = C.push(room(), p1, { "hanjin__snatch" }, policy)
    C.attachUse(room(), use, rec)
    C.pop(room(), p1, rec)
    local ok, reason = O.validateUse(room(), p1, use, {
      mode = "use", pattern = "snatch", extra_data = use.extra_data,
    })
    lu.assertTrue(ok, reason)
    lu.assertEquals(card.name, "hanjin__snatch")
    lu.assertEquals(card.subcards, { material.id })
  end)
end

function Testhanjin_card_use_targets:testNormalOnlyAsRequestCarriesPolicy()
  local p1, p5 = room().players[1], room().players[5]
  local material = give(p1, "hanjin__jink", Card.Heart, 4)
  emptyHand(p5)
  run(function()
    room():handleAddLoseSkills(p1, conversionSkill.name, nil, false, true)
    O.addSource(room(), {
      def = "hanjin_test_snatch_conversion", holder = p1, duration = "game",
    })
  end)
  FkTest.setNextReplies(p1, { {
    card = { skill = conversionSkill.name, subcards = { material.id } },
    targets = { p5.id },
    interaction_data = "hanjin__snatch",
  } })
  local use
  run(function()
    use = C.askToUseCard(room(), p1, {
      pattern = "snatch", names = { "hanjin__snatch" },
      policy = C.explicit({ other_roles = true }),
      skill_name = "hanjin_test_normal_only_as_request",
    })
  end)
  lu.assertNotNil(use)
  lu.assertEquals(use.card.name, "hanjin__snatch")
  lu.assertEquals(use.card.subcards, { material.id })
  lu.assertNotNil(C.trustedPolicy(room(), use))
  run(function() room():useCard(use) end)
  lu.assertFalse(table.contains(p1:getCardIds("h"), material.id))
end

function Testhanjin_card_use_targets:testClientRequestDoesNotCarryTheTrustedToken()
  local p1, p2 = room().players[1], room().players[2]
  local card = snatch(p1, Card.Spade, 3)
  give(p2, "hanjin__jink", Card.Heart, 2)
  local requestExtra
  local original = room().askToUseCard
  FkTest.setNextReplies(p1, { { card = card.id, targets = { p2.id } } })
  local use
  run(function()
    room().askToUseCard = function(self, player, params)
      requestExtra = table.simpleClone(params.extra_data or {})
      return original(self, player, params)
    end
    use = C.askToUseCard(room(), p1, {
      pattern = "snatch", names = { "hanjin__snatch" },
      policy = C.default(), skill_name = "hanjin_test_token_visibility",
    })
    room().askToUseCard = original
  end)
  lu.assertNotNil(use)
  lu.assertNotNil(requestExtra.hanjin_use_targets)
  lu.assertNil(requestExtra.hanjin_use_targets_token)
  lu.assertNotNil(C.trustedPolicy(room(), use))
end

function Testhanjin_card_use_targets:testProhibitUseAndProhibitedTargetAreStillEnforced()
  local p1, p2 = room().players[1], room().players[2]
  local card = snatch(p1, Card.Spade, 3)
  give(p2, "hanjin__jink", Card.Heart, 2)

  local skel = fk.CreateSkill { name = "#hanjin_test_use_target_prohibit" }
  skel:addEffect("prohibit", {
    is_prohibited = function(self, from, to, usedCard)
      return to:getMark("hanjin_test_use_target_prohibited") > 0
    end,
  })
  run(function()
    local skill = skel:createSkill()
    Fk.skills[skill.name] = skill
    room():addSkill(skill)
    room():setPlayerMark(p2, "hanjin_test_use_target_prohibited", 1)
  end)
  local candidates
  run(function() candidates = C.candidates(room(), p1, card, C.default()) end)
  lu.assertFalse(hasTarget(candidates, p2))
  local explicitCandidates
  run(function()
    explicitCandidates = C.candidates(room(), p1, card, C.explicit({ other_roles = true }))
  end)
  lu.assertFalse(hasTarget(explicitCandidates, p2))
  FkTest.setNextReplies(p1, { { card = card.id, targets = { p2.id } } })
  local use
  run(function()
    use = C.askToUseCard(room(), p1, {
      pattern = "snatch", names = { "hanjin__snatch" },
      policy = C.default(), skill_name = "hanjin_test_prohibit_target",
    })
  end)
  lu.assertNil(use)

  -- Independent prohibit_use: the physical card itself becomes forbidden.
  run(function()
    room():setPlayerMark(p2, "hanjin_test_use_target_prohibited", 0)
    O.addSource(room(), { def = "hanjin_test_forbid_snatch", holder = p1, duration = "game" })
  end)
  lu.assertTrue(p1:prohibitUse(card))
  FkTest.setNextReplies(p1, { { card = card.id, targets = { p2.id } } })
  run(function()
    use = C.askToUseCard(room(), p1, {
      pattern = "snatch", names = { "hanjin__snatch" },
      policy = C.default(), skill_name = "hanjin_test_prohibit_use",
    })
  end)
  lu.assertNil(use)
  lu.assertTrue(table.contains(p1:getCardIds("h"), card.id))
end

function Testhanjin_card_use_targets:testForgedPolicyCannotBypassPreCardUse()
  local p1, p5 = room().players[1], room().players[5]
  local slash = Fk:cloneCard("hanjin__slash")
  local hp = p5.hp
  run(function()
    room():useCard {
      from = p1,
      tos = { p5.id },
      card = slash,
      extra_data = {
        hanjin_use_targets = C.compact(C.explicit({ other_roles = true })),
        hanjin_use_targets_token = "forged-token",
      },
    }
  end)
  lu.assertEquals(p5.hp, hp)
end

function Testhanjin_card_use_targets:testStateChangeAfterSelectionIsRechecked()
  local p1, p5 = room().players[1], room().players[5]
  local policy = C.bypassDistance()
  emptyHand(p5)
  local farCard = give(p5, "hanjin__jink", Card.Heart, 3)
  local card = snatch(p1, Card.Spade, 3)
  FkTest.setNextReplies(p1, { { card = card.id, targets = { p5.id } } })
  local use
  run(function()
    use = C.askToUseCard(room(), p1, {
      pattern = "snatch", names = { "hanjin__snatch" },
      policy = policy, skill_name = "hanjin_test_state_change",
    })
  end)
  lu.assertNotNil(use)
  -- The far target loses its hand card after selection; the final PreCardUse
  -- recheck must reject the now-illegal target.
  run(function() room():throwCard(farCard.id, "test", p5, p5) end)
  local used
  run(function() used = room():useCard(use) end)
  lu.assertTrue(table.contains(p1:getCardIds("h"), card.id))
  lu.assertNil(room():getTag(C.POLICY_TAG))
end

function Testhanjin_card_use_targets:testCancelLeavesNoPolicyOrCost()
  local p1 = room().players[1]
  local material = give(p1, "hanjin__jink", Card.Heart, 4)
  run(function()
    O.addSource(room(), {
      def = "hanjin_test_snatch_conversion", holder = p1, duration = "game",
    })
  end)
  FkTest.setNextReplies(p1, { "" })
  local use
  run(function()
    use = O.askRestricted(room(), p1, {
      cards = { material.id }, pattern = "snatch",
      policy = C.explicit({ other_roles = true }),
      skill_name = "hanjin_test_cancel", cancelable = true,
    })
  end)
  lu.assertNil(use)
  lu.assertTrue(table.contains(p1:getCardIds("h"), material.id))
  lu.assertFalse(O.isAuthorized(room(), p1, material.id))
  local active
  run(function() active = C.activePolicy(room(), p1, material) end)
  lu.assertNil(active)
  lu.assertNil(C.topPolicy(room(), p1))
  lu.assertNil(O.currentRequest(room()))
end

function Testhanjin_card_use_targets:testJadeSealEntryUsesPublicPolicy()
  local p1, p2 = room().players[1], room().players[2]
  give(p2, "hanjin__jink", Card.Heart, 2)
  local card = Fk:cloneCard("hanjin__known_both")
  local policy = C.default()
  local candidates
  run(function() candidates = C.candidates(room(), p1, card, policy) end)
  lu.assertTrue(hasTarget(candidates, p2))
  local use
  FkTest.setNextReplies(p1, { "known_both_hand" })
  run(function()
    use = C.useVirtualCard(room(), p1, "hanjin__known_both", nil, { p2 },
      "hanjin__jade_seal_skill", nil, nil, policy)
  end)
  lu.assertNotNil(use)
  lu.assertNotNil(use.extra_data and use.extra_data.hanjin_use_targets)
end

-- Regression: the virtual-card helper must never use before the server token
-- and target recheck are in place.  Default and explicit skip both execute
-- exactly once; the returned use is already used and must not be used again.
function Testhanjin_card_use_targets:testVirtualUseDefaultExecutesExactlyOnce()
  local p1, p2 = room().players[1], room().players[2]
  local hp = p2.hp
  local counts, effects = cardProbe("hanjin__slash")
  FkTest.setNextReplies(p1, { {
    card = { skill = "virtual_viewas", subcards = {} },
    targets = { p2.id },
    interaction_data = "hanjin__slash",
  } })
  local use
  run(function()
    use = C.askToUseVirtualCard(room(), p1, {
      name = "hanjin__slash", names = { "hanjin__slash" },
      policy = C.default(), skill_name = "hanjin_test_virtual_once", cancelable = true,
    })
  end)
  lu.assertNotNil(use)
  lu.assertEquals(counts[fk.CardUsing], 1)
  lu.assertEquals(counts[fk.CardUseFinished], 1)
  lu.assertEquals(#effects, 1)
  lu.assertEquals(p2.hp, hp - 1)
end

function Testhanjin_card_use_targets:testVirtualUseExplicitSkipExecutesExactlyOnce()
  local p1, p2 = room().players[1], room().players[2]
  local hp = p2.hp
  local counts, effects = cardProbe("hanjin__slash")
  FkTest.setNextReplies(p1, { {
    card = { skill = "virtual_viewas", subcards = {} },
    targets = { p2.id },
    interaction_data = "hanjin__slash",
  } })
  local use
  run(function()
    use = C.askToUseVirtualCard(room(), p1, {
      name = "hanjin__slash", names = { "hanjin__slash" },
      policy = C.default(), skill_name = "hanjin_test_virtual_skip", cancelable = true,
      skip = true, -- must not turn the helper into a no-op; contract is unified
    })
  end)
  lu.assertNotNil(use)
  lu.assertEquals(counts[fk.CardUsing], 1)
  lu.assertEquals(counts[fk.CardUseFinished], 1)
  lu.assertEquals(#effects, 1)
  lu.assertEquals(p2.hp, hp - 1)
end

-- Regression: 群体牌 expand in card.skill:onUse before PreCardUse.  The old
-- declared check compared the expanded count with the initial target count and
-- cancelled every such use.
function Testhanjin_card_use_targets:testVirtualGroupExpansionUsesRealCardSkill()
  setKingdoms(groupKingdoms)
  local p1, p2 = room().players[1], room().players[2]
  emptyHand(p1)
  local counts, effects = cardProbe("hanjin__fight_together")
  FkTest.setNextReplies(p1, { {
    card = { skill = "virtual_viewas", subcards = {} },
    targets = { p2.id },
    interaction_data = "hanjin__fight_together",
  } })
  local use
  run(function()
    use = C.askToUseVirtualCard(room(), p1, {
      name = "hanjin__fight_together", names = { "hanjin__fight_together" },
      policy = C.default(), skill_name = "hanjin_test_virtual_group", cancelable = true,
    })
  end)
  lu.assertNotNil(use)
  lu.assertTrue(#use.tos > 1, "the card's own onUse must expand the group")
  lu.assertEquals(counts[fk.CardUsing], 1)
  lu.assertEquals(#effects, #use.tos)
end

-- Regression: 借刀杀人 transforms selected pairs into main targets with their
-- own subTos.  Sub targets must be checked with the card's own structural rule,
-- never against a fresh empty-selection candidate list.
function Testhanjin_card_use_targets:testVirtualCollateralKeepsIndependentMainAndSubTargets()
  setKingdoms(groupKingdoms)
  local p1, p2, p3 = room().players[1], room().players[2], room().players[3]
  local weapon = equip(p2, "hanjin__qinggang_sword")
  emptyHand(p1)
  local counts, effects = cardProbe("hanjin__collateral")
  FkTest.setNextReplies(p1, { {
    card = { skill = "virtual_viewas", subcards = {} },
    targets = { p2.id, p3.id },
    interaction_data = "hanjin__collateral",
  } })
  FkTest.setNextReplies(p2, { "" })
  local use
  run(function()
    use = C.askToUseVirtualCard(room(), p1, {
      name = "hanjin__collateral", names = { "hanjin__collateral" },
      policy = C.default(), skill_name = "hanjin_test_virtual_collateral", cancelable = true,
    })
  end)
  lu.assertNotNil(use)
  lu.assertEquals(table.map(use.tos, Util.IdMapper), { p2.id })
  local subs = (use.subTos or {})[1] or {}
  lu.assertEquals(table.map(subs, Util.IdMapper), { p3.id })
  lu.assertEquals(counts[fk.CardUsing], 1)
  lu.assertEquals(#effects, 1)
  local effect = table.find(effects, function(target) return target == p2 end)
  lu.assertNotNil(effect)
  -- The main target declined the slash, so its weapon moves to the user.
  lu.assertTrue(table.contains(p1:getCardIds("h"), weapon.id))
end

-- Fixed-target cards are filled by the engine.  The declared check must run the
-- card's real target filter and never require a hand-picked initial list.
function Testhanjin_card_use_targets:testVirtualFixedTargetAoeUsesEngineTargets()
  local p1 = room().players[1]
  local hps = {}
  for index = 2, 8 do
    local target = room().players[index]
    hps[target.id] = target.hp
    FkTest.setNextReplies(target, { "" })
  end
  local counts, effects = cardProbe("hanjin__archery_attack")
  FkTest.setNextReplies(p1, { {
    card = { skill = "virtual_viewas", subcards = {} },
    targets = {},
    interaction_data = "hanjin__archery_attack",
  } })
  local use
  run(function()
    use = C.askToUseVirtualCard(room(), p1, {
      name = "hanjin__archery_attack", names = { "hanjin__archery_attack" },
      policy = C.default(), skill_name = "hanjin_test_virtual_aoe", cancelable = true,
    })
  end)
  lu.assertNotNil(use)
  lu.assertEquals(counts[fk.CardUsing], 1)
  lu.assertEquals(#effects, 7)
  for index = 2, 8 do
    local target = room().players[index]
    lu.assertEquals(target.hp, hps[target.id] - 1)
  end
end

-- Explicit numeric counts are separate from the target condition: two other
-- roles are allowed and the distance/card-area conditions are not stacked.
function Testhanjin_card_use_targets:testExplicitCountUsesOtherRolesConditionOnly()
  local p1, p2, p5 = room().players[1], room().players[2], room().players[5]
  emptyHand(p2)
  emptyHand(p5)
  local card = give(p2, "hanjin__jink", Card.Heart, 2)
  local policy = C.explicit({ other_roles = true }, { min_targets = 2, max_targets = 2 })
  local counts, effects = cardProbe("hanjin__snatch")
  FkTest.setNextReplies(p1, { {
    card = { skill = "virtual_viewas", subcards = {} },
    targets = { p2.id, p5.id },
    interaction_data = "hanjin__snatch",
  }, card.id })
  local use
  run(function()
    local originalNullification = room().askToNullification
    room().askToNullification = function() return nil end
    use = C.askToUseVirtualCard(room(), p1, {
      name = "hanjin__snatch", names = { "hanjin__snatch" },
      policy = policy, skill_name = "hanjin_test_virtual_explicit_count", cancelable = true,
    })
    room().askToNullification = originalNullification
  end)
  lu.assertNotNil(use)
  lu.assertEquals(counts[fk.CardUsing], 1)
  lu.assertEquals(#effects, 2)
  lu.assertTrue(table.contains(p1:getCardIds("h"), card.id))
end

-- A token is bound to its player and card.  A forged use cannot borrow another
-- player's token, and releasing a forged use must not delete the real token.
function Testhanjin_card_use_targets:testTrustedTokenBindsPlayerAndCard()
  local p1, p2 = room().players[1], room().players[2]
  local card = snatch(p1, Card.Spade, 3)
  give(p2, "hanjin__jink", Card.Heart, 2)
  FkTest.setNextReplies(p1, { { card = card.id, targets = { p2.id } } })
  local use
  run(function()
    use = C.askToUseCard(room(), p1, {
      pattern = "snatch", names = { "hanjin__snatch" },
      policy = C.default(), skill_name = "hanjin_test_token_bind",
    })
  end)
  lu.assertNotNil(use)
  local token = use.extra_data.hanjin_use_targets_token
  lu.assertNotNil(token)
  local compact = C.compact(C.default())

  local otherPlayer = {
    from = p2, tos = { p1 }, card = Fk:cloneCard("hanjin__snatch"),
    extra_data = { hanjin_use_targets = compact, hanjin_use_targets_token = token },
  }
  lu.assertNil(C.trustedPolicy(room(), otherPlayer))
  lu.assertFalse(C.validateUse(room(), p2, otherPlayer, nil, nil, { require_trusted = true }))

  local wrongCard = {
    from = p1, tos = { p2 }, card = Fk:cloneCard("hanjin__slash"),
    extra_data = { hanjin_use_targets = compact, hanjin_use_targets_token = token },
  }
  lu.assertNil(C.trustedPolicy(room(), wrongCard))
  lu.assertFalse(C.validateUse(room(), p1, wrongCard, nil, nil, { require_trusted = true }))

  -- Same player and card is still not enough: the use must carry the server
  -- request id that attachUse copied from this exact token.
  local sameCard = {
    from = p1, tos = { p2 }, card = Fk:cloneCard("hanjin__snatch"),
    extra_data = { hanjin_use_targets = compact, hanjin_use_targets_token = token },
  }
  lu.assertNil(C.trustedPolicy(room(), sameCard))
  sameCard.extra_data.hanjin_use_targets_request = "wrong-request"
  lu.assertNil(C.trustedPolicy(room(), sameCard))
  lu.assertNotNil(C.trustedPolicy(room(), use))
  lu.assertEquals(use.extra_data.hanjin_use_targets_request,
    C.trustedPolicy(room(), use).request)

  lu.assertNotNil(C.trustedPolicy(room(), use))
  run(function()
    C.releaseToken(room(), otherPlayer)
    C.releaseToken(room(), wrongCard)
    C.releaseToken(room(), sameCard)
  end)
  lu.assertNotNil(C.trustedPolicy(room(), use), "forged releases must not delete the real token")
  run(function() C.releaseToken(room(), use) end)
  lu.assertNil(C.trustedPolicy(room(), use))
end

function Testhanjin_card_use_targets:testNestedCandidateQueriesRestoreTheOuterPolicy()
  local p1 = room().players[1]
  local outer
  run(function()
    outer = C.push(room(), p1, { "hanjin__snatch" }, C.default())
  end)
  local before = C.topPolicy(room(), p1)
  run(function()
    C.candidates(room(), p1, Fk:cloneCard("hanjin__slash"), C.explicit({ other_roles = true }))
  end)
  lu.assertEquals(C.topPolicy(room(), p1), before)
  run(function() C.pop(room(), p1, outer) end)
  lu.assertNil(C.topPolicy(room(), p1))
end

function Testhanjin_card_use_targets:testVirtualCancelLeavesNoPolicyOrToken()
  local p1, p2 = room().players[1], room().players[2]
  give(p2, "hanjin__jink", Card.Heart, 2)
  FkTest.setNextReplies(p1, { "" })
  local use
  run(function()
    use = C.selectVirtualCard(room(), p1, {
      name = "hanjin__snatch", names = { "hanjin__snatch" },
      policy = C.default(), skill_name = "hanjin_test_virtual_cancel", cancelable = true,
    })
  end)
  lu.assertNil(use)
  lu.assertNil(C.topPolicy(room(), p1))
  lu.assertNil(room():getTag(C.POLICY_TAG))
end

-- The policy layer is a HanJin-mode entry, not a global monkey patch.  A forged
-- strategy in an ordinary upstream room must have no effect at all.
function Testhanjin_card_use_targets:testOrdinaryUpstreamRoomIsUnaffected()
  local upstream = support.createRoom()
  local p1, p2 = upstream.players[1], upstream.players[2]
  local hp = p2.hp
  local slash = Fk:cloneCard("slash")
  FkTest.runInRoom(function()
    upstream:useCard {
      from = p1,
      tos = { p2 },
      card = slash,
      extra_data = {
        hanjin_use_targets = C.compact(C.explicit({ other_roles = true })),
        hanjin_use_targets_token = "forged-token",
      },
    }
  end)
  lu.assertEquals(p2.hp, hp - 1)
  lu.assertNil(upstream:getTag(C.POLICY_TAG))
end

function Testhanjin_card_use_targets:testVirtualValidationFailureHasNoSideEffects()
  local p1, p2 = room().players[1], room().players[2]
  local hp1, hp2 = p1.hp, p2.hp
  local counts, effects = cardProbe("hanjin__slash")
  FkTest.setNextReplies(p1, { {
    card = { skill = "virtual_viewas", subcards = {} },
    targets = { p1.id }, -- self is never a legal 杀 target
    interaction_data = "hanjin__slash",
  } })
  local use
  run(function()
    use = C.selectVirtualCard(room(), p1, {
      name = "hanjin__slash", names = { "hanjin__slash" },
      policy = C.default(), skill_name = "hanjin_test_virtual_invalid", cancelable = true,
    })
  end)
  lu.assertNil(use)
  lu.assertEquals(counts[fk.CardUsing] or 0, 0)
  lu.assertEquals(#effects, 0)
  lu.assertEquals(p1.hp, hp1)
  lu.assertEquals(p2.hp, hp2)
  lu.assertNil(room():getTag(C.POLICY_TAG))
  lu.assertNil(C.topPolicy(room(), p1))
end

-- 玉玺 is covered through its public policy helper above; this drives the
-- concrete EventPhaseStart trigger's cost stage (the part that builds the
-- candidate list and asks for targets) through the real skill entry.  The
-- actual use callback is C.useVirtualCard, covered by the helper test above.
function Testhanjin_card_use_targets:testCommanderIllegalTargetRejectedBeforeCost()
  local holder, user, target = room().players[1], room().players[2], room().players[4]
  setHiddenGeneral(holder, "hanjin_test__commander_alpha", nil, "wei")
  setHiddenGeneral(user, "hanjin_test__wei_1", "hanjin_test__wei_2", "wei")
  setHiddenGeneral(target, "hanjin_test__wei_3", nil, "wei")
  revealGeneral(holder, false)
  revealGeneral(user, false)
  revealGeneral(user, true)
  revealGeneral(target, false)

  local beforeMain, beforeDeputy = user.general, user.deputyGeneral
  local counts = cardProbe("hanjin__thunder__slash")
  local result
  run(function()
    local skill = Fk.skills[CR.ABILITY_SKILL]
    result = room():handleUseCardReply(user, {
      card = { skill = CR.ABILITY_SKILL, subcards = {} },
      targets = { target.id }, -- distance 2, outside the slash's range 1
      interaction_data = "hanjin_test__commander_alpha",
    }, nil)
    skill.interaction.data = nil
  end)
  lu.assertEquals(type(result), "string")
  lu.assertEquals(user.general, beforeMain)
  lu.assertEquals(user.deputyGeneral, beforeDeputy)
  lu.assertEquals(counts[fk.CardUsing] or 0, 0)
end

function Testhanjin_card_use_targets:testJadeSealEventPhaseStartCost()
  setKingdoms({ "wei", "wei", "shu", "shu", "wu", "wu", "qun", "han" })
  local p1, p2 = room().players[1], room().players[2]
  give(p2, "hanjin__jink", Card.Heart, 2)
  equip(p1, "hanjin__jade_seal")
  p1.phase = Player.Play
  local originalChoose = room().askToChoosePlayers
  local offered, costOk
  FkTest.runInRoom(function()
    room().askToChoosePlayers = function(self, player, params)
      offered = table.map(params.targets or {}, Util.IdMapper)
      if table.contains(params.targets or {}, p2) then return { p2 } end
      return {}
    end
    local data = { phase = Player.Play }
    local event = fk.EventPhaseStart:new(room(), p1, data)
    for _, entry in ipairs(room().logic.skill_table[fk.EventPhaseStart] or {}) do
      local skeleton = entry:getSkeleton()
      if skeleton ~= nil and skeleton.name == "hanjin__jade_seal_skill" then
        costOk = entry:cost(event, p1, p1, data) == true
        local cost = event:getCostData(entry)
        lu.assertNotNil(cost)
        lu.assertEquals(table.map(cost.tos, Util.IdMapper), { p2.id })
        break
      end
    end
    room().askToChoosePlayers = originalChoose
  end)
  lu.assertTrue(costOk)
  lu.assertTrue(table.contains(offered or {}, p2.id))
end

-- The real 玉玺 EventPhaseStart entry: cost chooses 知己知彼 and its target,
-- then the skill's own on_use calls C.useVirtualCard.  A nested UseCard event
-- yields inside the room coroutine, so runInRoom must be resumed a second time
-- (with a no-op reason) to flush it; it must not be stubbed.
function Testhanjin_card_use_targets:testJadeSealEventPhaseStartActualUse()
  setKingdoms({ "wei", "wei", "shu", "shu", "wu", "wu", "qun", "han" })
  local p1, p2 = room().players[1], room().players[2]
  give(p2, "hanjin__jink", Card.Heart, 2)
  equip(p1, "hanjin__jade_seal")
  p1.phase = Player.Play
  local counts, effects = cardProbe("hanjin__known_both")
  local policySeen = false
  local policyProbe = fk.CreateSkill { name = "#hanjin_jade_policy_probe" }
  policyProbe:addEffect(fk.PreCardUse, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return target == player and data.card ~= nil and data.card.name == "hanjin__known_both"
    end,
    on_refresh = function(self, event, target, player, data)
      policySeen = C.trustedPolicy(room(), data) ~= nil
        and table.contains(data.tos or {}, p2)
    end,
  })
  run(function() room():addSkill(policyProbe:createSkill()) end)

  -- Real requests: jade cost target -> known_both choice -> view-cards confirm.
  FkTest.setNextReplies(p1, {
    FkTest.ReplyChoosePlayer({ p2 }),
    "known_both_hand",
    { cards = {}, choice = "OK" },
  })

  run(function()
    local saved = room().logic.skill_table[fk.EventPhaseStart]
    local only = {}
    for _, entry in ipairs(saved or {}) do
      local skeleton = entry:getSkeleton()
      if skeleton ~= nil and skeleton.name == "hanjin__jade_seal_skill" then
        table.insert(only, entry)
      end
    end
    room().logic.skill_table[fk.EventPhaseStart] = only
    room().logic:trigger(fk.EventPhaseStart, p1, { phase = Player.Play })
    room().logic.skill_table[fk.EventPhaseStart] = saved
  end)
  -- The trigger's on_use performs a nested room:useCard; runInRoom resumed only
  -- to the next yield, so resume the room coroutine again to complete the real
  -- known_both request chain.  This is scheduling, not an on_use stub.
  for _ = 1, 8 do
    if (counts[fk.CardUsing] or 0) >= 1 and (counts[fk.CardUseFinished] or 0) >= 1 then
      break
    end
    run(function() end)
  end

  lu.assertEquals(counts[fk.CardUsing], 1)
  lu.assertEquals(counts[fk.CardUseFinished], 1)
  lu.assertEquals(#effects, 1)
  lu.assertEquals(effects[1].id, p2.id)
  lu.assertTrue(policySeen, "PreCardUse must see the trusted policy and target for 玉玺's use")
end

-- 玉玺's public helper path, kept as the direct API regression.
return { name = "hanjin_card_use_targets" }
