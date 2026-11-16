-- SHU018B 费祎：生息、守成定向验收。
-- 规则依据：rules/generals/shu018b-feiyi.md。
-- 本轮只覆盖正式登记、真实结束阶段的生息、守成的摸2弃1与逐目标限次。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")

local FEIYI = "hanjin__shu018b"
local SHENGXI = "hanjin__skill_shu018b_1"
local SHOUCHENG = "hanjin__skill_shu018b_2"
local BLANK_DEPUTY = "hanjin_test__shu_2"

local STANDARD = require "packages.hanjin.pkg.hanjin_generals.data.standard"
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

local function moveHandToDiscard(player)
  FkTest.room:moveCardTo(player:getCardIds(Player.Hand), Card.DiscardPile, nil,
    fk.ReasonDiscard, "test", nil, false)
end

local function prepare()
  Fk.currentResponsePattern = nil
  local room = support.createRoom {
    mode = "hanjin_heg_mode",
    realSelection = true,
    settings = {
      hanjin_candidate_kingdoms = { "han", "wei", "shu", "wu", "qun", "jin" },
      hanjin_kingdom_limit = 6,
    },
  }
  inRoom(function()
    skill_test.installBlankGenerals(room, {
      "shu", "shu", "shu", "shu", "wei", "wei", "wei", "wei",
    })
    -- 清空初始手牌时费祎尚未安装，避免准备阶段触发守成。
    for _, player in ipairs(room.players) do clearCards(player) end
    skill_test.installDualGenerals(room, room.players[1], {
      main = FEIYI,
      deputy = BLANK_DEPUTY,
      kingdom = "shu",
    })
  end)
  return room
end

Testhanjin_shu018b_feiyi = {
  setup = prepare,
  tearDown = function()
    Fk.currentResponsePattern = nil
    support.clearRoom()
  end,
}

