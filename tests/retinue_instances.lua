-- 翼从同名独立实例：最小机制定向验收。
-- 规则依据：rules/commander-retinue.md「拥有数量与独立实例」。
--
-- 生产目录只有通用实例模块；探测技能与外部来源标记在
-- tests/support/retinue_instances.lua 中注册，使用 hanjin_test__ 前缀，不发布。
-- 本套件验证：
--   1. 两份同名实例共用单个技能定义，同一时机各自可选发动一次、各自计次；
--   2. 拒绝第一份后仍会询问并发动第二份（不是一次询问代表全部）；
--   3. 移除一份后另一份仍在并可继续发动，最后一份移除后才失去实例来源；
--   4. 实例授予/撤销只处理本模块来源，外部独立同名技能来源保留；
--   5. 客户端只通过公开 mark 读取数量与技能实例数，不读服务端 room tag。
--
-- 尚未加入 tests/all.lua；由唯一测试执行者按
--   python scripts/test.py --file tests/retinue_instances.lua --timeout 180
-- 定向串行运行。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local probe = __dofile("../../../tests/support/retinue_instances.lua")
local R = require "packages.hanjin.pkg.hanjin_generals.util.retinue_instances"

local SKILL = probe.SKILL
local EXTERNAL_SOURCE = probe.EXTERNAL_SOURCE
-- 兵种键只是测试记号；正式青州精锐的注册与正式翼从效果留待后续批次。
local GENERAL = "hanjin_test__retinue_qingzhou_jingrui"

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function p(n) return FkTest.room.players[n] end

local function clearHand(player)
  local ids = player:getCardIds("he")
  if #ids > 0 then
    FkTest.room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove,
      "test", nil, false)
  end
end

local function prepare()
  Fk.currentResponsePattern = nil
  local room = support.initHanjinRoom()
  inRoom(function()
    skill_test.installBlankGenerals(room, "han")
    for _, player in ipairs(room.players) do clearHand(player) end
  end)
  return room
end

--- 真实 ClientPlayer 副本：没有 room 字段，公开 mark 从服务端复制。
local function withClientPlayer(player, fn)
  local ClientPlayer = require "ltk.client.clientplayer"
  local copy = ClientPlayer:new(player._splayer)
  for key, value in pairs(player) do
    if key ~= "room" and key ~= "class" and key ~= "serverplayer" then
      copy[key] = value
    end
  end
  copy.mark = {}
  for _, name in ipairs(player:getMarkNames()) do
    copy.mark[name] = player:getMark(name)
  end
  local ok, err = pcall(fn, copy)
  if not ok then error(err, 0) end
end

Testhanjin_retinue_instances = {
  setup = prepare,
  tearDown = function()
    Fk.currentResponsePattern = nil
    support.clearRoom()
  end,
}

