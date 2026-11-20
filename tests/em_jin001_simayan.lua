-- EM(JIN001) 君司马炎：登记、诸王敕封册与赐、採幸、鼎沸核心验收。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local DATA = require "packages.qiao.pkg.qiao_bingqing.data.bingqing_lord_jin"
local A = require "packages.qiao.pkg.qiao_mode.rules.ascension"
local Versions = require "packages.qiao.pkg.qiao_mode.rules.general_versions"
local Ban = require "packages.qiao.pkg.qiao_mode.rules.faction_ban"
local content = __dofile("../../../tests/support/ascension_content.lua")

local LORD = "qiao_heg__em_jin001"
local NORMAL = "qiao_heg__jin001"
local TAIKANG = "qiao__skill_em_jin001_1"
local BANNER = "qiao__skill_em_jin001_banner"
local CI_MARK = "@[qiao_ci]"
local CAIXING = "qiao__skill_em_jin001_2"
local DINGFEI = "qiao__skill_em_jin001_3"
local RESOURCE_MAXCARD = "qiao__jin001_banner-resource-maxcard"
local RESOURCE_DRAW = "qiao__jin001_banner-resource-draw"

--- 资源分支按所选赐的牌面单独阴阳鱼数二选一，不再使用笼统的 resource 项。
local function resourceChoice(params)
  if table.contains(params.choices, RESOURCE_MAXCARD) then return RESOURCE_MAXCARD end
  if table.contains(params.choices, RESOURCE_DRAW) then return RESOURCE_DRAW end
  return nil
end

local function inRoom(fn, label)
  local room = FkTest.room
  local entered, completed, result = false, false, nil
  local before = tostring(room.game_finished)
  FkTest.runInRoom(function()
    entered = true
    result = fn()
    completed = true
  end)
  local after = tostring(room.game_finished)
  lu.assertTrue(entered, (label or "inRoom") .. " 未进入; finished " .. before .. "->" .. after)
  lu.assertTrue(completed, (label or "inRoom") .. " 未完成; finished " .. before .. "->" .. after)
  return result
end
local function p(n) return FkTest.room.players[n] end

local function setupLord()
  local room = FkTest.room
  inRoom(function()
    skill_test.installBlankGenerals(room, { "jin", "jin", "jin", "wei", "wei", "shu", "wu", "qun" })
    skill_test.installDualGenerals(room, room.players[1], {
      main = NORMAL, deputy = "qiao_test__jin_2", kingdom = "jin",
    })
    room.current = room.players[1]
    A.ascend(room, room.players[1], LORD, "jin", { kind = "lord" })
  end)
end

Testqiao_em_jin001_simayan = {
  setup = function()
    Fk.currentResponsePattern = nil
    support.initQiaoRoom()
    setupLord()
  end,
  tearDown = function()
    Fk.currentResponsePattern = nil
    support.clearRoom()
  end,
}

function Testqiao_em_jin001_simayan:testRegistrationAndAscension()
  local general = assert(Fk.generals[LORD])
  lu.assertEquals(DATA.generals[1].name, "司马炎")
  lu.assertTrue(general.hidden)
  lu.assertTrue(general.is_lord)
  lu.assertEquals(general.trueName, "司马炎")
  lu.assertEquals(general.prefix, "qiao_prefix_nu")
  lu.assertEquals(Fk:translate(LORD), '<font color="#FFFF00">君</font>司马炎')
  lu.assertTrue(Versions.is_lord(LORD))
  lu.assertEquals(p(1).general, LORD)
  lu.assertTrue(p(1):hasSkill(TAIKANG))
  lu.assertTrue(p(1):hasSkill(BANNER), "太康应授予诸王敕封册")
  lu.assertEquals(p(1):getMark(CI_MARK), 1, "持旗者应能打开空列表")
end

