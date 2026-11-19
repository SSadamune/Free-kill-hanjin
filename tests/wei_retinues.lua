-- WEI/QUN 翼从：并州狼骑、虎卫军、牛金。定向验收。
-- 2026-11-14 历史运行 3/3；虎卫军第二步改为公开候选选牌
-- （askToChooseCards / AskForCardsChosen）后需重跑本套件。
-- 2026-11-19 牛金自由用牌补充 not_passive、客户端被动牌禁用与服务端注入拒绝。
--   python scripts/test.py --file tests/wei_retinues.lua --timeout 180
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local ReqUseCard = require "ltk.core.request_type.use_card"

local BZ = "qiao__retinue_skill_bingzhou_langqi"
local HW = "qiao__retinue_skill_huweijun"
local NJ = "qiao__retinue_skill_niujin"
local AUX = "choose_players_to_move_card_in_board"

-- p1/p2 魏（发动者与回合结束的同势力目标），p3 群为击杀敌人，
-- p4 蜀保留另一存活势力，避免击杀导致游戏结束或同势力击杀弃牌。
local DEFAULT_KINGDOMS = { "wei", "wei", "qun", "shu", "wei", "wei", "wei", "wei" }

Testqiao_wei_retinues = {}

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function p(n) return FkTest.room.players[n] end
local function p1() return p(1) end
local function p2() return p(2) end
local function p3() return p(3) end
local function p4() return p(4) end

local function clearCards(room, player)
  local ids = player:getCardIds("he")
  if #ids > 0 then
    inRoom(function()
      room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false)
    end)
  end
end

local function setHand(room, player, specs)
  clearCards(room, player)
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

local function clearBoard(room, player)
  local ids = player:getCardIds("ej")
  if #ids > 0 then
    inRoom(function()
      room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false)
    end)
  end
end

--- 真实 ClientPlayer：没有 room 字段，复制牌区后用于验证选人筛选。
--- 参考 tests/qun_basic.lua 的 withClientRoom；退出时恢复 Fk.currentRoom。
local function withClientRoom(current, fn)
  local ClientPlayer = require "ltk.client.clientplayer"
  local clients = {}
  for _, original in ipairs(current.players) do
    local copy = ClientPlayer:new(original._splayer)
    for key, value in pairs(original) do
      if key ~= "room" and key ~= "class" and key ~= "serverplayer" then copy[key] = value end
    end
    local cards = {}
    for area, ids in pairs(copy.player_cards or {}) do cards[area] = table.simpleClone(ids) end
    copy.player_cards = cards
    table.insert(clients, copy)
  end
  for index, player in ipairs(clients) do
    player.next = clients[index % #clients + 1]
  end
  local clientRoom = setmetatable(
    { players = clients, alive_players = clients, current = clients[1] },
    { __index = current })
  local originalRoom = Fk.currentRoom
  Fk.currentRoom = function() return clientRoom end
  local ok, err = pcall(function() fn(clients, clientRoom) end)
  Fk.currentRoom = originalRoom
  if not ok then error(err) end
  return clients, clientRoom
end

--- 在 turnPlayer 的回合内由 from 对 to 造成实际伤害，再走完整 Turn 事件。
local function runTurnEndWithDamage(room, turnPlayer, from, to, amount)
  local probeName = "#qiao_wei_retinue_damage_probe"
  local skel = fk.CreateSkill { name = probeName }
  local done = false
  skel:addEffect(fk.EventPhaseStart, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return not done and target == turnPlayer and target.phase == Player.Start
    end,
    on_refresh = function(self, event, target, player, data)
      done = true
      room:damage { from = from, to = to, damage = amount or 2, skillName = "test" }
    end,
  })
  local probe = skel:createSkill()
  Fk.skills[probeName] = probe
  inRoom(function() room:addSkill(probe) end)
  inRoom(function()
    GameEvent.Turn:create(TurnData:new(turnPlayer, "game_rule", {
      Player.Start, Player.Finish,
    })):exec()
  end)
  return done
end

local function initializeGenerals(room)
  inRoom(function()
    for i, pl in ipairs(room.players) do
      local kingdom = DEFAULT_KINGDOMS[i]
      pl:revealGeneral(false, true)
      pl:revealGeneral(true, true)
      room:changeHero(pl, "qiao_test__" .. kingdom .. "_2", true, true, false, false, false)
      room:changeHero(pl, "qiao_test__" .. kingdom .. "_1", true, false, false, false, false)
      pl.kingdom = kingdom
      room:setPlayerProperty(pl, "kingdom", kingdom)
      room:setPlayerMark(pl, "__heg_general", pl.general)
      room:setPlayerMark(pl, "__heg_deputy", pl.deputyGeneral)
      room:setPlayerMark(pl, "__heg_kingdom", kingdom)
      room:setPlayerMark(pl, "__heg_init_kingdom", kingdom)
      room:setPlayerMark(pl, "__heg_wild", 0)
      -- 标记写入后按白板双将重算体力上限，避免硬编码。
      pl.maxHp = pl:getGeneralMaxHp()
      pl.hp = pl.maxHp
    end
  end)
