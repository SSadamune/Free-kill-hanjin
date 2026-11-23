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

function Testqiao_jin022b_qianhong:testLieRongRangeAndZeroLostHpUseRealRequest()
  local room, me, adjacent, farther = FkTest.room, p(1), p(2), p(3)
  local name = "qiao__skill_jin022b_1"
  local healAfterCost = false
  local watcher = fk.CreateSkill { name = "#qiao_test_lierong_recover" }
  watcher:addEffect(fk.HpLost, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return healAfterCost and target == me and player == me and data.skillName == name
    end,
    on_refresh = function()
      room:recover { who = me, num = 1 }
    end,
  })
  inRoom(function()
    room:addSkill(watcher:createSkill())
    room.current = me
    me.phase = Player.Play
    room:handleAddLoseSkills(me, name, nil, false, true)
    for _, target in ipairs({ adjacent, farther }) do
      local hand = target:getCardIds("h")
      if #hand > 0 then room:moveCardTo(hand, Card.DiscardPile, nil, fk.ReasonJustMove) end
    end
  end)
  local function useOn(target)
    FkTest.setNextReplies(me, { {
      card = { skill = "virtual_viewas", subcards = {} },
      targets = { target.id }, interaction_data = "qiao__fire__slash",
    } })
    FkTest.setNextReplies(target, { "" })
    inRoom(function() Fk.skills[name]:onUse(room, { from = me }) end)
  end
  local fartherHp, adjacentHp = farther.hp, adjacent.hp
  useOn(farther)
  lu.assertEquals(me:getMark(U.RANGE), 1)
  lu.assertEquals(farther.hp, fartherHp - 1)
  inRoom(function()
    room:setPlayerMark(me, U.RANGE, 0)
    me.hp = me.maxHp
  end)
  healAfterCost = true
  useOn(adjacent)
  lu.assertEquals(me.hp, me.maxHp)
  lu.assertEquals(me:getMark(U.RANGE), 0)
  lu.assertEquals(adjacent.hp, adjacentHp - 1)
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

function Testqiao_jin022b_qianhong:testLieRongAddsAcrossPlayPhases()
  local room, me = FkTest.room, FkTest.room.players[1]
  local skillName = "qiao__skill_jin022b_1"
  local limit = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_jin"
  local used, bonus = 0
  local skeleton = fk.CreateSkill{ name = "#qiao_test_lierong_extra_play" }
  skeleton:addEffect(fk.EventPhaseStart, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return target == me and player == me and data.phase == Player.Play
    end,
    on_refresh = function()
      local skill = Fk.skills[skillName]
      lu.assertTrue(skill:canUse(me))
      used = used + 1
      skill:onUse(room, { from = me, tos = {} })
      if used == 2 then bonus = me:getMark(limit.RANGE) end
    end,
  })
  skill_test.withSkillRequests(room, skillName, { askToChoice = function() return "1" end }, function()
    inRoom(function()
      room:handleAddLoseSkills(me, skillName, nil, false, true)
      room:addSkill(skeleton:createSkill())
      GameEvent.Turn:create(TurnData:new(me, "game_rule", { Player.Play, Player.Play })):exec()
    end)
  end)
  lu.assertEquals(used, 2)
  lu.assertEquals(bonus, 2, "同回合两次增加攻击范围应累计")
end

function Testqiao_jin022b_qianhong:testLieRongUsesSlashAfterPayment()
  local room, me, target = FkTest.room, FkTest.room.players[1], FkTest.room.players[2]
  local name = "qiao__skill_jin022b_1"
  local asked, canDecline, legal, range, spent, history
  local U = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_jin"
  skill_test.withSkillRequests(room, name, {
    askToUseVirtualCard = function(self, player, params, original)
      asked = true
      legal = player:canUseTo(Fk:cloneCard("qiao__fire__slash"), target)
      canDecline = params.cancelable
      FkTest.setNextReplies(me, { "" })
      return original(self, player, params)
    end,
  }, function()
    inRoom(function()
      room:setCurrent(me)
      me.phase = Player.Play
      room:handleAddLoseSkills(me, name, nil, false, true)
      local beforeHp = me.hp
      Fk.skills[name]:onUse(room, { from = me, tos = {} })
      spent = beforeHp - me.hp
      range = me:getMark(U.RANGE)
      history = #room.logic:getEventsOfScope(GameEvent.UseCard, 10, function(e)
        return e.data.from == me and e.data.card.name == "qiao__fire__slash"
      end, Player.HistoryGame)
    end)
  end)
  lu.assertEquals({ asked, legal, spent, range }, { true, true, 1, 1 })
  lu.assertFalse(canDecline)
  lu.assertEquals(history, 1)
end

return { name = "qiao_jin022b_qianhong" }
