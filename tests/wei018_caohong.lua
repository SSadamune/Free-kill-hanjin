-- WEI018 曹洪：护援、鹤翼定向验收。
-- 正式编号 qiao_heg__wei018；数据由阵包 fragment 经中央入口合并。
local F = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_formation"
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")

local CAOHONG = "qiao_heg__wei018"
local HUYUAN = "qiao__skill_wei018_1"
local HEYI = "qiao__skill_wei018_2"
local BLANK_DEPUTY = "qiao_test__wei_2"

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function p(n) return FkTest.room.players[n] end

local function give(player, name, suit, number)
  local id
  inRoom(function()
    local card = FkTest.room:printCard(name, suit or Card.Spade, number or 7)
    FkTest.room:obtainCard(player, card, false, fk.ReasonJustMove)
    id = card.id
  end)
  return id
end

local function clearZone(player, zone)
  local ids = player:getCardIds(zone)
  if #ids > 0 then
    FkTest.room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove,
      "test", nil, false)
  end
end

local function prepare(kingdoms, withBots)
  Fk.currentResponsePattern = nil
  local backend
  if withBots then
    backend = FkTest.createFakeRoom({ 1, -2, -3, -4, -5, -6, -7, -8 })
    -- 与原生进房相同，先把机器人加入客户端，再让服务器通知座次。
    local players = backend:getPlayers()
    for i = 1, players:length() - 1 do
      local bot = players:at(i)
      ClientInstance:removePlayer({ i + 1 })
      ClientInstance:addPlayer({ bot:getId(), bot:getScreenName(), bot:getAvatar(), true, 0 })
    end
  end
  local room = support.createRoom {
    mode = "qiao_heg_mode",
    backend = backend,
    realSelection = true,
    settings = {
      qiao_faction_ban_enabled = false,
    },
  }
  inRoom(function()
    skill_test.installBlankGenerals(room, kingdoms)
    skill_test.installDualGenerals(room, room.players[1], {
      main = CAOHONG, deputy = BLANK_DEPUTY, kingdom = "wei",
    })
    room.players[1]:revealGeneral(false)
    for _, player in ipairs(room.players) do clearZone(player, "he") end
  end)
  return room
end

Testqiao_wei018_caohong = {
  setup = function() prepare({ "wei", "wei", "wei", "wu", "wu", "wu", "wu", "wu" }) end,
  tearDown = function()
    Fk.currentResponsePattern = nil
    support.clearRoom()
  end,
}

function Testqiao_wei018_caohong:testFormalRegistration()
  local general = assert(Fk.generals[CAOHONG])
  lu.assertEquals(general.trueName, "曹洪")
  lu.assertEquals(general.maxHp, 4)
  lu.assertEquals(general.gender, General.Male)
  lu.assertEquals(general.kingdom, "wei")
  lu.assertTrue(general:isCompanionWith(Fk.generals["qiao_heg__wei011"]))
  lu.assertTrue(table.contains(general:getSkillNameList(), HUYUAN))
  lu.assertTrue(table.contains(general:getSkillNameList(), HEYI))
  inRoom(function() lu.assertTrue(Fk:canUseGeneral(CAOHONG)) end)
end

