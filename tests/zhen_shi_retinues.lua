-- 阵/势包翼从：青州精锐、庐江上甲定向验收。
-- 规则依据：docs/rules/generals/wei023-zangba.md、docs/rules/generals/wu023-chenwu-dongxi.md、
-- docs/rules/commander-retinue.md。数据注册与正式生命周期接线留给 Codex；本套件在
-- 房间内直接建立实例，只验证两种翼从技能的主流程与独立实例限次。
--
-- 尚未加入 tests/all.lua；由唯一测试执行者按
--   python scripts/test.py --file tests/zhen_shi_retinues.lua --timeout 180
-- 定向串行运行。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local R = require "packages.qiao.pkg.qiao_generals.util.retinue_instances"
local Z = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_retinues"

local QINGZHOU = "qiao__retinue_skill_qingzhou_jingrui"
local LUJIANG = "qiao__retinue_skill_lujiang_shangjia"
local QINGZHOU_GENERAL = "qiao_test__retinue_qingzhou_jingrui"
local LUJIANG_GENERAL = "qiao_test__retinue_lujiang_shangjia"
local QINGZHOU_DISCARD = "#qiao__retinue_skill_qingzhou_jingrui-option-discard"
local QINGZHOU_DAMAGE = "#qiao__retinue_skill_qingzhou_jingrui-option-damage"
local SLASH_BONUS = "qiao_lujiang_shangjia_slash_bonus-phase"

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function p(n) return FkTest.room.players[n] end

local function clearZone(player, zone)
  local ids = player:getCardIds(zone)
  if #ids > 0 then
    FkTest.room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove,
      "test", nil, false)
  end
end

local function give(player, name, suit, number)
  local id
  inRoom(function()
    local card = FkTest.room:printCard(name, suit or Card.Spade, number or 7)
    FkTest.room:obtainCard(player, card, false, fk.ReasonJustMove)
    id = card.id
  end)
  return id
end

local function enterPlay(player)
  inRoom(function()
    FkTest.room.current = player
    player.phase = Player.Play
    FkTest.room:setBanner("RoundCount", 1)
  end)
end

local function activate(skill, player, tos)
  inRoom(function()
    lu.assertTrue(skill:canUse(player), "skill should be usable before activation")
    FkTest.room:useSkill(player, skill, function()
      skill:onUse(FkTest.room, { from = player, cards = {}, tos = tos or {} })
    end, { from = player, cards = {}, tos = tos or {} })
  end)
end

local function slashMax(player)
  local result
  inRoom(function()
    local slashSkill = assert(Fk.skills["slash_skill"])
    result = slashSkill:getMaxUseTime(player, Player.HistoryPhase, Fk:cloneCard("slash"))
  end)
  return result
end

--- 真实 ClientPlayer 副本：无 room 字段，用于验证客户端可用性不读 server tag。
local function withClientRoom(current, fn)
  local ClientPlayer = require "ltk.client.clientplayer"
  local clients = {}
  for _, original in ipairs(current.players) do
    local copy = ClientPlayer:new(original._splayer)
    for key, value in pairs(original) do
      if key ~= "room" and key ~= "class" and key ~= "serverplayer" then
        copy[key] = value
      end
    end
    local cards = {}
    for area, ids in pairs(copy.player_cards or {}) do
      cards[area] = table.simpleClone(ids)
    end
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
end

local function prepare()
  Fk.currentResponsePattern = nil
  local room = support.initQiaoRoom()
  inRoom(function()
    skill_test.installBlankGenerals(room, "han")
    for _, player in ipairs(room.players) do
      clearZone(player, "he")
    end
  end)
  return room
end

Testqiao_zhen_shi_retinues = {
  setup = prepare,
  tearDown = function()
    Fk.currentResponsePattern = nil
    support.clearRoom()
  end,
}

