local support = __dofile("../../../tests/support/hegemony.lua")
local A = require "packages.hanjin.pkg.hanjin_mode.rules.adaptation"
Testhanjin_card_reuse = { setup = support.initHanjinRoom, tearDown = support.clearRoom }

local function card(name, suit, number)
  return assert(table.find(Fk.cards, function(c)
    return c.name == name and (suit == nil or c.suit == suit)
      and (number == nil or c.number == number)
  end), "missing " .. name)
end

local function give(room, player, c)
  if not table.contains(player:getCardIds("h"), c.id) then
    room:obtainCard(player, c.id, true, fk.ReasonJustMove, player, "test")
  end
  return c
end

local function use(room, from, tos, c, extra)
  local data = UseCardData:new { from = from, tos = tos or {}, card = c, extra_data = extra or {} }
  room:useCard(data)
  return data
end

function Testhanjin_card_reuse:testSlashDamage()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local c = card("hanjin__slash")
  local hp = t.hp
  FkTest.runInRoom(function()
    give(room, p, c)
    FkTest.setNextReplies(t, { "" })
    use(room, p, { t }, c)
  end)
  lu.assertEquals(t.hp, hp - 1)
end

function Testhanjin_card_reuse:testJinkResponse()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local slash, jink = card("hanjin__slash"), card("hanjin__jink")
  local hp = t.hp
  lu.assertEquals(jink.skill.name, "jink_skill")
  FkTest.runInRoom(function()
    give(room, p, slash)
    give(room, t, jink)
    FkTest.setNextReplies(t, { { card = jink.id } })
    room:useVirtualCard("hanjin__slash", nil, p, t)
  end)
  lu.assertEquals(t.hp, hp)
end

function Testhanjin_card_reuse:testPeachHeal()
  local room = FkTest.room
  local p = room.players[1]
  local c = card("hanjin__peach")
  FkTest.runInRoom(function()
    p.hp = p.maxHp - 1
    give(room, p, c)
    use(room, p, { p }, c)
  end)
  lu.assertEquals(p.hp, p.maxHp)
end

function Testhanjin_card_reuse:testDismantlement()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local c = card("hanjin__dismantlement")
  local targetCard = card("hanjin__slash", Card.Heart, 10)
  FkTest.runInRoom(function()
    give(room, p, c)
    give(room, t, targetCard)
    for _, q in ipairs(room.players) do FkTest.setNextReplies(q, { "" }) end
    local original = room.askToChooseCard
    room.askToChooseCard = function() return targetCard.id end
    use(room, p, { t }, c)
    room.askToChooseCard = original
  end)
  lu.assertFalse(table.contains(t:getCardIds("h"), targetCard.id))
end

function Testhanjin_card_reuse:testAxeEquipSkill()
  local room = FkTest.room
  local p = room.players[1]
  local c = card("hanjin__axe")
  FkTest.runInRoom(function()
    give(room, p, c)
    use(room, p, { p }, c)
  end)
  lu.assertTrue(table.contains(p:getEquipments(), c.id))
  lu.assertTrue(p:hasSkill("hanjin__axe_skill"))
end

function Testhanjin_card_reuse:testIceSlashDamage()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local c = card("hanjin__ice__slash")
  local hp = t.hp
  local dtype
  local skel = fk.CreateSkill { name = "#hanjin_probe_ice_damage" }
  skel:addEffect(fk.DamageInflicted, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return target == player and data.card and data.card.name == "hanjin__ice__slash"
    end,
    on_refresh = function(self, event, target, player, data) dtype = data.damageType end,
  })
  FkTest.runInRoom(function() room:addSkill(skel:createSkill()) end)
  FkTest.runInRoom(function()
    give(room, p, c)
    FkTest.setNextReplies(t, { "" })
    use(room, p, { t }, c)
  end)
  lu.assertEquals(t.hp, hp - 1)
  lu.assertEquals(dtype, fk.IceDamage)
end

