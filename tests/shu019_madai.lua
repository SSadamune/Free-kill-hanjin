-- SHU019 马岱：马术复用、潜袭保留材料颜色与失技后回合限制。
-- 规则依据：rules/generals/shu019-madai.md。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")

local MADAI = "hanjin__shu019"
local MASHU = "hanjin__skill_shu006_1"
local QIANXI = "hanjin__skill_shu019_2"
local BLANK_DEPUTY = "hanjin_test__shu_2"

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
    for _, player in ipairs(room.players) do clearCards(player) end
    skill_test.installDualGenerals(room, room.players[1], {
      main = MADAI,
      deputy = BLANK_DEPUTY,
      kingdom = "shu",
    })
  end)
  return room
end

Testhanjin_shu019_madai = {
  setup = prepare,
  tearDown = function()
    Fk.currentResponsePattern = nil
    support.clearRoom()
  end,
}

function Testhanjin_shu019_madai:testFormalRegistrationSharesMashu()
  local pack = assert(Fk.packages.hanjin_zhenshi)
  local entry = assert(table.find(ZHEN_SHI.generals, function(data)
    return data.id == MADAI
  end), "missing Ma Dai data entry")
  lu.assertEquals(entry.number, "SHU019")
  local general = assert(Fk.generals[MADAI])
  lu.assertIs(general.package, pack)
  lu.assertEquals(general.trueName, "马岱")
  lu.assertEquals(general.kingdom, "shu")
  lu.assertEquals(general.maxHp, 4)
  lu.assertEquals(general.gender, General.Male)
  lu.assertTrue(general:isCompanionWith(Fk.generals["hanjin__shu006"]))
  lu.assertTrue(table.contains(general:getSkillNameList(), MASHU))
  lu.assertTrue(table.contains(general:getSkillNameList(), QIANXI))
  lu.assertTrue(table.contains(Fk.generals["hanjin__shu006"]:getSkillNameList(), MASHU))
  lu.assertNotEquals(general, Fk.generals["ld__madai"])
  inRoom(function()
    lu.assertTrue(Fk:canUseGeneral(MADAI),
      "Ma Dai should be selectable in the formal HanJin mode")
  end)
end

