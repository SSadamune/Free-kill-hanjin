-- 实体翼从位置 → 实例登记同步定向验收。
-- 使用现有标准翼从（西园军）做真实位置变更；不注册正式将池、不改 central。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local R = require "packages.hanjin.pkg.hanjin_generals.util.retinue_instances"
local S = require "packages.hanjin.pkg.hanjin_generals.util.retinue_instance_sources"
local Z = require "packages.hanjin.pkg.hanjin_generals.util.zhen_shi_retinues"
local Commander = require "packages.hanjin.pkg.hanjin_mode.rules.commander_retinue"
local Exchange = require "packages.hanjin.pkg.hanjin_mode.rules.general_exchange"

local RETINUE = "hanjin__retinue_xiyuanjun"
local SKILL = "hanjin__retinue_skill_xiyuanjun"
local BLANK = "blank_shibing"

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function p(n) return FkTest.room.players[n] end

local function setPosition(player, isDeputy, general)
  inRoom(function()
    FkTest.room:changeHero(player, general, false, isDeputy, false, false, false)
    FkTest.room:setPlayerMark(player,
      isDeputy and "__heg_deputy" or "__heg_general", general)
  end)
end

local function assign(player, isDeputy, retinue)
  inRoom(function()
    local ok = Commander.assignRetinue(player, isDeputy, retinue)
    lu.assertTrue(ok, "assign failed: isRetinue=" .. tostring(Commander.isRetinue(retinue))
      .. " general=" .. tostring(isDeputy and player.deputyGeneral or player.general))
  end)
end

local function entities(player, isDeputy)
  return inRoom(function() return R.entityInstances(player, isDeputy) end)
end

local function prepare()
  Fk.currentResponsePattern = nil
  local room = support.initHanjinRoom()
  inRoom(function()
    skill_test.installBlankGenerals(room, { "han", "han", "han", "han", "qun", "qun", "qun", "qun" })
    for _, player in ipairs(room.players) do
      local ids = player:getCardIds("he")
      if #ids > 0 then
        room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove,
          "test", nil, false)
      end
    end
    lu.assertTrue(S.ensureRule(room), "汉晋房间应能安装实体翼从同步规则")
    -- 本套件手工指定翼从；清空统领来源，避免变白兵时先被自动转成别的翼从。
    Commander.saveSources(room, {})
  end)
  return room
end

Testhanjin_retinue_instance_sources = {
  setup = prepare,
  tearDown = function()
    Fk.currentResponsePattern = nil
    support.clearRoom()
  end,
}

