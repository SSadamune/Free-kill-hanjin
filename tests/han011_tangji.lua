-- HAN011 唐姬：哀舞、诀别。默认国战套件用例（加入 tests/all.lua 后生效）。
-- 规则依据：rules/standard-generals.md 汉区 HAN011、rulebook/events/death.md。
local support = __dofile("../../../tests/support/hegemony.lua")

local AY = "hanjin__skill_han011_1"
local JB = "hanjin__skill_han011_2"
local OPT_CARDS = "hanjin__skill_han011_2-cards"
local OPT_DRAW = "hanjin__skill_han011_2-draw"
local DEFAULT_KINGDOMS = { "han", "han", "wei", "wei", "shu", "shu", "wei", "han" }

Testhanjin_han011 = {}

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function p1() return FkTest.room.players[1] end
local function p2() return FkTest.room.players[2] end
local function p3() return FkTest.room.players[3] end

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
    for _, spec in ipairs(specs or {}) do
      local card = room:printCard(spec[1], spec[2] or Card.Spade, spec[3] or 1)
      room:obtainCard(player, card, false, fk.ReasonJustMove)
      table.insert(ids, card.id)
    end
  end)
  return ids
end

local function addEquip(room, player, name, suit, number)
  local id
  inRoom(function()
    local card = room:printCard(name, suit or Card.Spade, number or 1)
    room:moveCardTo(card, Card.PlayerEquip, player, fk.ReasonJustMove, "test", nil, false)
    id = card.id
  end)
  return id
end

local function setKingdom(room, player, kingdom)
  inRoom(function()
    player.kingdom = kingdom
    room:setPlayerProperty(player, "kingdom", kingdom)
    room:setPlayerMark(player, "__heg_kingdom", kingdom)
  end)
end

local function initializeGenerals(room)
  inRoom(function()
    for i, p in ipairs(room.players) do
      local kingdom = DEFAULT_KINGDOMS[i]
      p:revealGeneral(false, true)
      p:revealGeneral(true, true)
      room:changeHero(p, "hanjin_test__" .. kingdom .. "_2", true, true, false, false, false)
      room:changeHero(p, "hanjin_test__" .. kingdom .. "_1", true, false, false, false, false)
      p.kingdom = kingdom
      room:setPlayerProperty(p, "kingdom", kingdom)
      room:setPlayerMark(p, "__heg_general", p.general)
      room:setPlayerMark(p, "__heg_deputy", p.deputyGeneral)
      room:setPlayerMark(p, "__heg_kingdom", kingdom)
      room:setPlayerMark(p, "__heg_init_kingdom", kingdom)
      room:setPlayerMark(p, "__heg_wild", 0)
    end
    room:changeHero(p1(), "hanjin__han011", true, false, false, false, false)
    room:setPlayerMark(p1(), "__heg_general", "hanjin__han011")
    for _, p in ipairs(room.players) do p.hp = p.maxHp end
  end)
  return room
end

local function prepare()
  return initializeGenerals(support.initHanjinRoom())
end

Testhanjin_han011.setup = function() prepare() end
Testhanjin_han011.tearDown = support.clearRoom

function Testhanjin_han011:testAiwuOncePerDamageEventHealsWhenTotalAtLeastThree()
  local room = FkTest.room
  setKingdom(room, p1(), "han")
  setKingdom(room, p3(), "han")
  local mine = setHand(room, p1(), {
    { "hanjin__slash", Card.Spade, 1 },
    { "hanjin__jink", Card.Heart, 2 },
  })
  local theirs = setHand(room, p3(), { { "hanjin__slash", Card.Club, 3 } })
  inRoom(function()
    p1().maxHp = 10
    p3().maxHp = 10
    p1().hp = 3
    p3().hp = 3
  end)

  FkTest.setNextReplies(p1(), {
    FkTest.ReplyDiscard({ mine[1], mine[2] }),
  })
  FkTest.setNextReplies(p3(), { FkTest.ReplyDiscard({ theirs[1] }) })
  inRoom(function() room:damage { from = p2(), to = p3(), damage = 1 } end)

  lu.assertEquals(p1().hp, 4)
  lu.assertEquals(p3().hp, 3)
  lu.assertEquals(p1():usedSkillTimes(AY, Player.HistoryTurn), 1)

  -- 同一回合第二次受伤不再触发（每回合限一次，而非每伤害点一次）。
  FkTest.setNextReplies(p1(), { "" })
  inRoom(function() room:damage { from = p2(), to = p3(), damage = 1 } end)
  lu.assertEquals(p1():usedSkillTimes(AY, Player.HistoryTurn), 1)
  lu.assertEquals(p3().hp, 2)