function Testhanjin_retinue_instances:testSameNameInstancesEachActivateOnce()
  lu.assertNotNil(Fk.skills[SKILL], "instance probe skill was not loaded")
  local player, source = p(1), p(2)
  local first, second
  inRoom(function()
    first = R.grant(player, {
      general = GENERAL, skill = SKILL, position = "main",
    })
    second = R.grant(player, {
      general = GENERAL, skill = SKILL, position = "deputy",
    })
    lu.assertEquals(R.count(player), 2)
    lu.assertEquals(R.countForSkill(player, SKILL), 2)
    lu.assertNotEquals(first.id, second.id)
    -- 同名：兵种与技能定义相同，但实例身份各自独立。
    lu.assertEquals(first.general, second.general)
    lu.assertEquals(first.skill, second.skill)
    lu.assertTrue(player:hasSkill(SKILL))
    lu.assertEquals(first.uses, 0)
    lu.assertEquals(second.uses, 0)
  end)

  FkTest.setNextReplies(player, { "1", "1" })
  inRoom(function()
    FkTest.room:damage { from = source, to = player, damage = 1, skillName = "test" }
  end)

  -- 每份实例各发动一次：摸两张；两份实例的计次分别为 1。
  lu.assertEquals(#player:getCardIds(Player.Hand), 2)
  lu.assertEquals(first.uses, 1)
  lu.assertEquals(second.uses, 1)
  lu.assertEquals(player:usedSkillTimes(SKILL, Player.HistoryGame), 2)
  lu.assertEquals(R.publicCount(player), 2)
  local summary = R.publicInstances(player)
  lu.assertEquals(#summary, 1)
  lu.assertEquals(summary[1].skill, SKILL)
  lu.assertEquals(summary[1].count, 2)
  lu.assertNil(summary[1].id)
  lu.assertNil(summary[1].general)
  lu.assertNil(summary[1].origin)
  lu.assertNil(summary[1].uses)
end

function Testhanjin_retinue_instances:testDeclineFirstStillPromptsAndUsesSecond()
  local player, source = p(1), p(2)
  local first, second
  inRoom(function()
    first = R.grant(player, { general = GENERAL, skill = SKILL, position = "main" })
    second = R.grant(player, { general = GENERAL, skill = SKILL, position = "deputy" })
  end)

  -- 第一份拒绝，第二份接受。若实现把同名实例合并成一次询问，第二份不会发动。
  FkTest.setNextReplies(player, { "", "1" })
  inRoom(function()
    FkTest.room:damage { from = source, to = player, damage = 1, skillName = "test" }
  end)

  lu.assertEquals(#player:getCardIds(Player.Hand), 1)
  lu.assertEquals(first.uses, 0)
  lu.assertEquals(second.uses, 1)
  lu.assertEquals(player:usedSkillTimes(SKILL, Player.HistoryGame), 1)
  lu.assertEquals(R.publicCount(player), 2)
end

function Testhanjin_retinue_instances:testRemovingOneInstanceKeepsTheOther()
  local player, source = p(1), p(2)
  local first, second
  inRoom(function()
    first = R.grant(player, { general = GENERAL, skill = SKILL, position = "main" })
    second = R.grant(player, { general = GENERAL, skill = SKILL, position = "deputy" })
    lu.assertTrue(R.remove(player, first.id))
    lu.assertNil(R.get(player, first.id))
    lu.assertEquals(R.count(player), 1)
    lu.assertEquals(R.countForSkill(player, SKILL), 1)
    lu.assertIs(R.instancesForSkill(player, SKILL)[1], second)
    -- 只剩一份实例，技能本身仍须保留。
    lu.assertTrue(player:hasSkill(SKILL))
    lu.assertEquals(R.publicCount(player), 1)
  end)

  FkTest.setNextReplies(player, { "1" })
  inRoom(function()
    FkTest.room:damage { from = source, to = player, damage = 1, skillName = "test" }
  end)

  -- 保留的那一份继续独立发动与计次；已移除的一份不受影响。
  lu.assertEquals(#player:getCardIds(Player.Hand), 1)
  lu.assertEquals(second.uses, 1)
  lu.assertEquals(first.uses, 0)
  lu.assertEquals(player:usedSkillTimes(SKILL, Player.HistoryGame), 1)

  inRoom(function()
    lu.assertTrue(R.remove(player, second.id))
    lu.assertEquals(R.count(player), 0)
    lu.assertEquals(R.countForSkill(player, SKILL), 0)
    lu.assertEquals(R.publicCount(player), 0)
    lu.assertFalse(player:hasSkill(SKILL))
  end)
end

function Testhanjin_retinue_instances:testRemovalKeepsExternalSameNameSource()
  local player = p(1)
  inRoom(function()
    -- 外部独立导数来源先持有同名技能。
    FkTest.room:handleAddLoseSkills(player, SKILL, EXTERNAL_SOURCE, false, true)
    lu.assertTrue(player:hasSkill(SKILL))

    local first = R.grant(player, { general = GENERAL, skill = SKILL })
    local second = R.grant(player, { general = GENERAL, skill = SKILL })
    lu.assertTrue(R.remove(player, first.id))
    lu.assertTrue(R.remove(player, second.id))
    -- 本模块来源全部撤销后，外部来源必须保留。
    lu.assertTrue(player:hasSkill(SKILL), "外部独立来源不得被实例撤销删除")
    lu.assertEquals(R.count(player), 0)

    FkTest.room:handleAddLoseSkills(player, "-" .. SKILL, EXTERNAL_SOURCE, false, true)
    lu.assertFalse(player:hasSkill(SKILL))

    -- 角色原有技能（player_skills 来源）同样不被实例撤销删除。
    FkTest.room:handleAddLoseSkills(player, SKILL, nil, false, true)
    lu.assertTrue(player:hasSkill(SKILL))
    local third = R.grant(player, { general = GENERAL, skill = SKILL })
    lu.assertTrue(R.remove(player, third.id))
    lu.assertTrue(player:hasSkill(SKILL), "原有同名技能不得被实例撤销删除")

    FkTest.room:handleAddLoseSkills(player, "-" .. SKILL, nil, false, true)
    lu.assertFalse(player:hasSkill(SKILL))
  end)
end

function Testhanjin_retinue_instances:testClientReadsPublicSummaryWithoutServerRoom()
  local player = p(1)
  inRoom(function()
    R.grant(player, { general = GENERAL, skill = SKILL, position = "main" })
    R.grant(player, { general = GENERAL, skill = SKILL, position = "deputy" })
  end)

  withClientPlayer(player, function(client)
    lu.assertNil(client.room, "真实 ClientPlayer 不应有 room 字段")
    lu.assertEquals(R.count(client), 2)
    lu.assertEquals(R.publicCount(client), 2)
    lu.assertEquals(R.countForSkill(client, SKILL), 2)
    local summary = R.publicInstances(client)
    lu.assertEquals(#summary, 1)
    lu.assertEquals(summary[1].skill, SKILL)
    lu.assertEquals(summary[1].count, 2)
    -- 公开摘要不得带服务端实例细节。
    lu.assertNil(summary[1].id)
    lu.assertNil(summary[1].general)
    lu.assertNil(summary[1].position)
    lu.assertNil(summary[1].origin)
    lu.assertNil(summary[1].uses)
  end)
end

function Testhanjin_retinue_instances:testExternalMultiEffectSurvivesInstanceRemoval()
  local player = p(1)
  inRoom(function()
    -- 外部独立来源先持有“主效果 + 关联 targetmod”的多效果技能。
    FkTest.room:handleAddLoseSkills(player, probe.MULTI, probe.MULTI_EXTERNAL,
      false, true)
    lu.assertTrue(player:hasSkill(probe.MULTI))

    local instance = R.grant(player, { general = GENERAL, skill = probe.MULTI })
    local slashSkill = assert(Fk.skills["slash_skill"])
    local related = assert(Fk.skills[probe.MULTI].related_skills[1],
      "multi-effect skill should have a related targetmod")
    local function hasRelated()
      return table.find(player:getAllSkills(), function(s) return s == related end) ~= nil
    end
    local function maxSlash()
      return slashSkill:getMaxUseTime(player, Player.HistoryPhase,
        Fk:cloneCard("slash"))
    end
    -- 基线：基础1次 + 关联 targetmod 的1次，且关联效果在公开技能表中。
    lu.assertTrue(hasRelated())
    lu.assertEquals(maxSlash(), 2)

    -- 移除本模块最后一份实例；外部来源仍在，关联 targetmod 必须仍可观察。
    lu.assertTrue(R.remove(player, instance.id))
    lu.assertTrue(player:hasSkill(probe.MULTI), "外部独立来源不得被删除")
    lu.assertTrue(hasRelated(), "外部来源仍在时关联 targetmod 不得被连带删除")
    lu.assertEquals(maxSlash(), 2, "外部来源仍在时关联 targetmod 不得被连带删除")
  end)
end

return { name = "hanjin_retinue_instances" }
