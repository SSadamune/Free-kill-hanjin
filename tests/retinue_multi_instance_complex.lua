-- 并州狼骑/锦帆军多实例登记静态夹具；行为另由 runtime 验证。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local R = require "packages.hanjin.pkg.hanjin_generals.util.retinue_instances"
local Z = require "packages.hanjin.pkg.hanjin_generals.util.zhen_shi_retinues"

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end
local function p(n) return FkTest.room.players[n] end

Testhanjin_retinue_multi_instance_complex = {
  setup = function()
    local room = support.initHanjinRoom()
    inRoom(function() skill_test.installBlankGenerals(room, "han") end)
  end,
  tearDown = support.clearRoom,
}

function Testhanjin_retinue_multi_instance_complex:testTwoInstancesPerComplexSkill()
  local me, donor = p(1), p(2)
  inRoom(function()
    for _, spec in ipairs({
      { "hanjin__retinue_bingzhou_langqi", "hanjin__retinue_skill_bingzhou_langqi" },
      { "hanjin__retinue_jinfanjun", "hanjin__retinue_skill_jinfanjun" },
    }) do
      R.grant(me, { general = spec[1], skill = spec[2], origin = "shared", shared_from = donor.id })
      R.grant(me, { general = spec[1], skill = spec[2], origin = "shared", shared_from = donor.id })
      lu.assertEquals(R.countForSkill(me, spec[2]), 2)
      lu.assertTrue(me:hasSkill(spec[2]))
    end
  end)
end

function Testhanjin_retinue_multi_instance_complex:testDirectJinfanSkillFallbackExists()
  local me = p(3)
  inRoom(function()
    FkTest.room:handleAddLoseSkills(me, "hanjin__retinue_skill_jinfanjun", nil, false, true)
    lu.assertEquals(R.countForSkill(me, "hanjin__retinue_skill_jinfanjun"), 0)
    lu.assertTrue(me:hasSkill("hanjin__retinue_skill_jinfanjun"))
  end)
end

function Testhanjin_retinue_multi_instance_complex:testClientBingzhouButtonAfterOneOfTwoUsed()
  local me, donor = p(1), p(2)
  local first, second
  inRoom(function()
    first = R.grant(me, {
      general = "hanjin__retinue_bingzhou_langqi",
      skill = "hanjin__retinue_skill_bingzhou_langqi",
      origin = "shared", shared_from = donor.id,
    })
    second = R.grant(me, {
      general = "hanjin__retinue_bingzhou_langqi",
      skill = "hanjin__retinue_skill_bingzhou_langqi",
      origin = "shared", shared_from = donor.id,
    })
    Z.spend(me, first, "hanjin__retinue_skill_bingzhou_langqi")
  end)

  local ClientPlayer = require "ltk.client.clientplayer"
  local function copyOf(player)
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
    return copy
  end

  local copy = copyOf(me)
  copy.phase = Player.Play
  lu.assertEquals(R.countForSkill(copy, "hanjin__retinue_skill_bingzhou_langqi"), 2)
  lu.assertTrue(Z.canUse(copy, "hanjin__retinue_skill_bingzhou_langqi", 1),
    "第一份已用、第二份未用时，ClientPlayer应仍可点按钮")
  lu.assertTrue(Fk.skills["hanjin__retinue_skill_bingzhou_langqi"]:canUse(copy),
    "客户端主动按钮的 canUse 也应可用")

  inRoom(function()
    Z.spend(me, second, "hanjin__retinue_skill_bingzhou_langqi")
  end)
  copy = copyOf(me)
  copy.phase = Player.Play
  lu.assertFalse(Z.canUse(copy, "hanjin__retinue_skill_bingzhou_langqi", 1),
    "两份都用完后，ClientPlayer按钮应不可用")
  lu.assertFalse(Fk.skills["hanjin__retinue_skill_bingzhou_langqi"]:canUse(copy))
end

function Testhanjin_retinue_multi_instance_complex:testTwoJinfanInstancesUseRedIndependently()
  local me, donor = p(1), p(2)
  local first, second, red1, red2
  inRoom(function()
    first = R.grant(me, {
      general = "hanjin__retinue_jinfanjun",
      skill = "hanjin__retinue_skill_jinfanjun",
      origin = "shared", shared_from = donor.id,
    })
    second = R.grant(me, {
      general = "hanjin__retinue_jinfanjun",
      skill = "hanjin__retinue_skill_jinfanjun",
      origin = "shared", shared_from = donor.id,
    })
    red1 = FkTest.room:printCard("hanjin__jink", Card.Heart, 2)
    red2 = FkTest.room:printCard("hanjin__jink", Card.Heart, 3)
    FkTest.room:obtainCard(me, red1, false, fk.ReasonJustMove)
    FkTest.room:obtainCard(me, red2, false, fk.ReasonJustMove)
  end)

  local discarded = 0
  skill_test.withSkillRequests(FkTest.room, "hanjin__retinue_skill_jinfanjun", {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == "hanjin__retinue_skill_jinfanjun" then return true end
      return original(self, who, params)
    end,
    askToDiscard = function(self, who, params, original)
      if params.skill_name ~= "hanjin__retinue_skill_jinfanjun" then
        return original(self, who, params)
      end
      discarded = discarded + 1
      local id = discarded == 1 and red1.id or red2.id
      FkTest.room:throwCard({ id }, "hanjin__retinue_skill_jinfanjun", who, who)
      return { id }
    end,
  }, function()
    inRoom(function()
      FkTest.room.logic:trigger(fk.AfterCardsMove, nil, {
        {
          moveReason = fk.ReasonDiscard,
          toArea = Card.DiscardPile,
          proposer = me,
          skillName = "test",
          moveInfo = { { cardId = red1.id } },
        },
      })
    end)
  end)

  lu.assertEquals(discarded, 2, "两份锦帆军都应能就同一红色弃牌事件各发动一次")
  lu.assertTrue(first.jinfanUsed[Card.Red])
  lu.assertTrue(second.jinfanUsed[Card.Red])
end

return { name = "hanjin_retinue_multi_instance_complex" }
