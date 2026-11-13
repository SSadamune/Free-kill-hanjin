-- HAN001 刘协：天命、密诏。默认国战套件用例。
-- 规则依据：rules/generals/han001-liuxie.md 第 2、3 节。
-- 验收依据：docs/development/implementation/generals/han001-liuxie.md。
local support = __dofile("../../../tests/support/hegemony.lua")

local TM = "hanjin__skill_han001_1"
local MZ = "hanjin__skill_han001_2"
local probeSerial = 0

local DEFAULT_KINGDOMS = { "han", "han", "wei", "wei", "shu", "shu", "wei", "han" }

Testhanjin_han001 = {}

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function setKingdom(room, player, kingdom)
  inRoom(function()
    player.kingdom = kingdom
    room:setPlayerProperty(player, "kingdom", kingdom)
    room:setPlayerMark(player, "__heg_kingdom", kingdom)
  end)
end

local function setUnknown(room, player)
  inRoom(function()
    player.kingdom = "unknown"
    room:setPlayerProperty(player, "kingdom", "unknown")
    room:setPlayerMark(player, "__heg_kingdom", nil)
    room:setPlayerMark(player, "__heg_wild", 0)
  end)
end

local function setWild(room, player)
  inRoom(function()
    player.kingdom = "wild"
    room:setPlayerProperty(player, "kingdom", "wild")
    room:setPlayerMark(player, "__heg_wild", 1)
  end)
end

local function setDead(room, player)
  inRoom(function()
    player.dead = true
    room:setPlayerProperty(player, "dead", true)
    table.removeOne(room.alive_players, player)
  end)
end

local function clearCards(room, player, area)
  local ids = player:getCardIds(area or "he")
  if #ids > 0 then
    inRoom(function()
      room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false)
    end)
  end
end

--- Replace a player's hand (and optionally equipment) with printed cards.
--- specs: { { cardName, suit?, number? }, ... }
local function setHand(room, player, specs, area)
  clearCards(room, player, area or "he")
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

local function addHand(room, player, specs)
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

local function addEquip(room, player, name, suit, number)
  local id
  inRoom(function()
    local card = room:printCard(name, suit or Card.Spade, number or 1)
    room:moveCardTo(card, Card.PlayerEquip, player, fk.ReasonJustMove, "test", nil, false)
    id = card.id
  end)
  return id
end

