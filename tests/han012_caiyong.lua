-- HAN012 蔡邕：铸典、博通。默认国战套件用例（加入 tests/all.lua 后生效）。
-- 规则依据：rules/standard-generals.md 汉区、rulebook/events/use-card.md、
-- rulebook/terms/card-op-terms/recast.md、give.md。
local support = __dofile("../../../tests/support/hegemony.lua")

local ZD = "hanjin__skill_han012_1"
local BT = "hanjin__skill_han012_2"
local DEFAULT_KINGDOMS = { "han", "han", "wei", "wei", "shu", "shu", "wei", "han" }

Testhanjin_han012 = {}

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function p1() return FkTest.room.players[1] end
local function p2() return FkTest.room.players[2] end

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

--- Print cards and place them on top of the draw pile in the listed order.
local function seedDrawPile(room, specs)
  local ids = {}
  inRoom(function()
    for _, spec in ipairs(specs) do
      local card = room:printCard(spec[1], spec[2] or Card.Spade, spec[3] or 1)
      table.removeOne(room.draw_pile, card.id)
      table.insert(room.draw_pile, 1, card.id)
      room.card_place[card.id] = Card.DrawPile
      table.insert(ids, card.id)
    end
  end)
  return ids
end

local function installTestSkill(room, name, effects)
  local skel = fk.CreateSkill { name = name }
  for _, spec in ipairs(effects) do
    skel:addEffect(spec[1], spec[2])
  end
  local skill = skel:createSkill()
  Fk.skills[name] = skill
  inRoom(function() room:addSkill(skill) end)
end

local function runPlayPhase(room, player, replies)
  FkTest.setNextReplies(player, replies)
  inRoom(function()
    GameEvent.Turn:create(TurnData:new(player, "game_rule", { Player.Play })):exec()
  end)
end

local function useCard(room, from, tos, card)
  inRoom(function()
    room:useCard { from = from, tos = tos, card = card }
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
    room:changeHero(p1(), "hanjin__han012", true, false, false, false, false)
    room:setPlayerMark(p1(), "__heg_general", "hanjin__han012")
    for _, p in ipairs(room.players) do p.hp = p.maxHp end
  end)
  return room
end

local function prepare()
  return initializeGenerals(support.initHanjinRoom())
end

Testhanjin_han012.setup = function()
  prepare()
end
Testhanjin_han012.tearDown = support.clearRoom

function Testhanjin_han012:testZhudianBlackDrawRecastsEquipmentDespiteDiscardProhibition()
  local room = FkTest.room
  local hand = setHand(room, p1(), { { "hanjin__jink", Card.Spade, 9 } })
  local equip = addEquip(room, p1(), "jueying", Card.Spade, 5)
  -- 禁止弃置不影响重铸：这张装备仍应可被选择并置入弃牌堆。
  installTestSkill(room, "#han012_prohibit_equip_discard", {
    { "prohibit", {
      prohibit_discard = function(self, player, card)
        return card ~= nil and card.name == "jueying"
      end,
    } },
  })
  local drawn = seedDrawPile(room, {
    { "hanjin__slash", Card.Heart, 3 },  -- second draw (red)
    { "hanjin__slash", Card.Spade, 2 },  -- first draw (black)
  })

  local shown = {}
  installTestSkill(room, "#han012_show_probe", {
    { fk.CardShown, {
      global = true,
      can_refresh = function(self, event, target) return target == p1() end,
      on_refresh = function(self, event, target, player, data)
        table.insertTable(shown, data.cardIds or {})
      end,
    } },
  })

  FkTest.setNextReplies(p1(), {
    FkTest.ReplyChooseCards({ equip }),
    "1",
    "",
  })
  useCard(room, p2(), { p1() }, Fk:cloneCard("hanjin__slash", Card.Spade, 4))

  lu.assertEquals(room:getCardArea(equip), Card.DiscardPile)
  lu.assertEquals(#p1():getCardIds("e"), 0)
  lu.assertEquals(#p1():getCardIds("h"), 3) -- 原手牌 + 黑色 + 展示后再摸的红
  lu.assertEquals(p1():usedSkillTimes(ZD, Player.HistoryGame), 1)
  lu.assertTrue(table.contains(shown, drawn[2]))
  lu.assertFalse(table.contains(shown, drawn[1]))
  lu.assertTrue(table.contains(p1():getCardIds("h"), hand[1]))
end

function Testhanjin_han012:testZhudianRedDrawDoesNotRevealOrDrawAgain()
  local room = FkTest.room
  local ids = setHand(room, p1(), {
    { "hanjin__slash", Card.Spade, 9 },
    { "hanjin__jink", Card.Heart, 7 },
  })
  seedDrawPile(room, { { "hanjin__slash", Card.Heart, 3 } })

  local shown = {}
  installTestSkill(room, "#han012_show_probe_red", {
    { fk.CardShown, {
      global = true,
      can_refresh = function(self, event, target) return target == p1() end,
      on_refresh = function(self, event, target, player, data)
        table.insertTable(shown, data.cardIds or {})
      end,
    } },
  })

  FkTest.setNextReplies(p1(), {
    FkTest.ReplyChooseCards({ ids[1] }),
    "",
  })
  useCard(room, p2(), { p1() }, Fk:cloneCard("hanjin__slash", Card.Club, 5))

  lu.assertEquals(room:getCardArea(ids[1]), Card.DiscardPile)
  lu.assertEquals(#p1():getCardIds("h"), 2)
  lu.assertEquals(#shown, 0)
  lu.assertEquals(p1():usedSkillTimes(ZD, Player.HistoryGame), 1)
end

function Testhanjin_han012:testBotongFourSuitsAndGiveAfterUse()
  local room = FkTest.room
  setHand(room, p2(), {})
  local cards = setHand(room, p1(), {
    { "hanjin__slash", Card.Spade, 2 },
    { "hanjin__jink", Card.Heart, 3 },
    { "hanjin__slash", Card.Club, 4 },
    { "hanjin__slash", Card.Diamond, 5 },
  })
  local use = FkTest.ReplyUseSkill(BT, { p2() }, cards)
  use.interaction_data = "hanjin__slash"

  FkTest.setNextReplies(p2(), { "" })
  runPlayPhase(room, p1(), {
    use,
    "1",
    FkTest.ReplyChooseCardAndPlayers({ p2() }, cards),
    "",
  })
  lu.assertEquals(#p2():getCardIds("h"), 4)
  for _, id in ipairs(cards) do
    lu.assertTrue(table.contains(p2():getCardIds("h"), id))
  end
  lu.assertEquals(#p1():getCardIds("h"), 0)
end

function Testhanjin_han012:testBotongThreeCategoriesDiscardsWhenNotGiven()
  local room = FkTest.room
  setHand(room, p2(), {})
  local cards = setHand(room, p1(), {
    { "hanjin__slash", Card.Spade, 2 },
    { "hanjin__duel", Card.Heart, 3 },
    { "jueying", Card.Club, 4 },
  })
  local use = FkTest.ReplyUseSkill(BT, { p2() }, cards)
  use.interaction_data = "hanjin__slash"

  FkTest.setNextReplies(p1(), {
    use,
    "",
    "",
  })
  FkTest.setNextReplies(p2(), { "" })
  inRoom(function()
    GameEvent.Turn:create(TurnData:new(p1(), "game_rule", { Player.Play })):exec()
  end)

  for _, id in ipairs(cards) do
    lu.assertEquals(room:getCardArea(id), Card.DiscardPile)
  end
  lu.assertEquals(#p2():getCardIds("h"), 0)
end

return { name = "hanjin_han012" }