function Testhanjin_retinue_instance_sources:testExistingRetinuePositionCreatesOneStableEntity()
  local player = p(1)
  setPosition(player, false, BLANK)
  assign(player, false, RETINUE)
  local first = entities(player, false)
  lu.assertEquals(#first, 1)
  lu.assertEquals(first[1].origin, "entity")
  lu.assertEquals(first[1].position, "main")
  lu.assertEquals(first[1].general, RETINUE)
  lu.assertEquals(first[1].skill, SKILL)
  lu.assertTrue(player:hasSkill(SKILL))

  local id = first[1].id
  inRoom(function()
    S.syncPlayer(player)
    S.syncPlayer(player)
  end)
  local again = entities(player, false)
  lu.assertEquals(#again, 1, "重复同步不得重复添加实体实例")
  lu.assertEquals(again[1].id, id, "同一位置同一兵种应保留稳定实例")
end

function Testhanjin_retinue_instance_sources:testSameRetinueOnBothPositionsCreatesTwoEntities()
  local player = p(1)
  setPosition(player, false, BLANK)
  setPosition(player, true, BLANK)
  assign(player, false, RETINUE)
  assign(player, true, RETINUE)
  local main = entities(player, false)
  local deputy = entities(player, true)
  lu.assertEquals(#main, 1)
  lu.assertEquals(#deputy, 1)
  lu.assertNotEquals(main[1].id, deputy[1].id)
  lu.assertEquals(main[1].general, deputy[1].general)
  lu.assertEquals(main[1].skill, deputy[1].skill)
  lu.assertEquals(R.countForSkill(player, SKILL), 2, "两个位置各算一份实例")
end

function Testhanjin_retinue_instance_sources:testRemovingOnePositionKeepsOtherAndExtraSource()
  local player = p(1)
  setPosition(player, false, BLANK)
  setPosition(player, true, BLANK)
  assign(player, false, RETINUE)
  assign(player, true, RETINUE)
  local extra
  inRoom(function()
    extra = R.grant(player, {
      general = RETINUE, skill = SKILL, origin = "shared", shared_from = 2,
    })
  end)

  setPosition(player, false, BLANK)
  inRoom(function() S.syncPlayer(player) end)
  lu.assertEquals(#entities(player, false), 0, "普通士兵位置不应保留实体翼从")
  lu.assertEquals(#entities(player, true), 1, "另一位置的同名翼从必须保留")
  lu.assertNotNil(R.get(player, extra.id), "额外/共享实例不得被位置同步删除")
  lu.assertTrue(player:hasSkill(SKILL))
  lu.assertEquals(R.countForSkill(player, SKILL), 2)
end

function Testhanjin_retinue_instance_sources:testPositionChangeReplacesOnlyEntity()
  local player = p(1)
  setPosition(player, false, BLANK)
  assign(player, false, RETINUE)
  local old = entities(player, false)[1]
  local extra
  inRoom(function()
    extra = R.grant(player, { general = RETINUE, skill = SKILL, origin = "granted" })
  end)

  setPosition(player, false, "hanjin__retinue_mushun")
  inRoom(function() S.syncPlayer(player) end)
  local current = entities(player, false)
  lu.assertEquals(#current, 1)
  lu.assertEquals(current[1].general, "hanjin__retinue_mushun")
  lu.assertNotEquals(current[1].id, old.id)
  lu.assertNotNil(R.get(player, extra.id), "额外来源必须保留")
  local remaining = R.instancesForSkill(player, SKILL)
  lu.assertEquals(#remaining, 1)
  lu.assertIs(remaining[1], extra)
end

function Testhanjin_retinue_instance_sources:testExchangeMovesEntityIdentityUsesAndPhase()
  local first, second = p(1), p(2)
  setPosition(first, false, BLANK)
  setPosition(second, false, BLANK)
  assign(first, false, RETINUE)
  assign(second, false, RETINUE)

  local firstOld = entities(first, false)[1]
  local secondOld = entities(second, false)[1]
  local extra
  inRoom(function()
    extra = R.grant(first, { general = RETINUE, skill = SKILL, origin = "shared", shared_from = first.id })
    firstOld.bazhen_round=7
    Z.spend(first, firstOld, SKILL)
    lu.assertEquals(firstOld.uses, 1)
    lu.assertEquals(Z.phaseUsed(first, firstOld), 1)
    lu.assertEquals(secondOld.uses, 0)
  end)

  inRoom(function()
    local context = Exchange.exchange(FkTest.room,
      { player = first, isDeputy = false },
      { player = second, isDeputy = false })
    lu.assertNotNil(context)
  end)

  local firstNew = entities(first, false)[1]
  local secondNew = entities(second, false)[1]
  lu.assertEquals(secondNew.id, firstOld.id)
  lu.assertEquals(secondNew.uses, 1)
  lu.assertEquals(secondNew.bazhen_round,7,"翼从逐实例轮次状态随牌迁移")
  lu.assertEquals(firstNew.id, secondOld.id)
  lu.assertEquals(firstNew.uses, 0)
  inRoom(function()
    lu.assertEquals(Z.phaseUsed(second, secondNew), 1)
    lu.assertEquals(Z.phaseUsed(first, secondOld), 0)
    lu.assertNotNil(R.get(first, extra.id), "额外/共享来源不得随交换搬走")
    lu.assertTrue(first:hasSkill(SKILL))
    lu.assertTrue(second:hasSkill(SKILL))
    lu.assertEquals(R.countForSkill(first, SKILL), 2)
    lu.assertEquals(R.countForSkill(second, SKILL), 1)
  end)
end

function Testhanjin_retinue_instance_sources:testSamePlayerPositionExchangePreservesEachIdentity()
  local player = p(1)
  setPosition(player, false, BLANK)
  setPosition(player, true, BLANK)
  assign(player, false, RETINUE)
  assign(player, true, RETINUE)
  local mainOld = entities(player, false)[1]
  local deputyOld = entities(player, true)[1]
  inRoom(function()
    Z.spend(player, mainOld, SKILL)
    lu.assertEquals(mainOld.uses, 1)
    lu.assertEquals(Z.phaseUsed(player, mainOld), 1)
    lu.assertEquals(deputyOld.uses, 0)
  end)

  inRoom(function()
    local context = Exchange.exchange(FkTest.room,
      { player = player, isDeputy = false },
      { player = player, isDeputy = true })
    lu.assertNotNil(context)
  end)

  local mainNew = entities(player, false)[1]
  local deputyNew = entities(player, true)[1]
  lu.assertEquals(mainNew.id, deputyOld.id)
  lu.assertEquals(mainNew.uses, 0)
  lu.assertEquals(deputyNew.id, mainOld.id)
  lu.assertEquals(deputyNew.uses, 1)
  inRoom(function()
    lu.assertEquals(Z.phaseUsed(player, deputyNew), 1)
    lu.assertEquals(Z.phaseUsed(player, mainNew), 0)
    lu.assertEquals(R.countForSkill(player, SKILL), 2)
  end)
end

function Testhanjin_retinue_instance_sources:testIllegalHideDoesNotRecreateEntity()
  local player = p(1)
  setPosition(player, false, BLANK)
  assign(player, false, RETINUE)
  local original = entities(player, false)[1]
  inRoom(function()
    Z.spend(player, original, SKILL)
    lu.assertEquals(original.uses, 1)
    lu.assertEquals(Z.phaseUsed(player, original), 1)
  end)

  -- 翼从是士兵牌；引擎若仍按“暗置武将牌”触发，入口不得当常规生命周期
  -- 删除重建实体身份。
  inRoom(function() player:hideGeneral(false) end)
  local hidden = entities(player, false)
  lu.assertEquals(#hidden, 1)
  lu.assertEquals(hidden[1].id, original.id)
  lu.assertEquals(hidden[1].uses, 1)
  lu.assertEquals(Z.phaseUsed(player, hidden[1]), 1)

  inRoom(function() player:revealGeneral(false) end)
  inRoom(function()
    lu.assertEquals(player.general, RETINUE,
      "重新明置后主将实际应为翼从，实际=" .. tostring(player.general))
  end)
  local revealed = entities(player, false)
  lu.assertEquals(#revealed, 1)
  lu.assertEquals(revealed[1].id, original.id)
  lu.assertEquals(revealed[1].uses, 1)
  lu.assertEquals(Z.phaseUsed(player, revealed[1]), 1)
end

return { name = "hanjin_retinue_instance_sources" }
