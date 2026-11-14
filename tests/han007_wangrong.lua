-- HAN007 王荣：敏思、追德。默认国战套件用例（加入 tests/all.lua 后生效）。
-- 规则依据：rules/generals/han007-wangrong.md、rules/general-principles.md。
-- 验收依据：docs/development/implementation/generals/support.md#han007-1、damage.md#han007-2。
local support = __dofile("../../../tests/support/hegemony.lua")

local MS = "hanjin__skill_han007_1"
local ZD = "hanjin__skill_han007_2"
local MS_AUX = "#hanjin__skill_han007_1_aux"
local ZD_AUX = "#hanjin__skill_han007_2_aux"

local DEFAULT_KINGDOMS = { "han", "han", "wei", "wei", "shu", "shu", "wei", "han" }

Testhanjin_han007 = {}

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

--- Replace a player's hand and equipment with printed cards.
--- specs: { { cardName, suit?, number? }, ... }
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

--- Print cards and place them on top of the draw pile. Returned ids are the
--- cards that will be drawn, regardless of their relative order.
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

local function grant(player, skillName)
  inRoom(function()
    player.room:handleAddLoseSkills(player, skillName, nil, false, true)
  end)
end

local function runPlayPhase(room, player, replies)
  FkTest.setNextReplies(player, replies)
  inRoom(function()
    GameEvent.Turn:create(TurnData:new(player, "game_rule", { Player.Play })):exec()
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
    room:changeHero(p1(), "hanjin__han007", true, false, false, false, false)
    room:setPlayerMark(p1(), "__heg_general", "hanjin__han007")
    for _, p in ipairs(room.players) do p.hp = p.maxHp end
  end)
  return room
end

local function prepare()
  return initializeGenerals(support.initHanjinRoom())
end

Testhanjin_han007.setup = function()
  prepare()
end
Testhanjin_han007.tearDown = support.clearRoom

