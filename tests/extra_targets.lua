local support = __dofile("../../../tests/support/hegemony.lua")
local A = require "packages.hanjin.pkg.hanjin_mode.rules.adaptation"
local E = require "packages.hanjin.pkg.hanjin_mode.rules.extra_targets"
local H = require "packages.hegemony.util"

Testhanjin_extra_targets = { setup = support.initHanjinRoom, tearDown = support.clearRoom }

local function room() return FkTest.room end

local function contains(list, player)
  return table.find(list, function(p) return p == player end) ~= nil
end

local function give(player, name, suit, number)
  local card
  FkTest.runInRoom(function()
    card = room():printCard(name, suit, number)
    room():obtainCard(player, card, true, fk.ReasonJustMove, player, "test")
  end)
  return card
end

local function equip(player, name)
  local card = give(player, name)
  FkTest.runInRoom(function()
    room():moveCardTo(card, Card.PlayerEquip, player, fk.ReasonPut, "test", nil, true)
  end)
  return card
end

local function useData(from, tos, name, entries)
  local card = Fk:cloneCard(name)
  if entries ~= nil then A.setCardEntries(card, entries) end
  local use = UseCardData:new { from = from, tos = tos or {}, card = card, extra_data = {} }
  -- UseCardData:removeTarget removes the matching subTos entry; keep the arrays
  -- aligned even in direct rule tests.
  use.subTos = table.map(use.tos, function() return {} end)
  return use
end

local function emptyHand(player)
  FkTest.runInRoom(function()
    room():throwCard(player:getCardIds("h"), "test", player, player)
  end)
end

local function setKingdoms(kingdoms)
  FkTest.runInRoom(function()
    for index, kingdom in ipairs(kingdoms) do
      room():setPlayerProperty(room().players[index], "kingdom", kingdom)
    end
  end)
end

local function candidates(use, entry)
  local result
  FkTest.runInRoom(function() result = E.candidates(room(), use, entry or {}) end)
  return result
end

local function subCandidates(use, main, entry)
  local result
  FkTest.runInRoom(function() result = E.subCandidates(room(), use, main, entry or {}) end)
  return result
end

local function addTargetEntry(condition)
  return { { condition = condition or "kongchao", effect = "add_target" } }
end

local groupKingdoms = { "wei", "wei", "shu", "shu", "wu", "wu", "qun", "han" }

-- Basic scope ----------------------------------------------------------------

