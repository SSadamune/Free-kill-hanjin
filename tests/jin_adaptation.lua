-- JIN004/JIN013/JIN015 晋应变批次定向用例。
-- 规则依据：docs/rules/generals/jin004-jiachong.md、jin013-wangjun.md、
-- jin015-shibao.md 及 docs/rules/adaptation.md。测试只使用正式晋武将、真实请求与
-- 正式汉晋牌；不另建测试专用技能内容。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")

local TONGFA = "qiao__skill_jin004_1"
local CHENGLIU = "qiao__skill_jin013_1"
local QIANQU = "qiao__skill_jin015_1"

local function adaptation()
  return require "packages.qiao.pkg.qiao_mode.rules.adaptation"
end

Testqiao_jin_adaptation = {}
Testqiao_jin_adaptation.tearDown = support.clearRoom

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function clearCards(room, player, area)
  local ids = player:getCardIds(area or "he")
  if #ids > 0 then
    inRoom(function()
      room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false)
    end)
  end
end

local function resetCards(room)
  for _, p in ipairs(room.players) do clearCards(room, p) end
end

local function give(room, player, specs)
  local ids = {}
  inRoom(function()
    for _, spec in ipairs(specs) do
      local card = room:printCard(spec[1], spec[2] or Card.Spade, spec[3] or 1)
      room:obtainCard(player, card, false, fk.ReasonJustMove)
      table.insert(ids, card.id)
    end
  end)
  return ids
end

local function setHand(room, player, specs)
  clearCards(room, player)
  return give(room, player, specs)
end

local function addEquip(room, player, name)
  local id
  inRoom(function()
    local card = room:printCard(name, Card.Spade, 1)
    room:moveCardTo(card, Card.PlayerEquip, player, fk.ReasonJustMove, "test", nil, false)
    id = card.id
  end)
  return id
end

local function install(room, general)
  inRoom(function()
    skill_test.installDualGenerals(room, room.players[1], {
      main = general,
      deputy = "qiao_test__jin_2",
      kingdom = "jin",
    })
  end)
end

local function prepare(general)
  local room = support.initQiaoRoom()
  inRoom(function() skill_test.installBlankGenerals(room, { "jin", "jin", "wei" }) end)
  install(room, general)
  resetCards(room)
  return room
end

local function p1() return FkTest.room.players[1] end
local function p2() return FkTest.room.players[2] end
local function p3() return FkTest.room.players[3] end

--- 在真实 TurnStart 中执行 fn，令 room.current 为 player。
local function runTurnStart(room, player, fn)
  local fired = false
  local skel = fk.CreateSkill { name = "#qiao_jin_adaptation_turn_probe" }
  skel:addEffect(fk.TurnStart, {
    global = true,
    can_refresh = function(self, event, target, probe_player)
      return not fired and target == player and probe_player == player
    end,
    on_refresh = function()
      fired = true
      room:setCurrent(player)
      fn()
    end,
  })
  inRoom(function() room:addSkill(skel:createSkill()) end)
  inRoom(function()
    GameEvent.Turn:create(TurnData:new(player, "game_rule", { Player.Play })):exec()
  end)
end

