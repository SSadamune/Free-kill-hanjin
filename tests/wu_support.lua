-- 吴势力标准包：主动与支持组 9 技能定向验证。
-- 规则依据：rules/standard-generals.md 吴区、rules/generals/wu005-zhouyu.md、
-- rules/generals/wu015a-zhangzhao.md、rules/equipment-movement.md。
-- 夹具使用白板双将并重算 hp，避免随机初始双将的额外触发干扰。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")

local ZHI = "hanjin__skill_wu001_1"
local QI = "hanjin__skill_wu002_1"
local YINGZI = "hanjin__skill_wu005_1"
local FANJIAN = "hanjin__skill_wu005_2"
local JIEYIN = "hanjin__skill_wu008_1"
local XIAOJI = "hanjin__skill_wu008_2"
local YINGHUN = "hanjin__skill_wu009_1"
local ZHIJIAN = "hanjin__skill_wu015a_1"
local GUZHENG = "hanjin__skill_wu015a_2"

local DEFAULT_KINGDOMS = { "wu", "wu", "wu", "wu", "wu", "wu", "wu", "wu" }

local function room() return FkTest.room end
local function p(n) return room().players[n] end

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function grant(player, name)
  inRoom(function() player.room:handleAddLoseSkills(player, name, nil, false, true) end)
end

local function clearCards(player)
  inRoom(function()
    local ids = player:getCardIds("he")
    if #ids > 0 then
      room():moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false)
    end
  end)
end

local function give(player, name, suit, number)
  local id
  inRoom(function()
    local card = room():printCard(name, suit or Card.Spade, number or 7)
    room():obtainCard(player, card, false, fk.ReasonJustMove)
    id = card.id
  end)
  return id
end

local function setHand(player, specs)
  clearCards(player)
  local ids = {}
  inRoom(function()
    for _, spec in ipairs(specs or {}) do
      local card = room():printCard(spec[1], spec[2] or Card.Spade, spec[3] or 1)
      room():obtainCard(player, card, false, fk.ReasonJustMove)
      table.insert(ids, card.id)
    end
  end)
  return ids
end

local function equip(player, id)
  inRoom(function() room():moveCardIntoEquip(player, id, "test", true, player) end)
end

local function activate(player, name, targets, cards)
  inRoom(function()
    room():handleUseCardReply(player, FkTest.ReplyUseSkill(name, targets, cards or {}))
  end)
end

local function setPlayPhase(player)
  inRoom(function()
    room().current = player
    player.phase = Player.Play
    room():setBanner("RoundCount", 1)
  end)
end

local function initializeGenerals(room)
  inRoom(function() skill_test.installBlankGenerals(room, DEFAULT_KINGDOMS) end)
end

local function prepare()
  local r = support.initHanjinRoom()
  initializeGenerals(r)
  return r
end

--- 构造真实 ClientPlayer（没有 room 字段），临时让 Fk:currentRoom() 返回
--- 客户端房间，覆盖客户端可用性/筛选回调。与服务端房间的公共字段共用，
--- players/alive_players 使用客户端副本。
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

Testhanjin_wu_support = {}
Testhanjin_wu_support.setup = prepare
Testhanjin_wu_support.tearDown = support.clearRoom