function Testhanjin_card_reuse:testChasingNearExecuteBoth()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local c = card("hanjin__chasing_near")
  local first = card("hanjin__slash", Card.Club, 2)
  local second = card("hanjin__slash", Card.Club, 3)
  A.setCardEntries(c, { { id = "probe_both", condition = "kongchao", effect = "execute_both" } })
  local data
  FkTest.runInRoom(function()
    for _, id in ipairs(p:getCardIds("h")) do room:throwCard(id, "test", p, p) end
    give(room, p, c)
    give(room, t, first)
    give(room, t, second)
    local answers = { first.id, second.id }
    local original = room.askToChooseCard
    room.askToChooseCard = function(self, player, params)
      return table.remove(answers, 1)
    end
    for _, q in ipairs(room.players) do FkTest.setNextReplies(q, { "" }) end
    data = UseCardData:new { from = p, tos = { t }, card = c, extra_data = {} }
    room:useCard(data)
    room.askToChooseCard = original
  end)
  lu.assertFalse(table.contains(t:getCardIds("hej"), first.id))
  lu.assertTrue(table.contains(p:getCardIds("h"), second.id))
  lu.assertTrue(A.hasEffect(data, "execute_both"))
end

function Testhanjin_card_reuse:testBronzeSparrowGrantsAdaptationIgnore()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local bronze = card("hanjin__bronze_sparrow")
  local slash = card("hanjin__slash", Card.Club, 4)
  local extra = card("hanjin__peach", Card.Heart, 4)
  A.setCardEntries(slash, { { id = "probe_draw", condition = "kongchao", effect = "draw" } })
  local data
  FkTest.runInRoom(function()
    give(room, p, bronze)
    use(room, p, { p }, bronze)
    lu.assertTrue(p:hasSkill("hanjin__bronze_sparrow_skill"))
    give(room, p, slash)
    give(room, p, extra) -- ensure 空巢 is false
    FkTest.setNextReplies(t, { "" })
    data = UseCardData:new { from = p, tos = { t }, card = slash, extra_data = {} }
    room:useCard(data)
  end)
  lu.assertTrue(A.hasEffect(data, "draw"))
  lu.assertEquals(A.getResult(data).entries[1].ignored_by, "hanjin__bronze_sparrow_skill")
end

function Testhanjin_card_reuse:testAxeUnequipRemovesSkill()
  local room = FkTest.room
  local p = room.players[1]
  local c = card("hanjin__axe")
  FkTest.runInRoom(function()
    give(room, p, c)
    use(room, p, { p }, c)
    lu.assertTrue(p:hasSkill("hanjin__axe_skill"))
    room:moveCardTo({ c.id }, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile,
      "test", nil, true, p)
  end)
  lu.assertFalse(p:hasSkill("hanjin__axe_skill"))
end

function Testhanjin_card_reuse:testAdaptedEquipmentSkillsAttachAndDetach()
  local room = FkTest.room
  local p = room.players[1]
  local cases = {
    { "hanjin__spear", "hanjin__spear_skill" },
    { "hanjin__crossbow", "hanjin__crossbow_skill" },
    { "hanjin__six_swords", "hanjin__six_swords_skill" },
    { "hanjin__wooden_ox", "hanjin__wooden_ox_skill" },
    { "hanjin__jade_seal", "hanjin__jade_seal_skill" },
    { "hanjin__five_elements_fan", "hanjin__five_elements_fan_skill" },
    { "hanjin__black_chain", "hanjin__black_chain_skill" },
    { "hanjin__dark_armor", "hanjin__dark_armor_skill" },
    { "hanjin__eight_diagram", "hanjin__eight_diagram_skill" },
    { "hanjin__breastplate", "hanjin__breastplate_skill" },
    { "hanjin__peace_spell", "hanjin__peace_spell_skill" },
    { "hanjin__luminous_pearl", "hanjin__luminous_pearl_skill" },
    { "hanjin__dragon_phoenix", "#dragon_phoenix_skill" },
    { "hanjin__halberd", "#sa__halberd_skill" },
    { "hanjin__blade", "#sa__blade_skill" },
    { "hanjin__liulongcanjia", "#liulongcanjia_skill" },
    { "hanjin__taigong_tactics", "hanjin__taigong_tactics_skill" },
    { "hanjin__wonder_map", "hanjin__wonder_map_skill" },
  }
  for _, case in ipairs(cases) do
    local c = card(case[1])
    local attached, detached
    FkTest.runInRoom(function()
      give(room, p, c)
      use(room, p, { p }, c)
      attached = p:hasSkill(case[2])
      room:moveCardTo({ c.id }, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile,
        "test", nil, true, p)
      detached = not p:hasSkill(case[2])
    end)
    lu.assertTrue(attached, "Missing equip skill " .. case[2])
    lu.assertTrue(detached, "Equip skill did not detach " .. case[2])
  end
