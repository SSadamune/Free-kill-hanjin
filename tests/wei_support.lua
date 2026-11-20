-- 魏标准包：持重、突袭、放逐定向验收文件。
-- 规则依据：docs/rules/standard-generals.md 魏区、docs/rules/generals/wei014-caopi.md、
-- rulebook/terms/general-op-terms/stack.md、docs/development/implementation/only-as.md。
-- 此前已定向运行本文件（真实伤害/翻面/请求入口，无 mock）：
--   python scripts/test.py --file tests/wei_support.lua --timeout 180
local support = __dofile("../../../tests/support/hegemony.lua")
local O = require "packages.qiao.pkg.qiao_mode.rules.only_as"

local CHIZHONG = "qiao__skill_wei003_2"
local TUXI = "qiao__skill_wei004_1"
local TUXI_STATE = "qiao__wei_tuxi_state"
local TUXI_MARK = "@qiao_tuxi_slash-turn-inhand"
local FANGZHU = "qiao__skill_wei014_2"

local DEFAULT_KINGDOMS = { "wei", "wei", "wei", "wei", "wei", "wei", "wei", "wei" }

Testqiao_wei_support = {}

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

--- 走完整突袭摸牌流程：少摸2张、各获得 p2/p3 一张并展示。
--- @param onNotify? fun(command: string, data: table, players: table[])
--- @return integer, integer 获得的牌（按排序后的 p2、p3 顺序）
local function tuxiDraw(room, onNotify)
  grant(p(1), TUXI)
  setHand(room, p(1), {})
  local c2 = setHand(room, p(2), { { "qiao__jink", Card.Heart, 2 } })[1]
  local c3 = setHand(room, p(3), { { "qiao__peach", Card.Diamond, 3 } })[1]

  local data = DrawNCardsData:new {
    who = p(1),
    reason = "game_rule",
    phase = Player.Draw,
    n = 2,
  }
  -- 获得顺序按当前回合角色起逆时针；按实际排序准备对应目标的手牌回复。
  local order = { p(2), p(3) }
  inRoom(function() room:sortByAction(order) end)
  local replies = { FkTest.ReplyChoosePlayer({ p(2), p(3) }) }
  for _, target in ipairs(order) do
    table.insert(replies, target == p(2) and c2 or c3)
  end
  table.insert(replies, "1")
  FkTest.setNextReplies(p(1), replies)
  local choosePrompt
  FkTest.setRoomBreakpoint(p(1), "AskForUseActiveSkill", function(data)
    if data[2] and data[2]:startsWith("#" .. TUXI .. "-choose:") then
      choosePrompt = data[2]
    end
    return false
  end)
  inRoom(function()
    local original = room.doBroadcastNotify
    if onNotify ~= nil then
      room.doBroadcastNotify = function(self, command, payload, players)
        onNotify(command, payload, players)
        return original(self, command, payload, players)
      end
    end
    room.logic:trigger(fk.DrawNCards, p(1), data)
    room.doBroadcastNotify = original
  end)
  lu.assertEquals(choosePrompt, "#" .. TUXI .. "-choose:::2")
  return c2, c3
end

--- 正式客户端的普通出牌请求类（汉晋模式覆盖后的 QiaoPlayCard）。
local function qiaoPlayCardClass()
  local board = assert(Fk:getBoardGame("qiao_heg_mode"), "缺少汉晋模式")
  local client = board.client_klass:new(ClientInstance.client)
  return client.request_handlers.PlayCard
end

--- 实体牌标记保存在 Fk:currentRoom().card_marks，必须在房间上下文读取。
local function markOf(id)
  local value
  inRoom(function() value = Fk:getCardById(id):getMark(TUXI_MARK) end)
  return value
end