local function installMoveProbe(room, player, records)
  probeSerial = probeSerial + 1
  local name = "#hanjin_han001_move_probe_" .. probeSerial
  local skel = fk.CreateSkill { name = name }
  skel:addEffect(fk.AfterCardsMove, {
    global = true,
    can_refresh = function(self, event, target, owner)
      return owner == room.players[1]
    end,
    on_refresh = function(self, event, target, owner, data)
      for _, move in ipairs(data) do
        if move.toArea == Card.DiscardPile and move.from == player then
          table.insert(records, { "discard", #move.moveInfo })
        elseif move.toArea == Card.PlayerHand and move.to == player
          and move.moveReason == fk.ReasonDraw then
          table.insert(records, { "draw", #move.moveInfo })
        end
      end
    end,
  })
  local skill = skel:createSkill()
  Fk.skills[name] = skill
  inRoom(function() room:addSkill(skill) end)
end

local function installUseProbe(room, uses)
  local skel = fk.CreateSkill { name = "#hanjin_han001_use_probe" }
  skel:addEffect(fk.CardUsing, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return target == player and data.card ~= nil and data.card.trueName == "slash"
    end,
    on_refresh = function(self, event, target, player, data)
      table.insert(uses, {
        from = data.from,
        tos = table.simpleClone(data.tos or {}),
        card = data.card,
        extraUse = data.extraUse == true,
        use = data,
      })
    end,
  })
  skel:addEffect(fk.CardUseFinished, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return target == player and data.card ~= nil and data.card.trueName == "slash"
    end,
    on_refresh = function(self, event, target, player, data)
      for _, use in ipairs(uses) do
        if use.use == data then use.finished = (use.finished or 0) + 1 end
      end
    end,
  })
  inRoom(function() room:addSkill(skel:createSkill()) end)
end

local function installDamageProbe(room, damages)
  local skel = fk.CreateSkill { name = "#hanjin_han001_damage_probe" }
  skel:addEffect(fk.Damage, {
    global = true,
    can_refresh = function(self, event, target, player)
      return target == player
    end,
    on_refresh = function(self, event, target, player, data)
      table.insert(damages, { from = data.from, to = data.to, damage = data.damage })
    end,
  })
  inRoom(function() room:addSkill(skel:createSkill()) end)
end

local function installPindianProbe(room, log)
  probeSerial = probeSerial + 1
  local name = "#hanjin_han001_pindian_probe_" .. probeSerial
  local skel = fk.CreateSkill { name = name }
  skel:addEffect(fk.PindianFinished, {
    global = true,
    can_refresh = function(self, event, target, owner, data)
      return owner == room.players[1] and data.reason == MZ
    end,
    on_refresh = function(self, event, target, owner, data)
      table.insert(log, {
        from = data.from,
        tos = table.simpleClone(data.tos or {}),
        reason = data.reason,
        fromCard = data.fromCard,
        results = data.results,
      })
    end,
  })
  local skill = skel:createSkill()
  Fk.skills[name] = skill
  inRoom(function() room:addSkill(skill) end)
end

local function useSlash(room, from, to, name)
  inRoom(function()
    room:useCard {
      from = from,
      tos = { to },
      card = Fk:cloneCard(name or "hanjin__slash"),
    }
  end)
end

local function putOnDrawPile(room, card)
  inRoom(function()
    table.removeOne(room.draw_pile, card.id)
    table.insert(room.draw_pile, 1, card.id)
    room.card_place[card.id] = Card.DrawPile
  end)
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

local function installTestSkill(room, name, effects)
  local skel = fk.CreateSkill { name = name }
  for _, spec in ipairs(effects) do
    skel:addEffect(spec[1], spec[2])
  end
  local skill = skel:createSkill()
  Fk.skills[name] = skill
  inRoom(function() room:addSkill(skill) end)
end

local function activateSecret(room, player, to, cards)
  inRoom(function()
    room:handleUseCardReply(player, FkTest.ReplyUseSkill(MZ, { to }, cards))
  end)
end

local function secretMinimum(player)
  return Fk.skills[MZ]:getMinCardNum(player)
end

--- 构造真实的 ClientPlayer 形态（没有 room 字段），并临时让 Fk:currentRoom()
--- 返回客户端房间，用于覆盖客户端可用性、下限与提示计算。服务端房间对象
--- 通过元表提供客户端未单独同步的公共字段，players/alive_players 使用客户端副本。
local function asClient(room, fn)
  local ClientPlayer = require "ltk.client.clientplayer"
  local clients = {}
  for _, original in ipairs(room.players) do
    local copy = ClientPlayer:new(original._splayer)
    for key, value in pairs(original) do
      if key ~= "room" and key ~= "class" and key ~= "serverplayer" then copy[key] = value end
    end
    table.insert(clients, copy)
  end
  for index, player in ipairs(clients) do player.next = clients[index % #clients + 1] end
  local clientRoom = setmetatable(
    { players = clients, alive_players = clients, current = clients[1] },
    { __index = room })
  local originalRoom = Fk.currentRoom
  Fk.currentRoom = function() return clientRoom end
  local ok, err = pcall(fn, clients, clientRoom)
  Fk.currentRoom = originalRoom
  if not ok then error(err) end
end

local function initializeGenerals(room)
  inRoom(function()
    for i, p in ipairs(room.players) do
      local kingdom = DEFAULT_KINGDOMS[i]
      -- changeHero 只按当前可见将面移除技能；直接替换 anjiang 会留下
      -- 原暗将的 fake skill，使明将天命被当成暗将技能再次询问发动。
      -- 先通过引擎明置接口清理原来源，再安装本用例的已知双将。
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
    room:changeHero(room.players[1], "hanjin__han001", true, false, false, false, false)
    room:setPlayerMark(room.players[1], "__heg_general", "hanjin__han001")
    for _, p in ipairs(room.players) do p.hp = p.maxHp end
  end)
  return room
end

local function prepare()
  return initializeGenerals(support.initHanjinRoom())
end

Testhanjin_han001.setup = function()
  prepare()
end
Testhanjin_han001.tearDown = support.clearRoom

local function p1() return FkTest.room.players[1] end
local function p2() return FkTest.room.players[2] end
local function p3() return FkTest.room.players[3] end
local function p4() return FkTest.room.players[4] end
local function p5() return FkTest.room.players[5] end
local function p6() return FkTest.room.players[6] end
local function p7() return FkTest.room.players[7] end
local function p8() return FkTest.room.players[8] end

function Testhanjin_han001:testFixtureClearsHiddenSkillsBeforeInstallingKnownGenerals()
  local room = FkTest.room
  inRoom(function()
    p1():hideGeneral(false)
    p1():prelightSkill(Fk.skills[TM], true)
    room:setPlayerMark(p1(), "__heg_wild", 1)
  end)
  lu.assertTrue(p1():isFakeSkill(TM))
  initializeGenerals(room)
  lu.assertFalse(p1():isFakeSkill(TM))
  lu.assertEquals(p1():getMark("__heg_wild"), 0)
  local ids = setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" } })
  setHand(room, p3(), { { "hanjin__slash" } })
  FkTest.setNextReplies(p1(), { "1", "" })
  useSlash(room, p3(), p1())
  lu.assertEquals(p1():usedSkillTimes(TM, Player.HistoryGame), 1)
  for _, id in ipairs(ids) do lu.assertEquals(room:getCardArea(id), Card.DiscardPile) end
  lu.assertEquals(#p1():getCardIds("h"), 2)
end

function Testhanjin_han001:testTM01DiscardTwoThenDrawTwo()
  local room = FkTest.room
  local ids = setHand(room, p1(), {
    { "hanjin__slash" }, { "hanjin__jink" }, { "hanjin__peach" },
  })
  setHand(room, p3(), { { "hanjin__slash" } })
  local records = {}
  installMoveProbe(room, p1(), records)
  FkTest.setNextReplies(p1(), { "1", FkTest.ReplyDiscard({ ids[1], ids[2] }), "" })
  useSlash(room, p3(), p1())
  lu.assertEquals(#p1():getCardIds("h"), 3)
  lu.assertEquals(records[1][1], "discard")
  lu.assertEquals(records[1][2], 2)
  lu.assertTrue(table.find(records, function(r) return r[1] == "draw" and r[2] == 2 end) ~= nil)
end

function Testhanjin_han001:testTM02ExactlyTwoHandCards()
  local room = FkTest.room
  local ids = setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" } })
  setHand(room, p3(), { { "hanjin__slash" } })
  FkTest.setNextReplies(p1(), { "1", "" })
  useSlash(room, p3(), p1())
  lu.assertEquals(#p1():getCardIds("h"), 2)
  for _, id in ipairs(ids) do
    lu.assertEquals(room:getCardArea(id), Card.DiscardPile)
  end
end

function Testhanjin_han001:testTM03OneHandCardAndEquipment()
  local room = FkTest.room
  local hand = setHand(room, p1(), { { "hanjin__slash" } })
  local equip = addEquip(room, p1(), "jueying")
  setHand(room, p3(), { { "hanjin__slash" } })
  FkTest.setNextReplies(p1(), { "1", "" })
  useSlash(room, p3(), p1())
  lu.assertEquals(room:getCardArea(hand[1]), Card.DiscardPile)
  lu.assertEquals(room:getCardArea(equip), Card.PlayerEquip)
  lu.assertEquals(#p1():getCardIds("h"), 2)
end

function Testhanjin_han001:testTM04NoHandCardsStillDraws()
  local room = FkTest.room
  setHand(room, p1(), {})
  local equip = addEquip(room, p1(), "jueying")
  setHand(room, p3(), { { "hanjin__slash" } })
  FkTest.setNextReplies(p1(), { "1", "" })
  useSlash(room, p3(), p1())
  lu.assertEquals(#p1():getCardIds("h"), 2)
  lu.assertEquals(room:getCardArea(equip), Card.PlayerEquip)

  clearCards(room, p1(), "e")
  setHand(room, p1(), {})
  setHand(room, p3(), { { "hanjin__slash" } })
  FkTest.setNextReplies(p1(), { "1", "" })
  useSlash(room, p3(), p1())
  lu.assertEquals(#p1():getCardIds("h"), 2)
end

function Testhanjin_han001:testTM05DeclineDoesNothing()
  local room = FkTest.room
  local hand = setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" } })
  setHand(room, p3(), { { "hanjin__slash" } })
  FkTest.setNextReplies(p1(), { "", "" })
  useSlash(room, p3(), p1())
  lu.assertEquals(p1():getCardIds("h"), hand)
  lu.assertEquals(p1():usedSkillTimes(TM, Player.HistoryGame), 0)

  setHand(room, p1(), {})
  setHand(room, p3(), { { "hanjin__slash" } })
  FkTest.setNextReplies(p1(), { "", "" })
  useSlash(room, p3(), p1())
  lu.assertEquals(#p1():getCardIds("h"), 0)
  lu.assertEquals(p1():usedSkillTimes(TM, Player.HistoryGame), 0)
end

function Testhanjin_han001:testTM06AllSlashCategoriesTriggerButOtherCardsDoNot()
  local room = FkTest.room
  p1().hp = 20
  local count = 0
  for _, name in ipairs({ "hanjin__slash", "hanjin__fire__slash", "hanjin__thunder__slash" }) do
    local ids = setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" } })
    setHand(room, p3(), { { "hanjin__slash" } })
    FkTest.setNextReplies(p1(), { "1", "" })
    useSlash(room, p3(), p1(), name)
    count = count + 1
    lu.assertEquals(p1():usedSkillTimes(TM, Player.HistoryGame), count)
  end

  -- 转化/虚拟牌仍以 trueName 识别；上面的 clone 已经是无实体子牌的虚拟杀。
  local before = p1():usedSkillTimes(TM, Player.HistoryGame)
  setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" } })
  inRoom(function()
    room:useCard { from = p1(), tos = { p1() }, card = Fk:cloneCard("hanjin__peach") }
  end)
  lu.assertEquals(p1():usedSkillTimes(TM, Player.HistoryGame), before)
end

function Testhanjin_han001:testTM07EachTargetEventOnceAndNoTurnLimit()
  local room = FkTest.room
  local ids = setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" } })
  setHand(room, p2(), {})
  FkTest.setNextReplies(p1(), { "1", "" })
  FkTest.setNextReplies(p2(), { "" })
  inRoom(function()
    room:useCard {
      from = p3(),
      tos = { p1(), p2() },
      card = Fk:cloneCard("hanjin__slash"),
    }
  end)
  lu.assertEquals(p1():usedSkillTimes(TM, Player.HistoryGame), 1)

  ids = setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" } })
  setHand(room, p3(), { { "hanjin__slash" } })
  FkTest.setNextReplies(p1(), { "1", "" })
  useSlash(room, p3(), p1())
  lu.assertEquals(p1():usedSkillTimes(TM, Player.HistoryGame), 2)
end

function Testhanjin_han001:testTM08aRemovedBeforeTargetConfirmed()
  local room = FkTest.room
  installTestSkill(room, "#hanjin_han001_cancel_before", {
    { fk.TargetConfirming, {
      global = true,
      can_refresh = function(self, event, target) return target == p1() end,
      on_refresh = function(self, event, target) event.data:cancelTarget(target) end,
    } },
  })
  local hand = setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" } })
  setHand(room, p3(), { { "hanjin__slash" } })
  useSlash(room, p3(), p1())
  lu.assertEquals(p1():usedSkillTimes(TM, Player.HistoryGame), 0)
  lu.assertEquals(p1():getCardIds("h"), hand)
end

function Testhanjin_han001:testTM08bCancelledAfterTriggerKeepsResult()
  local room = FkTest.room
  installTestSkill(room, "#hanjin_han001_cancel_after", {
    { fk.TargetConfirmed, {
      global = true,
      priority = -100,
      can_refresh = function(self, event, target) return target == p1() end,
      on_refresh = function(self, event, target) event.data:cancelTarget(target) end,
    } },
  })
  local ids = setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" } })
  setHand(room, p3(), { { "hanjin__slash" } })
  FkTest.setNextReplies(p1(), { "1", "" })
  useSlash(room, p3(), p1())
  lu.assertEquals(p1():usedSkillTimes(TM, Player.HistoryGame), 1)
  lu.assertEquals(#p1():getCardIds("h"), 2)
end

function Testhanjin_han001:testTM09DrawHappensBeforeResponse()
  local room = FkTest.room
  local ids = setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" } })
  local jink = inRoom(function() return room:printCard("jink", Card.Heart, 1) end)
  putOnDrawPile(room, jink)
  setHand(room, p3(), { { "hanjin__slash" } })
  FkTest.setNextReplies(p1(), {
    "1",
    FkTest.ReplyCard(jink),
  })
  local hp = p1().hp
  useSlash(room, p3(), p1())
  lu.assertEquals(p1().hp, hp)
  lu.assertTrue(room:getCardArea(jink.id) ~= Card.DrawPile)
end

function Testhanjin_han001:testTM10ExtraSettlementDoesNotRepeatTargetEvent()
  local room = FkTest.room
  installTestSkill(room, "#hanjin_han001_repeat_settlement", {
    { fk.CardUsing, {
      global = true,
      can_refresh = function(self, event, target, player, data)
        return target == player and data.card.trueName == "slash"
      end,
      on_refresh = function(self, event, target, player, data)
        data.additionalEffect = (data.additionalEffect or 0) + 1
      end,
    } },
  })
  local confirmed = 0
  installTestSkill(room, "#hanjin_han001_confirmed_count", {
    { fk.TargetConfirmed, {
      global = true,
      can_refresh = function(self, event, target, player)
        return target == p1() and player == room.players[1]
      end,
      on_refresh = function() confirmed = confirmed + 1 end,
    } },
  })
  local ids = setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" } })
  setHand(room, p3(), { { "hanjin__slash" } })
  FkTest.setNextReplies(p1(), { "1", "" })
  useSlash(room, p3(), p1())
  lu.assertEquals(confirmed, 1)
  lu.assertEquals(p1():usedSkillTimes(TM, Player.HistoryGame), 1)
  lu.assertEquals(#p1():getCardIds("h"), 2)
end

function Testhanjin_han001:testTM11ShortDiscardAndZeroDiscard()
  local room = FkTest.room
  p1().hp = 20
  installTestSkill(room, "#hanjin_han001_prohibit_peach", {
    { "prohibit", {
      prohibit_discard = function(self, player, card) return card.name == "hanjin__peach" end,
    } },
  })
  local ids = setHand(room, p1(), {
    { "hanjin__peach" }, { "hanjin__peach" }, { "hanjin__slash" },
  })
  local equip = addEquip(room, p1(), "jueying")
  setHand(room, p3(), { { "hanjin__slash" } })
  FkTest.setNextReplies(p1(), { "1", "" })
  useSlash(room, p3(), p1())
  inRoom(function() p1().hp = p1().maxHp end)
  lu.assertEquals(room:getCardArea(ids[3]), Card.DiscardPile)
  lu.assertEquals(room:getCardArea(ids[1]), Card.PlayerHand)
  lu.assertEquals(room:getCardArea(ids[2]), Card.PlayerHand)
  lu.assertEquals(room:getCardArea(equip), Card.PlayerEquip)
  lu.assertEquals(p1():usedSkillTimes(TM, Player.HistoryGame), 1)

  ids = setHand(room, p1(), { { "hanjin__peach" } })
  setHand(room, p3(), { { "hanjin__slash" } })
  FkTest.setNextReplies(p1(), { "1", "" })
  useSlash(room, p3(), p1())
  inRoom(function() p1().hp = p1().maxHp end)
  lu.assertEquals(room:getCardArea(ids[1]), Card.PlayerHand)
  lu.assertEquals(p1():usedSkillTimes(TM, Player.HistoryGame), 2)

  ids = setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" } })
  setHand(room, p3(), { { "hanjin__slash" } })
  inRoom(function() p1().hp = p1().maxHp end)
  FkTest.setNextReplies(p1(), { "1", "" })
  useSlash(room, p3(), p1())
  for _, id in ipairs(ids) do lu.assertEquals(room:getCardArea(id), Card.DiscardPile) end
  lu.assertFalse(p1().dead)
  lu.assertEquals(p1():usedSkillTimes(TM, Player.HistoryGame), 3)
end

function Testhanjin_han001:testTM12DiscardChainResolvesBeforeDraw()
  local room = FkTest.room
  local extra = inRoom(function() return room:printCard("hanjin__jink", Card.Heart, 2) end)
  local done = false
  local ids = setHand(room, p1(), {
    { "hanjin__slash" }, { "hanjin__jink" }, { "hanjin__peach" },
  })
  installTestSkill(room, "#hanjin_han001_discard_chain", {
    { fk.AfterCardsMove, {
      global = true,
      can_refresh = function(self, event, target, owner, data)
        if done or owner ~= room.players[1] then return false end
        for _, move in ipairs(data) do
          if move.from == p1() and move.toArea == Card.DiscardPile then return true end
        end
        return false
      end,
      on_refresh = function(self, event, target, owner, data)
        done = true
        room:obtainCard(p1(), extra, false, fk.ReasonJustMove)
      end,
    } },
  })
  setHand(room, p3(), { { "hanjin__slash" } })
  FkTest.setNextReplies(p1(), { "1", FkTest.ReplyDiscard({ ids[1], ids[2] }), "" })
  useSlash(room, p3(), p1())
  lu.assertEquals(#p1():getCardIds("h"), 4)
  lu.assertEquals(room:getCardArea(extra.id), Card.PlayerHand)
end

function Testhanjin_han001:testTM13DeathInDiscardChainStopsDraw()
  local room = FkTest.room
  local ids = setHand(room, p1(), {
    { "hanjin__slash" }, { "hanjin__jink" }, { "hanjin__peach" },
  })
  installTestSkill(room, "#hanjin_han001_discard_death", {
    { fk.AfterCardsMove, {
      global = true,
      can_refresh = function(self, event, target, owner, data)
        for _, move in ipairs(data) do
          if move.from == p1() and move.toArea == Card.DiscardPile then return owner == room.players[1] end
        end
        return false
      end,
      on_refresh = function(self, event, target, owner, data)
        p1().dead = true
        table.removeOne(room.alive_players, p1())
      end,
    } },
  })
  setHand(room, p3(), { { "hanjin__slash" } })
  FkTest.setNextReplies(p1(), { "1", FkTest.ReplyDiscard({ ids[1], ids[2] }) })
  useSlash(room, p3(), p1())
  lu.assertTrue(p1().dead)
  lu.assertEquals(#p1():getCardIds("h"), 1)
end

function Testhanjin_han001:testTM14IllegalPaymentsAreNormalized()
  local room = FkTest.room
  inRoom(function() p1().hp = p1().maxHp end)
  -- 只交 1 张：服务端补足到 2。
  local ids = setHand(room, p1(), {
    { "hanjin__slash" }, { "hanjin__jink" }, { "hanjin__peach" },
  })
  setHand(room, p3(), { { "hanjin__slash" } })
  FkTest.setNextReplies(p1(), { "1", FkTest.ReplyDiscard({ ids[1] }), "" })
  useSlash(room, p3(), p1())
  inRoom(function() p1().hp = p1().maxHp end)
  lu.assertEquals(#table.filter(ids, function(id) return room:getCardArea(id) == Card.DiscardPile end), 2)
  lu.assertEquals(#p1():getCardIds("h"), 3)

  -- 交 3 张：服务端截断到 2。
  ids = setHand(room, p1(), {
    { "hanjin__slash" }, { "hanjin__jink" }, { "hanjin__peach" },
  })
  setHand(room, p3(), { { "hanjin__slash" } })
  FkTest.setNextReplies(p1(), { "1", FkTest.ReplyDiscard({ ids[1], ids[2], ids[3] }), "" })
  useSlash(room, p3(), p1())
  inRoom(function() p1().hp = p1().maxHp end)
  local discarded = table.filter(ids, function(id) return room:getCardArea(id) == Card.DiscardPile end)
  lu.assertEquals(#discarded, 2)

  -- 装备牌不能补足，也不能被弃置。
  ids = setHand(room, p1(), {
    { "hanjin__slash" }, { "hanjin__jink" }, { "hanjin__peach" },
  })
  local equip = addEquip(room, p1(), "jueying")
  lu.assertEquals(room:getCardArea(equip), Card.PlayerEquip)
  setHand(room, p3(), { { "hanjin__slash" } })
  FkTest.setNextReplies(p1(), {
    "1", FkTest.ReplyDiscard({ equip, ids[1] }), "",
  })
  useSlash(room, p3(), p1())
  inRoom(function() p1().hp = p1().maxHp end)
  lu.assertEquals(room:getCardArea(equip), Card.PlayerEquip)
  discarded = table.filter(ids, function(id) return room:getCardArea(id) == Card.DiscardPile end)
  lu.assertEquals(#discarded, 2)

  -- 仍属于他人的牌不能作为自己的弃牌。
  ids = setHand(room, p1(), {
    { "hanjin__slash" }, { "hanjin__jink" }, { "hanjin__peach" },
  })
  local other = addHand(room, p2(), { { "hanjin__slash" } })[1]
  setHand(room, p3(), { { "hanjin__slash" } })
  for _, id in ipairs(ids) do
    lu.assertEquals(room:getCardArea(id), Card.PlayerHand)
  end
  FkTest.setNextReplies(p1(), { "1", FkTest.ReplyDiscard({ other, ids[1] }), "" })
  useSlash(room, p3(), p1())
  lu.assertEquals(room:getCardArea(other), Card.PlayerHand)
  discarded = table.filter(ids, function(id) return room:getCardArea(id) == Card.DiscardPile end)
  lu.assertEquals(#discarded, 2)
end

function Testhanjin_han001:testMZ01OncePerPlayPhaseAndOnlyInIdlePlayPhase()
  local room = FkTest.room
  setKingdom(room, p2(), "han")
  setKingdom(room, p3(), "wei")
  setKingdom(room, p4(), "wei")
  setKingdom(room, p5(), "shu")
  setKingdom(room, p6(), "shu")
  setKingdom(room, p7(), "wei")
  setKingdom(room, p8(), "han")
  setHand(room, p2(), {})
  setHand(room, p3(), {})
  setHand(room, p4(), {})
  setHand(room, p5(), {})
  setHand(room, p6(), {})
  setHand(room, p7(), {})
  setHand(room, p8(), {})
  local ids = setHand(room, p1(), {
    { "hanjin__slash" }, { "hanjin__jink" }, { "hanjin__peach" }, { "hanjin__jink" },
  })
  local seenCanUse = {}
  installTestSkill(room, "#hanjin_han001_mz_phase_probe", {
    { fk.BeforePlayCard, {
      global = true,
      can_refresh = function(self, event, target, player) return player == room.players[1] end,
      on_refresh = function() table.insert(seenCanUse, Fk.skills[MZ]:canUse(p1())) end,
    } },
  })
  runPlayPhase(room, p1(), {
    FkTest.ReplyUseSkill(MZ, { p2() }, { ids[1], ids[2] }),
    "",
  })
  lu.assertEquals(p1():usedSkillTimes(MZ, Player.HistoryGame), 1)
  lu.assertTrue(seenCanUse[1])
  lu.assertTrue(table.find(seenCanUse, function(v) return v == false end) ~= nil)

  -- 取消发动选择不计次。
  setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" } })
  runPlayPhase(room, p1(), { "" })
  lu.assertEquals(p1():usedSkillTimes(MZ, Player.HistoryGame), 1)

  -- 其他角色的出牌阶段与自己的非出牌阶段不会提供发动。
  setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" } })
  FkTest.setNextReplies(p2(), { "" })
  inRoom(function()
    GameEvent.Turn:create(TurnData:new(p2(), "game_rule", { Player.Play })):exec()
  end)
  lu.assertEquals(p1():usedSkillTimes(MZ, Player.HistoryGame), 1)
  FkTest.setNextReplies(p1(), { "" })
  inRoom(function()
    GameEvent.Turn:create(TurnData:new(p1(), "game_rule", { Player.Draw })):exec()
  end)
  lu.assertEquals(p1():usedSkillTimes(MZ, Player.HistoryGame), 1)
end

function Testhanjin_han001:testMZ02EachExtraPlayPhaseGetsOneUse()
  local room = FkTest.room
  setHand(room, p2(), {})
  setHand(room, p3(), {})
  setHand(room, p4(), {})
  setHand(room, p5(), {})
  setHand(room, p6(), {})
  setHand(room, p7(), {})
  setHand(room, p8(), {})
  local ids = setHand(room, p1(), {
    { "hanjin__slash" }, { "hanjin__jink" }, { "hanjin__jink" }, { "hanjin__peach" },
  })
  runPlayPhase(room, p1(), { FkTest.ReplyUseSkill(MZ, { p2() }, { ids[1], ids[2] }), "" })
  runPlayPhase(room, p1(), { FkTest.ReplyUseSkill(MZ, { p2() }, { ids[3], ids[4] }), "" })
  lu.assertEquals(p1():usedSkillTimes(MZ, Player.HistoryGame), 2)
end

function Testhanjin_han001:testMZ04DeadUnknownAndUnusedAllowedKingdomsDoNotCount()
  local room = FkTest.room
  setKingdom(room, p2(), "han")
  setKingdom(room, p3(), "wei")
  setKingdom(room, p4(), "wei")
  setKingdom(room, p5(), "shu")
  setKingdom(room, p6(), "wu")
  setKingdom(room, p7(), "qun")
  setKingdom(room, p8(), "jin")
  setDead(room, p6())
  setUnknown(room, p7())
  lu.assertEquals(secretMinimum(p1()), 3)
  -- 房主允许集不参与计算；p8 是实际出场的晋，只有实际势力计数。
  local old = room:getBanner("all_kingdoms")
  inRoom(function() room:setBanner("all_kingdoms", { "han", "wei", "shu", "wu", "qun", "jin" }) end)
  lu.assertEquals(secretMinimum(p1()), 3)
  inRoom(function() room:setBanner("all_kingdoms", old) end)
end

function Testhanjin_han001:testMZ05WildsAreIndependentAndExcludedOnlyWhenSelf()
  local room = FkTest.room
  setKingdom(room, p2(), "wild")
  setKingdom(room, p3(), "wild")
  setKingdom(room, p4(), "han")
  setKingdom(room, p5(), "han")
  setKingdom(room, p6(), "han")
  setKingdom(room, p7(), "han")
  setKingdom(room, p8(), "han")
  lu.assertEquals(secretMinimum(p1()), 2)

  setWild(room, p1())
  lu.assertEquals(secretMinimum(p1()), 3)
end

function Testhanjin_han001:testMZ06GuestOrChangedKingdomUsesCurrentFaction()
  local room = FkTest.room
  setKingdom(room, p1(), "qun")
  setKingdom(room, p2(), "han")
  setKingdom(room, p3(), "wei")
  setKingdom(room, p4(), "wei")
  setKingdom(room, p5(), "shu")
  setKingdom(room, p6(), "shu")
  setKingdom(room, p7(), "wei")
  setKingdom(room, p8(), "han")
  lu.assertEquals(secretMinimum(p1()), 3)
end

function Testhanjin_han001:testMZ07HiddenGeneralRevealsBeforeLockingX()
  local room = FkTest.room
  setHand(room, p2(), {})
  setHand(room, p3(), {})
  setHand(room, p4(), {})
  setHand(room, p5(), {})
  setHand(room, p6(), {})
  setHand(room, p7(), {})
  setHand(room, p8(), {})
  local ids = setHand(room, p1(), {
    { "hanjin__slash" }, { "hanjin__jink" }, { "hanjin__peach" },
  })
  inRoom(function()
    p1().kingdom = "unknown"
    room:setPlayerProperty(p1(), "kingdom", "unknown")
    room:setPlayerMark(p1(), "__heg_kingdom", "han")
    room:setPlayerMark(p1(), "__heg_wild", 0)
    p1():hideGeneral(false)
    p1():prelightSkill(Fk.skills[MZ], true)
  end)
  lu.assertEquals(secretMinimum(p1()), 2)
  activateSecret(room, p1(), p2(), { ids[1], ids[2] })
  lu.assertEquals(p1().general, "hanjin__han001")
  lu.assertEquals(p1().kingdom, "han")
  lu.assertEquals(p1():usedSkillTimes(MZ, Player.HistoryGame), 1)
  lu.assertEquals(#p2():getCardIds("h"), 2)
end

function Testhanjin_han001:testMZ08XZeroStillNeedsOneCard()
  local room = FkTest.room
  for i = 2, 8 do setKingdom(room, FkTest.room.players[i], "han") end
  setHand(room, p1(), {})
  lu.assertEquals(secretMinimum(p1()), 1)
  lu.assertFalse(Fk.skills[MZ]:canUse(p1()))
  local ids = setHand(room, p1(), { { "hanjin__slash" } })
  lu.assertTrue(Fk.skills[MZ]:canUse(p1()))
  setHand(room, p2(), {})
  for i = 3, 8 do setHand(room, FkTest.room.players[i], {}) end
  activateSecret(room, p1(), p2(), { ids[1] })
  lu.assertEquals(p1():usedSkillTimes(MZ, Player.HistoryGame), 1)
  lu.assertEquals(#p2():getCardIds("h"), 1)
end

function Testhanjin_han001:testMZ09CannotPayWhenFewerThanMaxOneX()
  local room = FkTest.room
  setKingdom(room, p2(), "han")
  setKingdom(room, p3(), "wei")
  setKingdom(room, p4(), "wei")
  setKingdom(room, p5(), "shu")
  setKingdom(room, p6(), "shu")
  setKingdom(room, p7(), "wei")
  setKingdom(room, p8(), "han")
  local ids = setHand(room, p1(), { { "hanjin__slash" } })
  local other = addHand(room, p2(), { { "hanjin__jink" } })[1]
  local judge = inRoom(function()
    return room:printCard("hanjin__indulgence", Card.Spade, 2)
  end)
  inRoom(function()
    room:moveCardTo(judge, Card.PlayerJudge, p1(), fk.ReasonJustMove, "test", nil, false)
  end)
  lu.assertEquals(secretMinimum(p1()), 2)
  lu.assertFalse(Fk.skills[MZ]:canUse(p1()))
  lu.assertEquals(room:getCardArea(ids[1]), Card.PlayerHand)
  lu.assertEquals(room:getCardArea(other), Card.PlayerHand)
  lu.assertEquals(room:getCardArea(judge), Card.PlayerJudge)
end

function Testhanjin_han001:testMZ03XCountsDistinctDifferentKingdoms()
  local room = FkTest.room
  setKingdom(room, p2(), "han")
  setKingdom(room, p3(), "wei")
  setKingdom(room, p4(), "wei")
  setKingdom(room, p5(), "shu")
  setKingdom(room, p6(), "shu")
  setKingdom(room, p7(), "wei")
  setKingdom(room, p8(), "han")
  lu.assertEquals(secretMinimum(p1()), 2)
  local cards = setHand(room, p1(), {
    { "hanjin__slash" }, { "hanjin__jink" }, { "hanjin__peach" },
  })
  setHand(room, p2(), {})
  setHand(room, p3(), { { "hanjin__slash", Card.Spade, 9 } })
  setHand(room, p4(), { { "hanjin__jink", Card.Heart, 2 } })
  local bcard = addHand(room, p2(), { { "hanjin__slash", Card.Spade, 10 } })[1]
  local ccard = p4():getCardIds("h")[1]
  FkTest.setNextReplies(p1(), { FkTest.ReplyChoosePlayer({ p4() }) })
  FkTest.setNextReplies(p2(), { FkTest.ReplyChooseCards({ bcard }) })
  FkTest.setNextReplies(p4(), { FkTest.ReplyChooseCards({ ccard }), "" })
  activateSecret(room, p1(), p2(), { cards[1], cards[2] })
  lu.assertEquals(p1():usedSkillTimes(MZ, Player.HistoryPhase), 1)
  lu.assertTrue(#p2():getCardIds("h") >= 2)
end

function Testhanjin_han001:testMZ10HandAndEquipmentCanBeGiven()
  local room = FkTest.room
  installTestSkill(room, "#hanjin_han001_prohibit_peach_give", {
    { "prohibit", {
      prohibit_discard = function(self, player, card) return card.name == "hanjin__peach" end,
    } },
  })
  local ids = setHand(room, p1(), { { "hanjin__peach" } })
  local equip = addEquip(room, p1(), "jueying")
  setHand(room, p2(), {})
  for i = 3, 8 do setHand(room, FkTest.room.players[i], {}) end
  activateSecret(room, p1(), p2(), { ids[1], equip })
  lu.assertEquals(#p2():getCardIds("h"), 2)
  lu.assertEquals(#p1():getCardIds("e"), 0)
  lu.assertEquals(p1():usedSkillTimes(MZ, Player.HistoryGame), 1)
end

function Testhanjin_han001:testMZ11InvalidReceiverOrCardsAreRejected()
  local room = FkTest.room
  local ids = setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" } })
  setHand(room, p2(), {})
  for i = 3, 8 do setHand(room, FkTest.room.players[i], {}) end
  activateSecret(room, p1(), p1(), { ids[1], ids[2] })
  lu.assertEquals(p1():getCardIds("h"), ids)
  lu.assertEquals(p2():getCardIds("h"), {})

  activateSecret(room, p1(), p2(), { ids[1], ids[1] })
  lu.assertEquals(p1():getCardIds("h"), ids)
  lu.assertEquals(p2():getCardIds("h"), {})

  inRoom(function()
    room:moveCardTo(ids[1], Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false)
  end)
  activateSecret(room, p1(), p2(), { ids[1], ids[2] })
  lu.assertEquals(p2():getCardIds("h"), {})

  setDead(room, p2())
  ids = setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" } })
  activateSecret(room, p1(), p2(), { ids[1], ids[2] })
  lu.assertEquals(p1():getCardIds("h"), ids)
end

function Testhanjin_han001:testMZ12CancelDoesNotCountAndFailedPindianDoesNotRefund()
  local room = FkTest.room
  setHand(room, p2(), {})
  for i = 3, 8 do setHand(room, FkTest.room.players[i], {}) end
  local ids = setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" } })
  runPlayPhase(room, p1(), { "" })
  lu.assertEquals(p1():usedSkillTimes(MZ, Player.HistoryGame), 0)

  activateSecret(room, p1(), p2(), { ids[1], ids[2] })
  lu.assertEquals(p1():usedSkillTimes(MZ, Player.HistoryGame), 1)
  lu.assertEquals(#p2():getCardIds("h"), 2)
  lu.assertEquals(#p1():getCardIds("h"), 0)
end

function Testhanjin_han001:testMZ13GiveChainChangesKingdomButDoesNotRefund()
  local room = FkTest.room
  local ids = setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" } })
  setHand(room, p2(), {})
  setHand(room, p3(), {})
  for i = 4, 8 do setHand(room, FkTest.room.players[i], {}) end
  installTestSkill(room, "#hanjin_han001_give_kingdom", {
    { fk.AfterCardsMove, {
      global = true,
      can_refresh = function(self, event, target, owner, data)
        for _, move in ipairs(data) do
          if move.from == p1() and move.to == p2() then return owner == room.players[1] end
        end
        return false
      end,
      on_refresh = function()
        room:changeKingdom(p3(), "shu", false)
      end,
    } },
  })
  activateSecret(room, p1(), p2(), { ids[1], ids[2] })
  lu.assertEquals(p1():usedSkillTimes(MZ, Player.HistoryGame), 1)
  lu.assertEquals(#p2():getCardIds("h"), 2)
  lu.assertEquals(#p1():getCardIds("h"), 0)
end

function Testhanjin_han001:testMZ14GiveChainMovesBHandBeforePindian()
  local room = FkTest.room
  local ids = setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" } })
  setHand(room, p2(), {})
  local ccard = setHand(room, p3(), { { "hanjin__jink", Card.Heart, 5 } })[1]
  for i = 4, 8 do setHand(room, FkTest.room.players[i], {}) end
  local moved = false
  installTestSkill(room, "#hanjin_han001_give_chain_move", {
    { fk.AfterCardsMove, {
      global = true,
      can_refresh = function(self, event, target, owner, data)
        if moved or owner ~= room.players[1] then return false end
        for _, move in ipairs(data) do
          if move.from == p1() and move.to == p2() then return true end
        end
        return false
      end,
      on_refresh = function()
        moved = true
        local card = p2():getCardIds("h")[1]
        room:moveCardTo(card, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false)
      end,
    } },
  })
  local log = {}
  installPindianProbe(room, log)
  FkTest.setNextReplies(p1(), { FkTest.ReplyChoosePlayer({ p3() }) })
  -- B receives both cards, then the chain discards the first one; the remaining
  -- one is chosen by B.
  FkTest.setNextReplies(p2(), { FkTest.ReplyChooseCards({ ids[2] }) })
  FkTest.setNextReplies(p3(), { FkTest.ReplyChooseCards({ ccard }), "" })
  activateSecret(room, p1(), p2(), { ids[1], ids[2] })
  lu.assertEquals(#log, 1)
  lu.assertEquals(log[1].reason, MZ)
end

function Testhanjin_han001:testMZ15EmptyReceiverCanPindianAfterGiving()
  local room = FkTest.room
  local ids = setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" } })
  setHand(room, p2(), {})
  local ccard = setHand(room, p3(), { { "hanjin__jink", Card.Heart, 7 } })[1]
  for i = 4, 8 do setHand(room, FkTest.room.players[i], {}) end
  local log = {}
  installPindianProbe(room, log)
  FkTest.setNextReplies(p1(), { FkTest.ReplyChoosePlayer({ p3() }) })
  FkTest.setNextReplies(p2(), { FkTest.ReplyChooseCards({ ids[1] }) })
  FkTest.setNextReplies(p3(), { FkTest.ReplyChooseCards({ ccard }), "" })
  activateSecret(room, p1(), p2(), { ids[1], ids[2] })
  lu.assertEquals(#log, 1)
  lu.assertEquals(log[1].reason, MZ)
  lu.assertIs(log[1].from, p2())
end

function Testhanjin_han001:testMZ16NoLegalThirdEndsAfterGiving()
  local room = FkTest.room
  local ids = setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" } })
  setHand(room, p2(), {})
  for i = 3, 8 do setHand(room, FkTest.room.players[i], {}) end
  local uses = {}
  installUseProbe(room, uses)
  activateSecret(room, p1(), p2(), { ids[1], ids[2] })
  lu.assertEquals(#p2():getCardIds("h"), 2)
  lu.assertEquals(p1():usedSkillTimes(MZ, Player.HistoryGame), 1)
  lu.assertEquals(#uses, 0)
end

function Testhanjin_han001:testMZ17ThirdMustBeAnotherLegalLivingPindianTarget()
  local room = FkTest.room
  local ids = setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" } })
  setHand(room, p2(), {})
  local ccard = setHand(room, p3(), { { "hanjin__jink", Card.Heart, 4 } })[1]
  setDead(room, p4())
  for i = 5, 8 do setHand(room, FkTest.room.players[i], {}) end
  local captured
  local original = room.askToChoosePlayers
  room.askToChoosePlayers = function(self, player, params)
    if params.skill_name == MZ then
      captured = table.map(params.targets, Util.IdMapper)
      captured.cancelable = params.cancelable
    end
    return original(self, player, params)
  end
  FkTest.setNextReplies(p1(), { FkTest.ReplyChoosePlayer({ p3() }) })
  FkTest.setNextReplies(p2(), { FkTest.ReplyChooseCards({ ids[1] }) })
  FkTest.setNextReplies(p3(), { FkTest.ReplyChooseCards({ ccard }), "" })
  activateSecret(room, p1(), p2(), { ids[1], ids[2] })
  room.askToChoosePlayers = original
  lu.assertFalse(table.contains(captured, p1().id))
  lu.assertFalse(table.contains(captured, p2().id))
  lu.assertFalse(table.contains(captured, p4().id))
  lu.assertTrue(table.contains(captured, p3().id))
  lu.assertFalse(captured.cancelable)
end

function Testhanjin_han001:testMZ18BMayUseReceivedOrOriginalCard()
  local room = FkTest.room
  local ids = setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" } })
  setHand(room, p2(), {})
  local ccard = setHand(room, p3(), { { "hanjin__jink", Card.Heart, 8 } })[1]
  for i = 4, 8 do setHand(room, FkTest.room.players[i], {}) end
  local log = {}
  installPindianProbe(room, log)
  FkTest.setNextReplies(p1(), { FkTest.ReplyChoosePlayer({ p3() }) })
  FkTest.setNextReplies(p2(), { FkTest.ReplyChooseCards({ ids[1] }) })
  FkTest.setNextReplies(p3(), { FkTest.ReplyChooseCards({ ccard }), "" })
  activateSecret(room, p1(), p2(), { ids[1], ids[2] })
  lu.assertEquals(#log, 1)
  lu.assertEquals(log[1].fromCard.subcards[1], ids[1])

  -- 另一个出牌阶段：B 使用原有手牌。
  local bcard = setHand(room, p2(), { { "hanjin__slash", Card.Spade, 3 } })[1]
  ids = setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" } })
  ccard = setHand(room, p3(), { { "hanjin__jink", Card.Heart, 6 } })[1]
  log = {}
  installPindianProbe(room, log)
  FkTest.setNextReplies(p1(), { FkTest.ReplyChoosePlayer({ p3() }) })
  FkTest.setNextReplies(p2(), { FkTest.ReplyChooseCards({ bcard }) })
  FkTest.setNextReplies(p3(), { FkTest.ReplyChooseCards({ ccard }), "" })
  activateSecret(room, p1(), p2(), { ids[1], ids[2] })
  lu.assertEquals(#log, 1)
  lu.assertEquals(log[1].fromCard.subcards[1], bcard)
end

function Testhanjin_han001:testMZ19WinnerUsesVirtualSlash()
  local room = FkTest.room
  setKingdom(room, p2(), "han")
  setKingdom(room, p3(), "wei")
  setKingdom(room, p4(), "wei")
  setKingdom(room, p5(), "shu")
  setKingdom(room, p6(), "shu")
  setKingdom(room, p7(), "wei")
  setKingdom(room, p8(), "han")
  local cards = setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" } })
  local bcard = addHand(room, p2(), { { "hanjin__slash", Card.Spade, 10 } })[1]
  local ccard = addHand(room, p3(), { { "hanjin__jink", Card.Heart, 5 } })[1]
  setHand(room, p4(), {})
  local uses, damages = {}, {}
  installUseProbe(room, uses)
  installDamageProbe(room, damages)
  FkTest.setNextReplies(p1(), { FkTest.ReplyChoosePlayer({ p3() }) })
  FkTest.setNextReplies(p2(), { FkTest.ReplyChooseCards({ bcard }) })
  FkTest.setNextReplies(p3(), { FkTest.ReplyChooseCards({ ccard }), "" })
  activateSecret(room, p1(), p2(), cards)
  lu.assertEquals(#uses, 1)
  lu.assertIs(uses[1].from, p2())
  lu.assertIs(uses[1].tos[1], p3())
  lu.assertTrue(uses[1].extraUse)
  lu.assertEquals(uses[1].finished, 1)
  lu.assertEquals(#damages, 1)
  lu.assertIs(damages[1].from, p2())
  lu.assertEquals(p1():usedSkillTimes(MZ, Player.HistoryPhase), 1)
end

function Testhanjin_han001:testMZ19bTieHasNoSlashAndReverseWinnerSlash()
  local room = FkTest.room
  local ids = setHand(room, p1(), { { "hanjin__slash", Card.Spade, 7 }, { "hanjin__jink", Card.Heart, 7 } })
  setHand(room, p2(), {})
  local ccards = setHand(room, p3(), {
    { "hanjin__jink", Card.Heart, 7 }, { "hanjin__jink", Card.Heart, 10 },
  })
  for i = 4, 8 do setHand(room, FkTest.room.players[i], {}) end
  local uses = {}
  installUseProbe(room, uses)
  FkTest.setNextReplies(p1(), { FkTest.ReplyChoosePlayer({ p3() }) })
  FkTest.setNextReplies(p2(), { FkTest.ReplyChooseCards({ ids[1] }) })
  FkTest.setNextReplies(p3(), { FkTest.ReplyChooseCards({ ccards[1] }), "" })
  activateSecret(room, p1(), p2(), { ids[1], ids[2] })
  lu.assertEquals(#uses, 0)

  ids = setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" } })
  ccards = setHand(room, p3(), { { "hanjin__jink", Card.Heart, 10 }, { "hanjin__jink", Card.Heart, 10 } })
  local bcard = addHand(room, p2(), { { "hanjin__slash", Card.Spade, 5 } })[1]
  FkTest.setNextReplies(p1(), { FkTest.ReplyChoosePlayer({ p3() }) })
  FkTest.setNextReplies(p2(), { FkTest.ReplyChooseCards({ bcard }) })
  FkTest.setNextReplies(p3(), { FkTest.ReplyChooseCards({ ccards[1] }), "" })
  activateSecret(room, p1(), p2(), { ids[1], ids[2] })
  lu.assertEquals(#uses, 1)
  lu.assertIs(uses[1].from, p3())
  lu.assertIs(uses[1].tos[1], p2())
end

function Testhanjin_han001:testMZ20ModifiedPindianNumberControlsWinner()
  local room = FkTest.room
  local ids = setHand(room, p1(), {
    { "hanjin__slash", Card.Spade, 5 }, { "hanjin__jink", Card.Heart, 5 },
  })
  setHand(room, p2(), {})
  local ccard = setHand(room, p3(), { { "hanjin__jink", Card.Heart, 8 } })[1]
  for i = 4, 8 do setHand(room, FkTest.room.players[i], {}) end
  installTestSkill(room, "#hanjin_han001_pindian_number", {
    { fk.PindianCardsDisplayed, {
      global = true,
      can_refresh = function(self, event, target, owner) return owner == room.players[1] end,
      on_refresh = function(self, event, target, owner, data)
        room:changePindianNumber(data, p2(), 5, "test")
      end,
    } },
  })
  local uses = {}
  installUseProbe(room, uses)
  FkTest.setNextReplies(p1(), { FkTest.ReplyChoosePlayer({ p3() }) })
  FkTest.setNextReplies(p2(), { FkTest.ReplyChooseCards({ ids[1] }) })
  FkTest.setNextReplies(p3(), { FkTest.ReplyChooseCards({ ccard }), "" })
  activateSecret(room, p1(), p2(), { ids[1], ids[2] })
  lu.assertEquals(#uses, 1)
  lu.assertIs(uses[1].from, p2())
end

function Testhanjin_han001:testMZ21PindianReasonAndCards()
  local room = FkTest.room
  local ids = setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" } })
  setHand(room, p2(), {})
  local ccard = setHand(room, p3(), { { "hanjin__jink", Card.Heart, 3 } })[1]
  for i = 4, 8 do setHand(room, FkTest.room.players[i], {}) end
  local log = {}
  installPindianProbe(room, log)
  FkTest.setNextReplies(p1(), { FkTest.ReplyChoosePlayer({ p3() }) })
  FkTest.setNextReplies(p2(), { FkTest.ReplyChooseCards({ ids[1] }) })
  FkTest.setNextReplies(p3(), { FkTest.ReplyChooseCards({ ccard }), "" })
  activateSecret(room, p1(), p2(), { ids[1], ids[2] })
  lu.assertEquals(#log, 1)
  lu.assertEquals(log[1].reason, MZ)
  lu.assertIs(log[1].from, p2())
  lu.assertIs(log[1].tos[1], p3())
  lu.assertNotEquals(room:getCardArea(ids[1]), Card.PlayerHand)
  lu.assertNotEquals(room:getCardArea(ccard), Card.PlayerHand)
end

function Testhanjin_han001:testMZ22ProhibitedPindianEndsAfterGiving()
  local room = FkTest.room
  local ids = setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" } })
  setHand(room, p2(), {})
  local ccard = setHand(room, p3(), { { "hanjin__jink", Card.Heart, 4 } })[1]
  for i = 4, 8 do setHand(room, FkTest.room.players[i], {}) end
  installTestSkill(room, "#hanjin_han001_prohibit_pindian", {
    { "prohibit", {
      prohibit_pindian = function(self, from, to) return from == p2() and to == p3() end,
    } },
  })
  local log = {}
  installPindianProbe(room, log)
  activateSecret(room, p1(), p2(), { ids[1], ids[2] })
  lu.assertEquals(#log, 0)
  lu.assertEquals(#p2():getCardIds("h"), 2)
  lu.assertEquals(p1():usedSkillTimes(MZ, Player.HistoryGame), 1)
end

function Testhanjin_han001:testMZ23PindianDeathPreventsSlash()
  local room = FkTest.room
  local ids = setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" } })
  setHand(room, p2(), {})
  local ccard = setHand(room, p3(), { { "hanjin__jink", Card.Heart, 4 } })[1]
  for i = 4, 8 do setHand(room, FkTest.room.players[i], {}) end
  installTestSkill(room, "#hanjin_han001_pindian_death", {
    { fk.PindianFinished, {
      global = true,
      can_refresh = function(self, event, target, owner) return owner == room.players[1] end,
      on_refresh = function(self, event, target, owner, data)
        data.tos[1].dead = true
        table.removeOne(room.alive_players, data.tos[1])
      end,
    } },
  })
  local uses = {}
  installUseProbe(room, uses)
  FkTest.setNextReplies(p1(), { FkTest.ReplyChoosePlayer({ p3() }) })
  FkTest.setNextReplies(p2(), { FkTest.ReplyChooseCards({ ids[1] }) })
  FkTest.setNextReplies(p3(), { FkTest.ReplyChooseCards({ ccard }) })
  activateSecret(room, p1(), p2(), { ids[1], ids[2] })
  lu.assertEquals(#uses, 0)
  lu.assertEquals(p1():usedSkillTimes(MZ, Player.HistoryGame), 1)
end

function Testhanjin_han001:testMZ24SlashIsVirtualWithoutInheritedCardData()
  local room = FkTest.room
  local ids = setHand(room, p1(), {
    { "hanjin__fire__slash", Card.Spade, 9 }, { "hanjin__jink", Card.Heart, 2 },
  })
  setHand(room, p2(), {})
  local ccard = setHand(room, p3(), { { "hanjin__jink", Card.Heart, 3 } })[1]
  for i = 4, 8 do setHand(room, FkTest.room.players[i], {}) end
  local uses = {}
  installUseProbe(room, uses)
  FkTest.setNextReplies(p1(), { FkTest.ReplyChoosePlayer({ p3() }) })
  FkTest.setNextReplies(p2(), { FkTest.ReplyChooseCards({ ids[1] }) })
  FkTest.setNextReplies(p3(), { FkTest.ReplyChooseCards({ ccard }), "" })
  activateSecret(room, p1(), p2(), { ids[1], ids[2] })
  lu.assertEquals(#uses, 1)
  lu.assertTrue(uses[1].card:isVirtual())
  lu.assertEquals(#uses[1].card.subcards, 0)
  lu.assertEquals(uses[1].card.name, "hanjin__slash")
  lu.assertEquals(uses[1].card.suit, Card.NoSuit)
end

function Testhanjin_han001:testMZ25ExplicitTargetIgnoresSlashDistance()
  local room = FkTest.room
  local ids = setHand(room, p1(), { { "hanjin__slash", Card.Spade, 10 }, { "hanjin__jink", Card.Heart, 10 } })
  setHand(room, p2(), {})
  local ccard = setHand(room, p8(), { { "hanjin__jink", Card.Heart, 3 } })[1]
  for i = 3, 7 do setHand(room, FkTest.room.players[i], {}) end
  local uses = {}
  installUseProbe(room, uses)
  FkTest.setNextReplies(p1(), { FkTest.ReplyChoosePlayer({ p8() }) })
  FkTest.setNextReplies(p2(), { FkTest.ReplyChooseCards({ ids[1] }) })
  FkTest.setNextReplies(p8(), { FkTest.ReplyChooseCards({ ccard }), "" })
  activateSecret(room, p1(), p2(), { ids[1], ids[2] })
  lu.assertTrue(p2():distanceTo(p8()) > 1)
  lu.assertEquals(#uses, 1)
  lu.assertIs(uses[1].tos[1], p8())
end

function Testhanjin_han001:testMZ26SlashDoesNotConsumeNormalUseCount()
  local room = FkTest.room
  local ids = setHand(room, p1(), { { "hanjin__slash", Card.Spade, 10 }, { "hanjin__jink", Card.Heart, 10 } })
  setHand(room, p2(), {})
  local ccard = setHand(room, p3(), { { "hanjin__jink", Card.Heart, 3 } })[1]
  for i = 4, 8 do setHand(room, FkTest.room.players[i], {}) end
  inRoom(function() p2():addCardUseHistory("slash", 2) end)
  local before = p2():usedCardTimes("slash", Player.HistoryTurn)
  local uses = {}
  installUseProbe(room, uses)
  FkTest.setNextReplies(p1(), { FkTest.ReplyChoosePlayer({ p3() }) })
  FkTest.setNextReplies(p2(), { FkTest.ReplyChooseCards({ ids[1] }) })
  FkTest.setNextReplies(p3(), { FkTest.ReplyChooseCards({ ccard }), "" })
  activateSecret(room, p1(), p2(), { ids[1], ids[2] })
  lu.assertEquals(p2():usedCardTimes("slash", Player.HistoryTurn), before)
  lu.assertTrue(uses[1].extraUse)
end

function Testhanjin_han001:testMZ27ProhibitedUseOrTargetSkipsSlash()
  local room = FkTest.room
  local ids = setHand(room, p1(), { { "hanjin__slash", Card.Spade, 10 }, { "hanjin__jink", Card.Heart, 10 } })
  setHand(room, p2(), {})
  local ccard = setHand(room, p3(), { { "hanjin__jink", Card.Heart, 3 } })[1]
  for i = 4, 8 do setHand(room, FkTest.room.players[i], {}) end
  installTestSkill(room, "#hanjin_han001_prohibit_slash_use", {
    { "prohibit", {
      prohibit_use = function(self, player, card)
        return player == p2() and card.trueName == "slash"
      end,
    } },
  })
  local uses = {}
  installUseProbe(room, uses)
  FkTest.setNextReplies(p1(), { FkTest.ReplyChoosePlayer({ p3() }) })
  FkTest.setNextReplies(p2(), { FkTest.ReplyChooseCards({ ids[1] }) })
  activateSecret(room, p1(), p2(), { ids[1], ids[2] })
  lu.assertEquals(#uses, 0)
  lu.assertEquals(p1():usedSkillTimes(MZ, Player.HistoryGame), 1)
end

function Testhanjin_han001:testMZ27bProhibitedTargetSkipsSlash()
  local room = FkTest.room
  local ids = setHand(room, p1(), { { "hanjin__slash", Card.Spade, 10 }, { "hanjin__jink", Card.Heart, 10 } })
  setHand(room, p2(), {})
  local ccard = setHand(room, p3(), { { "hanjin__jink", Card.Heart, 3 } })[1]
  for i = 4, 8 do setHand(room, FkTest.room.players[i], {}) end
  installTestSkill(room, "#hanjin_han001_prohibit_slash_target", {
    { "prohibit", {
      is_prohibited = function(self, from, to, card)
        return card ~= nil and card.trueName == "slash" and to == p3()
      end,
    } },
  })
  local uses = {}
  installUseProbe(room, uses)
  FkTest.setNextReplies(p1(), { FkTest.ReplyChoosePlayer({ p3() }) })
  FkTest.setNextReplies(p2(), { FkTest.ReplyChooseCards({ ids[1] }) })
  activateSecret(room, p1(), p2(), { ids[1], ids[2] })
  lu.assertEquals(#uses, 0)
end

function Testhanjin_han001:testMZ28DodgeAndDamageUseNormalSlashFlow()
  local room = FkTest.room
  local ids = setHand(room, p1(), { { "hanjin__slash", Card.Spade, 10 }, { "hanjin__jink", Card.Heart, 10 } })
  setHand(room, p2(), {})
  local ccard = setHand(room, p3(), { { "hanjin__jink", Card.Heart, 3, }, { "jink", Card.Heart, 2 } })[1]
  local dodge = p3():getCardIds("h")[2]
  for i = 4, 8 do setHand(room, FkTest.room.players[i], {}) end
  local uses, damages = {}, {}
  installUseProbe(room, uses)
  installDamageProbe(room, damages)
  FkTest.setNextReplies(p1(), { FkTest.ReplyChoosePlayer({ p3() }) })
  FkTest.setNextReplies(p2(), { FkTest.ReplyChooseCards({ ids[1] }) })
  FkTest.setNextReplies(p3(), { FkTest.ReplyChooseCards({ ccard }), FkTest.ReplyCard(Fk:getCardById(dodge)) })
  activateSecret(room, p1(), p2(), { ids[1], ids[2] })
  lu.assertEquals(#uses, 1)
  lu.assertEquals(#damages, 0)
  lu.assertEquals(uses[1].finished, 1)
end

function Testhanjin_han001:testMZ29aDeathAfterGivingStopsThirdSelection()
  local room = FkTest.room
  local ids = setHand(room, p1(), { { "hanjin__slash", Card.Spade, 10 }, { "hanjin__jink", Card.Heart, 10 } })
  setHand(room, p2(), {})
  local ccard = setHand(room, p3(), { { "hanjin__jink", Card.Heart, 3 } })[1]
  for i = 4, 8 do setHand(room, FkTest.room.players[i], {}) end
  installTestSkill(room, "#hanjin_han001_death_after_give", {
    { fk.AfterCardsMove, {
      global = true,
      can_refresh = function(self, event, target, owner, data)
        for _, move in ipairs(data) do
          if move.from == p1() and move.to == p2() then return owner == room.players[1] end
        end
        return false
      end,
      on_refresh = function()
        p1().dead = true
        table.removeOne(room.alive_players, p1())
      end,
    } },
  })
  local log = {}
  installPindianProbe(room, log)
  activateSecret(room, p1(), p2(), { ids[1], ids[2] })
  lu.assertEquals(#log, 0)
  lu.assertEquals(#p2():getCardIds("h"), 2)
end

function Testhanjin_han001:testMZ29bDeathAfterPindianKeepsEstablishedFlow()
  local room = FkTest.room
  local ids = setHand(room, p1(), { { "hanjin__slash", Card.Spade, 10 }, { "hanjin__jink", Card.Heart, 10 } })
  setHand(room, p2(), {})
  local ccard = setHand(room, p3(), { { "hanjin__jink", Card.Heart, 3 } })[1]
  for i = 4, 8 do setHand(room, FkTest.room.players[i], {}) end
  installTestSkill(room, "#hanjin_han001_death_after_pindian", {
    { fk.PindianFinished, {
      global = true,
      can_refresh = function(self, event, target, owner) return owner == room.players[1] end,
      on_refresh = function()
        p1().dead = true
        table.removeOne(room.alive_players, p1())
      end,
    } },
  })
  local uses = {}
  installUseProbe(room, uses)
  FkTest.setNextReplies(p1(), { FkTest.ReplyChoosePlayer({ p3() }) })
  FkTest.setNextReplies(p2(), { FkTest.ReplyChooseCards({ ids[1] }) })
  FkTest.setNextReplies(p3(), { FkTest.ReplyChooseCards({ ccard }), "" })
  activateSecret(room, p1(), p2(), { ids[1], ids[2] })
  lu.assertEquals(#uses, 1)
end

function Testhanjin_han001:testMZ30ThirdSelectionCannotBeCancelled()
  local room = FkTest.room
  local ids = setHand(room, p1(), { { "hanjin__slash", Card.Spade, 10 }, { "hanjin__jink", Card.Heart, 10 } })
  setHand(room, p2(), {})
  local ccard = setHand(room, p3(), { { "hanjin__jink", Card.Heart, 3 } })[1]
  for i = 4, 8 do setHand(room, FkTest.room.players[i], {}) end
  local captured
  local original = room.askToChoosePlayers
  room.askToChoosePlayers = function(self, player, params)
    if params.skill_name == MZ then captured = params.cancelable end
    return original(self, player, params)
  end
  local log = {}
  installPindianProbe(room, log)
  FkTest.setNextReplies(p1(), { "__cancel" })
  FkTest.setNextReplies(p2(), { FkTest.ReplyChooseCards({ ids[1] }) })
  FkTest.setNextReplies(p3(), { FkTest.ReplyChooseCards({ ccard }), "" })
  activateSecret(room, p1(), p2(), { ids[1], ids[2] })
  room.askToChoosePlayers = original
  lu.assertFalse(captured)
  lu.assertEquals(#log, 1)
end

function Testhanjin_han001:testHG01MainAndDeputySourceAndHiddenReveal()
  local room = FkTest.room
  setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" } })
  setHand(room, p2(), {})
  for i = 3, 8 do setHand(room, FkTest.room.players[i], {}) end
  activateSecret(room, p1(), p2(), p1():getCardIds("h"))
  lu.assertEquals(p1():usedSkillTimes(MZ, Player.HistoryGame), 1)

  -- 副将位置：技能来源为副将，发动时只明置副将。
  inRoom(function()
    room:changeHero(p2(), "hanjin__han001", true, true, false, false, false)
    room:setPlayerMark(p2(), "__heg_deputy", "hanjin__han001")
    room:setPlayerMark(p2(), "__heg_kingdom", "han")
    p2().kingdom = "unknown"
    room:setPlayerProperty(p2(), "kingdom", "unknown")
    p2():hideGeneral(true)
    p2():prelightSkill(Fk.skills[MZ], true)
    room:setPlayerProperty(p2(), "hp", p2().maxHp)
  end)
  local ids = setHand(room, p2(), { { "hanjin__slash" }, { "hanjin__jink" } })
  setHand(room, p3(), {})
  for i = 4, 8 do setHand(room, FkTest.room.players[i], {}) end
  activateSecret(room, p2(), p3(), { ids[1], ids[2] })
  lu.assertEquals(p2().deputyGeneral, "hanjin__han001")
  lu.assertNotEquals(p2().general, "anjiang")
  lu.assertEquals(p2():usedSkillTimes(MZ, Player.HistoryGame), 1)
end

function Testhanjin_han001:testHG01bHiddenTianmingRevealsBeforeDiscardChain()
  local room = FkTest.room
  setHand(room, p3(), { { "hanjin__slash" } })
  local ids = setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" } })
  inRoom(function()
    room:setPlayerMark(p1(), "__heg_general", "hanjin__han001")
    room:setPlayerMark(p1(), "__heg_kingdom", "han")
    p1().kingdom = "unknown"
    room:setPlayerProperty(p1(), "kingdom", "unknown")
    p1():hideGeneral(false)
    p1():prelightSkill(Fk.skills[TM], true)
  end)
  local atDiscard
  installTestSkill(room, "#hanjin_han001_tm_hidden_probe", {
    { fk.AfterCardsMove, {
      global = true,
      can_refresh = function(self, event, target, owner, data)
        for _, move in ipairs(data) do
          if move.from == p1() and move.toArea == Card.DiscardPile then return true end
        end
        return false
      end,
      on_refresh = function(self, event, target, owner, data)
        atDiscard = { general = p1().general, kingdom = p1().kingdom, cards = {} }
        for _, move in ipairs(data) do
          for _, info in ipairs(move.moveInfo) do
            table.insert(atDiscard.cards, info.cardId)
          end
        end
      end,
    } },
  })
  -- 1: on_cost invoke; 2: doCost's extra invoke for a prelighted fake skill;
  -- "" : normal slash response after 天命.
  lu.assertEquals(p1().general, "anjiang")
  lu.assertEquals(p1().kingdom, "unknown")
  lu.assertTrue(p1():hasSkill(TM))
  FkTest.setNextReplies(p1(), { "1", "1", "" })
  useSlash(room, p3(), p1())
  lu.assertNotNil(atDiscard)
  lu.assertEquals(atDiscard.general, "hanjin__han001")
  lu.assertEquals(atDiscard.kingdom, "han")
  table.sort(atDiscard.cards)
  table.sort(ids)
  lu.assertEquals(atDiscard.cards, ids)
  lu.assertEquals(p1().general, "hanjin__han001")
  lu.assertEquals(p1():usedSkillTimes(TM, Player.HistoryGame), 1)
  lu.assertEquals(#p1():getCardIds("h"), 2)
end

function Testhanjin_han001:testHG02LostOrExchangedSkillCannotBeUsedByOldHolder()
  local room = FkTest.room
  inRoom(function()
    room:handleAddLoseSkills(p1(), "-" .. MZ, nil, false, true)
  end)
  lu.assertFalse(p1():hasSkill(MZ))
  local before = setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" } })
  setHand(room, p2(), {})
  activateSecret(room, p1(), p2(), { before[1], before[2] })
  lu.assertEquals(p1():getCardIds("h"), before)
  grant(p3(), MZ)
  lu.assertTrue(p3():hasSkill(MZ))

  inRoom(function()
    room:changeHero(p1(), "hanjin_test__han_1", true, false, false, false, false)
  end)
  lu.assertFalse(p1():hasSkill(MZ))
  lu.assertFalse(p1():hasSkill(TM))
end

function Testhanjin_han001:testHG03MizhaoSlashTriggersTianmingOnce()
  local room = FkTest.room
  grant(p3(), TM)
  local ids = setHand(room, p1(), {
    { "hanjin__slash", Card.Spade, 10 }, { "hanjin__jink", Card.Heart, 10 },
  })
  setHand(room, p2(), {})
  local ccards = setHand(room, p3(), {
    { "hanjin__jink", Card.Heart, 3 }, { "hanjin__slash" }, { "hanjin__jink" },
  })
  for i = 4, 8 do setHand(room, FkTest.room.players[i], {}) end
  local pindians, uses = {}, {}
  installPindianProbe(room, pindians)
  installUseProbe(room, uses)
  FkTest.setNextReplies(p1(), { FkTest.ReplyChoosePlayer({ p3() }) })
  FkTest.setNextReplies(p2(), { FkTest.ReplyChooseCards({ ids[1] }) })
  FkTest.setNextReplies(p3(), {
    FkTest.ReplyChooseCards({ ccards[1] }),
    "1",
    FkTest.ReplyChooseCards({ ccards[2], ccards[3] }),
    "",
  })
  activateSecret(room, p1(), p2(), { ids[1], ids[2] })
  lu.assertEquals(#pindians, 1)
  lu.assertEquals(#uses, 1)
  lu.assertEquals(uses[1].finished, 1)
  lu.assertEquals(p3():usedSkillTimes(TM, Player.HistoryGame), 1)
end

function Testhanjin_han001:testHG04DoubleHiddenKeepsCorrectSourceAndFaction()
  local room = FkTest.room
  setHand(room, p2(), {})
  for i = 3, 8 do setHand(room, FkTest.room.players[i], {}) end
  local ids = setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" } })
  inRoom(function()
    room:setPlayerMark(p1(), "__heg_general", "hanjin__han001")
    room:setPlayerMark(p1(), "__heg_deputy", "hanjin_test__han_1")
    room:setPlayerMark(p1(), "__heg_kingdom", "han")
    room:setPlayerMark(p1(), "__heg_wild", 0)
    p1().kingdom = "unknown"
    room:setPlayerProperty(p1(), "kingdom", "unknown")
    p1():hideGeneral(false)
    p1():hideGeneral(true)
    p1():prelightSkill(Fk.skills[MZ], true)
  end)
  lu.assertEquals(p1().general, "anjiang")
  lu.assertEquals(p1().deputyGeneral, "anjiang")
  lu.assertEquals(secretMinimum(p1()), 2)
  activateSecret(room, p1(), p2(), { ids[1], ids[2] })
  lu.assertEquals(p1().general, "hanjin__han001")
  lu.assertEquals(p1().deputyGeneral, "anjiang")
  lu.assertEquals(p1().kingdom, "han")
end

function Testhanjin_han001:testHG05DefaultSuiteAndRoomIsolation()
  lu.assertTrue(table.contains(Fk.packages.hanjin_generals.game_modes_whitelist, "hanjin_heg_mode"))
  lu.assertTrue(table.contains(Fk.game_modes.hanjin_heg_mode.whitelist, "hanjin_generals"))
  lu.assertEquals(FkTest.room:getSettings("gameMode"), "hanjin_heg_mode")
  lu.assertNotNil(Fk.skills[TM])
  lu.assertNotNil(Fk.skills[MZ])
end

function Testhanjin_han001:testMZ31RealClientPlayerWithoutRoomComputesKnownFaction()
  local room = FkTest.room
  setKingdom(room, p2(), "han")
  setKingdom(room, p3(), "wei")
  setKingdom(room, p4(), "wei")
  setKingdom(room, p5(), "shu")
  setKingdom(room, p6(), "shu")
  setKingdom(room, p7(), "wei")
  setKingdom(room, p8(), "han")
  setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" } })
  lu.assertEquals(secretMinimum(p1()), 2)
  asClient(room, function(clients)
    local me = clients[1]
    lu.assertNil(me.room)
    lu.assertEquals(me.class.name, "ClientPlayer")
    lu.assertEquals(me.kingdom, "han")
    local skill = Fk.skills[MZ]
    lu.assertEquals(skill:getMinCardNum(me), 2)
    lu.assertTrue(skill:canUse(me))
    lu.assertEquals(skill:prompt(me), "#hanjin__skill_han001_2-prompt:::2")
  end)
end

function Testhanjin_han001:testMZ32ClientWithoutRoomPredictsHiddenOwnFaction()
  local room = FkTest.room
  setKingdom(room, p2(), "wei")
  setKingdom(room, p3(), "han")
  setKingdom(room, p4(), "shu")
  setKingdom(room, p5(), "qun")
  setKingdom(room, p6(), "han")
  setKingdom(room, p7(), "han")
  setKingdom(room, p8(), "han")
  inRoom(function()
    room:setPlayerMark(p1(), "__heg_general", "hanjin__han001")
    room:setPlayerMark(p1(), "__heg_kingdom", "wei")
    room:setPlayerMark(p1(), "__heg_wild", 0)
    p1().kingdom = "unknown"
    room:setPlayerProperty(p1(), "kingdom", "unknown")
    p1():hideGeneral(false)
    p1():prelightSkill(Fk.skills[MZ], true)
  end)
  setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" }, { "hanjin__peach" } })
  for i = 2, 8 do setHand(room, FkTest.room.players[i], {}) end
  -- 自身暗置时应按公开标记预测为魏；魏不计入 X，故是汉、蜀、群三个势力。
  lu.assertEquals(secretMinimum(p1()), 3)
  asClient(room, function(clients)
    local me = clients[1]
    lu.assertNil(me.room)
    lu.assertEquals(me.kingdom, "unknown")
    lu.assertEquals(me:getMark("__heg_kingdom"), "wei")
    local skill = Fk.skills[MZ]
    lu.assertEquals(skill:getMinCardNum(me), 3)
    lu.assertTrue(skill:canUse(me))
    lu.assertEquals(skill:prompt(me), "#hanjin__skill_han001_2-prompt:::3")
  end)
end

function Testhanjin_han001:testMZ33ClientRecipientClickReplacesPreviousSelection()
  local room = FkTest.room
  local ids = setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" } })
  asClient(room, function(clients)
    local me, first, second = clients[1], clients[2], clients[3]
    local skill = Fk.skills[MZ]
    -- 技能严格只允许一名收牌者；汉晋客户端将新点击解释为替换。
    lu.assertTrue(skill:targetFilter(me, first, {}, ids))
    lu.assertFalse(skill:targetFilter(me, second, { first }, ids))

    -- 只登记一个共享 Engine 的 boardgame；汉晋与上游国战指向同一注册。
    local base = Fk:getBoardGame("new_heg_mode")
    local board = Fk:getBoardGame("hanjin_heg_mode")
    lu.assertIs(board, base)
    lu.assertIs(board.engine, Fk)
    lu.assertIs(board.client_klass, require "packages.hanjin.pkg.hanjin_mode.client")
    lu.assertNil(Fk.boardgames.hanjin)

    local function handlerFor(handlerClass, mode)
      room.settings.gameMode = mode
      local handler = handlerClass:new(me, { MZ, "", true, {} })
      handler.skill_name = MZ
      handler:setup()
      for _, id in ipairs(ids) do
        handler:update("CardItem", id, "click", { selected = true })
      end
      return handler
    end

    local client = board.client_klass:new(ClientInstance.client)
    for _, handlerClass in ipairs({ client.request_handlers.PlayCard,
      client.request_handlers.AskForUseActiveSkill }) do
      -- 汉晋房间：点击新收牌者替换旧收牌者。
      local handler = handlerFor(handlerClass, "hanjin_heg_mode")
      handler:update("Photo", first.id, "click", { selected = true })
      lu.assertEquals(handler.selected_targets, { first.id })
      lu.assertTrue(handler:feasible())
      lu.assertTrue(handler:targetValidity(second.id))
      handler:update("Photo", second.id, "click", { selected = true })
      lu.assertEquals(handler.selected_targets, { second.id })
      lu.assertEquals(handler.pendings, ids)
      lu.assertFalse(handler.scene:getAllItems("Photo")[first.id].selected)
      lu.assertTrue(handler.scene:getAllItems("Photo")[second.id].selected)
      lu.assertTrue(handler:feasible())
      -- 非法目标不应取消当前合法选择；再次点击已选角色仍可取消。
      handler:update("Photo", me.id, "click", { selected = true })
      lu.assertEquals(handler.selected_targets, { second.id })
      handler:update("Photo", second.id, "click", { selected = false })
      lu.assertEquals(handler.selected_targets, {})
      lu.assertFalse(handler:feasible())
      handler:_finish()

      -- 普通上游国战沿用原请求类：第二次点击是追加，不是替换。
      local normal = handlerFor(handlerClass, "new_heg_mode")
      normal:update("Photo", first.id, "click", { selected = true })
      normal:update("Photo", second.id, "click", { selected = true })
      lu.assertEquals(normal.selected_targets, { first.id, second.id })
      normal:_finish()
    end
    room.settings.gameMode = "hanjin_heg_mode"
  end)
end

return { name = "hanjin_han001" }