function Testhanjin_extra_targets:testEquipmentAndDelayedTrickHaveNoRoleCandidates()
  local p = room().players[1]
  local equipment = useData(p, {}, "hanjin__axe")
  local delayed = useData(p, {}, "hanjin__lightning")
  FkTest.runInRoom(function()
    lu.assertEquals(#E.candidates(room(), equipment, {}), 0)
    lu.assertEquals(#E.candidates(room(), delayed, {}), 0)
  end)
end

function Testhanjin_extra_targets:testJinkAndNullificationHaveNoRoleCandidates()
  local p = room().players[1]
  local jink = useData(p, {}, "hanjin__jink")
  local nullification = useData(p, {}, "hanjin__guozhan__nullification")
  FkTest.runInRoom(function()
    lu.assertEquals(#E.candidates(room(), jink, {}), 0)
    lu.assertEquals(#E.candidates(room(), nullification, {}), 0)
  end)
end

function Testhanjin_extra_targets:testCardTargetUseIsExcludedEvenWhenTheSkillWouldAllowRoles()
  local p = room().players
  local use = useData(p[1], {}, "hanjin__slash")
  use.toCard = Fk:cloneCard("hanjin__jink")
  FkTest.runInRoom(function()
    lu.assertEquals(#E.candidates(room(), use, {}), 0)
  end)
end

function Testhanjin_extra_targets:testSlashCandidatesRespectAttackRangeAndCurrentTargets()
  local p = room().players
  local use = useData(p[1], { p[2] }, "hanjin__slash")
  local result = candidates(use)
  lu.assertTrue(contains(result, p[8]))
  lu.assertFalse(contains(result, p[3]))
  lu.assertFalse(contains(result, p[7]))
  lu.assertFalse(contains(result, p[1]))
  lu.assertFalse(contains(result, p[2]))
end

function Testhanjin_extra_targets:testSlashReaddsALegalTargetWhenNoneRemain()
  local p = room().players
  local use = useData(p[1], { p[2] }, "hanjin__slash")
  use:removeAllTargets()
  local result = candidates(use)
  lu.assertTrue(contains(result, p[2]))
  lu.assertTrue(contains(result, p[8]))
  lu.assertFalse(contains(result, p[3]))
end

function Testhanjin_extra_targets:testSnatchCandidatesRespectDistanceAndCardArea()
  local p = room().players
  give(p[2], "hanjin__slash")
  give(p[3], "hanjin__slash")
  give(p[8], "hanjin__slash")
  local use = useData(p[1], { p[2] }, "hanjin__snatch")
  local result = candidates(use)
  lu.assertTrue(contains(result, p[8]))
  lu.assertFalse(contains(result, p[3]))
  lu.assertFalse(contains(result, p[1]))
end

function Testhanjin_extra_targets:testCandidatesUseCurrentStateInsteadOfAnInitialNameList()
  local p = room().players
  local use = useData(p[1], { p[2] }, "hanjin__slash")
  lu.assertFalse(contains(candidates(use), p[3]))
  equip(p[1], "hanjin__qinggang_sword") -- attack range 2
  lu.assertTrue(contains(candidates(use), p[3]))
end

function Testhanjin_extra_targets:testCommonProhibitionIsRespected()
  local p = room().players
  local skel = fk.CreateSkill { name = "#hanjin_test_extra_prohibit" }
  skel:addEffect("prohibit", {
    is_prohibited = function(self, from, to, card)
      return to:getMark("hanjin_test_extra_prohibited") > 0
    end,
  })
  local use = useData(p[1], { p[2] }, "hanjin__slash")
  FkTest.runInRoom(function()
    local skill = skel:createSkill()
    Fk.skills[skill.name] = skill
    room():addSkill(skill)
  end)
  FkTest.runInRoom(function() room():setPlayerMark(p[8], "hanjin_test_extra_prohibited", 1) end)
  lu.assertFalse(contains(candidates(use), p[8]))
  FkTest.runInRoom(function() room():setPlayerMark(p[8], "hanjin_test_extra_prohibited", 0) end)
  lu.assertTrue(contains(candidates(use), p[8]))
end

-- Card-specific conditions ----------------------------------------------------

function Testhanjin_extra_targets:testBefriendAttackingRejectsSameKingdom()
  setKingdoms(groupKingdoms)
  local p = room().players
  local use = useData(p[1], { p[3] }, "hanjin__befriend_attacking")
  local result = candidates(use)
  lu.assertTrue(contains(result, p[5]))
  lu.assertTrue(contains(result, p[7]))
  lu.assertFalse(contains(result, p[2]))
  lu.assertFalse(contains(result, p[3]))
end

function Testhanjin_extra_targets:testDrowningRequiresEquipmentArea()
  local p = room().players
  equip(p[2], "hanjin__qinggang_sword")
  equip(p[5], "hanjin__qinggang_sword")
  local use = useData(p[1], { p[2] }, "hanjin__drowning")
  local result = candidates(use)
  lu.assertTrue(contains(result, p[5]))
  lu.assertFalse(contains(result, p[3]))
  equip(p[3], "hanjin__qinggang_sword")
  lu.assertTrue(contains(candidates(use), p[3]))
end

function Testhanjin_extra_targets:testPeachAnalepticForesightAndExNihiloAllowOtherRoles()
  local p = room().players
  FkTest.runInRoom(function() room():loseHp(p[2], 1) end)
  local peach = candidates(useData(p[1], { p[1] }, "hanjin__peach"))
  lu.assertTrue(contains(peach, p[2]))
  lu.assertFalse(contains(peach, p[3]))
  for _, name in ipairs({ "hanjin__analeptic", "hanjin__foresight", "ex_nihilo" }) do
    local result = candidates(useData(p[1], { p[1] }, name))
    lu.assertTrue(contains(result, p[2]), name .. " should allow another role")
    lu.assertTrue(contains(result, p[3]), name .. " should allow another role")
  end
end

function Testhanjin_extra_targets:testPeachExtraTargetIsResolvedByTheCardEffect()
  local p = room().players
  p[1].hp = p[1].maxHp - 1
  p[2].hp = p[2].maxHp - 1
  emptyHand(p[1])
  local use = useData(p[1], { p[1] }, "hanjin__peach", addTargetEntry())
  FkTest.runInRoom(function()
    FkTest.setNextReplies(p[1], { FkTest.ReplyChoosePlayer({ p[2] }) })
    room():useCard(use)
  end)
  lu.assertEquals(p[1].hp, p[1].maxHp)
  lu.assertEquals(p[2].hp, p[2].maxHp)
  lu.assertEquals(A.getResult(use).triggered_count, 1)
end

-- Group/context cards --------------------------------------------------------

function Testhanjin_extra_targets:testAwaitExhaustedHasNoCandidateWhenTheGroupIsComplete()
  setKingdoms(groupKingdoms)
  local p = room().players
  local use = useData(p[1], { p[1], p[2] }, "hanjin__await_exhausted")
  lu.assertEquals(#candidates(use), 0)
  use:removeTarget(p[2])
  local readded = candidates(use)
  lu.assertTrue(contains(readded, p[2]))
  lu.assertFalse(contains(readded, p[3]))
  use:removeAllTargets()
  local all = candidates(use)
  lu.assertTrue(contains(all, p[1]))
  lu.assertTrue(contains(all, p[2]))
  lu.assertFalse(contains(all, p[3]))
end

function Testhanjin_extra_targets:testBurningCampsHasNoCandidateWhenTheQueueIsComplete()
  setKingdoms(groupKingdoms)
  local p = room().players
  local queue
  FkTest.runInRoom(function()
    local nextp = p[1]:getNextAlive()
    queue = { nextp }
    table.insertTable(queue, H.getFormationRelation(nextp))
  end)
  local use = useData(p[1], queue, "hanjin__burning_camps")
  lu.assertEquals(#candidates(use), 0)
  use:removeAllTargets()
  local all = candidates(use)
  lu.assertEquals(#all, #queue)
  for _, target in ipairs(queue) do lu.assertTrue(contains(all, target)) end
  lu.assertFalse(contains(all, p[3]))
end

function Testhanjin_extra_targets:testFightTogetherKeepsTheChosenCategoryWhenTheFirstTargetIsRemoved()
  setKingdoms(groupKingdoms)
  local p = room().players
  local use = useData(p[1], { p[2] }, "hanjin__fight_together")
  FkTest.runInRoom(function() use.card.skill:onUse(room(), use) end) -- expand the group
  lu.assertEquals(#use.tos, 6)
  lu.assertEquals(#candidates(use), 0)
  use:removeTarget(p[2])
  local readded = candidates(use)
  lu.assertTrue(contains(readded, p[2]))
  lu.assertFalse(contains(readded, p[7]))
end

function Testhanjin_extra_targets:testFightTogetherCannotSwitchToTheSmallGroupAndCanReaddAll()
  setKingdoms(groupKingdoms)
  local p = room().players
  local use = useData(p[1], { p[7] }, "hanjin__fight_together")
  FkTest.runInRoom(function() use.card.skill:onUse(room(), use) end) -- small group p7,p8
  lu.assertEquals(#use.tos, 2)
  use:removeAllTargets()
  local all = candidates(use)
  lu.assertTrue(contains(all, p[7]))
  lu.assertTrue(contains(all, p[8]))
  lu.assertFalse(contains(all, p[1]))
  lu.assertFalse(contains(all, p[2]))
end

function Testhanjin_extra_targets:testFightTogetherContextSurvivesTheRealUsePipeline()
  setKingdoms(groupKingdoms)
  local p = room().players
  emptyHand(p[1])
  local use = useData(p[1], { p[2] }, "hanjin__fight_together", {
    { condition = "kongchao", effect = "remove_target" },
    { condition = "kongchao", effect = "add_target" },
  })
  local candidateSets = {}
  local original = room().askToChoosePlayers
  FkTest.runInRoom(function()
    room().askToChoosePlayers = function(self, player, params)
      table.insert(candidateSets, table.map(params.targets, Util.IdMapper))
      if #candidateSets == 1 then return { p[2] } end -- remove the first target
      return { p[2] } -- add it back
    end
    room():useCard(use)
    room().askToChoosePlayers = original
  end)
  lu.assertEquals(#candidateSets, 2)
  lu.assertTrue(table.contains(candidateSets[2], p[2].id))
  lu.assertFalse(table.contains(candidateSets[2], p[7].id))
  lu.assertTrue(table.contains(use.tos, p[2]))
  lu.assertEquals(#use.tos, 6)
  lu.assertEquals(A.getResult(use).triggered_count, 2)
end

function Testhanjin_extra_targets:testAllianceFeastContextSurvivesTheRealUsePipeline()
  setKingdoms(groupKingdoms)
  local p = room().players
  emptyHand(p[1])
  local use = useData(p[1], { p[3] }, "hanjin__alliance_feast", {
    { condition = "kongchao", effect = "remove_target" },
    { condition = "kongchao", effect = "add_target" },
  })
  local candidateSets = {}
  local originalChoose = room().askToChoosePlayers
  local originalChoice = room().askToChoice
  FkTest.runInRoom(function()
    room().askToChoosePlayers = function(self, player, params)
      table.insert(candidateSets, table.map(params.targets, Util.IdMapper))
      if #candidateSets == 1 then return { p[3] } end
      return { p[3] }
    end
    room().askToChoice = function(self, player, params)
      if params.skill_name == "alliance_feast_skill" then
        return table.find(params.choices, function(choice)
          return choice:startsWith("alliance_feast_draw")
        end) or params.choices[1]
      end
      return originalChoice(self, player, params)
    end
    room():useCard(use)
    room().askToChoosePlayers = originalChoose
    room().askToChoice = originalChoice
  end)
  lu.assertEquals(#candidateSets, 2)
  lu.assertTrue(table.contains(candidateSets[2], p[3].id))
  lu.assertFalse(table.contains(candidateSets[2], p[5].id))
  lu.assertTrue(table.contains(use.tos, p[3]))
  lu.assertEquals(#use.tos, 3)
  lu.assertEquals(A.getResult(use).triggered_count, 2)
end

function Testhanjin_extra_targets:testAllianceFeastKeepsTheChosenKingdomWhenTheFirstTargetIsRemoved()
  setKingdoms(groupKingdoms)
  local p = room().players
  local use = useData(p[1], { p[3] }, "hanjin__alliance_feast")
  FkTest.runInRoom(function() use.card.skill:onUse(room(), use) end) -- p1 + shu p3,p4
  lu.assertEquals(#use.tos, 3)
  lu.assertEquals(#candidates(use), 0)
  use:removeTarget(p[3])
  local readded = candidates(use)
  lu.assertTrue(contains(readded, p[3]))
  lu.assertFalse(contains(readded, p[5]))
  lu.assertFalse(contains(readded, p[7]))
end

function Testhanjin_extra_targets:testAllianceFeastReaddsOnlyTheChosenKingdomAndSelf()
  setKingdoms(groupKingdoms)
  local p = room().players
  local use = useData(p[1], { p[3] }, "hanjin__alliance_feast")
  FkTest.runInRoom(function() use.card.skill:onUse(room(), use) end)
  use:removeAllTargets()
  local all = candidates(use)
  lu.assertTrue(contains(all, p[1]))
  lu.assertTrue(contains(all, p[3]))
  lu.assertTrue(contains(all, p[4]))
  lu.assertFalse(contains(all, p[2]))
  lu.assertFalse(contains(all, p[5]))
end

function Testhanjin_extra_targets:testThreatenEmperorOnlyReaddsTheUser()
  setKingdoms(groupKingdoms)
  local p = room().players
  local use = useData(p[1], { p[1] }, "hanjin__threaten_emperor")
  lu.assertEquals(#candidates(use), 0)
  use:removeAllTargets()
  local all = candidates(use)
  lu.assertTrue(contains(all, p[1]))
  lu.assertFalse(contains(all, p[2]))
end

-- Collateral: independent attached targets ------------------------------------

function Testhanjin_extra_targets:testCollateralMainCandidateNeedsItsOwnLegalSubTarget()
  setKingdoms(groupKingdoms)
  local p = room().players
  equip(p[2], "hanjin__qinggang_sword") -- range 2
  equip(p[6], "hanjin__qinggang_sword") -- p6 cannot reach p3 (distance 3)
  local use = useData(p[1], { p[2], p[3] }, "hanjin__collateral")
  FkTest.runInRoom(function()
    use.card.skill:onUse(room(), use)
    lu.assertFalse(p[6]:inMyAttackRange(p[3]))
    -- The old generic getExtraTargets inherited p3 and therefore missed p6.
    lu.assertFalse(table.contains(use:getExtraTargets(), p[6]))
    local main = E.candidates(room(), use, {})
    lu.assertTrue(table.contains(main, p[6]))
    local subs = E.subCandidates(room(), use, p[6], {})
    lu.assertTrue(table.contains(subs, p[5]))
    lu.assertFalse(table.contains(subs, p[3]))
  end)
end

function Testhanjin_extra_targets:testCollateralAddsAnIndependentSubTarget()
  setKingdoms(groupKingdoms)
  local p = room().players
  equip(p[2], "hanjin__qinggang_sword")
  equip(p[6], "hanjin__qinggang_sword")
  emptyHand(p[1])
  local use = useData(p[1], { p[2], p[3] }, "hanjin__collateral", addTargetEntry())
  local effects = {}
  local skel = fk.CreateSkill { name = "#hanjin_test_collateral_effect_probe" }
  skel:addEffect(fk.CardEffecting, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return data.card ~= nil and data.card.name == "hanjin__collateral"
    end,
    on_refresh = function(self, event, target, player, data)
      table.insert(effects, { to = data.to, subs = data.subTargets })
    end,
  })
  FkTest.runInRoom(function() room():addSkill(skel:createSkill()) end)
  FkTest.runInRoom(function()
    FkTest.setNextReplies(p[1], { FkTest.ReplyChoosePlayer({ p[6] }), FkTest.ReplyChoosePlayer({ p[5] }) })
    FkTest.setNextReplies(p[2], { "" })
    FkTest.setNextReplies(p[6], { "" })
    room():useCard(use)
  end)
  lu.assertEquals(#use.tos, 2)
  lu.assertTrue(table.contains(use.tos, p[6]))
  lu.assertEquals(table.map(use:getSubTos(p[2]), Util.IdMapper), { p[3].id })
  lu.assertEquals(table.map(use:getSubTos(p[6]), Util.IdMapper), { p[5].id })
  lu.assertEquals(A.getResult(use).triggered_count, 1)
  local addedEffect = table.find(effects, function(effect) return effect.to == p[6] end)
  lu.assertNotNil(addedEffect)
  lu.assertEquals(table.map(addedEffect.subs, Util.IdMapper), { p[5].id })
end

function Testhanjin_extra_targets:testCollateralDecliningTheSubTargetChangesNothing()
  setKingdoms(groupKingdoms)
  local p = room().players
  equip(p[2], "hanjin__qinggang_sword")
  equip(p[6], "hanjin__qinggang_sword")
  emptyHand(p[1])
  local use = useData(p[1], { p[2], p[3] }, "hanjin__collateral", addTargetEntry())
  FkTest.runInRoom(function()
    FkTest.setNextReplies(p[1], { FkTest.ReplyChoosePlayer({ p[6] }), "" })
    FkTest.setNextReplies(p[2], { "" })
    room():useCard(use)
  end)
  lu.assertEquals(table.map(use.tos, Util.IdMapper), { p[2].id })
  lu.assertEquals(table.map(use:getSubTos(p[2]), Util.IdMapper), { p[3].id })
  lu.assertFalse(A.getResult(use).triggered)
end

function Testhanjin_extra_targets:testCollateralSubTargetIsRecheckedAfterSelection()
  setKingdoms(groupKingdoms)
  local p = room().players
  equip(p[2], "hanjin__qinggang_sword")
  local weapon = equip(p[6], "hanjin__qinggang_sword")
  emptyHand(p[1])
  local use = useData(p[1], { p[2], p[3] }, "hanjin__collateral", addTargetEntry())
  local original = room().askToChoosePlayers
  local calls = 0
  FkTest.runInRoom(function()
    room().askToChoosePlayers = function(self, player, params)
      calls = calls + 1
      if calls == 1 then return { p[6] } end
      -- The main target loses its weapon while the sub target is being chosen.
      room():throwCard(weapon.id, "test", p[6], p[6])
      return { p[5] }
    end
    FkTest.setNextReplies(p[2], { "" })
    room():useCard(use)
    room().askToChoosePlayers = original
  end)
  lu.assertEquals(table.map(use.tos, Util.IdMapper), { p[2].id })
  lu.assertFalse(A.getResult(use).triggered)
end

function Testhanjin_extra_targets:testCollateralExplicitConditionStillRequiresItsOwnSubTarget()
  setKingdoms(groupKingdoms)
  local p = room().players
  equip(p[2], "hanjin__qinggang_sword")
  local entry = {
    condition = "kongchao", effect = "add_target",
    target_condition = { filter = function(room, use, target) return target == p[4] end },
  }
  local use = useData(p[1], { p[2], p[3] }, "hanjin__collateral", { entry })
  local result
  FkTest.runInRoom(function()
    use.card.skill:onUse(room(), use)
    result = E.candidates(room(), use, entry)
    lu.assertTrue(table.contains(result, p[4]))
    lu.assertTrue(table.contains(E.subCandidates(room(), use, p[4], entry), p[5]))
  end)
end

-- Add-target pipeline --------------------------------------------------------

function Testhanjin_extra_targets:testAddTargetSuccessTriggersOnce()
  local p = room().players
  emptyHand(p[1])
  local use = useData(p[1], { p[2] }, "hanjin__slash", addTargetEntry())
  local triggers = 0
  local skel = fk.CreateSkill { name = "#hanjin_test_extra_trigger_probe" }
  skel:addEffect(A.Triggered, {
    global = true,
    can_refresh = function(self, event, target, player) return target == player end,
    on_refresh = function() triggers = triggers + 1 end,
  })
  FkTest.runInRoom(function() room():addSkill(skel:createSkill()) end)
  FkTest.runInRoom(function()
    FkTest.setNextReplies(p[1], { FkTest.ReplyChoosePlayer({ p[8] }) })
    FkTest.setNextReplies(p[2], { "" })
    FkTest.setNextReplies(p[8], { "" })
    room():useCard(use)
  end)
  lu.assertEquals(table.map(use.tos, Util.IdMapper), { p[2].id, p[8].id })
  lu.assertEquals(A.getResult(use).triggered_count, 1)
  lu.assertEquals(A.getResult(use).effects.add_target, 1)
  lu.assertEquals(triggers, 1)
end

function Testhanjin_extra_targets:testCancellingTheExtraTargetDoesNotTrigger()
  local p = room().players
  emptyHand(p[1])
  local use = useData(p[1], { p[2] }, "hanjin__slash", addTargetEntry())
  FkTest.runInRoom(function()
    FkTest.setNextReplies(p[1], { "" })
    FkTest.setNextReplies(p[2], { "" })
    room():useCard(use)
  end)
  lu.assertEquals(table.map(use.tos, Util.IdMapper), { p[2].id })
  lu.assertFalse(A.getResult(use).triggered)
end

function Testhanjin_extra_targets:testSequentialRemoveThenAddUsesTheCurrentTargetList()
  local p = room().players
  emptyHand(p[1])
  local use = useData(p[1], { p[2] }, "hanjin__slash", {
    { condition = "kongchao", effect = "remove_target" },
    { condition = "kongchao", effect = "add_target" },
  })
  FkTest.runInRoom(function()
    FkTest.setNextReplies(p[1], {
      FkTest.ReplyChoosePlayer({ p[2] }),
      FkTest.ReplyChoosePlayer({ p[2] }),
    })
    FkTest.setNextReplies(p[2], { "" })
    room():useCard(use)
  end)
  lu.assertTrue(table.contains(use.tos, p[2]))
  lu.assertEquals(#use.tos, 1)
  lu.assertEquals(A.getResult(use).triggered_count, 2)
end

function Testhanjin_extra_targets:testServerRechecksAChangedCandidate()
  setKingdoms(groupKingdoms)
  local p = room().players
  emptyHand(p[1])
  local use = useData(p[1], { p[3] }, "hanjin__befriend_attacking", addTargetEntry())
  local original = room().askToChoosePlayers
  FkTest.runInRoom(function()
    room().askToChoosePlayers = function(self, player, params)
      -- p8 (qun) was a legal different-kingdom target; it becomes same-kingdom
      -- while the request is being answered.
      room():setPlayerProperty(p[8], "kingdom", "wei")
      return { p[8] }
    end
    room():useCard(use)
    room().askToChoosePlayers = original
  end)
  lu.assertEquals(table.map(use.tos, Util.IdMapper), { p[3].id })
  lu.assertFalse(A.getResult(use).triggered)
end

-- Quantity vs explicit replacement ------------------------------------------

function Testhanjin_extra_targets:testQuantityOnlyEntryDoesNotRelaxTheCardCondition()
  setKingdoms(groupKingdoms)
  local p = room().players
  local entry = addTargetEntry()[1]
  local use = useData(p[1], { p[3] }, "hanjin__befriend_attacking", { entry })
  local result = candidates(use, entry)
  lu.assertFalse(contains(result, p[2])) -- same kingdom as the user
  lu.assertTrue(contains(result, p[5]))
end

function Testhanjin_extra_targets:testExplicitConditionReplacesTheCardCondition()
  setKingdoms(groupKingdoms)
  local p = room().players
  local entry = { condition = "kongchao", effect = "add_target", target_condition = { same_kingdom = true } }
  local use = useData(p[1], { p[3] }, "hanjin__befriend_attacking", { entry })
  local result = candidates(use, entry)
  lu.assertTrue(contains(result, p[2])) -- allowed by the explicit condition
  lu.assertFalse(contains(result, p[5])) -- different kingdom is no longer allowed
end

function Testhanjin_extra_targets:testExplicitDistanceReplacesTheCardAttackRange()
  setKingdoms(groupKingdoms)
  local p = room().players
  local entry = { condition = "kongchao", effect = "add_target", target_condition = { distance = 2 } }
  local use = useData(p[1], { p[2] }, "hanjin__slash", { entry })
  local result = candidates(use, entry)
  lu.assertTrue(contains(result, p[3])) -- distance 2, outside the normal attack range
  lu.assertFalse(contains(result, p[8])) -- distance 1
  lu.assertFalse(contains(result, p[1])) -- distance 0
end

function Testhanjin_extra_targets:testExplicitConditionIsUsedByTheAddTargetPipeline()
  setKingdoms(groupKingdoms)
  local p = room().players
  emptyHand(p[1])
  local entry = { condition = "kongchao", effect = "add_target", target_condition = { same_kingdom = true } }
  local use = useData(p[1], { p[3] }, "hanjin__befriend_attacking", { entry })
  FkTest.runInRoom(function()
    FkTest.setNextReplies(p[1], { FkTest.ReplyChoosePlayer({ p[2] }) })
    room():useCard(use)
  end)
  lu.assertTrue(contains(use.tos, p[3]))
  lu.assertTrue(contains(use.tos, p[2]))
  lu.assertEquals(#use.tos, 2)
  lu.assertEquals(A.getResult(use).triggered_count, 1)
end

function Testhanjin_extra_targets:testDuelAddsAndResolvesEachTarget()
  local p = room().players
  emptyHand(p[1])
  local use = useData(p[1], { p[2] }, "hanjin__duel", addTargetEntry())
  local hp2, hp3 = p[2].hp, p[3].hp
  FkTest.runInRoom(function()
    FkTest.setNextReplies(p[1], { FkTest.ReplyChoosePlayer({ p[3] }) })
    FkTest.setNextReplies(p[2], { "" })
    FkTest.setNextReplies(p[3], { "" })
    room():useCard(use)
  end)
  lu.assertEquals(table.map(use.tos, Util.IdMapper), { p[2].id, p[3].id })
  lu.assertEquals(p[2].hp, hp2 - 1)
  lu.assertEquals(p[3].hp, hp3 - 1)
  lu.assertEquals(A.getResult(use).triggered_count, 1)
end

return { name = "hanjin_extra_targets" }