local function initializeGenerals(room)
  inRoom(function()
    for i, pl in ipairs(room.players) do
      local kingdom = DEFAULT_KINGDOMS[i] or "wei"
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
      -- changeHero 期间 getGeneralMaxHp() 读取的是 __heg_general/__heg_deputy
      -- 标记；若标记仍指向开局随机双将，则本测试的体力上限会随初始双将变化。
      -- 标记写入测试双将后重算，确保夹具固定为测试将面。
      pl.maxHp = pl:getGeneralMaxHp()
      pl.hp = pl.maxHp
    end
  end)
end

local function prepare()
  local room = support.initQiaoRoom()
  initializeGenerals(room)
  return room
end

Testqiao_wei_support.setup = function() prepare() end
Testqiao_wei_support.tearDown = support.clearRoom

function Testqiao_wei_support:testChizhongCanCancelAndDistributesExactExcess()
  local room = FkTest.room
  grant(p(1), CHIZHONG)
  local hand = setHand(room, p(1), {
    { "qiao__slash", Card.Spade, 1 },
    { "qiao__jink", Card.Heart, 2 },
    { "qiao__peach", Card.Diamond, 3 },
    { "qiao__duel", Card.Club, 4 },
  })
  setHand(room, p(2), {})
  -- 其他角色处于摸牌阶段、自己不在摸牌阶段：持重仍可发动。
  inRoom(function()
    room.current = p(2)
    p(2).phase = Player.Draw
    p(1).phase = Player.NotActive
    room:setBanner("RoundCount", 1)
  end)

  FkTest.setNextReplies(p(1), { "" })
  inRoom(function()
    local card = room:printCard("qiao__dismantlement", Card.Spade, 5)
    room:obtainCard(p(1), card, false, fk.ReasonJustMove)
  end)
  lu.assertEquals(#p(1):getCardIds(Player.Hand), 5)
  lu.assertEquals(#p(2):getCardIds(Player.Hand), 0)
  lu.assertEquals(p(1):usedSkillTimes(CHIZHONG, Player.HistoryTurn), 0)

  local given = { hand[1], hand[2] }
  FkTest.setNextReplies(p(1), {
    FkTest.ReplyChooseCards(given),
    FkTest.ReplyChooseCardAndPlayers({ p(2) }, given),
  })
  inRoom(function()
    local card = room:printCard("qiao__peach", Card.Heart, 6)
    room:obtainCard(p(1), card, false, fk.ReasonJustMove)
  end)

  lu.assertEquals(#p(1):getCardIds(Player.Hand), 4)
  lu.assertItemsEquals(p(2):getCardIds(Player.Hand), given)
  lu.assertEquals(p(1):usedSkillTimes(CHIZHONG, Player.HistoryTurn), 1)
end

-- 突袭：少摸等量张并获得手牌；展示后仅当杀，失技能不撤销 -----------------
function Testqiao_wei_support:testTuxiDrawReductionAndTurnRestriction()
  local room = FkTest.room
  grant(p(1), TUXI)
  setHand(room, p(1), {})
  local c2 = setHand(room, p(2), { { "qiao__jink", Card.Heart, 2 } })[1]
  local c3 = setHand(room, p(3), { { "qiao__peach", Card.Diamond, 3 } })[1]

  local data = DrawNCardsData:new {
    who = p(1),
    reason = "game_rule",
    phase = Player.Draw,
    n = 2,
  }
  -- 获得顺序按当前回合角色起逆时针；按实际排序准备对应目标的手牌回复。
  local order = { p(2), p(3) }
  inRoom(function() room:sortByAction(order) end)
  local replies = { FkTest.ReplyChoosePlayer({ p(2), p(3) }) }
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
  lu.assertTrue(table.contains(O.availableTargets(room, p(1), c2, "use"), "qiao__slash"))

  -- 失去技能不取消已产生的本回合限制；独立状态继续提供转换入口。
  inRoom(function()
    room:handleAddLoseSkills(p(1), "-" .. TUXI, nil, false, true)
  end)
  lu.assertTrue(p(1):hasSkill(TUXI_STATE), "失去突袭不应移除已建立的回合状态")
  lu.assertTrue(O.isForbidden(p(1), Fk:getCardById(c2)))
  lu.assertTrue(table.contains(O.availableTargets(room, p(1), c2, "use"), "qiao__slash"))
end

-- 突袭：真实客户端 PlayCard / 响应 handler 的入口、材料与虚拟杀 -------------
function Testqiao_wei_support:testTuxiStateClientEntriesAndHandHint()
  local room = FkTest.room
  local hintAudience = {}
  local c2, c3 = tuxiDraw(room, function(command, payload, players)
    if command == "SetCardMark" and payload[2] == TUXI_MARK then
      table.insert(hintAudience, players)
    end
  end)
  local p1 = p(1)
  lu.assertTrue(p1:hasSkill(TUXI_STATE), "展示后应挂上突袭回合状态")
  lu.assertNotEquals(Fk:translate(TUXI_MARK), TUXI_MARK, "卡面提示缺本地化")
  lu.assertTrue(markOf(c2) ~= 0, "本次获得的牌应有卡面提示")
  lu.assertTrue(markOf(c3) ~= 0, "本次获得的牌应有卡面提示")
  lu.assertEquals(#hintAudience, 2, "只应为本次获得的两张牌发送提示")
  for _, players in ipairs(hintAudience) do
    lu.assertEquals(#players, 1, "提示只能通知持有者")
    lu.assertEquals(players[1].id, p1.id, "提示只能通知持有者")
  end

  -- 其他手牌不属于本次来源，不得提示，也不得通过突袭入口转换。
  local extra
  inRoom(function()
    extra = room:printCard("qiao__slash", Card.Spade, 9)
    room:obtainCard(p1, extra, false, fk.ReasonJustMove)
  end)
  lu.assertEquals(markOf(extra.id), 0, "其他手牌不应有提示")

  local got = {}
  FkTest.runInClient(function()
    -- 测试后端不重放增量通知；按真实公开数据补客户端手牌、来源 mark 与新增技能。
    Self.player_cards[Player.Hand] = table.simpleClone(p1:getCardIds(Player.Hand))
    Self.mark[O.SOURCE_MARK] = p1:getMark(O.SOURCE_MARK)
    Self.player_skills = table.simpleClone(Self.player_skills or {})
    table.insertIfNeed(Self.player_skills, Fk.skills[TUXI_STATE])

    local handler = qiaoPlayCardClass():new(Self)
    handler.extra_data = handler.extra_data or {}
    got.playButton = handler:skillButtonValidity(TUXI_STATE)
    handler:selectSkill(TUXI_STATE, { selected = true })
    got.playMaterial = handler:cardValidity(c2)
    got.playOther = handler:cardValidity(extra.id)
    handler:selectCard(c2, { selected = true })
    local card = handler:getUsingCard()
    got.playName = card and card.trueName or nil
    got.playSubcards = card and table.simpleClone(card.subcards) or nil
    got.prompt = handler.prompt

    -- 伪客户端 SetCardMark 接线：在客户端上下文保存标记并发出 @ 标记 UI 通知；
    -- 服务端标记存放在房间 card_marks，客户端回调不能用来代替该断言。
    local markUi = false
    local originalNotify = ClientInstance.notifyUI
    ClientInstance.notifyUI = function(instance, command, data)
      if command == "SetCardMark" and data[2] == TUXI_MARK then markUi = true end
      return originalNotify(instance, command, data)
    end
    ClientInstance:setCardMark({ c2, TUXI_MARK, Fk.skill_skels[TUXI_STATE].MARK_VALUE })
    ClientInstance.notifyUI = originalNotify
    got.clientMark = Fk:getCardById(c2):getMark(TUXI_MARK)
    got.clientMarkUi = markUi
    Fk:getCardById(c2):setMark(TUXI_MARK, 0)

    Fk.currentResponsePattern = "slash"
    ClientInstance:setupRequestHandler(Self, "AskForResponseCard", { "", "slash", "", true, {} })
    local response = ClientInstance.current_request_handler
    got.responseButton = response:skillButtonValidity(TUXI_STATE)
    response:selectSkill(TUXI_STATE, { selected = true })
    got.responseMaterial = response:cardValidity(c3)
    response:selectCard(c3, { selected = true })
    local respondCard = response:getUsingCard()
    got.responseName = respondCard and respondCard.trueName or nil
    got.responseSubcards = respondCard and table.simpleClone(respondCard.subcards) or nil

    -- 突袭只提供【杀】：要求【闪】的响应窗口不得亮起该入口。
    Fk.currentResponsePattern = "jink"
    ClientInstance:setupRequestHandler(Self, "AskForResponseCard", { "", "jink", "", true, {} })
    got.jinkButton = ClientInstance.current_request_handler:skillButtonValidity(TUXI_STATE)

    ClientInstance.current_request_handler = nil
    Fk.currentResponsePattern = nil
  end)

  lu.assertTrue(got.playButton, "出牌阶段应出现突袭转换按钮")
  lu.assertTrue(got.playMaterial, "本次获得的牌应可选")
  lu.assertFalse(got.playOther, "其他手牌不应通过突袭转换")
  lu.assertEquals(got.playName, "slash", "应生成虚拟【杀】")
  lu.assertEquals(got.playSubcards, { c2 }, "虚拟【杀】应使用本次获得的实体牌")
  lu.assertNotNil(got.prompt, "选中突袭入口后应有提示")
  lu.assertTrue(got.responseButton, "响应窗口应出现突袭转换按钮")
  lu.assertTrue(got.responseMaterial, "响应窗口应可选本次获得的牌")
  lu.assertEquals(got.responseName, "slash", "响应应生成虚拟【杀】")
  lu.assertEquals(got.responseSubcards, { c3 })
  lu.assertFalse(got.jinkButton, "要求【闪】的窗口不得提供突袭当杀")
  lu.assertTrue(got.clientMark ~= 0, "伪客户端应保存卡面标记")
  lu.assertTrue(got.clientMarkUi, "伪客户端应发出 @ 标记 UI 通知")

  -- 服务端真实用牌/打出回包：技能名为状态骨架，底牌为本次获得的实体牌。
  local hp = p(2).hp
  local use
  FkTest.setNextReplies(p1, { {
    card = { skill = TUXI_STATE, subcards = { c2 } },
    targets = { p(2).id },
    interaction_data = "qiao__slash",
  } })
  inRoom(function()
    use = room:askToUseCard(p1, {
      pattern = "slash", skill_name = "qiao_test_tuxi_state", cancelable = true,
    })
  end)
  lu.assertNotNil(use)
  lu.assertEquals(use.card.trueName, "slash")
  lu.assertTrue(table.contains(use.card.skillNames, TUXI_STATE))
  inRoom(function() room:useCard(use) end)
  lu.assertEquals(p(2).hp, hp - 1)

  local respond
  FkTest.setNextReplies(p1, { {
    card = { skill = TUXI_STATE, subcards = { c3 } },
    targets = {},
    interaction_data = "qiao__slash",
  } })
  inRoom(function()
    respond = room:askToResponse(p1, {
      pattern = "slash", skill_name = "qiao_test_tuxi_response", cancelable = true,
    })
  end)
  lu.assertNotNil(respond)
  lu.assertEquals(respond.card.trueName, "slash")
  inRoom(function() room:responseCard(respond) end)

  -- 使用/打出离开手牌后，-inhand 由引擎清理提示。
  lu.assertEquals(markOf(c2), 0)
  lu.assertEquals(markOf(c3), 0)
end

-- 突袭：提示离手清理、回合结束移除状态并清掉剩余提示 ----------------------
function Testqiao_wei_support:testTuxiStateHintClearsOnLeaveAndTurnEnd()
  local room = FkTest.room
  local c2, c3 = tuxiDraw(room)
  local p1 = p(1)
  lu.assertTrue(p1:hasSkill(TUXI_STATE))
  lu.assertTrue(markOf(c2) ~= 0)
  lu.assertTrue(markOf(c3) ~= 0)

  -- 转移到其他区域（弃牌堆）时立即清理该牌提示。
  inRoom(function()
    room:moveCardTo(c2, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false)
  end)
  lu.assertEquals(markOf(c2), 0, "离手后应清理提示")

  -- 展示期间被移出的牌不得在 stamp 时补回提示（来源仍含该牌但已不在合法牌区）。
  local resent = 0
  inRoom(function()
    local original = room.doBroadcastNotify
    room.doBroadcastNotify = function(self, command, data, players)
      if command == "SetCardMark" and data[2] == TUXI_MARK then resent = resent + 1 end
      return original(self, command, data, players)
    end
    Fk.skill_skels[TUXI_STATE].stampCards(room, p1, { c2 })
    room.doBroadcastNotify = original
  end)
  lu.assertEquals(resent, 0, "已离手的牌不应补提示")
  lu.assertEquals(markOf(c2), 0, "已离手的牌不应重新带提示")

  -- 回合结束：接口移除状态，并清掉仍在手牌中的提示。
  inRoom(function()
    local event = fk.TurnEnd:new(room, p1, {})
    for _, s in ipairs(room.logic.skill_table[fk.TurnEnd] or {}) do
      local skel = s:getSkeleton()
      if skel ~= nil and skel.name == TUXI_STATE then
        s:trigger(event, p1, p1, {})
      end
    end
  end)
  lu.assertFalse(p1:hasSkill(TUXI_STATE), "回合结束应移除突袭状态")
  lu.assertEquals(markOf(c3), 0, "回合结束应清理剩余提示")
end

-- 放逐：叠置并摸2，足额弃4平置，牌名字数>7失去体力；不足4不进入弃牌分支 --
function Testqiao_wei_support:testFangzhuStackDrawDiscardAndHpLoss()
  local room = FkTest.room
  grant(p(1), FANGZHU)
  -- 连续三次受伤用于覆盖不同分支；固定施放者体力，避免第三次伤害进入濒死。
  inRoom(function()
    p(1).maxHp = 10
    p(1).hp = 10
  end)
  setHand(room, p(1), {})
  local four = setHand(room, p(2), {
    { "qiao__dismantlement", Card.Spade, 1 },
    { "qiao__dismantlement", Card.Heart, 2 },
    { "qiao__duel", Card.Club, 3 },
    { "qiao__duel", Card.Diamond, 4 },
  })
  local hp = p(2).hp

  FkTest.setNextReplies(p(1), { FkTest.ReplyChoosePlayer({ p(2) }) })
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
  setHand(room, p(2), { { "qiao__peach", Card.Heart, 7 } })
  FkTest.setNextReplies(p(1), { FkTest.ReplyChoosePlayer({ p(2) }) })
  inRoom(function() room:damage { from = p(3), to = p(1), damage = 1 } end)
  lu.assertFalse(p(2).faceup)
  lu.assertEquals(p(2).hp, hp2)
  lu.assertEquals(#p(2):getCardIds(Player.Hand), 3) -- 1+摸2

  -- 平置（faceup=true）→叠置（faceup=false）：不足4张不弃牌，但仍摸2。
  inRoom(function()
    if not p(2).faceup then p(2):turnOver() end
  end)
  lu.assertTrue(p(2).faceup)
  setHand(room, p(2), { { "qiao__peach", Card.Heart, 8 } })
  FkTest.setNextReplies(p(1), { FkTest.ReplyChoosePlayer({ p(2) }) })
  inRoom(function() room:damage { from = p(3), to = p(1), damage = 1 } end)
  lu.assertFalse(p(2).faceup)
end

return { name = "qiao_wei_support" }