function Testqiao_zhen_shi_retinues:testQingzhouMinHandTargetsAndPerInstanceLimit()
  local player, second, third, fourth = p(1), p(2), p(3), p(4)
  give(player, "qiao__jink", Card.Heart, 2)
  give(second, "qiao__jink", Card.Heart, 3)
  give(third, "qiao__jink", Card.Heart, 4)
  give(third, "qiao__jink", Card.Heart, 5)
  give(fourth, "qiao__jink", Card.Heart, 6)
  give(fourth, "qiao__jink", Card.Heart, 7)
  give(fourth, "qiao__jink", Card.Heart, 8)
  -- 全场最低必须真实为1：其余角色各留1张，不能留0张把设定目标挤出合法范围。
  for index = 5, 8 do
    give(p(index), "qiao__jink", Card.Heart, index + 2)
  end
  enterPlay(player)

  local skill = assert(Fk.skills[QINGZHOU])
  local instances
  inRoom(function()
    instances = {
      R.grant(player, { general = QINGZHOU_GENERAL, skill = QINGZHOU, position = "main" }),
      R.grant(player, { general = QINGZHOU_GENERAL, skill = QINGZHOU, position = "deputy" }),
    }
    -- 最小手牌数：p1=1、p2=1 并列；自己也可以成为目标；p3/p4 不行。
    lu.assertTrue(skill:targetFilter(player, player, {}, {}))
    lu.assertTrue(skill:targetFilter(player, second, {}, {}))
    lu.assertFalse(skill:targetFilter(player, third, {}, {}))
    lu.assertFalse(skill:targetFilter(player, fourth, {}, {}))
    lu.assertEquals(#Z.availableInstances(player, QINGZHOU, 1), 2)
  end)

  local choiceCount = 0
  skill_test.withSkillRequests(FkTest.room, QINGZHOU, {
    askToChoice = function(self, who, params, original)
      if params.skill_name ~= QINGZHOU then return original(self, who, params) end
      choiceCount = choiceCount + 1
      return choiceCount == 1 and QINGZHOU_DAMAGE or QINGZHOU_DISCARD
    end,
    askToDiscard = function(self, who, params, original)
      if params.skill_name ~= QINGZHOU then return original(self, who, params) end
      local hand = who:getCardIds(Player.Hand)
      lu.assertTrue(#hand >= params.min_num)
      local take = {}
      for i = 1, params.min_num do table.insert(take, hand[i]) end
      self:throwCard(take, QINGZHOU, who, who)
      return take
    end,
  }, function()
    activate(skill, player, { second }) -- 伤害分支
    lu.assertEquals(second.hp, second.maxHp - 1)
    activate(skill, player, { player }) -- 弃牌分支，目标为自己
  end)

  lu.assertEquals(choiceCount, 2)
  lu.assertEquals(#player:getCardIds(Player.Hand), 0)
  lu.assertEquals(instances[1].uses, 1)
  lu.assertEquals(instances[2].uses, 1)
  lu.assertEquals(Z.publicUsed(player, QINGZHOU), 2)
  inRoom(function()
    lu.assertEquals(#Z.availableInstances(player, QINGZHOU, 1), 0)
    lu.assertFalse(skill:canUse(player), "两份实例各限一次后不能再发动")
  end)
end

function Testqiao_zhen_shi_retinues:testLujiangOwnerCountVersusInstancesAndSlashBonus()
  local player, sharedOwner = p(1), p(2)
  enterPlay(player)
  local skill = assert(Fk.skills[LUJIANG])
  inRoom(function()
    R.grant(player, { general = LUJIANG_GENERAL, skill = LUJIANG, position = "main" })
    R.grant(player, { general = LUJIANG_GENERAL, skill = LUJIANG, position = "deputy" })
    -- 另一名角色也实际拥有同一个翼从（模拟共享来源），X 计为 2 名角色。
    R.grant(sharedOwner, { general = LUJIANG_GENERAL, skill = LUJIANG, origin = "shared", shared_from = player.id })
    lu.assertEquals(Z.characterCount(FkTest.room, LUJIANG), 2)
    lu.assertEquals(#R.instancesForSkill(player, LUJIANG), 2)
  end)

  give(player, "qiao__jink", Card.Heart, 2)
  give(player, "qiao__jink", Card.Heart, 3)

  local function discardAllForSkill()
    skill_test.withSkillRequests(FkTest.room, LUJIANG, {
      askToDiscard = function(self, who, params, original)
        if params.skill_name ~= LUJIANG then return original(self, who, params) end
        local hand = who:getCardIds(Player.Hand)
        lu.assertTrue(#hand >= params.min_num)
        local take = {}
        for i = 1, params.min_num do table.insert(take, hand[i]) end
        self:throwCard(take, LUJIANG, who, who)
        return take
      end,
    }, function()
      activate(skill, player, {})
    end)
  end

  discardAllForSkill() -- 手牌2、装备0：弃2张，只加一次【杀】次数
  lu.assertEquals(#player:getCardIds(Player.Hand), 0)
  lu.assertEquals(player:getMark(SLASH_BONUS), 1)
  lu.assertEquals(slashMax(player), 2) -- 基础1 + 1，不是按弃牌张数 +2
  inRoom(function()
    lu.assertEquals(#Z.availableInstances(player, LUJIANG, 2), 2) -- 两份实例都还有余额
  end)

  give(player, "qiao__jink", Card.Heart, 4)
  discardAllForSkill()
  lu.assertEquals(player:getMark(SLASH_BONUS), 2)
  lu.assertEquals(slashMax(player), 3)
  inRoom(function()
    lu.assertEquals(#Z.availableInstances(player, LUJIANG, 2), 1) -- 第一份已用满，第二份仍有
  end)

  give(player, "qiao__jink", Card.Heart, 5)
  discardAllForSkill()
  lu.assertEquals(player:getMark(SLASH_BONUS), 3)
  lu.assertEquals(slashMax(player), 4)

  give(player, "qiao__jink", Card.Heart, 6)
  discardAllForSkill()
  lu.assertEquals(player:getMark(SLASH_BONUS), 4)
  lu.assertEquals(slashMax(player), 5)

  -- 2 份实例 × X=2 名拥有者 = 本阶段最多4次；若误把实例总数3当作X会允许第5次。
  inRoom(function()
    lu.assertEquals(#Z.availableInstances(player, LUJIANG, 2), 0)
    lu.assertFalse(Z.canUse(player, LUJIANG, 2))
    lu.assertFalse(skill:canUse(player))
  end)
  give(player, "qiao__jink", Card.Heart, 7)
  inRoom(function()
    lu.assertFalse(skill:canUse(player), "达到角色数×实例数上限后不能继续发动")
  end)
end

function Testqiao_zhen_shi_retinues:testClientCanUseReadsPublicSummaryOnly()
  local player, sharedOwner, third = p(1), p(2), p(3)
  give(player, "qiao__jink", Card.Heart, 2) -- 手牌数≠装备数
  give(sharedOwner, "qiao__jink", Card.Heart, 3)
  give(sharedOwner, "qiao__jink", Card.Heart, 4)
  give(third, "qiao__jink", Card.Heart, 5)
  -- 其余角色各1张，使全场最低真实为1，p2的2张才被排除。
  for index = 4, 8 do
    give(p(index), "qiao__jink", Card.Heart, index + 4)
  end
  enterPlay(player)
  inRoom(function()
    R.grant(player, { general = QINGZHOU_GENERAL, skill = QINGZHOU, position = "main" })
    R.grant(player, { general = QINGZHOU_GENERAL, skill = QINGZHOU, position = "deputy" })
    R.grant(player, { general = LUJIANG_GENERAL, skill = LUJIANG, position = "main" })
    R.grant(player, { general = LUJIANG_GENERAL, skill = LUJIANG, position = "deputy" })
    R.grant(sharedOwner, { general = LUJIANG_GENERAL, skill = LUJIANG, origin = "shared", shared_from = player.id })
  end)

  local qingzhou = assert(Fk.skills[QINGZHOU])
  local lujiang = assert(Fk.skills[LUJIANG])
  withClientRoom(FkTest.room, function(clients)
    local me = clients[1]
    lu.assertNil(me.room, "真实 ClientPlayer 不应有 room 字段")
    -- 他人暗手牌数量：p1=1、p2=2、p3=1；最少为 p1/p3 并列，p2 不是合法目标。
    lu.assertEquals(clients[2]:getHandcardNum(), 2)
    lu.assertEquals(clients[3]:getHandcardNum(), 1)
    lu.assertTrue(qingzhou:targetFilter(me, clients[1], {}, {}))
    lu.assertFalse(qingzhou:targetFilter(me, clients[2], {}, {}))
    lu.assertTrue(qingzhou:targetFilter(me, clients[3], {}, {}))

    lu.assertTrue(qingzhou:canUse(me), "客户端青州可用性应只依赖公开摘要")
    lu.assertTrue(lujiang:canUse(me), "客户端庐江可用性应只依赖公开摘要与公开手牌/装备数")
  end)
end

function Testqiao_zhen_shi_retinues:testLujiangSlashBonusPersistsAfterWingLoss()
  local player = p(1)
  enterPlay(player)
  local skill = assert(Fk.skills[LUJIANG])
  local instance
  inRoom(function()
    instance = R.grant(player, { general = LUJIANG_GENERAL, skill = LUJIANG })
  end)
  give(player, "qiao__jink", Card.Heart, 2)
  give(player, "qiao__jink", Card.Heart, 3)

  skill_test.withSkillRequests(FkTest.room, LUJIANG, {
    askToDiscard = function(self, who, params, original)
      if params.skill_name ~= LUJIANG then return original(self, who, params) end
      local hand = who:getCardIds(Player.Hand)
      local take = {}
      for i = 1, params.min_num do table.insert(take, hand[i]) end
      self:throwCard(take, LUJIANG, who, who)
      return take
    end,
  }, function()
    activate(skill, player, {})
  end)

  lu.assertEquals(player:getMark(SLASH_BONUS), 1)
  lu.assertEquals(slashMax(player), 2)

  -- 失去最后一份翼从：加成是已建立的阶段状态，必须继续有效。
  inRoom(function() lu.assertTrue(R.remove(player, instance.id)) end)
  inRoom(function()
    lu.assertFalse(player:hasSkill(LUJIANG), "最后一份实例移除后应失去翼从技能")
    lu.assertEquals(Z.publicUsedList(player, LUJIANG), {})
  end)
  lu.assertEquals(slashMax(player), 2, "失去翼从后已建立的【杀】次数加成仍有效")
end

function Testqiao_zhen_shi_retinues:testClientAvailabilityAfterUsedInstanceRemoval()
  local player = p(1)
  enterPlay(player)
  local skill = assert(Fk.skills[LUJIANG])
  local first
  inRoom(function()
    first = R.grant(player, { general = LUJIANG_GENERAL, skill = LUJIANG, position = "main" })
    R.grant(player, { general = LUJIANG_GENERAL, skill = LUJIANG, position = "deputy" })
  end)

  local function discardOne()
    skill_test.withSkillRequests(FkTest.room, LUJIANG, {
      askToDiscard = function(self, who, params, original)
        if params.skill_name ~= LUJIANG then return original(self, who, params) end
        local hand = who:getCardIds(Player.Hand)
        local take = {}
        for i = 1, params.min_num do table.insert(take, hand[i]) end
        self:throwCard(take, LUJIANG, who, who)
        return take
      end,
    }, function()
      activate(skill, player, {})
    end)
  end

  -- 仅 p1 拥有（X=1），两份实例各一次。用掉第一份后其已用数为1、第二份为0。
  give(player, "qiao__jink", Card.Heart, 2)
  discardOne()
  give(player, "qiao__jink", Card.Heart, 3)
  inRoom(function()
    lu.assertEquals(Z.publicUsedList(player, LUJIANG), { 1, 0 })
    lu.assertTrue(R.remove(player, first.id))
    -- 移除已用满的那一份：公开数组只剩未用的第二份，客户端不得误灰。
    lu.assertEquals(Z.publicUsedList(player, LUJIANG), { 0 })
    lu.assertTrue(skill:canUse(player))
  end)
  withClientRoom(FkTest.room, function(clients)
    local me = clients[1]
    lu.assertTrue(skill:canUse(me), "移除已用实例后客户端应仍显示可用")
  end)
  discardOne() -- 第二份仍可实际发动
  inRoom(function()
    lu.assertEquals(Z.publicUsedList(player, LUJIANG), { 1 })
    lu.assertFalse(skill:canUse(player))
  end)
end

function Testqiao_zhen_shi_retinues:testLujiangOwnerCountExcludesDeadCharacters()
  local player, other = p(1), p(2)
  enterPlay(player)
  inRoom(function()
    R.grant(player, { general = LUJIANG_GENERAL, skill = LUJIANG })
    R.grant(other, { general = LUJIANG_GENERAL, skill = LUJIANG, origin = "shared", shared_from = player.id })
    lu.assertEquals(Z.characterCount(FkTest.room, LUJIANG), 2)
    other.dead = true
    lu.assertEquals(Z.characterCount(FkTest.room, LUJIANG), 1, "死亡角色不计入 X")
    other.dead = false
    lu.assertEquals(Z.characterCount(FkTest.room, LUJIANG), 2)
  end)
end

return { name = "qiao_zhen_shi_retinues" }
