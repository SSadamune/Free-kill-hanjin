-- 白马义从：同名多份实例各自触发；直接授予技能无实例时保留一份。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local R = require "packages.hanjin.pkg.hanjin_generals.util.retinue_instances"

local SKILL = "hanjin__retinue_skill_baima_yicong"
local GENERAL = "hanjin__retinue_baima_yicong"

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end
local function p(n) return FkTest.room.players[n] end

Testhanjin_retinue_multi_instance_baima = {
  setup = function()
    local room = support.initHanjinRoom()
    inRoom(function()
      skill_test.installBlankGenerals(room, "han")
      for _, player in ipairs(room.players) do
        local ids = player:getCardIds("he")
        if #ids > 0 then
          room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove,
            "test", nil, false)
        end
      end
    end)
  end,
  tearDown = support.clearRoom,
}

function Testhanjin_retinue_multi_instance_baima:testTwoSharedInstancesEachTrigger()
  local player, source = p(1), p(2)
  inRoom(function()
    for i = 1, 2 do
      local card = FkTest.room:printCard("hanjin__jink", Card.Heart, i)
      FkTest.room:obtainCard(source, card, false, fk.ReasonJustMove)
    end
    R.grant(player, { general = GENERAL, skill = SKILL, origin = "shared", shared_from = source.id })
    R.grant(player, { general = GENERAL, skill = SKILL, origin = "shared", shared_from = source.id + 10 })
    lu.assertEquals(R.countForSkill(player, SKILL), 2)
  end)

  local asked, gained = 0, 0
  skill_test.withSkillRequests(FkTest.room, SKILL, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == SKILL then asked = asked + 1; return true end
      return original(self, who, params)
    end,
    askToChooseCards = function(self, who, params, original)
      if params.skill_name ~= SKILL then return original(self, who, params) end
      gained = gained + 1
      return { source:getCardIds("he")[1] }
    end,
  }, function()
    inRoom(function()
      FkTest.room.logic:trigger(fk.CardUsing, player, {
        card = Fk:cloneCard("hanjin__jink"),
        responseToEvent = { from = source },
      })
    end)
  end)

  lu.assertEquals(asked, 2, "两份实例应各自询问")
  lu.assertEquals(gained, 2, "两份实例应各自获得一张牌")
end

function Testhanjin_retinue_multi_instance_baima:testDirectSkillWithoutInstanceActsOnce()
  local player, source = p(1), p(2)
  inRoom(function()
    local card = FkTest.room:printCard("hanjin__jink", Card.Heart, 3)
    FkTest.room:obtainCard(source, card, false, fk.ReasonJustMove)
    FkTest.room:handleAddLoseSkills(player, SKILL, nil, false, true)
  end)
  local asked = 0
  skill_test.withSkillRequests(FkTest.room, SKILL, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == SKILL then asked = asked + 1; return true end
      return original(self, who, params)
    end,
    askToChooseCards = function(self, who, params, original)
      if params.skill_name == SKILL then return { source:getCardIds("he")[1] } end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      FkTest.room.logic:trigger(fk.CardUsing, player, {
        card = Fk:cloneCard("hanjin__jink"),
        responseToEvent = { from = source },
      })
    end)
  end)
  lu.assertEquals(asked, 1, "直接授予技能无实例时保留本身一份")
end

return { name = "hanjin_retinue_multi_instance_baima" }
