-- HAN022 刘虞：安境及登记定向验收。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")

local LIUYU = "qiao_heg__han022"
local SUIFU = "qiao__skill_han022_1"
local ANJING = "qiao__skill_han022_2"
local ZHEN_SHI = require "packages.qiao.pkg.qiao_generals.data.zhen_shi"

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
    mode = "qiao_heg_mode", realSelection = true,
    settings = { qiao_candidate_kingdoms = { "han", "wei", "shu", "wu", "qun", "jin" }, qiao_kingdom_limit = 6 },
  }
  inRoom(function()
    skill_test.installBlankGenerals(room, { "han", "han", "wei", "wei", "wei", "wei", "wei", "wei" })
    for _, player in ipairs(room.players) do clearCards(player) end
    skill_test.installDualGenerals(room, room.players[1], { main = LIUYU, deputy = "qiao_test__han_2", kingdom = "han" })
  end)
  return room
end

Testqiao_han022_liuyu = { setup = prepare, tearDown = function() Fk.currentResponsePattern = nil; support.clearRoom() end }

function Testqiao_han022_liuyu:testFormalRegistration()
  local entry = assert(table.find(ZHEN_SHI.generals, function(d) return d.id == LIUYU end))
  lu.assertEquals(entry.number, "HAN022")
  local g = assert(Fk.generals[LIUYU])
  lu.assertEquals(g.trueName, "刘虞")
  lu.assertEquals(g.maxHp, 3)
  lu.assertTrue(table.contains(g:getSkillNameList(), SUIFU))
  lu.assertTrue(table.contains(g:getSkillNameList(), ANJING))
  inRoom(function() lu.assertTrue(Fk:canUseGeneral(LIUYU)) end)
end

function Testqiao_han022_liuyu:testAnjingSameKingdomDrawsOncePerTurn()
  local room, player, ally, other = FkTest.room, p(1), p(2), p(3)
  inRoom(function()
    room.current = other
    room:setPlayerProperty(player, "kingdom", "han"); player.kingdom = "han"
    room:setPlayerProperty(ally, "kingdom", "han"); ally.kingdom = "han"
    room:setPlayerProperty(other, "kingdom", "wei"); other.kingdom = "wei"
  end)
  local invoked = 0
  skill_test.withSkillRequests(room, ANJING, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == ANJING then invoked = invoked + 1; return true end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function() room:damage { from = other, to = ally, damage = 1, skillName = "test" } end)
    inRoom(function() room:damage { from = other, to = ally, damage = 1, skillName = "test" } end)
  end)
  lu.assertEquals(invoked, 1)
  lu.assertEquals(#player:getCardIds(Player.Hand), 1)
  lu.assertEquals(#ally:getCardIds(Player.Hand), 1)
  lu.assertEquals(#other:getCardIds(Player.Hand), 0)
end

function Testqiao_han022_liuyu:testSuifuRealFiveGrainOrderFromChosenStart()
  local room, player, current = FkTest.room, p(1), p(2)
  local start = p(3)
  local hand = give(current, "qiao__jink", Card.Heart, 2)
  inRoom(function()
    room:handleAddLoseSkills(player, "-" .. ANJING, nil, false)
    player.hp = player.maxHp
    current.hp = current.maxHp
    room.current = current
    room:setPlayerProperty(player, "kingdom", "han"); player.kingdom = "han"
    room:setPlayerProperty(current, "kingdom", "han"); current.kingdom = "han"
    room:setPlayerProperty(p(3), "kingdom", "wei"); p(3).kingdom = "wei"
  end)

  local damageSkill = fk.CreateSkill { name = "test_han022_damage_start" }
  damageSkill:addEffect(fk.EventPhaseStart, {
    global = true,
    can_trigger = function(self, event, target, who, data)
      return target == current and who == player and data ~= nil and data.phase == Player.Start
    end,
    on_cost = Util.TrueFunc,
    on_use = function()
      room:damage { from = p(3), to = player, damage = 1, skillName = "test" }
      room:damage { from = p(3), to = current, damage = 1, skillName = "test" }
    end,
  })
  Fk:addSkill(damageSkill:createSkill())

  local seen, topAtUse, handAtUse = {}, nil, nil
  local watcher = fk.CreateSkill { name = "test_han022_five_grain_order" }
  watcher:addEffect(fk.BeforeCardUseEffect, {
    global = true,
    can_refresh = function(self, event, target, who, data)
      return who == player and data and data.card and data.card.name == "qiao__amazing_grace"
    end,
    on_refresh = function(self, event, target, who, data)
      if topAtUse == nil then
        local displayed = data.extra_data and data.extra_data.AGFilled
        topAtUse = displayed and displayed[1] or room.draw_pile[1]
        handAtUse = current:getHandcardNum()
      end
    end,
  })
  watcher:addEffect(fk.CardEffectFinished, {
    global = true,
    can_refresh = function(self, event, target, who, data)
      return who == player and data and data.card and data.card.name == "qiao__amazing_grace"
    end,
    on_refresh = function(self, event, target, who, data)
      table.insert(seen, { to = target.id, from = data.from.id })
    end,
  })
  Fk:addSkill(watcher:createSkill())
  inRoom(function() room:addSkill(watcher.name) end)

  local oldAG = room.askToAG
  room.askToAG = function(self, who, params) return params.id_list[1] end
  skill_test.withSkillRequests(room, SUIFU, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == SUIFU then return true end
      return original(self, who, params)
    end,
    askToChoosePlayers = function(self, who, params, original)
      if params.skill_name == SUIFU then return { start } end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      room:addSkill(damageSkill.name)
      GameEvent.Turn:create(TurnData:new(current, "game_rule", {
        Player.Start, Player.Finish,
      })):exec()
    end)
  end)
  local suifuSeen, handAfterSuifu = seen, current:getHandcardNum()
  seen = {}
  inRoom(function()
    room:useCard {
      from = current, tos = table.simpleClone(room.alive_players),
      card = Fk:cloneCard("qiao__amazing_grace"),
    }
  end)
  local ordinaryFirst = seen[1] and seen[1].to
  seen = suifuSeen
  room.askToAG = oldAG

  lu.assertEquals(#seen, 8, "一次五谷应按八个目标各观察一次效果")
  lu.assertEquals(seen[1].to, start.id)
  lu.assertEquals(seen[1].from, player.id)
  lu.assertEquals(seen[2].to, p(4).id)
  lu.assertEquals(seen[8].to, p(2).id)
  lu.assertEquals(topAtUse, hand, "原手牌应实际置于牌堆顶")
  lu.assertEquals(handAtUse, 0, "使用五谷前当前角色已交出所有手牌")
  lu.assertEquals(handAfterSuifu, 1, "当前角色也会从五谷获得一张牌")
  lu.assertEquals(ordinaryFirst, current.id, "普通五谷保留正常结算起点")
end

return { name = "qiao_han022_liuyu" }