end

function Testhanjin_han011:testAiwuTotalLessThanThreeDoesNotHeal()
  local room = FkTest.room
  setKingdom(room, p1(), "han")
  setKingdom(room, p3(), "han")
  local mine = setHand(room, p1(), { { "hanjin__slash", Card.Spade, 1 } })
  local theirs = setHand(room, p3(), { { "hanjin__jink", Card.Heart, 2 } })
  inRoom(function()
    p1().maxHp = 10
    p3().maxHp = 10
    p1().hp = 3
    p3().hp = 3
  end)

  FkTest.setNextReplies(p1(), {
    FkTest.ReplyDiscard({ mine[1] }),
  })
  FkTest.setNextReplies(p3(), { FkTest.ReplyDiscard({ theirs[1] }) })
  inRoom(function() room:damage { from = p2(), to = p3(), damage = 1 } end)

  lu.assertEquals(p1().hp, 3)
  lu.assertEquals(p3().hp, 2)
  lu.assertEquals(p1():usedSkillTimes(AY, Player.HistoryTurn), 1)
end

function Testhanjin_han011:testJuebieOtherSameKingdomGetsAllCardsBeforeBury()
  local room = FkTest.room
  setKingdom(room, p1(), "han")
  setKingdom(room, p3(), "han")
  setHand(room, p1(), {})
  local cards = setHand(room, p3(), {
    { "hanjin__slash", Card.Spade, 4 },
    { "hanjin__jink", Card.Heart, 5 },
  })
  local equip = addEquip(room, p3(), "jueying", Card.Club, 6)

  FkTest.setNextReplies(p3(), {
    "1",
    { OPT_CARDS },
    FkTest.ReplyChoosePlayer({ p1() }),
  })
  inRoom(function() room:killPlayer { who = p3(), killer = p2(), extra_data = { ignorePunishment = true } } end)

  lu.assertTrue(p3().dead)
  lu.assertEquals(p3():usedSkillTimes(JB, Player.HistoryGame), 0) -- 技能属于唐姬
  local hand = p1():getCardIds("h")
  lu.assertEquals(#hand, 3)
  for _, id in ipairs(cards) do lu.assertTrue(table.contains(hand, id)) end
  lu.assertTrue(table.contains(hand, equip))
  lu.assertEquals(room:getCardArea(equip), Card.PlayerHand)
end

function Testhanjin_han011:testJuebieOwnerDeathAlsoAppliesAndBeneficiaryDrawsThree()
  local room = FkTest.room
  setKingdom(room, p1(), "han")
  setKingdom(room, p2(), "han")
  setHand(room, p2(), {})
  setHand(room, p1(), { { "hanjin__slash", Card.Spade, 7 } })

  FkTest.setNextReplies(p1(), {
    "1",
    { OPT_DRAW },
    FkTest.ReplyChoosePlayer({ p2() }),
  })
  inRoom(function() room:killPlayer { who = p1(), killer = p2(), extra_data = { ignorePunishment = true } } end)

  lu.assertTrue(p1().dead)
  lu.assertEquals(#p2():getCardIds("h"), 3)
  -- 死亡角色的技能历史在死亡清理后不作为可观察断言；牌数已证明效果。
end

return { name = "hanjin_han011" }
