-- 群势力标准包：济世、完杀的濒死入口用例。
--
-- 本轮未接入 tests/all.lua，也尚未执行共享运行时；文件由后续唯一测试执行者
-- 接入默认国战套件后运行。模式级 qun_dying_rule 尚待 Codex 接入 mode.init，
-- 因此本套件在 setup 中显式 room:addSkill 该规则，验证规则本身而非接线。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_support = __dofile("../../../tests/support/skill_test.lua")

local HUATUO = "qiao_heg__qun001"
local JIAXU = "qiao_heg__qun007"
local JISHI = "qiao__skill_qun001_1"
local WANSHA = "qiao__skill_qun007_1"
local RULE = "qiao__qun_dying_rule"

Testqiao_qun_dying = {}
Testqiao_qun_dying.tearDown = support.clearRoom

Testqiao_qun_dying.setup = function()
  local room = support.initQiaoRoom()
  FkTest.runInRoom(function()
    skill_support.installBlankGenerals(room, "qun")
    for _, player in ipairs(room.players) do
      room:setPlayerProperty(player, "hp", player.maxHp)
    end
    -- 模式 init 的接线由 Codex 完成；这里直接安装规则以验证规则本体。
    room:addSkill(RULE)
    lu.assertTrue(room:hasSkill(RULE), "qun_dying_rule 未安装，交换/清理不会运行")
  end)
end

local function p(index) return FkTest.room.players[index] end

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

-- 以下辅助均须在 FkTest.runInRoom 内调用，不再内嵌 runInRoom。
local function clearCards(room, player)
  local ids = player:getCardIds("he")
  if #ids > 0 then
    room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false)
  end
end

local function clearAll(room)
  for _, player in ipairs(room.players) do clearCards(room, player) end
end

--- 发一张实体牌到手牌。
local function give(room, player, name, suit, number)
  local card = room:printCard(name, suit or Card.Heart, number or 1)
  room:obtainCard(player, card, false, fk.ReasonJustMove)
  return card.id
end

local function placeEquip(room, player, name, suit, number)
  local card = room:printCard(name, suit or Card.Heart, number or 1)
  room:moveCardTo(card, Card.PlayerEquip, player, fk.ReasonJustMove, "test", nil, false)
  return card.id
end

local function enterDying(room, who)
  inRoom(function()
    room:enterDying { who = who }
  end)
end

-- 济世：红色装备牌当【桃】救起濒死，濒死结束后首次跨势力交换华佗 --------

function Testqiao_qun_dying:testJishiDescriptionFollowsRoomSetting()
  local room = FkTest.room
  local rescue = "你可以将红色牌当【桃】对濒死角色使用"
  local exchange = "，此濒死结算后，若此武将为客将，与你势力不同的角色依次选择是否用一个武将交换此武将"
  inRoom(function()
    for _, enabled in ipairs({ true, false }) do
      room.settings.qiao_guest_replacement = enabled
      local expected = rescue .. (enabled and exchange or "") .. "。"
      lu.assertEquals(Fk:getDescription(JISHI, "zh_CN"), expected)
      lu.assertEquals(Fk:getDescription(JISHI, "zh_CN", p(1)), expected)
    end
  end)
end

function Testqiao_qun_dying:testJishiSavesWithRedEquipmentThenExchangesHuatuoOnce()
  local room = FkTest.room
  local owner, exchanged, later = p(1), p(2), p(3)
  local exchangedMain
  local redEquip

  inRoom(function()
    clearAll(room)
    skill_support.installDualGenerals(room, owner, {
      main = HUATUO, deputy = "qiao_test__qun_2", kingdom = "qun",
    })
    skill_support.installDualGenerals(room, exchanged, {
      main = "qiao_test__wei_1", deputy = "qiao_test__wei_2", kingdom = "wei",
    })
    -- 第三名不同势力角色用于验证“首次成功交换即止”，不为他提供华佗。
    skill_support.installDualGenerals(room, later, {
      main = "qiao_test__shu_1", deputy = "qiao_test__shu_2", kingdom = "shu",
    })
    for _, player in ipairs(room.players) do
      if player ~= owner and player ~= exchanged and player ~= later then
        skill_support.installDualGenerals(room, player, {
          main = "qiao_test__qun_1", deputy = "qiao_test__qun_2", kingdom = "qun",
        })
      end
    end
    exchangedMain = exchanged.general
    -- 从救人的华佗开始行动顺序：其后的交换者先于第三名不同势力角色。
    room:setCurrent(owner)
    room:setPlayerProperty(exchanged, "hp", 0)
    redEquip = placeEquip(room, owner, "qiao__chitu", Card.Heart, 5)
  end)

  -- 济世：红色装备牌作为唯一的【桃】来源；救援后立即进入客将交换询问。
  FkTest.setNextReplies(owner, {
    { card = { skill = JISHI, subcards = { redEquip } }, targets = { exchanged.id } },
  })
  -- AskForChoices 的回复体是选项表；裸字符串会被 askToChoices 当作非法回复取消。
  FkTest.setNextReplies(exchanged, { { "#qiao__skill_qun001_1-main" } })
  -- 若错误地在首次成功后继续询问，这张牌会被换给原持有者。
  FkTest.setNextReplies(later, { { "#qiao__skill_qun001_1-main" } })
  enterDying(room, exchanged)

  lu.assertEquals(exchanged.hp, 1)
  lu.assertEquals(owner.general, exchangedMain)
  lu.assertEquals(exchanged.general, HUATUO)
  lu.assertEquals(owner:getMark("__heg_general"), exchangedMain)
  lu.assertTrue(exchanged:hasSkill(JISHI))
  lu.assertFalse(owner:hasSkill(JISHI))
  lu.assertEquals(room:getCardArea(redEquip), Card.DiscardPile)