function Testqiao_em_jin001_simayan:testFirstDoubleRevealMakesCiAndChangeBranch()
  local room, lord, target = FkTest.room, p(1), p(3)
  local pileBefore
  inRoom(function()
    content.setupHidden(room, target, "qiao_heg__jin002", "qiao_heg__jin003", "jin")
    room.general_pile = { "qiao_heg__jin004", "qiao_heg__wei001", LORD, "qiao_heg__jin005", "qiao_heg__jin006" }
    room.disabled_generals = { "qiao_heg__jin006" }
    pileBefore = #room.general_pile
  end)
  local invokes, picks, drawRange = 0, 0, nil
  local random = room.random
  skill_test.withSkillRequests(room, BANNER, {
    askToSkillInvoke = function(self)
      invokes = invokes + 1
      self.random = function(_, lo, hi)
        self.random = random
        drawRange = { lo, hi }
        return 2
      end
      return true
    end,
    askToChoice = function(_, _, params)
      picks = picks + 1
      return params.choices[1]
    end,
  }, function()
    inRoom(function()
      target:revealGeneral(false)
      target:revealGeneral(true)
    end)
  end)
  room.random = random
  local ci = lord:getTableMark(BANNER) or {}
  lu.assertEquals(ci, { "qiao_heg__jin005" })
  lu.assertEquals(drawRange, { 1, 2 }, "只在两张合法晋将中随机抽取")
  lu.assertEquals(invokes, 1, "旗确认应一次")
  lu.assertEquals(picks, 0, "取得赐时不询问玩家选将")
  lu.assertEquals(lord:getMark(CI_MARK), 2, "赐入口应显示一张牌")
  lu.assertEquals(#room.general_pile, pileBefore - 1, "该将牌应占用剩余将池")
  -- 真实消费：用刚取得的赐走资源分支，验证消耗与回池。
  local ciName = ci[1]
  inRoom(function() lord.phase = Player.Play end)
  skill_test.withSkillRequests(room, BANNER, {
    askToChoice = function(self, who, params, original)
      if params.skill_name == BANNER then
        local resource = resourceChoice(params)
        if resource ~= nil then return resource end
      end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      room:useSkill(lord, Fk.skills[BANNER], function()
        Fk.skills[BANNER]:onUse(room, { from = lord, tos = {} })
      end)
    end)
  end)
  lu.assertEquals(#(lord:getTableMark(BANNER) or {}), 0, "执行分支应消耗赐")
  lu.assertEquals(lord:getMark(CI_MARK), 1, "消耗最后一张后仍可打开列表")
  lu.assertTrue(table.contains(room.general_pile, ciName), "消费后赐将牌应回剩余池")
end

function Testqiao_em_jin001_simayan:testFirstDoubleWithoutBannerDoesNotBackfill()
  local room, lord, target = FkTest.room, p(1), p(3)
  inRoom(function()
    content.setupHidden(room, target, "qiao_heg__jin002", "qiao_heg__jin003", "jin")
    room:handleAddLoseSkills(lord, "-" .. TAIKANG, nil)
    lu.assertFalse(lord:hasSkill(BANNER), "先撤掉旗")
  end)
  inRoom(function()
    target:revealGeneral(false)
    target:revealGeneral(true)
  end)
  lu.assertEquals(target:getMark("qiao_jin001_first_double"), 1, "无旗时也应记录首次双亮")
  lu.assertEquals(#(lord:getTableMark(BANNER) or {}), 0, "无旗时不产生赐")
  inRoom(function()
    room:handleAddLoseSkills(lord, TAIKANG, nil, false, true)
    room.logic:trigger(fk.GeneralRevealed, target, { m = target.general, d = target.deputyGeneral })
  end)
  lu.assertEquals(#(lord:getTableMark(BANNER) or {}), 0, "后来获得旗不补领首次双亮")
end

function Testqiao_em_jin001_simayan:testCiChangeAndResourceAfterUsed()
  local room, lord, target = FkTest.room, p(1), p(3)
  local oldDeputy, chosen
  inRoom(function()
    content.setupHidden(room, target, "qiao_heg__jin002", "qiao_heg__jin003", "jin")
    room.general_pile = { "qiao_heg__jin005" }
    room.disabled_generals = {}
    oldDeputy = lord.deputyGeneral
    lord.phase = Player.Play
  end)
  local handler = function(self, who, params, original)
    if params.skill_name ~= BANNER then return original(self, who, params) end
    if table.contains(params.choices, "change") then return "change" end
    if table.contains(params.choices, "main") and table.contains(params.choices, "deputy") then
      return "deputy"
    end
    local resource = resourceChoice(params)
    if resource ~= nil then return resource end
    chosen = params.choices[1]
    return chosen
  end
  -- 通过真实首次双亮生成赐，确保该将牌已从剩余池占用。
  skill_test.withSkillRequests(room, BANNER, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == BANNER then return true end
      return original(self, who, params)
    end,
    askToChoice = handler,
  }, function()
    inRoom(function()
      target:revealGeneral(false)
      target:revealGeneral(true)
    end)
  end)
  local ci = lord:getTableMark(BANNER) or {}
  lu.assertEquals(#ci, 1, "真实首次双亮应生成一枚赐")
  lu.assertEquals(ci[1], "qiao_heg__jin005", "固定池后首张赐应可确定")
  lu.assertFalse(table.contains(room.general_pile, ci[1]), "生成的赐不应仍留在剩余池")
  inRoom(function() room.general_pile = { "qiao_heg__jin004", "qiao_heg__jin006" } end)
  skill_test.withSkillRequests(room, BANNER, { askToChoice = handler }, function()
    inRoom(function()
      room:useSkill(lord, Fk.skills[BANNER], function()
        Fk.skills[BANNER]:onUse(room, { from = lord, tos = {} })
      end)
    end)
  end)
  lu.assertNotNil(chosen)
  lu.assertEquals(lord.deputyGeneral, chosen, "赐变更应通过公共 changeHero 换上所选副将")
  lu.assertTrue(table.contains(room.general_pile, oldDeputy), "旧普通武将应回将池")
  lu.assertFalse(table.contains(room.general_pile, chosen), "新武将不应重复留在池中")
  lu.assertTrue(lord:getMark("qiao_jin001_change_used") > 0, "变更分支应记录整局已用")
  lu.assertEquals(#(lord:getTableMark(BANNER) or {}), 0, "变更应消耗赐")
  local branches
  inRoom(function()
    lord.phase = Player.Play
    room:setPlayerMark(lord, BANNER, { "qiao_heg__jin004" })
  end)
  skill_test.withSkillRequests(room, BANNER, {
    askToChoice = function(self, who, params, original)
      if params.skill_name == BANNER then
        local resource = resourceChoice(params)
        if resource ~= nil then
          branches = table.simpleClone(params.choices)
          lu.assertTrue(params.detailed, "资源分支应在确认前显示实际效果说明")
          return resource
        end
      end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      Fk.skills[BANNER]:onUse(room, { from = lord, tos = {} })
    end)
  end)
  lu.assertNotNil(branches)
  local expected = Fk.generals["qiao_heg__jin004"].maxHp <= 3 and RESOURCE_MAXCARD or RESOURCE_DRAW
  lu.assertTrue(table.contains(branches, expected),
    "资源分支应按所选赐显示“本回合手牌上限+3”或“将手牌摸至四张”")
  lu.assertFalse(table.contains(branches, "change"), "整局限一次后不应再提供变更分支")
  lu.assertEquals(#(lord:getTableMark(BANNER) or {}), 0, "资源分支应消耗赐")
end
function Testqiao_em_jin001_simayan:testCaixingMultipleMountsOpensClientCardChooser()
  local room, lord, other = FkTest.room, p(1), p(2)
  local field, discarded
  inRoom(function()
    field = room:printCard("qiao__chitu", Card.Heart, 5)
    discarded = room:printCard("qiao__linxiao_yuyu", Card.Spade, 5)
    room:moveCardIntoEquip(other, field.id, CAIXING, false, lord)
    room:moveCardTo(discarded.id, Card.DiscardPile, nil, fk.ReasonJustMove, CAIXING)
  end)

  local wire
  FkTest.setRoomBreakpoint(lord, "AskForCardChosen", function(data)
    wire = cbor.encode(data)
    return false
  end)
  FkTest.setNextReplies(lord, { discarded.id })
  local phase = { phase = Player.Play, skipped = false }
  skill_test.withSkillRequests(room, CAIXING, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == CAIXING then return true end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function() room.logic:trigger(fk.EventPhaseChanging, lord, phase) end)
  end)

  lu.assertNotNil(wire, "两张合法坐骑应发出真实选牌请求")
  FkTest.runInClient(function()
    local client = ClientInstance
    local data = cbor.decode(wire)
    lu.assertIs(data[1], client:getPlayerById(lord.id))
    local shown
    local notify = client.notifyUI
    client.notifyUI = function(_, name, payload)
      if name == "AskForCardChosen" then shown = payload end
    end
    local ok, err = pcall(client.askForCardChosen, client, data)
    client.notifyUI = notify
    lu.assertTrue(ok, tostring(err))
    lu.assertEquals(shown.card_data, { { "$Equip", { field.id } }, { "弃牌堆", { discarded.id } } })
  end)
  lu.assertTrue(phase.skipped)
  lu.assertEquals(room:getCardArea(discarded.id), Card.PlayerEquip)
  lu.assertIs(room:getCardOwner(discarded.id), lord)
  lu.assertIs(room:getCardOwner(field.id), other)
end

function Testqiao_em_jin001_simayan:testResourceCiAndCaixingAndDingfei()
  local room, lord = FkTest.room, p(1)
  inRoom(function()
    room:setPlayerMark(lord, BANNER, { "qiao_heg__jin004" })
    lord.phase = Player.Play
  end)
  local fish = Fk.generals["qiao_heg__jin004"].maxHp
  local beforeHand
  skill_test.withSkillRequests(room, BANNER, {
    askToChoice = function(self, who, params, original)
      if params.skill_name == BANNER then
        local resource = resourceChoice(params)
        if resource ~= nil then return resource end
      end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      beforeHand = #lord:getCardIds("h")
      Fk.skills[BANNER]:onUse(room, { from = lord, tos = {} })
    end)
  end)
  if fish <= 3 then
    lu.assertTrue(lord:getMark(MarkEnum.AddMaxCardsInTurn) >= 3, "≤3 应本回合手牌上限+3")
  else
    lu.assertTrue(#lord:getCardIds("h") >= math.min(4, beforeHand + 4), "≥4 应补手至四张")
  end
  -- 採幸：跳过出牌阶段并置入弃牌堆临筱玉舆。
  local linxiao
  inRoom(function()
    linxiao = room:printCard("qiao__linxiao_yuyu", Card.Heart, 9)
    room:moveCardTo(linxiao, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, true, lord)
  end)
  local data = { phase = Player.Play, skipped = false }
  local oldInvoke = room.askToSkillInvoke
  room.askToSkillInvoke = function(self, who, params)
    if params.skill_name == CAIXING then return true end
    return oldInvoke(self, who, params)
  end
  inRoom(function() room.logic:trigger(fk.EventPhaseChanging, lord, data) end)
  room.askToSkillInvoke = oldInvoke
  lu.assertTrue(data.skipped, "採幸应跳过出牌阶段")
  lu.assertEquals(room:getCardArea(linxiao.id), Card.PlayerEquip, "临筱玉舆应置入空坐骑栏")
  -- 鼎沸：晋角色合计已损 > 体力。
  inRoom(function()
    lord.hp = 1
    p(2).hp = 1
    p(3).hp = 1
    lord.phase = Player.Finish
  end)
  local oldInvoke2 = room.askToSkillInvoke
  room.askToSkillInvoke = function(self, who, params)
    if params.skill_name == DINGFEI then return true end
    return oldInvoke2(self, who, params)
  end
  local handBefore
  inRoom(function()
    handBefore = #lord:getCardIds("h")
    room.logic:trigger(fk.EventPhaseStart, lord, PhaseData:new { who = lord, phase = Player.Finish })
  end)
  room.askToSkillInvoke = oldInvoke2
  lu.assertEquals(#lord:getCardIds("h") >= handBefore + 2, true, "鼎沸应摸两张")
  lu.assertFalse(lord:hasSkill(TAIKANG), "鼎沸应失去太康")
  lu.assertTrue(lord:hasSkill("qiao__skill_jin001_2"), "鼎沸应获得兴图")
end

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
  for index, player in ipairs(clients) do player.next = clients[index % #clients + 1] end
  local clientRoom = setmetatable({ players = clients, alive_players = clients, current = clients[1] },
    { __index = current })
  local originalRoom = Fk.currentRoom
  Fk.currentRoom = function() return clientRoom end
  local ok, err = pcall(function() fn(clients, clientRoom) end)
  Fk.currentRoom = originalRoom
  if not ok then error(err, 0) end
  return clients, clientRoom
end

function Testqiao_em_jin001_simayan:testClientCiPopupUsesOrdinaryActiveSkill()
  local room, lord = FkTest.room, p(1)
  local stored = "qiao_heg__jin004"
  inRoom(function()
    lord.phase = Player.Play
    table.removeOne(room.general_pile, stored)
    room:setPlayerMark(lord, BANNER, { stored })
    room:setPlayerMark(lord, CI_MARK, 2)
  end)
  local reply
  withClientRoom(room, function(clients)
    local me = clients[1]
    lu.assertNil(me.room)
    lu.assertFalse(Fk.skills[BANNER].visible, "消费按钮应只放在赐列表内")
    local mark = assert(Fk.qml_marks.qiao_ci)
    local popup = mark.qml(CI_MARK, me:getMark(CI_MARK), me)
    lu.assertEquals(mark.how_to_show(CI_MARK, me:getMark(CI_MARK)), "1")
    lu.assertEquals(popup.url, "packages/qiao/pkg/qiao_mode/qml/CiPile.qml")
    lu.assertEquals(popup.prop, { holderId = me.id, cardNames = { stored } })

    local board = assert(Fk:getBoardGame("qiao_heg_mode"))
    local client = board.client_klass:new(ClientInstance.client)
    local play = client.request_handlers.PlayCard:new(me)
    client.current_request_handler = play
    lu.assertFalse(client:canConsumeCi(clients[2].id))
    me.phase = Player.Finish
    lu.assertFalse(client:canConsumeCi(me.id))
    me.phase = Player.Play
    lu.assertTrue(client:canConsumeCi(me.id))

    local originalNotify = ClientInstance.notifyUI
    ClientInstance.notifyUI = function(_, cmd, data)
      if cmd == "ReplyToServer" then reply = data end
    end
    local ok, err = pcall(function() play:update("QiaoCi", me.id, "click", {}) end)
    ClientInstance.notifyUI = originalNotify
    if not ok then error(err, 0) end
    lu.assertNotNil(reply, "点击列表按钮应产生标准技能回包")
    lu.assertEquals(reply.card.skill, BANNER)
    lu.assertEquals(reply.card.subcards, {})
    lu.assertEquals(reply.targets, {})
    lu.assertFalse(client:canConsumeCi(me.id), "提交后不可重复点击")
    play:_finish()
  end)
  skill_test.withSkillRequests(room, BANNER, {
    askToChoice = function(_, _, params) return resourceChoice(params) end,
  }, function()
    inRoom(function() room:handleUseCardReply(lord, reply) end)
  end)
  lu.assertEquals(lord:getTableMark(BANNER), {})
  lu.assertEquals(lord:getMark(CI_MARK), 1)
  lu.assertEquals(lord:usedSkillTimes(BANNER, Player.HistoryPhase), 1)
  lu.assertTrue(table.contains(room.general_pile, stored))
end

return { name = "qiao_em_jin001_simayan" }