end

local function grant(player, skillName)
  inRoom(function()
    player.room:handleAddLoseSkills(player, skillName, skillName, false, true)
  end)
end

local function prepare()
  local room = support.initQiaoRoom()
  initializeGenerals(room)
  return room
end

Testqiao_wei_retinues.setup = function() prepare() end
Testqiao_wei_retinues.tearDown = support.clearRoom

--- 记录实际使用事件（用于确认决斗使用者/牛金窗口用牌）。
local function installUseProbe(room, uses)
  local skel = fk.CreateSkill { name = "#qiao_wei_retinue_use_probe" }
  skel:addEffect(fk.CardUseFinished, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return data.card ~= nil
    end,
    on_refresh = function(self, event, target, player, data)
      table.insert(uses, {
        name = data.card.name,
        from = data.from,
        tos = table.simpleClone(data.tos or {}),
      })
    end,
  })
  local skill = skel:createSkill()
  Fk.skills[skel.name] = skill
  inRoom(function() room:addSkill(skill) end)
end

--- 记录牛金奖励实际摸牌（按 move.skillName 去重，每名接收者只统计一次）。
local function installMoveProbe(room, record)
  local skel = fk.CreateSkill { name = "#qiao_wei_retinue_move_probe" }
  skel:addEffect(fk.AfterCardsMove, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      for _, move in ipairs(data or {}) do
        if player == move.to and move.skillName == NJ then return true end
      end
      return false
    end,
    on_refresh = function(self, event, target, player, data)
      for _, move in ipairs(data or {}) do
        if player == move.to and move.skillName == NJ then
          record.moves = record.moves + 1
          record.cards = record.cards + #(move.moveInfo or {})
        end
      end
    end,
  })
  local skill = skel:createSkill()
  Fk.skills[skel.name] = skill
  inRoom(function() room:addSkill(skill) end)
end

function Testqiao_wei_retinues:testBingzhouDuelByTargetFixedDistanceAndOncePerPhase()
  local room = FkTest.room
  grant(p1(), BZ)
  setHand(room, p1(), {})
  setHand(room, p2(), {})
  local uses = {}
  installUseProbe(room, uses)

  inRoom(function()
    local old = p1().phase
    p1().phase = Player.Play
    room:handleUseCardReply(p1(), FkTest.ReplyUseSkill(BZ, { p2() }))
    p1().phase = old
  end)

  -- 决斗由目标角色对并州狼骑持有者使用。
  local duel = table.find(uses, function(use)
    return use.name == "qiao__duel" and use.from == p2()
  end)
  lu.assertNotNil(duel)
  lu.assertIs(duel.tos[1], p1())
  -- 双向距离1，且关系以表记录。
  lu.assertEquals(p1():distanceTo(p2()), 1)
  lu.assertEquals(p2():distanceTo(p1()), 1)
  local pairs = p1():getMark("@[qiao_bingzhou_pairs]")
  lu.assertEquals(type(pairs), "table")
  lu.assertNotNil(table.find(pairs, function(entry)
    return type(entry) == "table" and entry.other == p2().id
  end), "距离关系按翼从实例及对手记录")
  -- 阶段次数限制。
  lu.assertEquals(p1():usedSkillTimes(BZ, Player.HistoryPhase), 1)
  inRoom(function()
    local old = p1().phase
    p1().phase = Player.Play
    lu.assertFalse(Fk.skills[BZ]:canUse(p1()))
    p1().phase = old
  end)
end