end

-- 济世：原文只写“此濒死结算后”，未救活也处理仍有效的来源交换 ---------------

function Testqiao_qun_dying:testJishiStillExchangesWhenDyingPlayerDies()
  local room = FkTest.room
  local owner, victim, candidate = p(1), p(2), p(3)
  local redEquip, candidateMain

  inRoom(function()
    clearAll(room)
    skill_support.installDualGenerals(room, owner, {
      main = HUATUO, deputy = "qiao_test__qun_2", kingdom = "qun",
    })
    skill_support.installDualGenerals(room, victim, {
      main = "qiao_test__wei_1", deputy = "qiao_test__wei_2", kingdom = "wei",
    })
    skill_support.installDualGenerals(room, candidate, {
      main = "qiao_test__shu_1", deputy = "qiao_test__shu_2", kingdom = "shu",
    })
    for _, player in ipairs(room.players) do
      if player ~= owner and player ~= victim and player ~= candidate then
        skill_support.installDualGenerals(room, player, {
          main = "qiao_test__qun_1", deputy = "qiao_test__qun_2", kingdom = "qun",
        })
      end
    end
    candidateMain = candidate.general
    room:setCurrent(owner)
    -- 一张济世【桃】只回复1点：-1 → 0，仍濒死，随后死亡，交换照常处理。
    room:setPlayerProperty(victim, "hp", -1)
    redEquip = placeEquip(room, owner, "qiao__chitu", Card.Heart, 6)
  end)

  FkTest.setNextReplies(owner, {
    { card = { skill = JISHI, subcards = { redEquip } }, targets = { victim.id } },
  })
  -- 其余存活角色均放弃求桃；第三名角色在濒死结束后同意交换。
  for index = 2, #room.players do
    local player = p(index)
    if player == candidate then
      FkTest.setNextReplies(player, { "", { "#qiao__skill_qun001_1-main" } })
    else
      FkTest.setNextReplies(player, { "", "" })
    end
  end
  enterDying(room, victim)

  lu.assertTrue(victim.dead)
  lu.assertEquals(owner.general, candidateMain)
  lu.assertEquals(candidate.general, HUATUO)
  lu.assertTrue(candidate:hasSkill(JISHI))
  lu.assertFalse(owner:hasSkill(JISHI))
end

-- 完杀：贾诩回合内其他角色濒死，其他人（含贾诩）不能对其用桃 ----------------

function Testqiao_qun_dying:testWanshaBlocksEveryoneButDyingPlayer()
  local room = FkTest.room
  local other, jiaxu, victim = p(1), p(2), p(3)
  local otherPeach, jiaxuPeach

  inRoom(function()
    clearAll(room)
    skill_support.installDualGenerals(room, jiaxu, {
      main = JIAXU, deputy = "qiao_test__qun_2", kingdom = "qun",
    })
    room:setCurrent(jiaxu)
    room:setPlayerProperty(victim, "hp", 0)
    otherPeach = give(room, other, "qiao__peach", Card.Heart, 4)
    jiaxuPeach = give(room, jiaxu, "qiao__peach", Card.Heart, 5)
  end)

  -- 濒死角色本人没有桃；其他存活角色均被禁止使用桃，因此不会产生求桃请求。
  FkTest.setNextReplies(victim, { "" })
  enterDying(room, victim)

  lu.assertTrue(victim.dead)
  lu.assertTrue(table.contains(other:getCardIds("h"), otherPeach))
  lu.assertTrue(table.contains(jiaxu:getCardIds("h"), jiaxuPeach))
  -- 本次濒死结束后限制清理，不延续到下一次。
  inRoom(function()
    lu.assertFalse(other:isProhibited(victim, Fk:cloneCard("qiao__peach")))
  end)
end

-- 完杀：濒死角色本人使用自己的【桃】自救不受限制 ----------------------------

function Testqiao_qun_dying:testWanshaAllowsDyingPlayerOwnPeach()
  local room = FkTest.room
  local jiaxu, victim = p(2), p(3)
  local victimPeach

  inRoom(function()
    clearAll(room)
    skill_support.installDualGenerals(room, jiaxu, {
      main = JIAXU, deputy = "qiao_test__qun_2", kingdom = "qun",
    })
    room:setCurrent(jiaxu)
    room:setPlayerProperty(victim, "hp", 0)
    victimPeach = give(room, victim, "qiao__peach", Card.Heart, 6)
  end)

  FkTest.setNextReplies(victim, {
    { card = victimPeach, targets = { victim.id } },
  })
  enterDying(room, victim)

  lu.assertFalse(victim.dead)
  lu.assertEquals(victim.hp, 1)
  lu.assertFalse(table.contains(victim:getCardIds("h"), victimPeach))
end

-- 完杀：不在贾诩回合时不产生用桃限制 ---------------------------------------

function Testqiao_qun_dying:testWanshaInactiveOutsideJiaxuTurn()
  local room = FkTest.room
  local other, jiaxu, victim = p(1), p(2), p(3)
  local otherPeach

  inRoom(function()
    clearAll(room)
    skill_support.installDualGenerals(room, jiaxu, {
      main = JIAXU, deputy = "qiao_test__qun_2", kingdom = "qun",
    })
    room:setCurrent(other)
    room:setPlayerProperty(victim, "hp", 0)
    otherPeach = give(room, other, "qiao__peach", Card.Heart, 7)
  end)

  FkTest.setNextReplies(other, {
    { card = otherPeach, targets = { victim.id } },
  })
  enterDying(room, victim)

  lu.assertFalse(victim.dead)
  lu.assertEquals(victim.hp, 1)
  lu.assertFalse(table.contains(other:getCardIds("h"), otherPeach))
end

return { name = "qiao_qun_dying" }
