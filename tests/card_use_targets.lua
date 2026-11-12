local support = __dofile("../../../tests/support/hegemony.lua")
local C = require "packages.hanjin.pkg.hanjin_mode.rules.card_use_targets"
local O = require "packages.hanjin.pkg.hanjin_mode.rules.only_as"

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

local function emptyHand(player)
  run(function()
    local ids = player:getCardIds("h")
    if #ids > 0 then room():throwCard(ids, "test", player, player) end
  end)
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
  lu.assertNotNil(C.trustedPolicy(room(), use))
  run(function() room():useCard(use) end)
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

return { name = "hanjin_card_use_targets" }
