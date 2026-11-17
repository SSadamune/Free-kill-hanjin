-- --testfile loads this after the native test runner has initialized FkTest.
-- Return a name descriptor so FreeKill selects the matching global LuaUnit suite.
Testhanjin_smoke = {
  setup = FkTest.initRoom,
  tearDown = FkTest.clearRoom,
}

function Testhanjin_smoke:testExtensionLoaded()
  lu.assertNotNil(Fk.packages.hanjin_generals)
  lu.assertEquals(Fk.packages.hanjin_generals.extensionName, "hanjin")
  local names = {
    hanjin = "平行时空",
    hanjin_mode = "国战平行时空",
    hanjin_heg_mode = "大合集",
    hanjin_rule_settings = "平行时空规则",
    hanjin_generals = "标准包",
    hanjin_zhenshi = "君临天下·阵势变权",
    hanjin_cards = "国战平行时空",
  }
  for key, expected in pairs(names) do
    lu.assertEquals(Fk:translate(key), expected)
  end
end

function Testhanjin_smoke:testJianxiongObtainsDamageCard()
  local room = FkTest.room
  local me, attacker = room.players[1], room.players[2]
  FkTest.RunAddSkills(me, "jianxiong")
  local hp = me.hp
  local slash = Fk:getCardById(1)
  lu.assertEquals(slash.trueName, "slash")
  FkTest.setNextReplies(me, { "__cancel", "1" })
  FkTest.runInRoom(function()
    room:useCard { from = attacker, tos = { me }, card = slash }
  end)
  lu.assertEquals(me.hp, hp - 1)
  lu.assertTrue(table.contains(me:getCardIds("h"), slash.id))
  lu.assertEquals(room:getCardArea(slash), Card.PlayerHand)
end

return { name = "hanjin_smoke" }