-- 通法的令牌在 AfterCardUseDeclared 才登记，晚于公共应变 prepare。
function Testqiao_jin_adaptation:testLateIgnoreTokenAfterPrepareIsReadByResolve()
  local room = prepare("qiao_heg__jin004")
  local user = p2()
  local data = UseCardData:new {
    from = user,
    tos = { p3() },
    card = Fk:cloneCard("qiao_test__blank_basic"),
    extra_data = {},
  }
  adaptation().setCardEntries(data.card, {
    { id = "late_token", condition = "canqu", effect = "draw" },
  })
  inRoom(function() user.hp = 2 end)
  local before = #user:getCardIds("h")
  inRoom(function()
    adaptation().prepare(room, data)
    -- 模拟通法在 prepare 之后、resolve 之前登记。
    adaptation().grantIgnore(data, TONGFA, "late_token")
    adaptation().resolve(room, data)
  end)
  lu.assertEquals(#user:getCardIds("h"), before + 1)
  lu.assertEquals(adaptation().getResult(data).entries[1].ignored_by, TONGFA)
end

-- 通法：同势力使用者交给贾充一张牌，令牌只令本次一个未满足条目成立。
function Testqiao_jin_adaptation:testTongfaPaysThenOneEntryTriggers()
  local room = prepare("qiao_heg__jin004")
  local jiaChong, user, target = p1(), p2(), p3()
  local gift = give(room, user, { { "qiao__peach" } })[1]
  inRoom(function() user.hp = 2 end)
  local usedCard = Fk:cloneCard("qiao__slash")
  adaptation().setCardEntries(usedCard, {
    { id = "tongfa_canqu", condition = "canqu", effect = "draw" },
  })

  skill_test.withSkillRequests(room, TONGFA, {
    askToSkillInvoke = function() return true end,
    askToChooseCard = function() return gift end,
  }, function()
    runTurnStart(room, user, function()
      room:useCard { from = user, tos = { target }, card = usedCard }
    end)
  end)

  -- 初始 1 张：用虚拟杀不耗手牌，交出后 0，令牌令残躯摸 1。
  lu.assertEquals(#user:getCardIds("h"), 1)
  lu.assertTrue(table.contains(jiaChong:getCardIds("h"), gift))
  lu.assertEquals(jiaChong:usedSkillTimes(TONGFA, Player.HistoryGame), 1)
end

-- 乘流：伤害牌在本次使用中附富甲条目并改为雷电伤害，结算后可横置实际受伤者。
function Testqiao_jin_adaptation:testChengliuThunderAndChainActualVictim()
  local room = prepare("qiao_heg__jin013")
  local wangJun, target = p1(), p2()
  local slash = setHand(room, wangJun, { { "qiao__slash" } })[1]
  local damageType
  local skel = fk.CreateSkill { name = "#qiao_jin013_damage_probe" }
  skel:addEffect(fk.DamageCaused, {
    global = true,
    can_refresh = function(self, event, target_player, player)
      return target_player == player and damageType == nil
    end,
    on_refresh = function(self, event, target_player, player, data)
      damageType = data.damageType
    end,
  })
  inRoom(function() room:addSkill(skel:createSkill()) end)

  FkTest.setNextReplies(wangJun, { "1" })
  runTurnStart(room, wangJun, function()
    room:useCard { from = wangJun, tos = { target }, card = Fk:getCardById(slash) }
  end)

  lu.assertEquals(damageType, fk.ThunderDamage)
  lu.assertTrue(target.chained)
end

-- 乘流：富甲不成立时仍能横置实际受伤者；雷伤不因后续可选技能未触发而误加。
function Testqiao_jin_adaptation:testChengliuChainWithoutFujia()
  local room = prepare("qiao_heg__jin013")
  local wangJun, target = p1(), p2()
  local slash = setHand(room, wangJun, { { "qiao__slash" } })[1]
  give(room, target, { { "qiao__peach" }, { "qiao__peach" } })
  local damageType
  local skel = fk.CreateSkill { name = "#qiao_jin013_no_fujia_probe" }
  skel:addEffect(fk.DamageCaused, {
    global = true,
    can_refresh = function(self, event, target_player, player)
      return target_player == player and damageType == nil
    end,
    on_refresh = function(self, event, target_player, player, data)
      damageType = data.damageType
    end,
  })
  inRoom(function() room:addSkill(skel:createSkill()) end)

  FkTest.setNextReplies(wangJun, { "1" })
  runTurnStart(room, wangJun, function()
    room:useCard { from = wangJun, tos = { target }, card = Fk:getCardById(slash) }
  end)

  lu.assertEquals(damageType, fk.NormalDamage)
  lu.assertTrue(target.chained)
end

-- 前驱：真实使用无距离杀，助战弃目标装备；造成伤害后当前回合角色获得此杀并摸牌。
function Testqiao_jin_adaptation:testQianquUsesRealSlashAndRewardsCurrentTurn()
  local room = prepare("qiao_heg__jin015")
  local shiBao, turnPlayer, target = p1(), p2(), p3()
  local slash = setHand(room, shiBao, { { "qiao__slash" } })[1]
  local helper = give(room, turnPlayer, { { "qiao__jink" } })[1]
  local equip = addEquip(room, target, "jueying")
  local hp = target.hp

  FkTest.setNextReplies(shiBao, {
    "1",
    FkTest.ReplyCard(Fk:getCardById(slash), { target }),
  })
  FkTest.setNextReplies(turnPlayer, { FkTest.ReplyDiscard({ helper }) })
  skill_test.withSkillRequests(room, "#qiao_adaptation_rule", {
    askToChooseCard = function() return equip end,
  }, function()
    inRoom(function()
      room:setCurrent(turnPlayer)
      turnPlayer.phase = Player.Start
      room.logic:trigger(fk.EventPhaseStart, turnPlayer, { phase = Player.Start })
    end)
  end)

  lu.assertEquals(target.hp, hp - 1)
  lu.assertEquals(room:getCardArea(equip), Card.DiscardPile)
  lu.assertTrue(table.contains(turnPlayer:getCardIds("h"), slash))
  lu.assertEquals(#turnPlayer:getCardIds("h"), 2)
end

return { name = "qiao_jin_adaptation" }