function Testhanjin_shu018b_feiyi:testFormalRegistrationDoesNotMixUpstreamFeiyi()
  local pack = assert(Fk.packages.hanjin_zhenshi, "missing 阵/势 formal package")
  local entry = assert(table.find(ZHEN_SHI.generals, function(data)
    return data.id == FEIYI
  end), "missing Feiyi data entry")
  lu.assertEquals(entry.number, "SHU018B")
  lu.assertEquals(#Fk.packages.hanjin_generals.generals,
    STANDARD.generalCount + STANDARD.retinueCount)
  lu.assertNil(table.find(Fk.packages.hanjin_generals.generals, function(g)
    return g.name == FEIYI
  end))
  lu.assertEquals(STANDARD.generalCount, 90)
  lu.assertEquals(ZHEN_SHI.generalCount, #ZHEN_SHI.generals)

  lu.assertTrue(table.contains(Fk.extensions["hanjin"], "hanjin_zhenshi"))
  local general = assert(Fk.generals[FEIYI])
  lu.assertIs(general.package, pack)
  lu.assertTrue(table.contains(pack.generals, general))
  lu.assertEquals(general.trueName, "费祎")
  lu.assertEquals(general.kingdom, "shu")
  lu.assertEquals(general.maxHp, 3)
  lu.assertEquals(general.gender, General.Male)
  lu.assertEquals(general.mainMaxHpAdjustedValue, 0)
  lu.assertEquals(general.deputyMaxHpAdjustedValue, 0)
  lu.assertTrue(general:isCompanionWith(Fk.generals["hanjin__shu004"]))
  lu.assertTrue(table.contains(general:getSkillNameList(), SHENGXI))
  lu.assertTrue(table.contains(general:getSkillNameList(), SHOUCHENG))
  lu.assertNotEquals(general, Fk.generals["os_heg__feiyi"])
  inRoom(function()
    lu.assertTrue(Fk:canUseGeneral(FEIYI),
      "Feiyi should be selectable in the formal HanJin mode")
  end)
end

function Testhanjin_shu018b_feiyi:testShengxiDrawsTwoInRealEndPhaseWithoutDamage()
  local room, player = FkTest.room, p(1)
  local invoked = 0
  skill_test.withSkillRequests(room, SHENGXI, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == SHENGXI then
        invoked = invoked + 1
        return true
      end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      GameEvent.Turn:create(TurnData:new(player, "game_rule", { Player.Finish })):exec()
    end)
  end)
  lu.assertEquals(invoked, 1)
  lu.assertEquals(#player:getCardIds(Player.Hand), 2)
  lu.assertEquals(player:usedSkillTimes(SHENGXI, Player.HistoryGame), 1)
end

function Testhanjin_shu018b_feiyi:testShengxiSeesDamageBeforeLateAcquireAndSkipsAfterDamage()
  local room, player = FkTest.room, p(1)
  local victim = p(3)
  inRoom(function()
    room:handleAddLoseSkills(player, "-" .. SHENGXI, nil, false, true)
  end)

  -- 在真实出牌阶段内造成一次伤害；伤害后重新取得生息，再进入结束阶段。
  -- 若实现只记录“取得技能后”的伤害，就会错误触发。
  local probe = fk.CreateSkill { name = "#hanjin_shu018b_damage_probe" }
  probe:addEffect(fk.EventPhaseStart, {
    global = true,
    can_refresh = function(self, event, target, who, data)
      return target == player and who == player and data.phase == Player.Play
    end,
    on_refresh = function()
      room:damage { from = player, to = victim, damage = 1, skillName = "test" }
      room:handleAddLoseSkills(player, SHENGXI, nil, false, true)
    end,
  })
  inRoom(function() room:addSkill(probe:createSkill()) end)

  local invoked = 0
  skill_test.withSkillRequests(room, SHENGXI, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == SHENGXI then
        invoked = invoked + 1
        return true
      end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      GameEvent.Turn:create(TurnData:new(player, "game_rule", {
        Player.Play, Player.Finish,
      })):exec()
    end)
  end)

  lu.assertEquals(victim.hp, victim.maxHp - 1)
  lu.assertEquals(invoked, 0)
  lu.assertEquals(#player:getCardIds(Player.Hand), 0)
  lu.assertEquals(player:usedSkillTimes(SHENGXI, Player.HistoryGame), 0)
end

function Testhanjin_shu018b_feiyi:testShouchengPerTargetOnceAndDrawTwoDiscardOne()
  local room = FkTest.room
  local holder, first, second = p(1), p(2), p(4)
  local turn_player, second_holder, other_kingdom = p(3), p(5), p(6)
  give(first, "hanjin__jink", Card.Heart, 2)
  give(first, "hanjin__peach", Card.Diamond, 3)
  give(second, "hanjin__slash", Card.Spade, 4)
  give(turn_player, "hanjin__jink", Card.Club, 5)
  give(other_kingdom, "hanjin__peach", Card.Heart, 6)

  local invoked, discards, invokedBy = 0, {}, {}
  local probe = fk.CreateSkill { name = "#hanjin_shu018b_shoucheng_probe" }
  probe:addEffect(fk.EventPhaseStart, {
    global = true,
    can_refresh = function(self, event, target, who, data)
      return target == p(3) and who == p(3) and data.phase == Player.Play
    end,
    on_refresh = function()
      -- 直接执行 Turn 事件时引擎不会替测试夹具写 room.current；真实回合由
      -- 游戏循环在进入事件前设置。这里显式设置以验证“目标回合外”条件。
      room.current = turn_player
      -- 当前回合角色本人在自己回合内失去最后手牌，不触发。
      moveHandToDiscard(turn_player)
      lu.assertEquals(invoked, 0)

      -- 一次批量失去两张手牌：只按角色触发一次，且此时手牌为空。
      moveHandToDiscard(first)
      lu.assertEquals(invoked, 1)
      lu.assertEquals(#first:getCardIds(Player.Hand), 1)

      -- 失去并重新取得守成、再暗置并明置费祎，均不得抹掉第一目标的本回合记录。
      room:handleAddLoseSkills(holder, "-" .. SHOUCHENG, nil, false, true)
      room:handleAddLoseSkills(holder, SHOUCHENG, nil, false, true)
      holder:hideGeneral(false)
      holder:revealGeneral(false, true)
      moveHandToDiscard(first)
      lu.assertEquals(invoked, 1)
      lu.assertEquals(#first:getCardIds(Player.Hand), 0)

      -- 不同受益角色的限次独立。
      moveHandToDiscard(second)
      lu.assertEquals(invoked, 2)
      lu.assertEquals(#second:getCardIds(Player.Hand), 1)

      -- 第二名守成持有者：第一持有者已对 first 发动过，不得占用第二持有者的
      -- 独立限次。先给 first 一张新手牌，再令其于回合外失去最后手牌。
      room:setPlayerProperty(second_holder, "kingdom", "shu")
      second_holder.kingdom = "shu"
      room:setPlayerMark(second_holder, "__heg_kingdom", "shu")
      room:handleAddLoseSkills(second_holder, SHOUCHENG, nil, false, true)
      local extra = room:printCard("hanjin__jink", Card.Heart, 8)
      room:obtainCard(first, extra, false, fk.ReasonJustMove)
      moveHandToDiscard(first)
      lu.assertEquals(invoked, 3)
      lu.assertEquals(#first:getCardIds(Player.Hand), 1)

      -- 不同势力角色即使在其回合外失去最后手牌，也不触发。
      moveHandToDiscard(other_kingdom)
      lu.assertEquals(invoked, 3)
      lu.assertEquals(#other_kingdom:getCardIds(Player.Hand), 0)
    end,
  })
  inRoom(function() room:addSkill(probe:createSkill()) end)

  skill_test.withSkillRequests(room, SHOUCHENG, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == SHOUCHENG then
        invoked = invoked + 1
        invokedBy[who.id] = (invokedBy[who.id] or 0) + 1
        return true
      end
      return original(self, who, params)
    end,
    askToDiscard = function(self, who, params, original)
      if params.skill_name ~= SHOUCHENG then
        return original(self, who, params)
      end
      local hand = who:getCardIds(Player.Hand)
      lu.assertEquals(#hand, 2) -- 先摸两张，再弃一张；不是摸一张。
      local id = hand[1]
      table.insert(discards, { player = who, id = id })
      self:throwCard({ id }, SHOUCHENG, who, who)
      return { id }
    end,
  }, function()
    inRoom(function()
      GameEvent.Turn:create(TurnData:new(p(3), "game_rule", { Player.Play })):exec()
    end)
  end)

  lu.assertEquals(invoked, 3)
  lu.assertEquals(#discards, 3)
  lu.assertIs(discards[1].player, first)
  lu.assertIs(discards[2].player, second)
  lu.assertIs(discards[3].player, first)
  for _, record in ipairs(discards) do
    lu.assertEquals(FkTest.room:getCardArea(record.id), Card.DiscardPile)
  end
  lu.assertEquals(invokedBy[holder.id], 2)
  lu.assertEquals(invokedBy[second_holder.id], 1)
  lu.assertEquals(#first:getCardIds(Player.Hand), 1)
  lu.assertEquals(#second:getCardIds(Player.Hand), 1)
  lu.assertEquals(#turn_player:getCardIds(Player.Hand), 0)
  lu.assertEquals(#other_kingdom:getCardIds(Player.Hand), 0)
end

return { name = "hanjin_shu018b_feiyi" }
