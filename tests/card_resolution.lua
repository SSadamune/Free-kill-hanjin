local support = __dofile("../../../tests/support/hegemony.lua")
Testhanjin_card_resolution = { setup = support.initHanjinRoom, tearDown = support.clearRoom }

-- Observe the real use pipeline; grant repetition at CardUsing, as a skill would.
local function probe(room, name, cardName, repeats)
  local counts, effects, uses = {}, {}, {}
  local skel = fk.CreateSkill { name = "#hanjin_resolution_probe_" .. name }
  for _, event in ipairs({ fk.AfterCardUseDeclared, fk.CardUsing,
    fk.TargetSpecifying, fk.TargetConfirming, fk.TargetSpecified, fk.TargetConfirmed,
    fk.PreCardEffect, fk.CardEffecting, fk.CardUseFinished }) do
    skel:addEffect(event, {
      global = true,
      can_refresh = function(self, ev, target, player, data)
        return target == player and data.card and data.card.name == cardName
      end,
      on_refresh = function(self, ev, target, player, data)
        counts[event] = (counts[event] or 0) + 1
        if event == fk.CardUsing then
          data.additionalEffect = (data.additionalEffect or 0) + repeats
          table.insert(uses, data)
        elseif event == fk.PreCardEffect then
          table.insert(effects, { to = data.to, hp = data.to and data.to.hp,
            recover = (data.extra_data or {}).analepticRecover, use = data.use })
        end
      end,
    })
  end
  FkTest.runInRoom(function() room:addSkill(skel:createSkill()) end)
  return counts, effects, uses
end

local function assertSingleUse(counts, targets, effects)
  lu.assertEquals(counts[fk.AfterCardUseDeclared], 1)
  lu.assertEquals(counts[fk.CardUsing], 1)
  lu.assertEquals(counts[fk.CardUseFinished], 1)
  for _, event in ipairs({ fk.TargetSpecifying, fk.TargetConfirming,
    fk.TargetSpecified, fk.TargetConfirmed }) do
    lu.assertEquals(counts[event], targets)
  end
  lu.assertEquals(counts[fk.PreCardEffect], effects)
  lu.assertEquals(counts[fk.CardEffecting], effects)
end

function Testhanjin_card_resolution:testDyingAnalepticKeepsRecoveryAfterLeavingDying()
  local room, p = FkTest.room, FkTest.room.players[1]
  local c = Fk:cloneCard("hanjin__analeptic")
  local counts, effects, uses = probe(room, "dying", c.name, 1)
  FkTest.runInRoom(function()
    local physical = room:printCard(c.name)
    room:obtainCard(p, physical)
    p.hp = 1
    FkTest.setNextReplies(p, { { card = physical.id } })
    room:loseHp(p, 1)
  end)
  lu.assertFalse(p.dead)
  lu.assertEquals(p.hp, 2)
  lu.assertEquals(p.drank, 0)
  lu.assertEquals(p:usedCardTimes("analeptic", Player.HistoryTurn), 0)
  assertSingleUse(counts, 1, 2)
  lu.assertEquals(effects[1].hp, 0)
  lu.assertEquals(effects[2].hp, 1)
  for _, effect in ipairs(effects) do
    lu.assertTrue(effect.recover)
    lu.assertIs(effect.use, uses[1])
  end
end

function Testhanjin_card_resolution:testNormalAnalepticRepeatsSameUse()
  local room, p = FkTest.room, FkTest.room.players[1]
  local c = Fk:cloneCard("hanjin__analeptic")
  local counts = probe(room, "drank", c.name, 2)
  FkTest.runInRoom(function()
    p.hp = p.maxHp - 1
    room:useCard { from = p, card = c }
  end)
  lu.assertEquals(p.hp, p.maxHp - 1)
  lu.assertEquals(p.drank, 3)
  lu.assertEquals(p:usedCardTimes("analeptic", Player.HistoryTurn), 1)
  assertSingleUse(counts, 1, 3)
end

function Testhanjin_card_resolution:testRepeatVisitsAllTargetsWithoutRepeatingAimEvents()
  local room = FkTest.room
  local p, a, b = room.players[1], room.players[2], room.players[3]
  local c = Fk:cloneCard("hanjin__slash")
  local counts, effects, uses = probe(room, "targets", c.name, 1)
  local ahp, bhp = a.hp, b.hp
  FkTest.runInRoom(function()
    FkTest.setNextReplies(a, { "", "" })
    FkTest.setNextReplies(b, { "", "" })
    room:useCard { from = p, tos = { a, b }, card = c }
  end)
  assertSingleUse(counts, 2, 4)
  lu.assertEquals(a.hp, ahp - 2)
  lu.assertEquals(b.hp, bhp - 2)
  lu.assertEquals(p:usedCardTimes("slash", Player.HistoryTurn), 1)
  lu.assertEquals({ effects[1].to.id, effects[2].to.id, effects[3].to.id, effects[4].to.id },
    { a.id, b.id, a.id, b.id })
  for _, effect in ipairs(effects) do lu.assertIs(effect.use, uses[1]) end
end

-- Repeating a cancellation cannot cancel the same responding card any further.
function Testhanjin_card_resolution:testToCardCancellationRemainsSingleEffect()
  local room, p = FkTest.room, FkTest.room.players[1]
  local c = Fk:cloneCard("hanjin__jink")
  local counts, effects, uses = probe(room, "tocard", c.name, 1)
  FkTest.runInRoom(function()
    room:useCard { from = p, card = c, toCard = Fk:cloneCard("hanjin__slash") }
  end)
  lu.assertEquals(counts[fk.CardUsing], 1)
  lu.assertEquals(counts[fk.CardUseFinished], 1)
  lu.assertEquals(#effects, 1)
  lu.assertEquals(uses[1].additionalEffect, 1)
end

return { name = "hanjin_card_resolution" }