function Testqiao_wei_retinues:testHuweijunOtherTurnDamageAllowsMove()
  local room = FkTest.room
  grant(p1(), HW)
  setHand(room, p1(), {})
  setHand(room, p2(), {})
  local equip = addEquip(room, p2(), "qiao__chixiao_sword")
  addEquip(room, p1(), "qiao__vine", Card.Heart, 4)
  -- 在 p2 的真实 Turn 事件范围内由 p1 造成实际伤害；回合末再检查历史。
  local probeName = "#qiao_wei_retinue_turn_damage_probe"
  local skel = fk.CreateSkill { name = probeName }
  local done = false
  skel:addEffect(fk.EventPhaseStart, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return not done and target == p2() and target.phase == Player.Start
    end,
    on_refresh = function(self, event, target, player, data)
      done = true
      room:damage { from = p1(), to = p3(), damage = 2, skillName = "test" }
    end,
  })
  local probe = skel:createSkill()
  Fk.skills[probeName] = probe
  inRoom(function() room:addSkill(probe) end)

  FkTest.setNextReplies(p1(), {
    "1",
    { card = { skill = "choose_players_to_move_card_in_board", subcards = {} },
      targets = { p1().id, p2().id } },
    -- 第二步为公开候选选牌（AskForPoxi / AskForCardsChosen）：回复选中的牌 id。
    { equip },
  })
  inRoom(function()
    GameEvent.Turn:create(TurnData:new(p2(), "game_rule", {
      Player.Start, Player.Finish,
    })):exec()
  end)
  lu.assertTrue(done)
  lu.assertEquals(room:getCardOwner(equip).id, p1().id)
end

