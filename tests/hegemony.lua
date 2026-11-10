local support = __dofile("../../../tests/support/hegemony.lua")
local H = require "packages.hegemony.util"
Testhanjin_hegemony = { setup = support.initRoom, tearDown = support.clearRoom }

function Testhanjin_hegemony:testRegistrationAndPackageScope()
  lu.assertEquals(Fk.game_modes.new_heg_mode.rule, "heg_rule")
  lu.assertTrue(table.contains(Fk.game_mode_disabled.new_heg_mode, "hanjin_generals"))
  lu.assertTrue(table.contains(Fk.game_mode_disabled.aaa_role_mode, "hanjin_generals"))
  lu.assertTrue(FkTest.room:isGameMode("heg_mode"))
end

function Testhanjin_hegemony:testHiddenGeneralsAndInitialCards()
  local room = FkTest.room
  lu.assertEquals(#room.players, 8)
  for _, p in ipairs(room.players) do
    lu.assertEquals(p.general, "anjiang")
    lu.assertEquals(p.deputyGeneral, "anjiang")
    lu.assertEquals(p.kingdom, "unknown")
    lu.assertEquals(#p:getCardIds("h"), 4)
    local main = Fk.generals[p:getMark("__heg_general")]
    local deputy = Fk.generals[p:getMark("__heg_deputy")]
    lu.assertEquals(p.maxHp, (main.maxHp + main.mainMaxHpAdjustedValue
      + deputy.maxHp + deputy.deputyMaxHpAdjustedValue) // 2)
  end
end

function Testhanjin_hegemony:testNationalWarGeneralAndCardPools()
  local room = FkTest.room
  lu.assertFalse(table.contains(room.general_pile, "caocao"))
  lu.assertTrue(#room.general_pile > 0)
  for _, name in ipairs(room.general_pile) do
    lu.assertTrue(table.contains(Fk.game_modes.new_heg_mode.whitelist, Fk.generals[name].package.name))
  end
  for _, id in ipairs(room.draw_pile) do
    lu.assertTrue(table.contains(Fk.game_modes.new_heg_mode.whitelist,
      Fk:getCardById(id).package.name))
  end
end

function Testhanjin_hegemony:testRevealAndKingdomRelations()
  local room = FkTest.room
  local first, second = room.players[1], room.players[2]
  lu.assertFalse(H.compareKingdomWith(first, second))
  FkTest.runInRoom(function()
    first:revealGeneral(false)
    second:revealGeneral(false)
  end)
  lu.assertEquals(first.general, first:getMark("__heg_general"))
  lu.assertEquals(first.kingdom, "wei")
  lu.assertTrue(first:hasSkill("hs__jianxiong"))
  lu.assertTrue(H.compareKingdomWith(first, second))
  lu.assertFalse(H.compareKingdomWith(first, room.players[3]))
end

function Testhanjin_hegemony:testRemoveDeputyPreservesMaxHp()
  local room = FkTest.room
  local me = room.players[1]
  local maxHp = me.maxHp
  FkTest.runInRoom(function() H.removeGeneral(me, true) end)
  lu.assertEquals(me.deputyGeneral, "blank_shibing")
  lu.assertEquals(me:getMark("__heg_deputy"), "blank_shibing")
  lu.assertEquals(me.maxHp, maxHp)
  lu.assertFalse(me:hasSkill("hs__ganglie"))
end

function Testhanjin_hegemony:testHideAndRevealRestoresSkill()
  local me = FkTest.room.players[1]
  FkTest.runInRoom(function() me:revealGeneral(false) end)
  lu.assertTrue(me:hasSkill("hs__jianxiong"))
  FkTest.runInRoom(function() me:hideGeneral(false) end)
  lu.assertEquals(me.general, "anjiang")
  lu.assertFalse(me:hasSkill("hs__jianxiong"))
  lu.assertEquals(me:getMark("__heg_general"), "hs__caocao")
  FkTest.runInRoom(function() me:revealGeneral(false) end)
  lu.assertTrue(me:hasSkill("hs__jianxiong"))
end

return { name = "hanjin_hegemony" }
