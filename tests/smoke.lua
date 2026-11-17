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
    hanjin = "平行时空国战",
    hanjin_mode = "国战平行时空",
    hanjin_heg_mode = "大合集",
    hanjin_rule_settings = "平行时空规则",
    hanjin_generals = "标准包",
    hanjin_zhenshi = "君临天下",
    hanjin_buchen = "君临天下·不臣篇",
    hanjin_bingqing = "君临天下·兵情篇",
    hanjin_zongheng = "纵横捭阖",
    hanjin_cards = "国战平行时空",
  }
  for key, expected in pairs(names) do
    lu.assertEquals(Fk:translate(key), expected)
  end

  local hanjinIndex, hegemonyIndex
  for i, name in ipairs(Fk.extension_names) do
    if name == "hanjin" then hanjinIndex = i end
    if name == "hegemony" then hegemonyIndex = i end
  end
  lu.assertNotNil(hanjinIndex, "hanjin missing from extension_names")
  lu.assertNotNil(hegemonyIndex, "hegemony missing from extension_names")
  lu.assertEquals(hanjinIndex, hegemonyIndex + 1)
end

function Testhanjin_smoke:testEmptyGeneralPacks()
  local ClientUtil = require "ltk.client.util"
  local listed = ClientUtil:getAllGeneralPack()
  local group = assert(Fk.extensions["hanjin"], "missing hanjin extension group")
  -- Mirror GeneralsOverview.loadPackages: UI order is the extension group order
  -- filtered by the client's GeneralPack enumeration, not package_names order.
  local visible = {}
  for _, name in ipairs(group) do
    if table.contains(listed, name) then table.insert(visible, name) end
  end
  local expected = {
    "hanjin_generals",
    "hanjin_zhenshi",
    "hanjin_bingqing",
    "hanjin_buchen",
    "hanjin_zongheng",
  }
  lu.assertEquals(#visible, #expected)
  for i, name in ipairs(expected) do lu.assertEquals(visible[i], name) end
  for _, name in ipairs({ "hanjin_buchen", "hanjin_bingqing", "hanjin_zongheng" }) do
    local pack = assert(Fk.packages[name], "missing empty pack " .. name)
    lu.assertEquals(pack.type, Package.GeneralPack)
    lu.assertEquals(pack.extensionName, "hanjin")
    lu.assertTrue(table.contains(pack.game_modes_whitelist, "hanjin_heg_mode"))
    lu.assertEquals(#pack.generals, 0)
    lu.assertEquals(#pack.cards, 0)
    lu.assertTrue(table.contains(Fk.package_names, name))
    lu.assertTrue(table.contains(listed, name))
    lu.assertTrue(table.contains(group, name))
    lu.assertEquals(#ClientUtil:getGenerals(name), 0)
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