function Testqiao_wei_retinues:testNiujinUsesCardKillsAndDrawsThree()
  local room = FkTest.room
  grant(p1(), NJ)
  lu.assertTrue(p1():hasSkill(NJ))
  local slash = setHand(room, p1(), { { "qiao__slash" } })[1]
  addEquip(room, p1(), "qiao__qinggang_sword", Card.Spade, 2)
  setHand(room, p2(), {})
  setHand(room, p3(), {})
  inRoom(function()
    p3().maxHp = p3():getGeneralMaxHp()
    p3().hp = 1
  end)
  local uses = {}
  installUseProbe(room, uses)
  local reward = { moves = 0, cards = 0 }
  installMoveProbe(room, reward)
  FkTest.setNextReplies(p1(), {
    "1",
    { "basic" },
    FkTest.ReplyCard(Fk:getCardById(slash), { p3() }),
    { "#qiao__retinue_skill_niujin-stop" },
  })
  inRoom(function()
    room.logic:trigger(fk.TurnEnd, p2(), TurnData:new(p2(), "game_rule", { Player.Start }))
  end)

  local usedSlash = table.find(uses, function(use)
    return use.name == "qiao__slash" and use.from == p1()
  end)
  lu.assertNotNil(usedSlash)
  lu.assertTrue(p3().dead)
  -- 牛金奖励必须恰好一次、恰好3张；另加标准国战击杀不同势力角色的正常奖励1张。
  lu.assertEquals(reward.moves, 1)
  lu.assertEquals(reward.cards, 3)
  lu.assertEquals(#p1():getCardIds("h"), 4)
  lu.assertEquals(p1():usedSkillTimes(NJ, Player.HistoryGame), 1)
end

--- 自由用牌窗口必须排除无响应时机的被动牌；客户端按同一请求数据禁止【闪】，
--- 服务端即使收到注入的【闪】也按放弃处理，不产生用牌或击杀奖励。
function Testqiao_wei_retinues:testNiujinFreeUseHidesPassiveCardsAndRejectsInjectedJink()
  local room = FkTest.room
  grant(p1(), NJ)
  local ids = setHand(room, p1(), {
    { "qiao__jink", Card.Spade, 6 },
    { "qiao__slash", Card.Spade, 7 },
  })
  local jink, slash = ids[1], ids[2]
  setHand(room, p2(), {})
  setHand(room, p3(), {})
  local uses = {}
  installUseProbe(room, uses)

  local captured
  skill_test.withSkillRequests(room, NJ, {
    askToUseCard = function(self, player, params, original)
      captured = params
      return original(self, player, params)
    end,
  }, function()
    FkTest.setNextReplies(p1(), {
      "1",
      { "basic" },
      FkTest.ReplyCard(Fk:getCardById(jink), {}),
      { "#qiao__retinue_skill_niujin-stop" },
    })
    inRoom(function()
      room.logic:trigger(fk.TurnEnd, p2(), TurnData:new(p2(), "game_rule", { Player.Start }))
    end)
  end)

  lu.assertNotNil(captured, "牛金必须发出真实自由用牌请求")
  lu.assertTrue(captured.extra_data ~= nil and captured.extra_data.not_passive == true,
    "自由用牌请求必须声明 not_passive")
  lu.assertTrue(captured.extra_data.bypass_times == true,
    "效果内用牌仍应绕过通常次数")
  lu.assertTrue(captured.extra_data.extraUse == true,
    "效果内用牌仍不应占通常次数")
  lu.assertTrue(table.contains(p1():getCardIds("h"), jink),
    "服务端应拒绝注入的【闪】，牌留在手牌")
  lu.assertNil(table.find(uses, function(use) return use.name == "qiao__jink" end),
    "被拒绝的【闪】不得产生实际使用事件")

  -- 真实客户端按同一请求数据判断：无响应时机的被动牌不可选，合法基本牌仍可选。
  withClientRoom(room, function(clients)
    local me = clients[1]
    local handler = ReqUseCard:new(me, {
      nil, captured.pattern, "", true, captured.extra_data,
    })
    handler:setup()
    lu.assertFalse(handler:cardValidity(jink),
      "客户端不应允许直接选中无响应时机的【闪】")
    lu.assertTrue(handler:cardValidity(slash), "客户端仍应允许合法基本牌")
    handler:_finish()
  end)
end

-- 选人阶段：真实 ClientPlayer 与客户端房间下，场上无牌的角色不能成为移牌
-- 关系的一端；有两张可互移装备时，第二步只接受确有可移动关系的角色。
function Testqiao_wei_retinues:testHuweijunClientSelectionExcludesEmptyBoardPlayers()
  local room = FkTest.room
  for _, player in ipairs(room.players) do
    clearCards(room, player)
    clearBoard(room, player)
  end
  grant(p1(), HW)
  addEquip(room, p3(), "qiao__chixiao_sword")
  lu.assertIs(type(Fk.skills[AUX]), "table")

  withClientRoom(room, function(clients)
    local me = clients[1]
    lu.assertNil(me.room, "真实 ClientPlayer 不应有 room 字段")
    local aux = assert(Fk.skills[AUX])
    local saved = aux._extra_data
    aux._extra_data = {
      flag = nil,
      excludeIds = {},
      froms = clients,
      tos = clients,
      skillName = HW,
    }
    local ok, err = pcall(function()
      lu.assertFalse(aux:targetFilter(me, clients[1], {}, {}),
        "场上无牌的 p1 不能作为第一个选中者")
      lu.assertFalse(aux:targetFilter(me, clients[2], {}, {}),
        "场上无牌的 p2 不能作为第一个选中者")
      lu.assertTrue(aux:targetFilter(me, clients[3], {}, {}),
        "有装备的 p3 可以作为来源")
      lu.assertTrue(aux:targetFilter(me, clients[1], { clients[3] }, {}),
        "p3 的武器可以移动到空装备栏的 p1")
      lu.assertFalse(aux:targetFilter(me, clients[2], { clients[1] }, {}),
        "p1 场上无牌，不能与 p2 组成移牌对")
    end)
    aux._extra_data = saved
    if not ok then error(err, 0) end
  end)
end

-- 请求级：一对合法角色（各有一张可互移装备）→ 参与角色收窄 → 公开候选
-- 选牌面板（AskForPoxi / AskForCardsChosen）→ 真实移动。
function Testqiao_wei_retinues:testHuweijunCardRequestUsesLegalPairAndMoves()
  local room = FkTest.room
  grant(p1(), HW)
  setHand(room, p1(), {})
  setHand(room, p2(), {})
  local equip = addEquip(room, p2(), "qiao__chixiao_sword")
  addEquip(room, p1(), "qiao__vine", Card.Heart, 4)

  local chooseParams, cardParams
  FkTest.setNextReplies(p1(), {
    "1",
    { card = { skill = AUX, subcards = {} }, targets = { p2().id, p1().id } },
    { equip },
  })
  skill_test.withSkillRequests(room, HW, {
    askToChooseToMoveCardInBoard = function(self, who, params, original)
      chooseParams = params
      return original(self, who, params)
    end,
    askToChooseCards = function(self, who, params, original)
      cardParams = params
      return original(self, who, params)
    end,
  }, function()
    lu.assertTrue(runTurnEndWithDamage(room, p2(), p1(), p3()))
  end)

  lu.assertNotNil(chooseParams, "应真实发起选人请求")
  -- 提示不能为空，且必须解析为真实文案（避免客户端只显示空提示）。
  lu.assertEquals(chooseParams.prompt, "#qiao_wei_move_board")
  local promptText = Fk:translate(chooseParams.prompt)
  lu.assertTrue(promptText:find("移动", 1, true) ~= nil, "选人提示应有本地化文案：" .. promptText)
  -- p1/p2 各有一张可移出的装备；其余角色只有手牌，不再作为第一步来源。
  lu.assertEquals(#chooseParams.froms, 2, "来源候选只保留确有可移动牌的角色")
  lu.assertTrue(table.contains(chooseParams.tos, p1()))
  lu.assertTrue(table.contains(chooseParams.tos, p2()))

  lu.assertNotNil(cardParams, "选定两人后应真实发起公开选牌请求")
  lu.assertEquals(cardParams.skill_name, HW)
  lu.assertEquals(cardParams.min, 1)
  lu.assertEquals(cardParams.max, 1)
  lu.assertEquals(cardParams.cancelable, true)
  lu.assertEquals(cardParams.prompt, "#qiao_move_board_pick")
  local cardPrompt = Fk:translate(cardParams.prompt)
  lu.assertTrue(cardPrompt:find("移动", 1, true) ~= nil, "选牌提示应有本地化文案：" .. cardPrompt)
  -- 候选按来源角色分组：p2 的武器与 p1 的防具都在组内，两个方向都可移动。
  local grouped, groupedCount = {}, 0
  for _, group in ipairs(cardParams.flag.card_data) do
    -- 分组标题只使用座位键，由客户端翻译，不暴露暗置武将。
    lu.assertTrue(type(group[1]) == "string" and group[1]:find("^seat#%d+$") ~= nil,
      "候选分组标题应为座位键：" .. tostring(group[1]))
    for _, id in ipairs(group[2]) do
      if not grouped[id] then groupedCount = groupedCount + 1 end
      grouped[id] = true
    end
  end
  lu.assertTrue(grouped[equip], "p2 的可移动武器应在候选中")
  lu.assertEquals(groupedCount, 2, "两张可互移装备都应作为候选")
  lu.assertEquals(room:getCardOwner(equip).id, p1().id, "引擎应真实移动装备")
end

-- 取消第二步选牌：不移动，询问结束，回合可正常走完。
function Testqiao_wei_retinues:testHuweijunCancelCardChoiceEndsWithoutMove()
  local room = FkTest.room
  grant(p1(), HW)
  setHand(room, p1(), {})
  setHand(room, p2(), {})
  local equip = addEquip(room, p2(), "qiao__chixiao_sword")
  addEquip(room, p1(), "qiao__vine", Card.Heart, 4)

  FkTest.setNextReplies(p1(), {
    "1",
    { card = { skill = AUX, subcards = {} }, targets = { p2().id, p1().id } },
    {}, -- 客户端取消（AskForPoxi rejected → 空选牌）
  })
  lu.assertTrue(runTurnEndWithDamage(room, p2(), p1(), p3()))
  lu.assertEquals(room:getCardOwner(equip).id, p2().id, "取消后不应移动牌")
end

-- 反方向：选中 p1 的装备并移动到 p2，验证两方向都按所选牌的实际来源执行。
function Testqiao_wei_retinues:testHuweijunMovesFromEitherChosenPlayer()
  local room = FkTest.room
  grant(p1(), HW)
  setHand(room, p1(), {})
  setHand(room, p2(), {})
  local weapon = addEquip(room, p2(), "qiao__chixiao_sword")
  local armor = addEquip(room, p1(), "qiao__vine", Card.Heart, 4)

  FkTest.setNextReplies(p1(), {
    "1",
    { card = { skill = AUX, subcards = {} }, targets = { p2().id, p1().id } },
    { armor },
  })
  lu.assertTrue(runTurnEndWithDamage(room, p2(), p1(), p3()))
  lu.assertEquals(room:getCardOwner(armor).id, p2().id, "应把 p1 的防具移到 p2")
  lu.assertEquals(room:getCardOwner(weapon).id, p2().id, "未被选择的装备保持原位")
end

-- 空候选：客户端/旧状态送来一对场上无牌的角色时，不再向客户端发没有候选
-- 牌的移牌弹窗（空面板无法确认），询问可直接结束。
function Testqiao_wei_retinues:testHuweijunPairWithoutBoardCardsEndsWithoutCardRequest()
  local room = FkTest.room
  grant(p1(), HW)
  for _, player in ipairs(room.players) do
    clearCards(room, player)
    clearBoard(room, player)
  end
  -- 场上另有可移动牌（p3/p4），但被选中的 p1/p2 都没有场上牌。
  addEquip(room, p3(), "qiao__vine", Card.Heart, 4)
  addEquip(room, p4(), "qiao__chixiao_sword")

  local cardRequests = 0
  FkTest.setNextReplies(p1(), {
    "1",
    { card = { skill = AUX, subcards = {} }, targets = { p1().id, p2().id } },
  })
  skill_test.withSkillRequests(room, HW, {
    askToChooseCards = function(self, who, params, original)
      cardRequests = cardRequests + 1
      return original(self, who, params)
    end,
  }, function()
    lu.assertTrue(runTurnEndWithDamage(room, p2(), p1(), p3()))
  end)

  lu.assertEquals(cardRequests, 0, "没有可移动牌的一对角色不应收到选牌请求")
end

return { name = "qiao_wei_retinues" }
