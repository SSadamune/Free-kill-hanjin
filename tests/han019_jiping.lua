-- HAN019 吉平：烈医、蛊毒定向验收。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local Commander = require "packages.hanjin.pkg.hanjin_mode.rules.commander_retinue"

local JIPING = "hanjin__han019"
local LIEYI = "hanjin__skill_han019_1"
local GUDU = "hanjin__skill_han019_2"
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
    FkTest.room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false)
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
    settings = { hanjin_candidate_kingdoms = { "han", "wei", "shu", "wu", "qun", "jin" }, hanjin_kingdom_limit = 6 },
  }
  inRoom(function()
    skill_test.installBlankGenerals(room, { "han", "han", "han", "han", "wei", "wei", "wei", "wei" })
    Commander.saveSources(room, {})
    for _, player in ipairs(room.players) do clearCards(player) end
    skill_test.installDualGenerals(room, room.players[1], { main = JIPING, deputy = "hanjin_test__han_2", kingdom = "han" })
  end)
  return room
end

Testhanjin_han019_jiping = { setup = prepare, tearDown = function() Fk.currentResponsePattern = nil; support.clearRoom() end }

function Testhanjin_han019_jiping:testFormalRegistration()
  local entry = assert(table.find(ZHEN_SHI.generals, function(d) return d.id == JIPING end))
  lu.assertEquals(entry.number, "HAN019")
  local g = assert(Fk.generals[JIPING])
  lu.assertEquals(g.trueName, "吉平")
  lu.assertEquals(g.maxHp, 3)
  lu.assertTrue(table.contains(g:getSkillNameList(), LIEYI))
  lu.assertTrue(table.contains(g:getSkillNameList(), GUDU))
  inRoom(function() lu.assertTrue(Fk:canUseGeneral(JIPING)) end)
end

function Testhanjin_han019_jiping:testLieyiHealsThenPreventsLaterDamage()
  local room, player, target = FkTest.room, p(1), p(2)
  local first = give(player, "hanjin__slash", Card.Spade, 2)
  local second = give(player, "hanjin__slash", Card.Heart, 3)
  inRoom(function() room.current = player; player.phase = Player.Play; room:setBanner("RoundCount", 1) end)
  skill_test.withSkillRequests(room, LIEYI, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == LIEYI then return true end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      room:useCard(UseCardData:new { from = player, tos = { target }, card = Fk:getCardById(first), extra_data = {} })
    end)
    inRoom(function()
      room:useCard(UseCardData:new { from = player, tos = { target }, card = Fk:getCardById(second), extra_data = {} })
    end)
  end)
  lu.assertEquals(target.hp, target.maxHp)
end

function Testhanjin_han019_jiping:testGuduPreventsRecoverThenTurnEndLosesHpAndRemovesCard()
  local room, player, target = FkTest.room, p(1), p(2)
  inRoom(function() target.hp = 2; player.phase = Player.Finish end)
  skill_test.withSkillRequests(room, GUDU, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == GUDU then return true end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      room:recover { who = target, num = 1, recoverBy = target, skillName = "test" }
      room.logic:trigger(fk.TurnEnd, player, TurnData:new(player, "game_rule", { Player.Start }))
    end)
  end)
  lu.assertEquals(target.hp, 1)
  local Exchange = require "packages.hanjin.pkg.hanjin_mode.rules.general_exchange"
  lu.assertTrue((Exchange.actualGeneral(player, false) or ""):startsWith("blank_"))
end

local function lieyiHealChoice(choice, expectedHp)
  local room, player, target = FkTest.room, p(1), p(2)
  local first = give(player, "hanjin__slash", Card.Spade, 2)
  local second = give(player, "hanjin__slash", Card.Heart, 3)
  inRoom(function()
    target.hp = 2
    room.current = player; player.phase = Player.Play; room:setBanner("RoundCount", 1)
  end)
  skill_test.withSkillRequests(room, LIEYI, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == LIEYI then return true end
      return original(self, who, params)
    end,
    askToChoice = function(self, who, params, original)
      if params.skill_name == LIEYI then return choice end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      room:useCard(UseCardData:new { from = player, tos = { target }, card = Fk:getCardById(first), extra_data = {} })
    end)
    inRoom(function()
      room:useCard(UseCardData:new { from = player, tos = { target }, card = Fk:getCardById(second), extra_data = {} })
    end)
  end)
  lu.assertEquals(target.hp, expectedHp)
end

function Testhanjin_han019_jiping:testLieyiChooseOne()
  lieyiHealChoice("hanjin__skill_han019_1-heal1", 2)
end

function Testhanjin_han019_jiping:testLieyiChooseTwo()
  lieyiHealChoice("hanjin__skill_han019_1-heal2", 3)
end

function Testhanjin_han019_jiping:testGuduRemovesSourceAfterGeneralExchange()
  local room, source, other, target = FkTest.room, p(1), p(2), p(3)
  local Exchange = require "packages.hanjin.pkg.hanjin_mode.rules.general_exchange"
  inRoom(function()
    -- 确定性合法统领来源：HAN009 伏完提供穆顺；p4 明置后，蛊毒移除
    -- 留下的空士兵可沿公共 GeneralRemoved -> queueConversion 链转翼从。
    local commander = p(4)
    room:changeHero(commander, "hanjin__han009", false, false, false, false, false)
    room:setPlayerMark(commander, "__heg_general", "hanjin__han009")
    commander:revealGeneral(false)
    local commanderSource = Commander.ensureSource(room, "hanjin__han009")
    commanderSource.factions.han = true
    commanderSource.revealed = true
    commanderSource.holder_id = commander.id
    target.hp = 2
    local ok = Exchange.exchange(room,
      { player = source, isDeputy = false },
      { player = other, isDeputy = false })
    lu.assertTrue(ok ~= false, "Jiping main should exchange to the other player")
    room:changeHero(source, "hanjin_test__han_3", false, false, false, false, false)
    room:setPlayerMark(source, "__heg_general", "hanjin_test__han_3")
    lu.assertEquals(other.general, JIPING)
  end)

  skill_test.withSkillRequests(room, GUDU, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == GUDU then return true end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      room:recover { who = target, num = 1, recoverBy = target, skillName = "test" }
      room.logic:trigger(fk.TurnEnd, other, TurnData:new(other, "game_rule", { Player.Start }))
    end)
  end)

  lu.assertEquals(target.hp, 1)
  local Exchange = require "packages.hanjin.pkg.hanjin_mode.rules.general_exchange"
  local actual = Exchange.actualGeneral(other, false)
  lu.assertNotEquals(actual, JIPING, "蛊毒应移除来源牌 JIPING")
  lu.assertTrue(Commander.isRetinue(actual),
    "确定性统领来源下，蛊毒移除后的空士兵应转翼从；other.general=" .. tostring(other.general)
    .. " actual=" .. tostring(actual)
    .. " mark=" .. tostring(other:getMark("__heg_general"))
    .. " deputy=" .. tostring(other.deputyGeneral)
    .. " source=" .. tostring(source.general)
    .. " gameover=" .. tostring(room.game_finished))
  lu.assertEquals(source.general, "hanjin_test__han_3")
end

return { name = "hanjin_han019_jiping" }
