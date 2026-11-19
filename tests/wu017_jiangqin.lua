-- WU017 蒋钦：尚义、鸟翔定向验收。
-- 正式编号 qiao_heg__wu017；数据由阵包 fragment 经中央入口合并。
local H = require "packages.hegemony.util"
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")

local JIANGQIN = "qiao_heg__wu017"
local SHANGYI = "qiao__skill_wu017_1"
local NIAOXIANG = "qiao__skill_wu017_2"
local BLANK_DEPUTY = "qiao_test__wu_2"

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function p(n) return FkTest.room.players[n] end

local function give(player, name, suit, number)
  local id
  inRoom(function()
    local card = FkTest.room:printCard(name, suit or Card.Spade, number or 7)
    FkTest.room:obtainCard(player, card, false, fk.ReasonJustMove)
    id = card.id
  end)
  return id
end

local function clearZone(player, zone)
  local ids = player:getCardIds(zone)
  if #ids > 0 then
    FkTest.room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove,
      "test", nil, false)
  end
end

local function prepare(kingdoms)
  Fk.currentResponsePattern = nil
  local room = support.createRoom {
    mode = "qiao_heg_mode",
    realSelection = true,
    settings = {
      qiao_faction_ban_enabled = false,
    },
  }
  inRoom(function()
    skill_test.installBlankGenerals(room, kingdoms)
    skill_test.installDualGenerals(room, room.players[1], {
      main = JIANGQIN, deputy = BLANK_DEPUTY, kingdom = "wu",
    })
    room.players[1]:revealGeneral(false)
    for _, player in ipairs(room.players) do clearZone(player, "he") end
  end)
  return room
end

Testqiao_wu017_jiangqin = {
  setup = function() prepare({ "wu", "wu", "wu", "wu", "wei", "wei", "wei", "wei" }) end,
  tearDown = function()
    Fk.currentResponsePattern = nil
    support.clearRoom()
  end,
}

function Testqiao_wu017_jiangqin:testFormalRegistration()
  local general = assert(Fk.generals[JIANGQIN])
  lu.assertEquals(general.trueName, "蒋钦")
  lu.assertEquals(general.maxHp, 4)
  lu.assertEquals(general.gender, General.Male)
  lu.assertEquals(general.kingdom, "wu")
  lu.assertTrue(general:isCompanionWith(Fk.generals["qiao_heg__wu013"]))
  lu.assertTrue(general:isCompanionWith(Fk.generals["qiao_heg__wu003"]))
  lu.assertTrue(table.contains(general:getSkillNameList(), SHANGYI))
  lu.assertTrue(table.contains(general:getSkillNameList(), NIAOXIANG))
  inRoom(function() lu.assertTrue(Fk:canUseGeneral(JIANGQIN)) end)
end

function Testqiao_wu017_jiangqin:testShangyiActiveViewsAndDiscardsOnePerBlackSuit()
  local room, player, target = FkTest.room, p(1), p(2)
  give(player, "qiao__jink", Card.Heart, 2)
  local spade = give(target, "qiao__jink", Card.Spade, 3)
  local club = give(target, "qiao__jink", Card.Club, 4)
  local heart = give(target, "qiao__jink", Card.Heart, 5)
  inRoom(function()
    room.current = player
    player.phase = Player.Play
    room:setBanner("RoundCount", 1)
  end)
  local skill = assert(Fk.skills[SHANGYI])
  local views = 0
  skill_test.withSkillRequests(room, SHANGYI, {
    viewCards = function(self, who, params, original)
      if params.skill_name ~= SHANGYI then return original(self, who, params) end
      views = views + 1
      return nil
    end,
    askToChooseCards = function(self, who, params, original)
      if params.skill_name ~= SHANGYI then return original(self, who, params) end
      return { spade, club }
    end,
  }, function()
    inRoom(function()
      lu.assertTrue(skill:canUse(player))
      room:useSkill(player, skill, function()
        skill:onUse(room, { from = player, cards = {}, tos = { target } })
      end, { from = player, cards = {}, tos = { target } })
    end)
  end)

  lu.assertEquals(views, 2, "先由目标看发动者手牌，再由发动者看目标手牌")
  lu.assertEquals(room:getCardArea(spade), Card.DiscardPile)
  lu.assertEquals(room:getCardArea(club), Card.DiscardPile)
  lu.assertEquals(room:getCardArea(heart), Card.PlayerHand)
  lu.assertEquals(player:getMark("qiao__skill_wu017_1_active-phase"), 1)
  inRoom(function() lu.assertFalse(skill:canUse(player), "主动入口本阶段限一次") end)