function Testhanjin_han007:testMinsiDiscardsHandSum13DrawsTwiceShowsAndLimitsPhase()
  local room = FkTest.room
  local ids = setHand(room, p1(), {
    { "hanjin__slash", Card.Spade, 1 },   -- A = 1
    { "hanjin__jink", Card.Heart, 12 },   -- Q = 12
    { "hanjin__peach", Card.Heart, 7 },   -- kept; not part of this draw
  })
  local drawn = seedDrawPile(room, {
    { "hanjin__slash", Card.Spade, 2 },
    { "hanjin__slash", Card.Spade, 3 },
    { "hanjin__slash", Card.Spade, 4 },
    { "hanjin__slash", Card.Spade, 6 },
  })

  local shown = {}
  installTestSkill(room, "#han007_show_probe", {
    { fk.CardShown, {
      global = true,
      can_refresh = function(self, event, target, player)
        return target == p1() and player == p1()
      end,
      on_refresh = function(self, event, target, player, data)
        table.insertTable(shown, data.cardIds or {})
      end,
    } },
  })

  local canUseDuringPhase = {}
  installTestSkill(room, "#han007_phase_probe", {
    { fk.BeforePlayCard, {
      global = true,
      can_refresh = function(self, event, target, player)
        return target == p1() and player == p1()
      end,
      on_refresh = function()
        table.insert(canUseDuringPhase, Fk.skills[MS]:canUse(p1()))
      end,
    } },
  })

  runPlayPhase(room, p1(), {
    FkTest.ReplyUseSkill(MS, {}, { ids[1], ids[2] }),
    "",
  })

  -- 弃 1+12，摸 2*2=4；原先保留的红桃 7 仍在手中。
  lu.assertEquals(#p1():getCardIds("h"), 5)
  lu.assertEquals(room:getCardArea(ids[1]), Card.DiscardPile)
  lu.assertEquals(room:getCardArea(ids[2]), Card.DiscardPile)
  lu.assertEquals(room:getCardArea(ids[3]), Card.PlayerHand)
  lu.assertEquals(#shown, 4)
  for _, id in ipairs(drawn) do lu.assertTrue(table.contains(shown, id)) end
  lu.assertEquals(p1():usedSkillTimes(MS, Player.HistoryGame), 1)

  -- 出牌阶段限一次：首次可用，本次发动后同一阶段不再可用。
  lu.assertIs(canUseDuringPhase[1], true)
  lu.assertIs(canUseDuringPhase[2], false)
end

function Testhanjin_han007:testMinsiAllowsHandAndEquipmentCards()
  local room = FkTest.room
  local hand = setHand(room, p1(), { { "hanjin__slash", Card.Spade, 8 } })
  local equip = addEquip(room, p1(), "jueying", Card.Spade, 5)
  seedDrawPile(room, {
    { "hanjin__slash", Card.Spade, 2 },
    { "hanjin__slash", Card.Spade, 3 },
    { "hanjin__slash", Card.Spade, 4 },
    { "hanjin__slash", Card.Spade, 6 },
  })

  runPlayPhase(room, p1(), {
    FkTest.ReplyUseSkill(MS, {}, { hand[1], equip }),
    "",
  })

  lu.assertEquals(room:getCardArea(hand[1]), Card.DiscardPile)
  lu.assertEquals(room:getCardArea(equip), Card.DiscardPile)
  lu.assertEquals(#p1():getCardIds("e"), 0)
  lu.assertEquals(#p1():getCardIds("h"), 4)
  lu.assertEquals(p1():usedSkillTimes(MS, Player.HistoryGame), 1)
end

function Testhanjin_han007:testMinsiDrawnHeartsDoNotCountForHandLimit()
  local room = FkTest.room
  p1().hp = 1
  local ids = setHand(room, p1(), {
    { "hanjin__slash", Card.Spade, 1 },   -- A, cost
    { "hanjin__jink", Card.Heart, 12 },   -- Q, cost
    { "hanjin__peach", Card.Heart, 7 },   -- old heart, must still count
  })
  local drawnHearts = seedDrawPile(room, {
    { "hanjin__jink", Card.Heart, 2 },
    { "hanjin__jink", Card.Heart, 3 },
  })
  local drawnSpades = seedDrawPile(room, {
    { "hanjin__slash", Card.Spade, 4 },
    { "hanjin__slash", Card.Spade, 6 },
  })

  local captured
  local original = room.askToDiscard
  room.askToDiscard = function(self, player, params)
    if params.skill_name == "phase_discard" then
      captured = { min_num = params.min_num, max_num = params.max_num }
    end
    return original(self, player, params)
  end

  -- 手中 5 张、其中此次摸到的 2 张红桃不计，故弃 5-2-maxCards 张。
  local expectedDiscard = math.max(0, 5 - 2 - p1():getMaxCards())
  FkTest.setNextReplies(p1(), {
    FkTest.ReplyUseSkill(MS, {}, { ids[1], ids[2] }),
    "",
    FkTest.ReplyDiscard({ drawnSpades[1], drawnSpades[2] }),
  })
  inRoom(function()
    GameEvent.Turn:create(TurnData:new(p1(), "game_rule",
      { Player.Play, Player.Discard })):exec()
  end)
  room.askToDiscard = original

  lu.assertTrue(captured ~= nil)
  lu.assertEquals(captured.max_num, expectedDiscard)
  lu.assertEquals(captured.min_num, expectedDiscard)
  local hand = p1():getCardIds("h")
  lu.assertEquals(#hand, 5 - expectedDiscard)
  lu.assertTrue(table.contains(hand, ids[3]))
  for _, id in ipairs(drawnHearts) do lu.assertTrue(table.contains(hand, id)) end
end

function Testhanjin_han007:testZhuideGivesHeartsDrawsAndExtraMinsiNeedsCombination()
  local room = FkTest.room
  local hearts = setHand(room, p1(), {
    { "hanjin__jink", Card.Heart, 1 },
    { "hanjin__peach", Card.Heart, 1 },
    { "hanjin__slash", Card.Spade, 9 },
  })
  setHand(room, p2(), {})
  local drawn = seedDrawPile(room, {
    { "hanjin__slash", Card.Spade, 2 },
    { "hanjin__slash", Card.Spade, 2 },
  })
  local shown = {}
  installTestSkill(room, "#han007_zhuide_show_probe", {
    { fk.CardShown, {
      global = true,
      can_refresh = function(self, event, target, player)
        return target == p1() and player == p1()
      end,
      on_refresh = function(self, event, target, player, data)
        table.insertTable(shown, data.cardIds or {})
      end,
    } },
  })

  FkTest.setNextReplies(p1(), {
    "1",
    FkTest.ReplyUseSkill(ZD_AUX, { p2() }, { hearts[1], hearts[2] }),
  })
  -- 用异势力凶手，避免国战奖惩清空受赠者手牌。
  inRoom(function()
    p2().kingdom = "wei"
    room:setPlayerProperty(p2(), "kingdom", "wei")
    room:killPlayer { who = p1(), killer = p2(), extra_data = { ignorePunishment = true } }
  end)

  lu.assertTrue(p1().dead)
  -- 先展示，再交给；两张红桃都在展示记录中。
  lu.assertEquals(#shown, 2)
  for _, id in ipairs({ hearts[1], hearts[2] }) do
    lu.assertTrue(table.contains(shown, id))
  end
  -- 两张红桃交给 p2，等量摸两张；合计最多 6 点，不能发动敏思。
  local p2Hand = p2():getCardIds("h")
  lu.assertEquals(#p2Hand, 4)
  for _, id in ipairs({ hearts[1], hearts[2] }) do
    lu.assertTrue(table.contains(p2Hand, id))
  end
  for _, id in ipairs(drawn) do lu.assertTrue(table.contains(p2Hand, id)) end
  lu.assertEquals(p2():usedSkillTimes(MS, Player.HistoryGame), 0)

  -- 未交出的非红桃牌随死亡清理进入弃牌堆。
  lu.assertEquals(room:getCardArea(hearts[3]), Card.DiscardPile)
end

function Testhanjin_han007:testZhuideHiddenGeneralAllowsExtraMinsiAndKeepsPhaseLimit()
  local room = FkTest.room
  local hearts = setHand(room, p1(), {
    { "hanjin__slash", Card.Heart, 13 },  -- K of hearts
    { "hanjin__jink", Card.Spade, 9 },
  })
  setHand(room, p2(), {})
  grant(p2(), MS)
  -- 模拟受赠者本出牌阶段已经用过普通敏思：额外发动仍应发生，且不增加次数。
  inRoom(function() p2():addSkillUseHistory(MS, 1) end)
  lu.assertEquals(p2():usedSkillTimes(MS, Player.HistoryPhase), 1)

  local firstDraw = seedDrawPile(room, { { "hanjin__slash", Card.Spade, 2 } })
  local extraDraw = seedDrawPile(room, {
    { "hanjin__slash", Card.Spade, 3 },
    { "hanjin__slash", Card.Spade, 4 },
  })

  -- 主将暗置：死亡流程先由国战公共时机翻开武将，追德仍应触发。
  inRoom(function() p1():hideGeneral(false) end)
  lu.assertEquals(p1().general, "anjiang")

  FkTest.setNextReplies(p1(), {
    "1",
    FkTest.ReplyUseSkill(ZD_AUX, { p2() }, { hearts[1] }),
  })
  FkTest.setNextReplies(p2(), {
    FkTest.ReplyUseSkill(MS_AUX, {}, { hearts[1] }),
  })
  -- 用异势力凶手，避免国战奖惩清空受赠者手牌。
  inRoom(function()
    p2().kingdom = "wei"
    room:setPlayerProperty(p2(), "kingdom", "wei")
    room:killPlayer { who = p1(), killer = p2(), extra_data = { ignorePunishment = true } }
  end)

  lu.assertEquals(p1().general, "hanjin__han007")
  lu.assertTrue(p1().dead)
  -- 受赠者摸 1 张后以刚得到的红桃 K 额外发动敏思：弃 K，摸 2。
  lu.assertEquals(room:getCardArea(hearts[1]), Card.DiscardPile)
  local p2Hand = p2():getCardIds("h")
  lu.assertEquals(#p2Hand, 3)
  for _, id in ipairs({ firstDraw[1], extraDraw[1], extraDraw[2] }) do
    lu.assertTrue(table.contains(p2Hand, id))
  end
  -- 额外发动不占用、也不增加普通敏思的出牌阶段次数。
  lu.assertEquals(p2():usedSkillTimes(MS, Player.HistoryPhase), 1)
  lu.assertEquals(p2():usedSkillTimes(MS, Player.HistoryGame), 1)
end

return { name = "hanjin_han007" }
