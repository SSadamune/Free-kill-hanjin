-- --testfile loads this after the native test runner has initialized FkTest.
-- Return a name descriptor so FreeKill selects the matching global LuaUnit suite.
Testqiao_smoke = {
  setup = FkTest.initRoom,
  tearDown = FkTest.clearRoom,
}

function Testqiao_smoke:testExtensionLoaded()
  lu.assertNotNil(Fk.packages.qiao_generals)
  lu.assertEquals(Fk.packages.qiao_generals.extensionName, "qiao")
  local names = {
    qiao = "平行时空国战",
    qiao_mode = "国战平行时空",
    qiao_heg_mode = "大合集",
    qiao_rule_settings = "平行时空规则",
    qiao_generals = "标准包",
    qiao_zhenshi = "君临天下",
    qiao_buchen = "君临天下·不臣篇",
    qiao_bingqing = "君临天下·兵情篇",
    qiao_zongheng = "纵横捭阖",
    qiao_cards = "国战平行时空",
  }
  for key, expected in pairs(names) do
    lu.assertEquals(Fk:translate(key), expected)
  end

  local qiaoIndex, hegemonyIndex
  for i, name in ipairs(Fk.extension_names) do
    if name == "qiao" then qiaoIndex = i end
    if name == "hegemony" then hegemonyIndex = i end
  end
  lu.assertNotNil(qiaoIndex, "qiao missing from extension_names")
  lu.assertNotNil(hegemonyIndex, "hegemony missing from extension_names")
  lu.assertEquals(qiaoIndex, hegemonyIndex + 1)
end

function Testqiao_smoke:testEmptyGeneralPacks()
  local ClientUtil = require "ltk.client.util"
  local listed = ClientUtil:getAllGeneralPack()
  local group = assert(Fk.extensions["qiao"], "missing qiao extension group")
  -- Mirror GeneralsOverview.loadPackages: UI order is the extension group order
  -- filtered by the client's GeneralPack enumeration, not package_names order.
  local visible = {}
  for _, name in ipairs(group) do
    if table.contains(listed, name) then table.insert(visible, name) end
  end
  local expected = {
    "qiao_generals",
    "qiao_zhenshi",
    "qiao_bingqing",
    "qiao_buchen",
    "qiao_zongheng",
  }
  lu.assertEquals(#visible, #expected)
  for i, name in ipairs(expected) do lu.assertEquals(visible[i], name) end
  for _, name in ipairs({ "qiao_buchen", "qiao_zongheng" }) do
    local pack = assert(Fk.packages[name], "missing empty pack " .. name)
    lu.assertEquals(pack.type, Package.GeneralPack)
    lu.assertEquals(pack.extensionName, "qiao")
    lu.assertTrue(table.contains(pack.game_modes_whitelist, "qiao_heg_mode"))
    lu.assertEquals(#pack.generals, 0)
    lu.assertEquals(#pack.cards, 0)
    lu.assertTrue(table.contains(Fk.package_names, name))
    lu.assertTrue(table.contains(listed, name))
    lu.assertTrue(table.contains(group, name))
    lu.assertEquals(#ClientUtil:getGenerals(name), 0)
  end
  local bingqing = assert(Fk.packages.qiao_bingqing)
  lu.assertEquals(bingqing.type, Package.GeneralPack)
  lu.assertEquals(bingqing.extensionName, "qiao")
  lu.assertTrue(table.contains(bingqing.game_modes_whitelist, "qiao_heg_mode"))
  lu.assertEquals(#ClientUtil:getGenerals("qiao_bingqing"), 10)
  lu.assertEquals(#bingqing.cards, 0)
end

function Testqiao_smoke:testJianxiongObtainsDamageCard()
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

return { name = "qiao_smoke" }