function Testqiao_wei018_caohong:testHuyuanDiscardsAreaCardAtDistanceOne()
  -- p2/p3 在曹洪队列中已有飞影，距离不再为1；p8为相邻异势力角色。
  local room, player, second, third = FkTest.room, p(1), p(8), p(3)
  local victimCard = give(second, "qiao__jink", Card.Heart, 2)
  give(third, "qiao__jink", Card.Heart, 3)
  inRoom(function()
    room.current = player
    player.phase = Player.Play
    room:setBanner("RoundCount", 1)
    lu.assertTrue(player:hasShownSkill(HUYUAN), "护援来源应已明置")
    lu.assertEquals(player:distanceTo(second), 1, "被弃牌者须实际距被装备者1")
  end)
  local equip = give(player, "qiao__eight_diagram", Card.Spade, 2)

  local chosenPlayer, chosenCard
  skill_test.withSkillRequests(room, HUYUAN, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == HUYUAN then return true end
      return original(self, who, params)
    end,
    askToChoosePlayers = function(self, who, params, original)
      if params.skill_name ~= HUYUAN then return original(self, who, params) end
      chosenPlayer = table.find(params.targets, function(candidate) return candidate == second end) or params.targets[1]
      return { chosenPlayer }
    end,
    askToChooseCard = function(self, who, params, original)
      if params.skill_name ~= HUYUAN then return original(self, who, params) end
      chosenPlayer = params.target
      chosenCard = params.target:getCardIds("h")[1]
      return chosenCard
    end,
  }, function()
    inRoom(function()
      room:moveCardIntoEquip(player, equip, "test", true, player)
    end)
  end)

  lu.assertIs(chosenPlayer, second)
  lu.assertNotNil(chosenCard)
  lu.assertEquals(room:getCardArea(victimCard), Card.DiscardPile)
  lu.assertEquals(#player:getCardIds("e"), 1)
end

function Testqiao_wei018_caohong:testHeyiGrantsRealFeiyingAndKeepsOtherSources()
  support.clearRoom()
  local room = prepare({ "wei", "wei", "wei", "wu", "wu", "wu", "wu", "wu" }, true)
  local player, second, third, outsider = p(1), p(2), p(3), p(4)
  inRoom(function()
    -- 先暂时移除鹤翼本身并刷新，取得“无飞影”基线；不能再逐张移除飞影，
    -- 因为失技会触发鹤翼刷新并立刻重新授予。
    room:handleAddLoseSkills(player, "-" .. HEYI, nil, false, true)
    F.refreshFormationSources(room)
    local without = third:distanceTo(player)
    room:handleAddLoseSkills(player, HEYI, nil, false, true)
    room.logic:trigger(fk.TurnStart, player, TurnData:new(player, "game_rule"))
    lu.assertTrue(player:hasSkill(F.FEIYING_SKILL), "鹤翼应让队列中的自己真正拥有飞影")
    lu.assertTrue(second:hasSkill(F.FEIYING_SKILL))
    lu.assertTrue(third:hasSkill(F.FEIYING_SKILL))
    lu.assertFalse(outsider:hasSkill(F.FEIYING_SKILL), "非队列角色不应获得飞影")
    local with = third:distanceTo(player)
    lu.assertEquals(with, without + 1)
    lu.assertEquals(F.feiyingLayers(third), 1)

    -- 第二名鹤翼持有者加入；移除第一名来源后，第二来源仍授予真实飞影。
    lu.assertTrue(player.id < 0 or second.id < 0, "至少一名鹤翼来源为机器人")
    room:handleAddLoseSkills(second, HEYI, nil, false, true)
    F.refreshFormationSources(room)
    local two = third:getMark(F.FEIYING_MARK)
    lu.assertEquals(type(two), "table")
    local twoCount = 0
    for _ in pairs(two) do twoCount = twoCount + 1 end
    lu.assertEquals(twoCount, 2)
    lu.assertEquals(F.feiyingLayers(third), 2)
    lu.assertEquals(third:distanceTo(player), without + 2)
    room:handleAddLoseSkills(player, "-" .. HEYI, nil, false, true)
    F.refreshFormationSources(room)
    lu.assertTrue(third:hasSkill(F.FEIYING_SKILL), "其他鹤翼来源不得被连带删除")
    local one = third:getMark(F.FEIYING_MARK)
    local oneCount = 0
    for _ in pairs(one) do oneCount = oneCount + 1 end
    lu.assertEquals(oneCount, 1)
    lu.assertEquals(F.feiyingLayers(third), 1)
    lu.assertEquals(third:distanceTo(player), without + 1)
    lu.assertTrue(player:hasSkill(F.FEIYING_SKILL), "第二来源仍覆盖原队列")

    -- 外部原有飞影：不因鹤翼来源撤销而误删；另算一层。
    room:handleAddLoseSkills(outsider, F.FEIYING_SKILL, nil, false, true)
    F.refreshLayers(room)
    lu.assertTrue(outsider:hasSkill(F.FEIYING_SKILL))
    lu.assertEquals(F.feiyingLayers(outsider), 1)
    local outsiderDistance = third:distanceTo(outsider)
    room:handleAddLoseSkills(second, "-" .. HEYI, nil, false, true)
    F.refreshFormationSources(room)
    lu.assertTrue(outsider:hasSkill(F.FEIYING_SKILL), "原有独立飞影不得被鹤翼撤销误删")
    lu.assertEquals(F.feiyingLayers(outsider), 1)
    lu.assertEquals(third:distanceTo(outsider), outsiderDistance)
  end)
end

function Testqiao_wei018_caohong:testFeiyingSourceSkillsArePreRegisteredAndClientLoadable()
  local room, player, third = FkTest.room, p(1), p(3)
  inRoom(function()
    F.refreshFormationSources(room)
    local capacity = Fk.game_modes.qiao_heg_mode.maxPlayer
    lu.assertNotNil(Fk.skills[F.sourceSkillName(capacity)], "最大房间的最后席位也有预注册来源")
    lu.assertTrue(player:hasSkill(F.FEIYING_SKILL))
    lu.assertEquals(F.feiyingLayers(third), 1)
  end)

  local ClientPlayer = require "ltk.client.clientplayer"
  local copy = ClientPlayer:new(third._splayer)
  for key, value in pairs(third) do
    if key ~= "room" and key ~= "class" and key ~= "serverplayer" then
      copy[key] = value
    end
  end
  copy.mark = {}
  for _, name in ipairs(third:getMarkNames()) do copy.mark[name] = third:getMark(name) end
  copy.player_skills = {}
  copy.derivative_skills = {}
  lu.assertNil(copy.room)
  lu.assertEquals(F.feiyingLayers(copy), 1, "客户端从公开层数 mark 读取飞影层数")
  -- 客户端技能回调在服务端房间协程以外执行；失败也必须恢复全局入口。
  local oldRoom = Fk.currentRoom
  Fk.currentRoom = function() return { status_skills = {} } end
  local ok, err = pcall(function()
    copy:addSkill(Fk.skills[F.FEIYING_SKILL])
    lu.assertTrue(copy:hasSkill(F.FEIYING_SKILL))
    copy:loseSkill(Fk.skills[F.FEIYING_SKILL])
    lu.assertFalse(copy:hasSkill(F.FEIYING_SKILL))
  end)
  Fk.currentRoom = oldRoom
  if not ok then error(err, 0) end
end

function Testqiao_wei018_caohong:testHeyiNoQueueGrantsNothing()
  local room = support.createRoom {
    mode = "qiao_heg_mode",
    realSelection = true,
    settings = {
      qiao_faction_ban_enabled = false,
    },
  }
  inRoom(function()
    skill_test.installBlankGenerals(room, { "wu", "wu", "wu", "wu", "wu", "wu", "wu", "wu" })
    skill_test.installDualGenerals(room, room.players[1], {
      main = CAOHONG, deputy = "qiao_test__wu_2", kingdom = "wei",
    })
    F.refreshFormationSources(room)
    lu.assertFalse(F.hasFormationFeiying(room.players[1]),
      "队列不存在时不能因自己与自己同势力而获得飞影")
  end)
  support.clearRoom()
end

return { name = "qiao_wei018_caohong" }
