-- 同名翼从触发技：两份共享实例在同一个 EventPhaseStart 各自询问一次。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local R = require "packages.qiao.pkg.qiao_generals.util.retinue_instances"

local XIYUAN = "qiao__retinue_skill_xiyuanjun"

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function p(n) return FkTest.room.players[n] end

Testqiao_retinue_multi_instance = {
  setup = function()
    Fk.currentResponsePattern = nil
    local room = support.initQiaoRoom()
    inRoom(function()
      skill_test.installBlankGenerals(room, { "han", "han", "han", "han", "qun", "qun", "qun", "qun" })
      for _, player in ipairs(room.players) do
        local ids = player:getCardIds("he")
        if #ids > 0 then
          room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove,
            "test", nil, false)
        end
      end
    end)
  end,
  tearDown = function()
    Fk.currentResponsePattern = nil
    support.clearRoom()
  end,
}

function Testqiao_retinue_multi_instance:testTwoSharedXiyuanInstancesAskTwice()
  local player, target = p(1), p(2)
  inRoom(function()
    for _, spec in ipairs({ { Card.Heart, 2 }, { Card.Spade, 3 } }) do
      local card = FkTest.room:printCard("qiao__jink", spec[1], spec[2])
      FkTest.room:obtainCard(target, card, false, fk.ReasonJustMove)
    end
    local first = R.grant(player, {
      general = "qiao_heg__retinue_xiyuanjun",
      skill = XIYUAN,
      origin = "shared",
      shared_from = 2,
    })
    local second = R.grant(player, {
      general = "qiao_heg__retinue_xiyuanjun",
      skill = XIYUAN,
      origin = "shared",
      shared_from = 3,
    })
    lu.assertNotEquals(first.id, second.id)
    lu.assertEquals(R.countForSkill(player, XIYUAN), 2)
    lu.assertTrue(player:hasSkill(XIYUAN))
    player.phase = Player.Play
  end)

  local selected = 0
  local choices = 0
  FkTest.setRoomBreakpoint(player, "AskForUseActiveSkill", function(data)
    if data[1] == "choose_players_skill" and data[4].skillName == XIYUAN then
      lu.assertTrue(data[3])
      lu.assertEquals(data[4].targets, { target.id })
      selected = selected + 1
    end
    return false
  end)
  FkTest.setNextReplies(player, {
    FkTest.ReplyChoosePlayer({ target }),
    FkTest.ReplyChoosePlayer({ target }),
  })
  skill_test.withSkillRequests(FkTest.room, XIYUAN, {
    askToSkillInvoke = function() error("西园军应在选人请求中确认发动") end,
    askToChooseCard = function(self, who, params, original)
      if params.skill_name ~= XIYUAN then return original(self, who, params) end
      choices = choices + 1
      return target:getCardIds(Player.Hand)[choices]
    end,
  }, function()
    inRoom(function()
      FkTest.room.logic:trigger(fk.EventPhaseStart, player, { phase = Player.Play })
    end)
  end)

  lu.assertEquals(selected, 2, "两份同名共享实例应各自确认一次唯一目标")
  lu.assertEquals(choices, 2, "两份实例应各自完成一次选牌成本")
end

return { name = "qiao_retinue_multi_instance" }
