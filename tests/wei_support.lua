-- 魏标准包：持重、突袭、放逐定向验收文件。
-- 规则依据：rules/standard-generals.md 魏区、rules/generals/wei014-caopi.md、
-- rulebook/terms/general-op-terms/stack.md、docs/development/implementation/only-as.md。
-- 本轮已定向运行本文件（真实伤害/翻面/请求入口，无 mock）：
--   python scripts/test.py --file tests/wei_support.lua --timeout 180
local support = __dofile("../../../tests/support/hegemony.lua")
local O = require "packages.hanjin.pkg.hanjin_mode.rules.only_as"

local CHIZHONG = "hanjin__skill_wei003_2"
local TUXI = "hanjin__skill_wei004_1"
local FANGZHU = "hanjin__skill_wei014_2"

local DEFAULT_KINGDOMS = { "wei", "wei", "wei", "wei", "wei", "wei", "wei", "wei" }

Testhanjin_wei_support = {}

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function p(n) return FkTest.room.players[n] end

local function clearCards(room, player, area)
  local ids = player:getCardIds(area or "he")
  if #ids > 0 then
    inRoom(function()
      room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false)
    end)
  end
end

local function setHand(room, player, specs)
  clearCards(room, player, "he")
  local ids = {}
  inRoom(function()
    for _, spec in ipairs(specs) do
      local card = room:printCard(spec[1], spec[2] or Card.Spade, spec[3] or 1)
      room:obtainCard(player, card, false, fk.ReasonJustMove)
      table.insert(ids, card.id)
    end
  end)
  return ids
end

local function grant(player, skillName)
  inRoom(function()
    player.room:handleAddLoseSkills(player, skillName, nil, false, true)
  end)
end

local function initializeGenerals(room)
  inRoom(function()
    for i, pl in ipairs(room.players) do
      local kingdom = DEFAULT_KINGDOMS[i] or "wei"
      pl:revealGeneral(false, true)
      pl:revealGeneral(true, true)
      room:changeHero(pl, "hanjin_test__" .. kingdom .. "_2", true, true, false, false, false)
      room:changeHero(pl, "hanjin_test__" .. kingdom .. "_1", true, false, false, false, false)
      pl.kingdom = kingdom
      room:setPlayerProperty(pl, "kingdom", kingdom)
      room:setPlayerMark(pl, "__heg_general", pl.general)
      room:setPlayerMark(pl, "__heg_deputy", pl.deputyGeneral)
      room:setPlayerMark(pl, "__heg_kingdom", kingdom)
      room:setPlayerMark(pl, "__heg_init_kingdom", kingdom)
      room:setPlayerMark(pl, "__heg_wild", 0)
      -- changeHero 期间 getGeneralMaxHp() 读取的是 __heg_general/__heg_deputy
      -- 标记；若标记仍指向开局随机双将，则本测试的体力上限会随初始双将变化。
      -- 标记写入测试双将后重算，确保夹具固定为测试将面。
      pl.maxHp = pl:getGeneralMaxHp()
      pl.hp = pl.maxHp
    end
  end)
end

local function prepare()
  local room = support.initHanjinRoom()
  initializeGenerals(room)
  return room
end

Testhanjin_wei_support.setup = function() prepare() end
Testhanjin_wei_support.tearDown = support.clearRoom