end

function Testqiao_wu017_jiangqin:testShangyiResponseEntryUsesCardSource()
  local room, player, source = FkTest.room, p(1), p(2)
  local slash = give(source, "qiao__slash", Card.Spade, 6)
  local jink = give(player, "qiao__jink", Card.Heart, 7)
  give(player, "qiao__peach", Card.Heart, 9) -- 响应后仍有手牌可供对方观看
  give(source, "qiao__jink", Card.Spade, 8)
  local skill = assert(Fk.skills[SHANGYI])
  local viewed = {}
  skill_test.withSkillRequests(room, SHANGYI, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == SHANGYI then return true end
      return original(self, who, params)
    end,
    viewCards = function(self, who, params, original)
      if params.skill_name ~= SHANGYI then return original(self, who, params) end
      table.insert(viewed, who)
      return nil
    end,
    askToChooseCards = function(self, who, params, original)
      if params.skill_name ~= SHANGYI then return original(self, who, params) end
      return {}
    end,
  }, function()
    FkTest.setNextReplies(player, { { card = jink } })
    inRoom(function()
      room:useCard {
        from = source,
        tos = { player },
        card = Fk:getCardById(slash),
      }
    end)
  end)
  lu.assertTrue(#viewed >= 1)
  lu.assertIs(viewed[1], source, "响应入口先让牌的使用者观看发动者手牌")
end

function Testqiao_wu017_jiangqin:testNiaoxiangAddsOneJinkToExistingRequirement()
  Fk.currentResponsePattern = nil
  local room = support.createRoom {
    mode = "qiao_heg_mode",
    realSelection = true,
    settings = {
      qiao_faction_ban_enabled = false,
    },
  }
  local holder, user, victim
  inRoom(function()
    -- 座位：p1=围攻者、p2=被围攻者、p3=另一围攻者。
    skill_test.installBlankGenerals(room, { "wu", "wei", "wu", "wu", "wu", "wu", "wu", "wu" })
    skill_test.installDualGenerals(room, room.players[1], {
      main = JIANGQIN, deputy = BLANK_DEPUTY, kingdom = "wu",
    })
    holder, user, victim = room.players[1], room.players[3], room.players[2]
    lu.assertTrue(H.inSiegeRelation(user, holder, victim), "测试座位应形成围攻关系")
  end)
  local recorded
  local function addProbe(name, priority, onUse)
    local skeleton = fk.CreateSkill { name = name, tags = { Skill.Compulsory } }
    skeleton:addEffect(fk.TargetSpecified, {
      global = true,
      priority = priority,
      can_trigger = function(self, event, target, player, data)
        return player == user and target == user and data.card ~= nil
          and data.card.trueName == "slash" and data.to == victim
      end,
      on_use = onUse,
    })
    local skill = skeleton:createSkill()
    Fk:addSkill(skill)
    inRoom(function() room:addSkill(skill) end)
  end
  addProbe("#qiao_test_niaoxiang_set_two", 2, function(self, event, target, player, data)
    data:setResponseTimes(2, data.to)
  end)
  addProbe("#qiao_test_niaoxiang_record", 0, function(self, event, target, player, data)
    recorded = data:getResponseTimes(data.to)
  end)

  FkTest.setNextReplies(victim, { "", "", "" })
  inRoom(function()
    room:useCard {
      from = user,
      tos = { victim },
      card = Fk:cloneCard("slash"),
    }
  end)
  lu.assertEquals(recorded, 3, "鸟翔应在已有2次要求上+1，而不是固定为2")
  support.clearRoom()
end

return { name = "qiao_wu017_jiangqin" }
