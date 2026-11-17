-- HAN014 朱儁：摧破、虎翼定向验收。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")

local ZHUJUN = "hanjin__han014"
local CUICUO = "hanjin__skill_han014_1"
local HUYI = "hanjin__skill_han014_2"
local ZHEN_SHI = require "packages.hanjin.pkg.hanjin_generals.data.zhen_shi"

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end
local function p(n) return FkTest.room.players[n] end
local function clearCards(player)
  local ids = player:getCardIds("he")
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

local function prepare()
  Fk.currentResponsePattern = nil
  local room = support.createRoom {
    mode = "hanjin_heg_mode", realSelection = true,
    settings = {
      hanjin_candidate_kingdoms = { "han", "wei", "shu", "wu", "qun", "jin" },
      hanjin_kingdom_limit = 6,
    },
  }
  inRoom(function()
    skill_test.installBlankGenerals(room, { "han", "han", "han", "han", "han", "han", "han", "han" })
    for _, player in ipairs(room.players) do clearCards(player) end
    skill_test.installDualGenerals(room, room.players[1], {
      main = ZHUJUN, deputy = "hanjin_test__han_2", kingdom = "han",
    })
  end)
  return room
end

Testhanjin_han014_zhujun = {
  setup = prepare,
  tearDown = function() Fk.currentResponsePattern = nil; support.clearRoom() end,
}

function Testhanjin_han014_zhujun:testFormalRegistration()
  local pack = assert(Fk.packages.hanjin_zhenshi)
  local entry = assert(table.find(ZHEN_SHI.generals, function(d) return d.id == ZHUJUN end))
  lu.assertEquals(entry.number, "HAN014")
  local g = assert(Fk.generals[ZHUJUN])
  lu.assertIs(g.package, pack)
  lu.assertEquals(g.trueName, "朱儁")
  lu.assertEquals(g.kingdom, "han")
  lu.assertEquals(g.maxHp, 4)
  lu.assertEquals(g.gender, General.Male)
  lu.assertTrue(g:isCompanionWith(Fk.generals["hanjin__han013"]))
  lu.assertTrue(g:isCompanionWith(Fk.generals["hanjin__wu009"]))
  lu.assertTrue(table.contains(g:getSkillNameList(), CUICUO))
  lu.assertTrue(table.contains(g:getSkillNameList(), HUYI))
  inRoom(function() lu.assertTrue(Fk:canUseGeneral(ZHUJUN)) end)
end

function Testhanjin_han014_zhujun:testCuipuoFirstCardAddsDamageToTarget()
  local room, player, target = FkTest.room, p(1), p(2)
  local slash = give(player, "hanjin__slash", Card.Spade, 2)
  inRoom(function()
    room.current = player; player.phase = Player.Play; room:setBanner("RoundCount", 1)
  end)
  inRoom(function()
    room:useCard(UseCardData:new {
      from = player, tos = { target }, card = Fk:getCardById(slash), extra_data = {},
    })
  end)
  lu.assertEquals(target.hp, target.maxHp - 2)
end

function Testhanjin_han014_zhujun:testHuyiOtherBesiegerFollowsWithRealSlash()
  local room, owner, victim, ally = FkTest.room, p(1), p(2), p(3)
  inRoom(function()
    room:setPlayerProperty(ally, "kingdom", "han")
    ally.kingdom = "han"
    room:setPlayerProperty(victim, "kingdom", "wei")
    victim.kingdom = "wei"
    owner.hp, ally.hp, victim.hp = owner.maxHp, ally.maxHp, victim.maxHp
    room.current = ally
  end)
  local allySlash = give(ally, "hanjin__slash", Card.Spade, 2)
  local ownerSlash = give(owner, "hanjin__slash", Card.Heart, 3)

  skill_test.withSkillRequests(room, HUYI, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == HUYI then return true end
      return original(self, who, params)
    end,
    askToUseCard = function(self, who, params, original)
      lu.assertIs(who, owner)
      return {
        from = owner, tos = { victim },
        card = Fk:getCardById(ownerSlash), extra_data = {},
      }
    end,
  }, function()
    inRoom(function()
      room:useCard(UseCardData:new {
        from = ally, tos = { victim }, card = Fk:getCardById(allySlash), extra_data = {},
      })
    end)
  end)

  lu.assertEquals(owner:usedSkillTimes(HUYI, Player.HistoryTurn), 1)
  lu.assertEquals(FkTest.room:getCardArea(ownerSlash), Card.DiscardPile)
end

return { name = "hanjin_han014_zhujun" }