function Testhanjin_wu_support:testZhihengLimitAndAllHandExtraDraw()
  local p1 = p(1)
  grant(p1, ZHI)
  local hand = setHand(p1, {
    { "hanjin__jink", Card.Spade, 1 },
    { "hanjin__jink", Card.Heart, 2 },
    { "hanjin__jink", Card.Club, 3 },
    { "hanjin__jink", Card.Diamond, 4 },
    { "hanjin__slash", Card.Spade, 5 },
  })
  setPlayPhase(p1)
  activate(p1, ZHI, {}, { hand[1], hand[2], hand[3], hand[4] })
  -- 至多 X=4 张；弃 4 留 1 再摸 4。
  lu.assertEquals(#p1:getCardIds("h"), 5)
end

function Testhanjin_wu_support:testZhihengDiscardingAllHandDrawsOneExtra()
  local p1 = p(1)
  grant(p1, ZHI)
  local hand = setHand(p1, {
    { "hanjin__jink", Card.Spade, 1 },
    { "hanjin__jink", Card.Heart, 2 },
    { "hanjin__slash", Card.Club, 3 },
  })
  setPlayPhase(p1)
  activate(p1, ZHI, {}, hand)
  -- 弃光全部 3 张手牌，摸 3+1。
  lu.assertEquals(#p1:getCardIds("h"), 4)
end

function Testhanjin_wu_support:testYingziDrawAndHandLimit()
  local p1 = p(1)
  grant(p1, YINGZI)
  inRoom(function() p1.hp = 2 end)
  lu.assertEquals(inRoom(function() return p1:getMaxCards() end), p1.maxHp)
  local n
  inRoom(function()
    local data = { n = 2 }
    room().logic:trigger(fk.DrawNCards, p1, data)
    n = data.n
  end)
  lu.assertEquals(n, 3)
end

function Testhanjin_wu_support:testYinghunDrawThenDiscard()
  local p1, p2 = p(1), p(2)
  grant(p1, YINGHUN)
  clearCards(p2)
  inRoom(function()
    p1.maxHp = 4
    p1.hp = 2
    p1.phase = Player.Start
  end)
  local oldChoose, oldChoice, oldDiscard = room().askToChoosePlayers, room().askToChoice, room().askToDiscard
  skill_test.withSkillRequests(room(), YINGHUN, {
    askToChoosePlayers = function(self, player, params) return { p2 } end,
    askToChoice = function(self, player, params) return "#hanjin__skill_wu009_1-draw" end,
    askToDiscard = function(self, player, params)
      local id = player:getCardIds("h")[1]
      self:throwCard({ id }, params.skill_name, player, player)
      return { id }
    end,
  }, function()
    inRoom(function()
      room().logic:trigger(fk.EventPhaseStart, p1, PhaseData:new {
        who = p1, reason = "game_rule", phase = Player.Start,
      })
    end)
  end)
  lu.assertIs(room().askToChoosePlayers, oldChoose)
  lu.assertIs(room().askToChoice, oldChoice)
  lu.assertIs(room().askToDiscard, oldDiscard)
  -- X=2：摸 2 后弃 1，净得 1 张。
  lu.assertEquals(#p2:getCardIds("h"), 1)
end

function Testhanjin_wu_support:testFanjianAcceptDiscardsHandAndEquip()
  local p1, p2 = p(1), p(2)
  grant(p1, FANJIAN)
  clearCards(p1)
  clearCards(p2)
  local shown = give(p1, "hanjin__jink", Card.Spade, 7)
  give(p2, "hanjin__jink", Card.Spade, 3)
  give(p2, "hanjin__jink", Card.Spade, 4)
  give(p2, "hanjin__slash", Card.Club, 5)
  local spadeEquip = give(p2, "hanjin__qinggang_sword", Card.Spade, 6)
  equip(p2, spadeEquip)
  setPlayPhase(p1)

  local oldShow, oldChoice = room().showCards, room().askToChoice
  local showedEquip = false
  room().showCards = function(self, cards, from, proposer)
    if from == p2 then
      for _, id in ipairs(Card:getIdList(cards)) do
        if table.contains(p2:getCardIds("e"), id) then showedEquip = true end
      end
    end
    return oldShow(self, cards, from, proposer)
  end
  room().askToChoice = function(self, player, params)
    if params.skill_name ~= FANJIAN then return oldChoice(self, player, params) end
    lu.assertIs(player, p2)
    lu.assertEquals(#params.choices, 2)
    return "#hanjin__skill_wu005_2-accept"
  end
  local ok, err = pcall(function() activate(p1, FANJIAN, { p2 }, { shown }) end)
  room().showCards, room().askToChoice = oldShow, oldChoice
  assert(ok, err)

  -- 展示的是手牌，不含装备；弃置范围含 3 张黑桃手牌 + 1 张黑桃装备。
  lu.assertFalse(showedEquip)
  lu.assertEquals(#p2:getCardIds("h"), 1) -- 仅剩非黑桃【杀】
  lu.assertEquals(#p2:getCardIds("e"), 0)
  lu.assertEquals(p2.hp, p2.maxHp)
end

function Testhanjin_wu_support:testFanjianCanRefuseAndLoseHp()
  local p1, p2 = p(1), p(2)
  grant(p1, FANJIAN)
  clearCards(p1)
  clearCards(p2)
  local shown = give(p1, "hanjin__jink", Card.Heart, 7)
  give(p2, "hanjin__jink", Card.Heart, 3)
  give(p2, "hanjin__jink", Card.Heart, 4)
  setPlayPhase(p1)
  inRoom(function() p2.hp = p2.maxHp end)

  local oldChoice = room().askToChoice
  room().askToChoice = function(self, player, params)
    if params.skill_name ~= FANJIAN then return oldChoice(self, player, params) end
    return "#hanjin__skill_wu005_2-lose"
  end
  local ok, err = pcall(function() activate(p1, FANJIAN, { p2 }, { shown }) end)
  room().askToChoice = oldChoice
  assert(ok, err)
  lu.assertEquals(p2.hp, p2.maxHp - 1)
  lu.assertEquals(#p2:getCardIds("h"), 3) -- 展示牌已交给其，未弃置
end

function Testhanjin_wu_support:testFanjianMainPlaceData()
  lu.assertTrue(Fk.skills[FANJIAN]:hasTag(Skill.MainPlace))
  local general = Fk.generals["hanjin__wu005"]
  lu.assertEquals(general.mainMaxHpAdjustedValue, -1)
  lu.assertEquals(general.deputyMaxHpAdjustedValue, 0)
end

function Testhanjin_wu_support:testJieyinPlacesEquipFromHandAndDrawer()
  local p1, p2 = p(1), p(2)
  grant(p1, JIEYIN)
  clearCards(p1)
  clearCards(p2)
  inRoom(function() p1.hp = 3; p2.hp = 2 end)
  local sword = give(p1, "hanjin__qinggang_sword", Card.Spade, 5)
  setPlayPhase(p1)

  local oldChoice, oldAsk = room().askToChoice, room().askToChooseCards
  room().askToChoice = function(self, player, params)
    if params.skill_name ~= JIEYIN then return oldChoice(self, player, params) end
    return "#hanjin__skill_wu008_1-place"
  end
  room().askToChooseCards = function(self, player, params)
    if params.skill_name ~= JIEYIN then return oldAsk(self, player, params) end
    return { sword }
  end
  local ok, err = pcall(function() activate(p1, JIEYIN, { p2 }, {}) end)
  room().askToChoice, room().askToChooseCards = oldChoice, oldAsk
  assert(ok, err)

  -- 手牌来源置入目标空栏；你体力较大，你摸，其回复。
  lu.assertEquals(room():getCardOwner(sword).id, p2.id)
  lu.assertEquals(room():getCardArea(sword), Card.PlayerEquip)
  lu.assertEquals(#p1:getCardIds("h"), 1)
  lu.assertEquals(p2.hp, 3)
end

function Testhanjin_wu_support:testXiaojiDrawsMoreOutsideOwnTurn()
  local p1, p2 = p(1), p(2)
  grant(p2, XIAOJI)
  clearCards(p2)
  inRoom(function() p2.hp = p2.maxHp end)
  local oldInvoke = room().askToSkillInvoke
  room().askToSkillInvoke = function() return true end

  local out = give(p2, "hanjin__qinggang_sword", Card.Spade, 5)
  equip(p2, out)
  inRoom(function() room().current = p1 end)
  local before = #p2:getCardIds("h")
  inRoom(function() room():throwCard({ out }, "test", p2, p2) end)
  lu.assertEquals(#p2:getCardIds("h"), before + 2)

  local inside = give(p2, "hanjin__eight_diagram", Card.Heart, 2)
  equip(p2, inside)
  inRoom(function() room().current = p2 end)
  before = #p2:getCardIds("h")
  inRoom(function() room():throwCard({ inside }, "test", p2, p2) end)
  lu.assertEquals(#p2:getCardIds("h"), before + 1)
  room().askToSkillInvoke = oldInvoke
end

function Testhanjin_wu_support:testZhijianHandAndEquipSources()
  local p1, p2 = p(1), p(2)
  grant(p1, ZHIJIAN)
  clearCards(p1)
  clearCards(p2)
  local fromHand = give(p1, "hanjin__qinggang_sword", Card.Spade, 5)
  setPlayPhase(p1)
  activate(p1, ZHIJIAN, { p2 }, { fromHand })
  lu.assertEquals(room():getCardOwner(fromHand).id, p2.id)
  lu.assertEquals(room():getCardArea(fromHand), Card.PlayerEquip)
  lu.assertEquals(#p1:getCardIds("h"), 1) -- 手牌来源：你摸

  local fromEquip = give(p1, "hanjin__eight_diagram", Card.Heart, 2)
  equip(p1, fromEquip)
  local beforeP2 = #p2:getCardIds("h")
  activate(p1, ZHIJIAN, { p2 }, { fromEquip })
  lu.assertEquals(room():getCardOwner(fromEquip).id, p2.id)
  lu.assertEquals(#p2:getCardIds("h"), beforeP2 + 1) -- 装备来源：其摸
end

function Testhanjin_wu_support:testGuzhengGivesOneAndTakesUpToThree()
  local p1, p2 = p(1), p(2)
  grant(p1, GUZHENG)
  clearCards(p1)
  clearCards(p2)
  local ids = setHand(p2, {
    { "hanjin__slash", Card.Spade, 1 },
    { "hanjin__jink", Card.Heart, 2 },
    { "hanjin__jink", Card.Club, 3 },
    { "hanjin__slash", Card.Diamond, 4 },
  })
  inRoom(function() p1.hp = p1.maxHp end)

  local oldInvoke, oldAsk = room().askToSkillInvoke, room().askToChooseCards
  local askCount = 0
  room().askToSkillInvoke = function(self, player, params)
    if params.skill_name ~= GUZHENG then return oldInvoke(self, player, params) end
    return true
  end
  room().askToChooseCards = function(self, player, params)
    if params.skill_name ~= GUZHENG then return oldAsk(self, player, params) end
    askCount = askCount + 1
    if askCount == 1 then return { ids[1] } end
    return { ids[2], ids[3], ids[4] }
  end
  local ok, err = pcall(function()
    inRoom(function() room():throwCard(ids, "test", p2, p2) end)
  end)
  room().askToSkillInvoke, room().askToChooseCards = oldInvoke, oldAsk
  assert(ok, err)

  lu.assertEquals(#p2:getCardIds("h"), 1)
  lu.assertEquals(#p1:getCardIds("h"), 3)
end

function Testhanjin_wu_support:testGuzhengChoosesOwnerWhenMultipleDiscarders()
  local p1, p2, p3 = p(1), p(2), p(3)
  grant(p1, GUZHENG)
  clearCards(p1)
  local ids2 = setHand(p2, {
    { "hanjin__slash", Card.Spade, 1 },
    { "hanjin__jink", Card.Heart, 2 },
  })
  local ids3 = setHand(p3, {
    { "hanjin__slash", Card.Club, 3 },
    { "hanjin__jink", Card.Diamond, 4 },
  })
  inRoom(function() p1.hp = p1.maxHp end)

  local oldInvoke, oldChoose, oldAsk = room().askToSkillInvoke, room().askToChoosePlayers, room().askToChooseCards
  local askCount, ownerAsked = 0, false
  room().askToSkillInvoke = function(self, player, params)
    if params.skill_name ~= GUZHENG then return oldInvoke(self, player, params) end
    return true
  end
  room().askToChoosePlayers = function(self, player, params)
    if params.skill_name ~= GUZHENG then return oldChoose(self, player, params) end
    ownerAsked = true
    lu.assertEquals(#params.targets, 2)
    return { p3 }
  end
  room().askToChooseCards = function(self, player, params)
    if params.skill_name ~= GUZHENG then return oldAsk(self, player, params) end
    askCount = askCount + 1
    if askCount == 1 then return { ids3[1] } end
    return { ids3[2] }
  end
  local ok, err = pcall(function()
    inRoom(function()
      room():moveCards({
        ids = ids2, from = p2, toArea = Card.DiscardPile,
        moveReason = fk.ReasonDiscard, proposer = p2,
      }, {
        ids = ids3, from = p3, toArea = Card.DiscardPile,
        moveReason = fk.ReasonDiscard, proposer = p3,
      })
    end)
  end)
  room().askToSkillInvoke, room().askToChoosePlayers, room().askToChooseCards = oldInvoke, oldChoose, oldAsk
  assert(ok, err)

  lu.assertTrue(ownerAsked)
  lu.assertEquals(#p2:getCardIds("h"), 0)
  lu.assertEquals(#p3:getCardIds("h"), 1)
  lu.assertEquals(#p1:getCardIds("h"), 1)
  lu.assertEquals(room():getCardArea(ids2[1]), Card.DiscardPile)
  lu.assertEquals(room():getCardArea(ids2[2]), Card.DiscardPile)
end

function Testhanjin_wu_support:testJieyinClientCanUseWithoutRoom()
  local p1 = p(1)
  grant(p1, JIEYIN)
  clearCards(p1)
  clearCards(p(2))
  local sword = give(p1, "hanjin__qinggang_sword", Card.Spade, 5)

  asClient(room(), function(clients)
    local me = clients[1]
    lu.assertNil(me.room)
    local skill = Fk.skills[JIEYIN]
    lu.assertTrue(skill:canUse(me))
    lu.assertTrue(skill:targetFilter(me, clients[2], {}, { sword }))
  end)
end

function Testhanjin_wu_support:testZhijianClientCandidatesWithoutRoom()
  local p1 = p(1)
  grant(p1, ZHIJIAN)
  clearCards(p1)
  clearCards(p(2))
  local sword = give(p1, "hanjin__qinggang_sword", Card.Spade, 5)

  asClient(room(), function(clients)
    local me = clients[1]
    lu.assertNil(me.room)
    local skill = Fk.skills[ZHIJIAN]
    lu.assertTrue(skill:canUse(me))
    lu.assertTrue(skill:cardFilter(me, sword, {}, {}))
    lu.assertTrue(skill:targetFilter(me, clients[2], {}, { sword }))
  end)
end

function Testhanjin_wu_support:testQixiViewAsDismantlement()
  local p1 = p(1)
  grant(p1, QI)
  local black = give(p1, "hanjin__slash", Card.Spade, 9)
  local card = Fk.skills[QI]:viewAs(p1, { black })
  lu.assertNotNil(card)
  lu.assertEquals(card.name, "hanjin__dismantlement")
  lu.assertEquals(card.skillName, QI)
end

return { name = "hanjin_wu_support" }
