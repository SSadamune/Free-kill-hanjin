-- JIN022B 牵弘：烈戎攻击范围持续、勤边最远目标静态验收。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local U = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_jin"
local DATA = require "packages.qiao.pkg.qiao_generals.data.zhen_shi_jin"

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function p(n) return FkTest.room.players[n] end

Testqiao_jin022b_qianhong = {
  setup = function()
    Fk.currentResponsePattern = nil
    local room = support.initQiaoRoom()
    inRoom(function() skill_test.installBlankGenerals(room, { "han", "han", "han", "han", "qun", "qun", "qun", "qun" }) end)
  end,
  tearDown = function()
    Fk.currentResponsePattern = nil
    support.clearRoom()
  end,
}

function Testqiao_jin022b_qianhong:testDataFragment()
  local qianhong
  for _, general in ipairs(DATA.generals) do
    if general.id == "qiao_heg__jin022b" then qianhong = general end
  end
  lu.assertNotNil(qianhong)
  lu.assertNotNil(Fk.generals["qiao_heg__jin022b"], "正式将池尚未合入 JIN022B")
  lu.assertEquals(qianhong.mainHpAdjust, 0)
  lu.assertEquals(#qianhong.skills, 2)
  lu.assertEquals(qianhong.skills[1].id, "qiao__skill_jin022b_1")
  lu.assertEquals(qianhong.skills[2].id, "qiao__skill_jin022b_2")
end

function Testqiao_jin022b_qianhong:testRangeSkillAndFarthestCandidate()
  local first, second, third = p(1), p(2), p(3)
  inRoom(function()
    FkTest.room:addSkill(Fk.skills[U.RANGE_SKILL])
    FkTest.room:setPlayerMark(first, U.RANGE, 1)
    lu.assertEquals(first:getAttackRange(), 2)
    lu.assertTrue(first:inMyAttackRange(third), "距离2应在+X后的攻击范围内")

    local candidates = U.farthestInRange(first)
    lu.assertTrue(table.contains(candidates, third), "距离2的third应在最远候选中")
    lu.assertFalse(table.contains(candidates, second), "距离1的second不是最远")

    FkTest.room:setPlayerMark(first, U.RANGE, 0)
    lu.assertEquals(first:getAttackRange(), 1)
  end)
end

function Testqiao_jin022b_qianhong:testLieRongMainFlowUsesFireSlash()
  local me, target = p(1), p(2)
  inRoom(function()
    local A = require "packages.qiao.pkg.qiao_mode.rules.adaptation"
    local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"
    FkTest.room:handleAddLoseSkills(me, "qiao__skill_jin022b_1", nil, false, true)
    local oldSelect, oldUse = C.selectVirtualCard, C.useCard
    local observed
    C.selectVirtualCard = function()
      return { from = me, tos = { target }, card = Fk:cloneCard("qiao__fire__slash"), extra_data = {} }
    end
    C.useCard = function(room, player, use, policy)
      observed = use
      return oldUse(room, player, use, policy)
    end
    local before = target.hp
    local ok, err = pcall(function()
      skill_test.withSkillRequests(FkTest.room, "qiao__skill_jin022b_1", {
        askToChoice = function() return "1" end,
      }, function()
        Fk.skills["qiao__skill_jin022b_1"]:onUse(FkTest.room, { from = me })
      end)
    end)
    C.selectVirtualCard, C.useCard = oldSelect, oldUse
    if not ok then error(err, 0) end
    lu.assertNotNil(observed)
    lu.assertEquals(observed.card.name, "qiao__fire__slash")
    lu.assertEquals(me:getMark(U.RANGE), 1)
    lu.assertTrue(target.hp < before, "真实火杀使用入口应实际结算伤害")
    lu.assertTrue(A.isAdaptationCard(observed.card, observed))
    lu.assertTrue(table.find(A.getEntries(observed.card, observed), function(entry)
      return entry.condition == "zhuzhan" and entry.effect == "damage"
    end) ~= nil)
  end)
end

return { name = "qiao_jin022b_qianhong" }