-- 持重：手牌数多于体力值时，选择体力值+1张以上并全部分配 -------------------
function Testhanjin_wei_support:testChizhongDistributesMoreThanHp()
  local room = FkTest.room
  grant(p(1), CHIZHONG)
  local given = setHand(room, p(1), {
    { "hanjin__slash", Card.Spade, 1 },
    { "hanjin__jink", Card.Heart, 2 },
    { "hanjin__peach", Card.Diamond, 3 },
    { "hanjin__duel", Card.Club, 4 },
    { "hanjin__dismantlement", Card.Spade, 5 },
  })
  setHand(room, p(2), {})
  -- 其他角色处于摸牌阶段、自己不在摸牌阶段：持重仍可发动。
  inRoom(function()
    room.current = p(2)
    p(2).phase = Player.Draw
    p(1).phase = Player.NotActive
    room:setBanner("RoundCount", 1)
  end)

  local extra
  FkTest.setNextReplies(p(1), {
    "1",
    FkTest.ReplyChooseCards({ given[1], given[2], given[3], given[4], given[5] }),
    FkTest.ReplyChooseCardAndPlayers({ p(2) }, { given[1], given[2], given[3], given[4], given[5] }),
  })
  inRoom(function()
    local card = room:printCard("hanjin__peach", Card.Heart, 6)
    room:obtainCard(p(1), card, false, fk.ReasonJustMove)
    extra = card.id
  end)

  -- 体力值4：交出5张（>4），保留额外得到的1张；不是只交超额1张。
  lu.assertEquals(#p(1):getCardIds(Player.Hand), 1)
  lu.assertEquals(p(1):getCardIds(Player.Hand)[1], extra)
  lu.assertEquals(#p(2):getCardIds(Player.Hand), 5)
  lu.assertEquals(p(1):usedSkillTimes(CHIZHONG, Player.HistoryTurn), 1)
end

-- 突袭：少摸等量张并获得手牌；展示后仅当杀，失技能不撤销 -----------------
function Testhanjin_wei_support:testTuxiDrawReductionAndTurnRestriction()
  local room = FkTest.room
  grant(p(1), TUXI)
  setHand(room, p(1), {})
  local c2 = setHand(room, p(2), { { "hanjin__jink", Card.Heart, 2 } })[1]
  local c3 = setHand(room, p(3), { { "hanjin__peach", Card.Diamond, 3 } })[1]

  local data = DrawNCardsData:new {
    who = p(1),
    reason = "game_rule",
    phase = Player.Draw,
    n = 2,
  }
  -- 获得顺序按当前回合角色起逆时针；按实际排序准备对应目标的手牌回复。
  local order = { p(2), p(3) }
  inRoom(function() room:sortByAction(order) end)
  local replies = { "1", FkTest.ReplyChoosePlayer({ p(2), p(3) }) }
  for _, target in ipairs(order) do
    table.insert(replies, target == p(2) and c2 or c3)
  end
  table.insert(replies, "1")
  FkTest.setNextReplies(p(1), replies)
  inRoom(function() room.logic:trigger(fk.DrawNCards, p(1), data) end)

  lu.assertEquals(data.n, 0) -- 少摸2张
  lu.assertTrue(table.contains(p(1):getCardIds(Player.Hand), c2))
  lu.assertTrue(table.contains(p(1):getCardIds(Player.Hand), c3))
  lu.assertTrue(O.isForbidden(p(1), Fk:getCardById(c2)))
  lu.assertTrue(table.contains(O.availableTargets(room, p(1), c2, "use"), "hanjin__slash"))

  -- 失去技能不取消已产生的本回合限制。
  inRoom(function()
    room:handleAddLoseSkills(p(1), "-" .. TUXI, nil, false, true)
  end)
  lu.assertTrue(O.isForbidden(p(1), Fk:getCardById(c2)))
  lu.assertTrue(table.contains(O.availableTargets(room, p(1), c2, "use"), "hanjin__slash"))
end

-- 放逐：叠置并摸2，足额弃4平置，牌名字数>7失去体力；不足4不进入弃牌分支 --
function Testhanjin_wei_support:testFangzhuStackDrawDiscardAndHpLoss()
  local room = FkTest.room
  grant(p(1), FANGZHU)
  -- 连续三次受伤用于覆盖不同分支；固定施放者体力，避免第三次伤害进入濒死。
  inRoom(function()
    p(1).maxHp = 10
    p(1).hp = 10
  end)
  setHand(room, p(1), {})
  local four = setHand(room, p(2), {
    { "hanjin__dismantlement", Card.Spade, 1 },
    { "hanjin__dismantlement", Card.Heart, 2 },
    { "hanjin__duel", Card.Club, 3 },
    { "hanjin__duel", Card.Diamond, 4 },
  })
  local hp = p(2).hp

  FkTest.setNextReplies(p(1), { "1", FkTest.ReplyChoosePlayer({ p(2) }) })
  FkTest.setNextReplies(p(2), { FkTest.ReplyDiscard({ four[1], four[2], four[3], four[4] }) })
  inRoom(function() room:damage { from = p(3), to = p(1), damage = 1 } end)

  lu.assertEquals(p(2).hp, hp - 1) -- 牌名字数之和 4+4+2+2=12 > 7
  lu.assertTrue(p(2).faceup) -- 弃牌后平置（faceup=true）
  lu.assertEquals(#p(2):getCardIds(Player.Hand), 2) -- 摸2后弃4
  for _, id in ipairs(four) do
    lu.assertEquals(room:getCardArea(id), Card.DiscardPile)
  end

  -- 已有叠置状态（faceup=false）：再次叠置不反转；摸牌仍执行。
  inRoom(function()
    if p(2).faceup then p(2):turnOver() end
  end)
  lu.assertFalse(p(2).faceup)

  -- 不足四张：不提供弃牌分支，保持叠置也不失去体力。
  local hp2 = p(2).hp
  setHand(room, p(2), { { "hanjin__peach", Card.Heart, 7 } })
  FkTest.setNextReplies(p(1), { "1", FkTest.ReplyChoosePlayer({ p(2) }) })
  inRoom(function() room:damage { from = p(3), to = p(1), damage = 1 } end)
  lu.assertFalse(p(2).faceup)
  lu.assertEquals(p(2).hp, hp2)
  lu.assertEquals(#p(2):getCardIds(Player.Hand), 3) -- 1+摸2

  -- 平置（faceup=true）→叠置（faceup=false）：不足4张不弃牌，但仍摸2。
  inRoom(function()
    if not p(2).faceup then p(2):turnOver() end
  end)
  lu.assertTrue(p(2).faceup)
  setHand(room, p(2), { { "hanjin__peach", Card.Heart, 8 } })
  FkTest.setNextReplies(p(1), { "1", FkTest.ReplyChoosePlayer({ p(2) }) })
  inRoom(function() room:damage { from = p(3), to = p(1), damage = 1 } end)
  lu.assertFalse(p(2).faceup)
end

return { name = "hanjin_wei_support" }