function Testhanjin_shu019_madai:testQianxiMaterialsAndRestrictionSurvivesSkillLoss()
  local room, player, target = FkTest.room, p(1), p(2)
  give(player, "hanjin__jink", Card.Heart, 2)
  local black = give(player, "hanjin__slash", Card.Spade, 3)
  local targetBlack = give(target, "hanjin__peach", Card.Club, 4)
  local targetRed = give(target, "hanjin__jink", Card.Diamond, 5)
  local equip = give(target, "hanjin__qinggang_sword", Card.Spade, 6)
  inRoom(function()
    room:moveCardIntoEquip(target, equip, "test", true, player)
  end)

  local invoked, discarded = 0, nil
  local captured = {}
  local probe = fk.CreateSkill { name = "#hanjin_shu019_qianxi_probe" }
  probe:addEffect(fk.EventPhaseStart, {
    global = true,
    can_refresh = function(self, event, target, who, data)
      return target == player and who == player and data.phase == Player.Play
    end,
    on_refresh = function()
      captured.hasRule = room:hasSkill("hanjin__shu019_qianxi_rule")
      captured.mark = target:getTableMark("hanjin_shu019_qianxi_restrictions")
      local blackCard = Fk:getCardById(targetBlack)
      local redCard = Fk:getCardById(targetRed)
      local equipCard = Fk:getCardById(equip)
      captured.black = target:prohibitUse(blackCard)
      captured.red = target:prohibitUse(redCard)
      captured.blackResponse = target:prohibitResponse(blackCard)
      captured.equip = target:prohibitUse(equipCard)

      -- 纯虚拟黑牌没有手牌材料：不能只因转化后颜色被禁止。
      captured.virtualNoMaterial = target:prohibitUse(
        Fk:cloneCard("hanjin__slash", Card.Spade, 7))
      -- 转化后显示红色，但实体材料是黑色手牌：仍须按材料禁止。
      local materialVirtual = Fk:cloneCard("hanjin__jink")
      materialVirtual:addSubcards({ targetBlack })
      materialVirtual.suit = Card.Heart
      materialVirtual.color = Card.Red
      captured.virtualMaterial = target:prohibitUse(materialVirtual)

      room:handleAddLoseSkills(player, "-" .. QIANXI, nil, false, true)
      captured.afterLoss = target:prohibitUse(blackCard)
    end,
  })
  inRoom(function() room:addSkill(probe:createSkill()) end)

  skill_test.withSkillRequests(room, QIANXI, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == QIANXI then
        invoked = invoked + 1
        return true
      end
      return original(self, who, params)
    end,
    askToDiscard = function(self, who, params, original)
      if params.skill_name ~= QIANXI then
        return original(self, who, params)
      end
      local hand = who:getCardIds(Player.Hand)
      lu.assertEquals(#hand, 3) -- 原有2张，先摸1再弃1。
      lu.assertTrue(table.contains(hand, black))
      discarded = black
      -- 技能以 skip=true 选牌后自行弃置；这里只返回选择结果。
      return { black }
    end,
    askToChoosePlayers = function(self, who, params, original)
      if params.skill_name ~= QIANXI then
        return original(self, who, params)
      end
      captured.chooseCalled = true
      captured.targets = params.targets
      lu.assertTrue(table.contains(params.targets, target))
      lu.assertNil(table.find(params.targets, function(candidate)
        return candidate == player
      end))
      return { target }
    end,
  }, function()
    inRoom(function()
      GameEvent.Turn:create(TurnData:new(player, "game_rule", {
        Player.Start, Player.Play,
      })):exec()
    end)
  end)

  lu.assertEquals(invoked, 1)
  lu.assertEquals(FkTest.room:getCardArea(discarded), Card.DiscardPile)
  lu.assertEquals(#player:getCardIds(Player.Hand), 2)
  lu.assertTrue(captured.chooseCalled, "Qianxi target selection was not reached")
  lu.assertTrue(captured.hasRule, "Qianxi rule skill is missing")
  lu.assertEquals(#captured.mark, 1)
  lu.assertTrue(captured.black)
  lu.assertFalse(captured.red)
  lu.assertTrue(captured.blackResponse)
  lu.assertFalse(captured.equip)
  lu.assertFalse(captured.virtualNoMaterial)
  lu.assertTrue(captured.virtualMaterial)
  lu.assertTrue(captured.afterLoss)

  inRoom(function()
    captured.afterTurn = target:prohibitUse(Fk:getCardById(targetBlack))
  end)
  lu.assertFalse(captured.afterTurn)
end

-- 潜袭反馈回归：不以初始距离1目标为发动门槛；弃牌时先保存持有者过滤后的
-- 颜色（红颜黑桃骑乘牌为红色），再做实际弃牌和距离选择。
-- 潜袭反馈回归一：先摸1弃1，不能因发动时没有距离1目标而拒绝发动。
function Testhanjin_shu019_madai:testQianxiStillDrawsAndDiscardsWithoutInitialTarget()
  local room, player = FkTest.room, p(1)
  inRoom(function()
    skill_test.installDualGenerals(room, player, {
      main = "hanjin_test__shu_1",
      deputy = "hanjin_test__shu_2",
      kingdom = "shu",
    })
    clearCards(player)
    room:handleAddLoseSkills(player, QIANXI, nil, false, true)
  end)

  local card = give(player, "hanjin__jink", Card.Heart, 2)
  for index = 2, 8 do
    local horse = give(p(index), "hanjin__jueying", Card.Spade, index + 4)
    inRoom(function()
      room:moveCardIntoEquip(p(index), horse, "test", true, p(index))
    end)
  end
  -- 无马术；所有其他角色装备防御坐骑后，初始没有距离1目标。
  lu.assertEquals(inRoom(function() return player:distanceTo(p(2)) end), 2)

  local invoked, chosen, discarded = 0, false, nil
  skill_test.withSkillRequests(room, QIANXI, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == QIANXI then
        invoked = invoked + 1
        return true
      end
      return original(self, who, params)
    end,
    askToDiscard = function(self, who, params, original)
      if params.skill_name ~= QIANXI then
        return original(self, who, params)
      end
      lu.assertTrue(params.skip)
      discarded = card
      return { card }
    end,
    askToChoosePlayers = function(self, who, params, original)
      if params.skill_name == QIANXI then chosen = true end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      GameEvent.Turn:create(TurnData:new(player, "game_rule", {
        Player.Start, Player.Play,
      })):exec()
    end)
  end)

  lu.assertEquals(invoked, 1)
  lu.assertEquals(discarded, card)
  lu.assertFalse(chosen)
  lu.assertEquals(FkTest.room:getCardArea(card), Card.DiscardPile)
  lu.assertEquals(#player:getCardIds(Player.Hand), 1) -- 摸1再弃1。
end

-- 潜袭反馈回归二：弃牌时先保存持有者过滤后的颜色。红颜使黑桃牌为红色，
-- 离区后再取牌会恢复黑色，不能据此建立限制。
function Testhanjin_shu019_madai:testQianxiSavesFilteredColorBeforeDiscard()
  local room, player, target = FkTest.room, p(1), p(2)
  inRoom(function()
    skill_test.installDualGenerals(room, player, {
      main = "hanjin_test__shu_1",
      deputy = "hanjin_test__shu_2",
      kingdom = "shu",
    })
    clearCards(player)
    room:handleAddLoseSkills(player, QIANXI, nil, false, true)
    room:handleAddLoseSkills(player, "hanjin__skill_wu011_2", nil, false, true)
  end)

  local spade = give(player, "hanjin__jink", Card.Spade, 5)
  local red = give(target, "hanjin__jink", Card.Heart, 2)
  local black = give(target, "hanjin__slash", Card.Club, 3)

  local invoked = 0
  local captured = {}
  local probe = fk.CreateSkill { name = "#hanjin_shu019_qianxi_color_probe" }
  probe:addEffect(fk.EventPhaseStart, {
    global = true,
    can_refresh = function(self, event, who, data)
      return who == player and data.phase == Player.Play
    end,
    on_refresh = function()
      captured.red = target:prohibitUse(Fk:getCardById(red))
      captured.black = target:prohibitUse(Fk:getCardById(black))
    end,
  })
  inRoom(function() room:addSkill(probe:createSkill()) end)

  skill_test.withSkillRequests(room, QIANXI, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == QIANXI then
        invoked = invoked + 1
        return true
      end
      return original(self, who, params)
    end,
    askToDiscard = function(self, who, params, original)
      if params.skill_name ~= QIANXI then
        return original(self, who, params)
      end
      return { spade }
    end,
    askToChoosePlayers = function(self, who, params, original)
      if params.skill_name ~= QIANXI then
        return original(self, who, params)
      end
      lu.assertTrue(table.contains(params.targets, target))
      return { target }
    end,
  }, function()
    inRoom(function()
      GameEvent.Turn:create(TurnData:new(player, "game_rule", {
        Player.Start, Player.Play,
      })):exec()
    end)
  end)

  lu.assertEquals(invoked, 1)
  lu.assertEquals(FkTest.room:getCardArea(spade), Card.DiscardPile)
  lu.assertTrue(captured.red)
  lu.assertFalse(captured.black)
end

return { name = "hanjin_shu019_madai" }