end

function Testhanjin_card_reuse:testBreastplateBPreventsNonLethalTwoDamage()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local c = card("hanjin__breastplate")
  local hp = p.hp
  local attached, equipped
  FkTest.runInRoom(function()
    give(room, p, c)
    use(room, p, { p }, c)
    attached = p:hasSkill("hanjin__breastplate_skill")
    equipped = table.contains(p:getEquipments(), c.id)
    FkTest.setNextReplies(p, { "1" })
    room:damage { from = t, to = p, damage = 2, damageType = fk.NormalDamage }
  end)
  lu.assertTrue(attached)
  lu.assertTrue(equipped)
  lu.assertEquals(p.hp, hp)
  lu.assertFalse(table.contains(p:getEquipments(), c.id))
end

function Testhanjin_card_reuse:testDrowningARequiresEquipmentAndBothOnZhuzhan()
  local room = FkTest.room
  local p, t, bare = room.players[1], room.players[2], room.players[3]
  local c = card("hanjin__drowning")
  local weapon = card("hanjin__axe")
  local treasure = card("hanjin__jade_seal")
  local hp = t.hp
  local data
  local order = {}
  FkTest.runInRoom(function()
    local entry = A.getEntries(c)[1]
    lu.assertEquals(entry.condition, "zhuzhan")
    lu.assertEquals(entry.effect, "execute_both")
    for _, id in ipairs(t:getCardIds("he")) do room:throwCard(id, "test", t, t) end
    room:moveCardTo({ weapon.id }, Card.PlayerEquip, t, fk.ReasonPut, "test", nil, true, t)
    room:moveCardTo({ treasure.id }, Card.PlayerEquip, t, fk.ReasonPut, "test", nil, true, t)
    lu.assertEquals(#t:getCardIds("e"), 2)
    local originalThrow = t.throwAllCards
    t.throwAllCards = function(self, area)
      if area == "e" then table.insert(order, "discard") end
      return originalThrow(self, area)
    end
    local skel = fk.CreateSkill { name = "#hanjin_probe_drowning_order" }
    skel:addEffect(fk.DamageInflicted, {
      global = true,
      can_refresh = function(self, event, target, player, damage)
        return target == t and damage.card and damage.card.name == "hanjin__drowning"
      end,
      on_refresh = function()
        table.insert(order, "damage")
      end,
    })
    room:addSkill(skel:createSkill())
    give(room, p, c)
    lu.assertNotIsTrue(p:canUseTo(c, bare))
    for _, q in ipairs(room.players) do FkTest.setNextReplies(q, { "" }) end
    data = UseCardData:new { from = p, tos = { t }, card = c, extra_data = {} }
    A.grantIgnore(data, "probe_zhuzhan")
    room:useCard(data)
    t.throwAllCards = originalThrow
  end)
  lu.assertEquals(order[1], "discard")
  lu.assertEquals(order[2], "damage")
  lu.assertEquals(#t:getCardIds("e"), 0)
  lu.assertEquals(t.hp, hp - 1)
  lu.assertTrue(A.hasEffect(data, "execute_both"))
  lu.assertEquals(A.getResult(data).entries[1].effect, "execute_both")
end

function Testhanjin_card_reuse:testBreastplateBAllowsRejection()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local c = card("hanjin__breastplate")
  local hp = p.hp
  FkTest.runInRoom(function()
    give(room, p, c)
    use(room, p, { p }, c)
    FkTest.setNextReplies(p, { "" })
    room:damage { from = t, to = p, damage = 2, damageType = fk.NormalDamage }
  end)
  lu.assertEquals(p.hp, hp - 2)
  lu.assertTrue(table.contains(p:getEquipments(), c.id))
end

function Testhanjin_card_reuse:testBreastplateBShieldCountsForLethalThreshold()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local c = card("hanjin__breastplate")
  FkTest.runInRoom(function()
    p.hp = 1
    room:changeShield(p, 1)
    give(room, p, c)
    use(room, p, { p }, c)
    -- 1 damage is not lethal while shield is counted (hp+shield = 2), and is
    -- not >1, so 护心镜 must not ask or trigger.
    room:damage { from = t, to = p, damage = 1, damageType = fk.NormalDamage }
  end)
  lu.assertTrue(table.contains(p:getEquipments(), c.id))
  lu.assertEquals(p.hp, 1)
  lu.assertEquals(p.shield, 0)
end

function Testhanjin_card_reuse:testDragonPhoenixADiscardsOnSlashTarget()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local equip = card("hanjin__dragon_phoenix")
  local slash = card("hanjin__slash")
  local victimCard = card("hanjin__peach", Card.Heart, 4)
  FkTest.runInRoom(function()
    give(room, p, equip)
    use(room, p, { p }, equip)
    lu.assertTrue(p:hasSkill("#dragon_phoenix_skill"))
    give(room, p, slash)
    give(room, t, victimCard)
    FkTest.setNextReplies(p, { "1" })
    FkTest.setNextReplies(t, { FkTest.ReplyDiscard({ victimCard }), "" })
    local data = UseCardData:new { from = p, tos = { t }, card = slash, extra_data = {} }
    room:useCard(data)
  end)
  lu.assertFalse(table.contains(t:getCardIds("he"), victimCard.id))
end

function Testhanjin_card_reuse:testHalberdAUsesStrategicSkill()
  local room = FkTest.room
  local p = room.players[1]
  local c = card("hanjin__halberd")
  FkTest.runInRoom(function()
    give(room, p, c)
    use(room, p, { p }, c)
    lu.assertTrue(p:hasSkill("#sa__halberd_skill"))
    lu.assertFalse(p:hasSkill("#halberd_skill"))
  end)
end

function Testhanjin_card_reuse:testBladeAUsesStrategicSkill()
  local room = FkTest.room
  local p = room.players[1]
  local c = card("hanjin__blade")
  FkTest.runInRoom(function()
    give(room, p, c)
    use(room, p, { p }, c)
    lu.assertTrue(p:hasSkill("#sa__blade_skill"))
    lu.assertFalse(p:hasSkill("#blade_skill"))
  end)
end

function Testhanjin_card_reuse:testLiulongAInstallsNationalMountLock()
  local room = FkTest.room
  local p = room.players[1]
  local c = card("hanjin__liulongcanjia")
  FkTest.runInRoom(function()
    give(room, p, c)
    use(room, p, { p }, c)
    lu.assertTrue(p:hasSkill("#liulongcanjia_skill"))
    lu.assertEquals(p:getMark("@@liulongcanjia"), 1)
  end)
end

function Testhanjin_card_reuse:testLuminousAInstallsZhiheng()
  local room = FkTest.room
  local p = room.players[1]
  local c = card("hanjin__luminous_pearl")
  FkTest.runInRoom(function()
    give(room, p, c)
    use(room, p, { p }, c)
    lu.assertTrue(p:hasSkill("hanjin__luminous_pearl_skill"))
  end)
end

function Testhanjin_card_reuse:testPeaceAPreventsAttributeDamage()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local c = card("hanjin__peace_spell")
  local hp = p.hp
  FkTest.runInRoom(function()
    give(room, p, c)
    use(room, p, { p }, c)
    lu.assertTrue(p:hasSkill("hanjin__peace_spell_skill"))
    room:damage { from = t, to = p, damage = 2, damageType = fk.FireDamage }
  end)
  lu.assertEquals(p.hp, hp)
end


return { name = "hanjin_card_reuse" }



