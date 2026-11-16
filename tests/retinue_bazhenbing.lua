-- 八阵兵：正常选择 1-2 名其他角色、本次结算临时无懈、同名轮次独立。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local R = require "packages.hanjin.pkg.hanjin_generals.util.retinue_instances"

local BAZHEN = "hanjin__retinue_skill_bazhenbing"
local TEMP = "hanjin__retinue_skill_bazhenbing_viewas"
local LURE = "hanjin__lure_tiger"

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end
local function p(n) return FkTest.room.players[n] end

Testhanjin_retinue_bazhenbing = {
  setup = function()
    Fk.currentResponsePattern = nil
    local room = support.initHanjinRoom()
    inRoom(function()
      skill_test.installBlankGenerals(room, {
        "shu", "shu", "shu", "shu", "qun", "qun", "qun", "qun",
      })
      room.current = room.players[2]
    end)
  end,
  tearDown = function()
    Fk.currentResponsePattern = nil
    support.clearRoom()
  end,
}

local function triggerPhase(room, target)
  room.logic:trigger(fk.EventPhaseStart, target, PhaseData:new {
    who = target, reason = "game_rule", phase = Player.Play,
  })
end

function Testhanjin_retinue_bazhenbing:testTargetsOtherAndTemporaryViewAsCleansUp()
  local room, owner, phase, other = FkTest.room, p(1), p(2), p(3)
  inRoom(function()
    R.grant(owner, { general = "hanjin__retinue_bazhenbing", skill = BAZHEN,
      origin = "granted" })
  end)
  skill_test.withSkillRequests(room, BAZHEN, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == BAZHEN then return true end
      return original(self, who, params)
    end,
    askToUseVirtualCard = function(self, who, params, original)
      if params.skill_name ~= BAZHEN then return original(self, who, params) end
      local card = Fk:cloneCard(LURE)
      card.skillName = BAZHEN
      -- 出牌阶段者是 phase；正常选择不应强制它。
      return { from = who, tos = { other }, card = card, extra_data = {} }
    end,
  }, function()
    inRoom(function() triggerPhase(room, phase) end)
  end)
  lu.assertEquals(other:getMark("@@lure_tiger-turn"), 1)
  lu.assertEquals(phase:getMark("@@lure_tiger-turn"), 0)
  lu.assertFalse(phase:hasSkill(TEMP))
  lu.assertEquals(phase:getMark("@@hanjin_bazhen_viewas"), 0)
end

function Testhanjin_retinue_bazhenbing:testSameNameInstancesHaveIndependentRoundLedgers()
  local room, owner, phase, a, b = FkTest.room, p(1), p(2), p(3), p(4)
  inRoom(function()
    R.grant(owner, { general = "hanjin__retinue_bazhenbing", skill = BAZHEN,
      origin = "granted" })
    R.grant(owner, { general = "hanjin__retinue_bazhenbing", skill = BAZHEN,
      origin = "granted" })
  end)
  local turns = { a, b }
  local index = 0
  skill_test.withSkillRequests(room, BAZHEN, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == BAZHEN then return true end
      return original(self, who, params)
    end,
    askToUseVirtualCard = function(self, who, params, original)
      if params.skill_name ~= BAZHEN then return original(self, who, params) end
      index = index + 1
      local card = Fk:cloneCard(LURE)
      card.skillName = BAZHEN
      return { from = who, tos = { turns[index] }, card = card, extra_data = {} }
    end,
  }, function()
    inRoom(function()
      triggerPhase(room, phase)
      triggerPhase(room, phase)
      triggerPhase(room, phase)
    end)
  end)
  lu.assertEquals(a:getMark("@@lure_tiger-turn"), 1)
  lu.assertEquals(b:getMark("@@lure_tiger-turn"), 1)
  lu.assertFalse(phase:hasSkill(TEMP))
end

function Testhanjin_retinue_bazhenbing:testRealNullificationRequestUsesSlashAsNullification()
  local room, owner, phase, other = FkTest.room, p(1), p(2), p(3)
  inRoom(function()
    R.grant(owner, { general = "hanjin__retinue_bazhenbing", skill = BAZHEN,
      origin = "granted" })
  end)
  local slash = inRoom(function()
    local card = room:printCard("hanjin__slash", Card.Spade, 8)
    room:obtainCard(phase, card, false, fk.ReasonJustMove)
    return card.id
  end)
  for _, p in ipairs(room.players) do
    if p == phase then
      FkTest.setNextReplies(p, {
        { card = { skill = TEMP, subcards = { slash } }, targets = {},
          interaction_data = "hanjin__nullification" },
      })
    else
      FkTest.setNextReplies(p, { "" })
    end
  end
  skill_test.withSkillRequests(room, BAZHEN, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == BAZHEN then return true end
      return original(self, who, params)
    end,
    askToUseVirtualCard = function(self, who, params, original)
      if params.skill_name ~= BAZHEN then return original(self, who, params) end
      local card = Fk:cloneCard(LURE)
      card.skillName = BAZHEN
      return { from = who, tos = { other }, card = card, extra_data = {} }
    end,
  }, function()
    inRoom(function() triggerPhase(room, phase) end)
  end)
  -- 出牌阶段者用临时 viewAs 把杀当无懈，调虎离山被抵消，目标不获得标记。
  lu.assertEquals(other:getMark("@@lure_tiger-turn"), 0)
  lu.assertFalse(table.contains(phase:getCardIds("h"), slash))
  lu.assertFalse(phase:hasSkill(TEMP))
  lu.assertEquals(phase:getMark("@@hanjin_bazhen_viewas"), 0)
end

function Testhanjin_retinue_bazhenbing:testTemporaryViewAsActuallyUsesSlashAsNullification()
  local room, phase = FkTest.room, p(2)
  local slash = inRoom(function()
    local card = room:printCard("hanjin__slash", Card.Spade, 7)
    room:obtainCard(phase, card, false, fk.ReasonJustMove)
    return card.id
  end)
  local card
  inRoom(function()
    room:setPlayerMark(phase, "@@hanjin_bazhen_viewas", 1)
    room:handleAddLoseSkills(phase, TEMP, BAZHEN, false, true)
    card = Fk.skills[TEMP]:viewAs(phase, { slash })
  end)
  lu.assertNotNil(card)
  lu.assertEquals(card.trueName, "nullification")
  lu.assertEquals(card.skillName, TEMP)
  inRoom(function()
    room:useCard { from = phase, tos = {}, card = card }
    room:handleAddLoseSkills(phase, "-" .. TEMP, BAZHEN, false, true)
    room:setPlayerMark(phase, "@@hanjin_bazhen_viewas", 0)
  end)
  lu.assertFalse(table.contains(phase:getCardIds("h"), slash))
  lu.assertFalse(phase:hasSkill(TEMP))
end

return { name = "hanjin_retinue_bazhenbing" }
