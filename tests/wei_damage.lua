-- WEI 标准包：受伤／伤害类 8 技能定向验收文件。
-- 规则依据：docs/rules/standard-generals.md 魏区原文、docs/rules/generals/wei016-yuejin.md、
-- rulebook/events/damage.md、rulebook/topics/skill-effect-classification.md。
-- 由 Codex 统一并入默认国战套件前，可先定向运行：
--   python scripts/test.py --file tests/wei_damage.lua --timeout 120
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")

local JIANXIONG = "qiao__skill_wei001_1"
local LANGGU = "qiao__skill_wei002_1"
local GANGLIE = "qiao__skill_wei003_1"
local LUOYI = "qiao__skill_wei005_1"
local YIJI = "qiao__skill_wei006_2"
local JIEMING = "qiao__skill_wei013_2"
local XINGSHANG = "qiao__skill_wei014_1"
local XIAOGUO = "qiao__skill_wei016_1"

local DEFAULT_KINGDOMS = { "wei", "wei", "wei", "wei", "wei", "wei", "wei", "wei" }

Testqiao_wei_damage = {}

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function p(n) return FkTest.room.players[n] end

local function clearCards(room, player, area)
  local ids = player:getCardIds(area or "he")
  if #ids > 0 then
    inRoom(function()
      room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false)
    end)
  end
end

local function setHand(room, player, specs)
  clearCards(room, player, "he")
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

local function addEquip(room, player, name, suit, number)
  local id
  inRoom(function()
    local card = room:printCard(name, suit or Card.Spade, number or 2)
    room:moveCardTo(card, Card.PlayerEquip, player, fk.ReasonJustMove, "test", nil, false)
    id = card.id
  end)
  return id
end

--- 把指定牌置于牌堆顶；逐张插入使最后一张成为最顶牌。
local function seedDrawPile(room, specs)
  local ids = {}
  inRoom(function()
    for _, spec in ipairs(specs) do
      local card = room:printCard(spec[1], spec[2] or Card.Spade, spec[3] or 1)
      table.removeOne(room.draw_pile, card.id)
      table.insert(room.draw_pile, 1, card.id)
      room.card_place[card.id] = Card.DrawPile
      table.insert(ids, card.id)
    end
  end)
  return ids
end

local function grant(player, skillName)
  inRoom(function()
    player.room:handleAddLoseSkills(player, skillName, nil, false, true)
  end)
end

local function triggerPhase(room, player, phase, event)
  inRoom(function()
    room.logic:trigger(event or fk.EventPhaseStart, player, PhaseData:new {
      who = player,
      reason = "game_rule",
      phase = phase,
    })
  end)
end

local function initializeGenerals(room)
  inRoom(function()
    for i, pl in ipairs(room.players) do
      local kingdom = DEFAULT_KINGDOMS[i] or "wei"
      pl:revealGeneral(false, true)
      pl:revealGeneral(true, true)
      room:changeHero(pl, "qiao_test__" .. kingdom .. "_2", true, true, false, false, false)
      room:changeHero(pl, "qiao_test__" .. kingdom .. "_1", true, false, false, false, false)
      pl.kingdom = kingdom
      room:setPlayerProperty(pl, "kingdom", kingdom)
      room:setPlayerMark(pl, "__heg_general", pl.general)
      room:setPlayerMark(pl, "__heg_deputy", pl.deputyGeneral)
      room:setPlayerMark(pl, "__heg_kingdom", kingdom)
      room:setPlayerMark(pl, "__heg_init_kingdom", kingdom)
      room:setPlayerMark(pl, "__heg_wild", 0)
      -- changeHero 期间 getGeneralMaxHp() 读取 __heg_general/__heg_deputy；
      -- 标记写入测试双将后重算，避免体力上限随本局随机初始双将变化。
      pl.maxHp = pl:getGeneralMaxHp()
      pl.hp = pl.maxHp
    end
  end)
end

local function prepare()
  local room = support.initQiaoRoom()
  initializeGenerals(room)
  return room
end

Testqiao_wei_damage.setup = function() prepare() end
Testqiao_wei_damage.tearDown = support.clearRoom

-- 奸雄：先摸一张，再足额弃一张牌取得伤害牌 -------------------------------
function Testqiao_wei_damage:testJianxiongDrawThenDiscardForDamageCard()
  local room = FkTest.room
  local peach = setHand(room, p(1), { { "qiao__peach" } })[1]
  local slash = setHand(room, p(2), { { "qiao__slash" } })[1]
  grant(p(1), JIANXIONG)

  FkTest.setNextReplies(p(1), {
    "__cancel", -- 不响应【杀】
    "1",
    FkTest.ReplyDiscard({ peach }),
  })
  inRoom(function()
    room:useCard { from = p(2), tos = { p(1) }, card = Fk:getCardById(slash) }
  end)

  lu.assertEquals(room:getCardArea(peach), Card.DiscardPile)
  lu.assertTrue(table.contains(p(1):getCardIds(Player.Hand), slash))
  -- 摸到一张 + 获得的伤害牌，弃掉原手牌后共两张。
  lu.assertEquals(#p(1):getCardIds(Player.Hand), 2)
  lu.assertEquals(p(1):usedSkillTimes(JIANXIONG, Player.HistoryGame), 1)
end

-- 狼顾：获得来源的一张牌 ---------------------------------------------------
function Testqiao_wei_damage:testLanggouObtainsSourceCard()
  local room = FkTest.room
  setHand(room, p(1), {})
  local stolen = setHand(room, p(2), { { "qiao__peach" } })[1]
  grant(p(1), LANGGU)

  FkTest.setNextReplies(p(1), { "1", stolen })
  inRoom(function()
    room:damage { from = p(2), to = p(1), damage = 1 }
  end)

  lu.assertTrue(table.contains(p(1):getCardIds(Player.Hand), stolen))
  lu.assertEquals(room:getCardArea(stolen), Card.PlayerHand)
end

-- 刚烈：红色伤害来源，黑色弃置来源一张牌 --------------------------------
function Testqiao_wei_damage:testGanglieRedAndBlackBranches()
  local room = FkTest.room
  grant(p(1), GANGLIE)
  setHand(room, p(1), {})

  -- 红色判定：对来源造成1点伤害。
  seedDrawPile(room, { { "qiao__peach", Card.Heart, 2 } })
  setHand(room, p(2), { { "qiao__peach" } })
  local hp2 = p(2).hp
  FkTest.setNextReplies(p(1), { "1" })
  inRoom(function()
    room:damage { from = p(2), to = p(1), damage = 1 }
  end)
  lu.assertEquals(p(2).hp, hp2 - 1)

  -- 黑色判定：弃置来源一张牌。
  seedDrawPile(room, { { "qiao__slash", Card.Spade, 5 } })
  local victim = setHand(room, p(2), { { "qiao__jink", Card.Heart, 3 } })[1]
  FkTest.setNextReplies(p(1), { "1", victim })
  inRoom(function()
    room:damage { from = p(2), to = p(1), damage = 1 }
  end)
  lu.assertEquals(room:getCardArea(victim), Card.DiscardPile)
end

-- 裸衣：摸牌阶段结束弃牌，失去技能后本回合加伤仍有效 --------------------
function Testqiao_wei_damage:testLuoyiBonusSurvivesSkillLoss()
  local room = FkTest.room
  local ids = setHand(room, p(1), {
    { "qiao__peach", Card.Heart, 2 },
    { "qiao__slash", Card.Spade, 3 },
  })
  local discard, slash = ids[1], ids[2]
  setHand(room, p(2), {})
  grant(p(1), LUOYI)

  -- 弃牌请求本身就是发动确认，没有单独的 askToSkillInvoke 回复。
  FkTest.setNextReplies(p(1), { FkTest.ReplyDiscard({ discard }) })
  triggerPhase(room, p(1), Player.Draw, fk.EventPhaseEnd)
  lu.assertEquals(p(1):getCardIds(Player.Hand)[1], slash)

  -- 发动后立刻失去技能：本回合的延时加伤不绑定技能。
  inRoom(function()
    room:handleAddLoseSkills(p(1), "-" .. LUOYI, nil, false, true)
  end)
  local hp2 = p(2).hp
  inRoom(function()
    room:useCard { from = p(1), tos = { p(2) }, card = Fk:getCardById(slash) }
  end)
  lu.assertEquals(p(2).hp, hp2 - 2)
end

-- 裸衣：取消唯一弃牌请求即不发动；请求提示写明消耗与加伤 -----------------
function Testqiao_wei_damage:testLuoyiCancelDoesNotActivate()
  local room = FkTest.room
  local ids = setHand(room, p(1), {
    { "qiao__peach", Card.Heart, 2 },
    { "qiao__slash", Card.Spade, 3 },
  })
  local peach, slash = ids[1], ids[2]
  setHand(room, p(2), {})
  grant(p(1), LUOYI)

  FkTest.setNextReplies(p(1), { "" })
  triggerPhase(room, p(1), Player.Draw, fk.EventPhaseEnd)

  lu.assertEquals(p(1):usedSkillTimes(LUOYI, Player.HistoryGame), 0)
  lu.assertEquals(room:getCardArea(peach), Card.PlayerHand)

  -- 未发动则本回合的【杀】仍是原伤害。
  local hp2 = p(2).hp
  inRoom(function()
    room:useCard { from = p(1), tos = { p(2) }, card = Fk:getCardById(slash) }
  end)
  lu.assertEquals(p(2).hp, hp2 - 1)
end

function Testqiao_wei_damage:testLuoyiCostRequestExplainsBonus()
  local room = FkTest.room
  setHand(room, p(1), { { "qiao__peach", Card.Heart, 2 } })
  setHand(room, p(2), {})
  grant(p(1), LUOYI)

  local request
  skill_test.withSkillRequests(room, LUOYI, {
    askToSkillInvoke = function()
      error("裸衣不应再单独询问是否发动")
    end,
    askToDiscard = function(self, who, params, original)
      if who.id ~= p(1).id then return original(self, who, params) end
      request = params
      return {}
    end,
  }, function()
    triggerPhase(room, p(1), Player.Draw, fk.EventPhaseEnd)
  end)

  lu.assertNotNil(request, "裸衣应发起一次弃牌请求")
  lu.assertEquals(request.cancelable, true)
  lu.assertEquals(request.skip, true)
  lu.assertEquals(request.min_num, 1)
  lu.assertEquals(request.max_num, 1)
  lu.assertEquals(request.prompt, "#qiao__skill_wei005_1-discard")
  local text = Fk:translate(request.prompt)
  lu.assertTrue(text:find("弃置一张牌发动", 1, true) ~= nil,
    "请求提示应写明弃牌是发动消耗：" .. text)
  lu.assertTrue(text:find("伤害+1", 1, true) ~= nil,
    "请求提示应写明本回合加伤：" .. text)
  -- 请求返回空（无合法成本）不发动。
  lu.assertEquals(p(1):usedSkillTimes(LUOYI, Player.HistoryGame), 0)
end

-- 遗计：一次伤害事件发动一次，先1~2张给一人，其余给一人 -----------------
function Testqiao_wei_damage:testYijiOneEventTwoGives()
  local room = FkTest.room
  grant(p(1), YIJI)
  local top = seedDrawPile(room, {
    { "qiao__peach", Card.Heart, 4 },
    { "qiao__peach", Card.Heart, 5 },
  })
  local first, second = top[2], top[1] -- 后插入的 top[2] 是最顶牌

  FkTest.setNextReplies(p(1), {
    "1",
    FkTest.ReplyChooseCardAndPlayers({ p(3) }, { first }),
    FkTest.ReplyChoosePlayer({ p(4) }),
  })
  inRoom(function()
    room:damage { from = p(8), to = p(1), damage = 2 }
  end)

  lu.assertTrue(table.contains(p(3):getCardIds(Player.Hand), first))
  lu.assertTrue(table.contains(p(4):getCardIds(Player.Hand), second))
  -- 2点伤害仍只发动一次遗计。
  lu.assertEquals(p(1):usedSkillTimes(YIJI, Player.HistoryGame), 1)
end

-- 节命：同一次2点伤害按点数逐次调度两次 ---------------------------------
function Testqiao_wei_damage:testJiemingTriggersPerDamagePoint()
  local room = FkTest.room
  grant(p(1), JIEMING)
  setHand(room, p(2), {})
  setHand(room, p(3), {})

  -- 目标选择本身即发动确认（取消则不发动），每次伤害点各询问一次。
  FkTest.setNextReplies(p(1), {
    FkTest.ReplyChoosePlayer({ p(2) }),
    FkTest.ReplyChoosePlayer({ p(3) }),
  })
  inRoom(function()
    room:damage { from = p(8), to = p(1), damage = 2 }
  end)

  lu.assertEquals(#p(2):getCardIds(Player.Hand), math.min(p(2).maxHp, 5))
  lu.assertEquals(#p(3):getCardIds(Player.Hand), math.min(p(3).maxHp, 5))
  lu.assertEquals(p(1):usedSkillTimes(JIEMING, Player.HistoryGame), 2)
end

-- 行殇：获得死亡角色所有牌；无牌时改为回复1点体力 -----------------------
function Testqiao_wei_damage:testXingshangTakesCardsOrRecovers()
  local room = FkTest.room
  grant(p(1), XINGSHANG)
  setHand(room, p(1), {})
  local xsIds = setHand(room, p(2), {
    { "qiao__peach", Card.Heart, 6 },
    { "qiao__jink", Card.Diamond, 7 },
  })
  local c1, c2 = xsIds[1], xsIds[2]
  FkTest.setNextReplies(p(1), { "1" })
  inRoom(function()
    room.logic:trigger(fk.Death, p(2), DeathData:new { who = p(2), killer = p(4) })
  end)
  lu.assertTrue(table.contains(p(1):getCardIds(Player.Hand), c1))
  lu.assertTrue(table.contains(p(1):getCardIds(Player.Hand), c2))
  local assertMoveViews = __dofile("../../../tests/support/move_visibility.lua")
  assertMoveViews(c1, Card.PlayerHand, Card.PlayerHand, { p(2), p(1) })

  inRoom(function() room:loseHp(p(1), 1, "test") end)
  local damagedHp = p(1).hp
  setHand(room, p(3), {})
  FkTest.setNextReplies(p(1), { "1" })
  inRoom(function()
    room.logic:trigger(fk.Death, p(3), DeathData:new { who = p(3), killer = p(4) })
  end)
  lu.assertEquals(p(1).hp, damagedHp + 1)

  -- 只有判定区有牌也视为“没有牌”：改为回复体力，判定区牌不移动。
  inRoom(function() room:loseHp(p(1), 1, "test") end)
  local judgeHp = p(1).hp
  local judge
  inRoom(function()
    local card = room:printCard("qiao__indulgence", Card.Spade, 1)
    room:moveCardTo(card, Card.PlayerJudge, p(2), fk.ReasonJustMove, "test", nil, false)
    judge = card.id
  end)
  FkTest.setNextReplies(p(1), { "1" })
  inRoom(function()
    room.logic:trigger(fk.Death, p(2), DeathData:new { who = p(2), killer = p(4) })
  end)
  lu.assertEquals(p(1).hp, judgeHp + 1)
  lu.assertEquals(room:getCardArea(judge), Card.PlayerJudge)
end

-- 骁果：基本牌多于装备牌造成伤害；相等时摸一张 ---------------------------
function Testqiao_wei_damage:testXiaoguoDamageVersusDraw()
  local room = FkTest.room
  grant(p(1), XIAOGUO)
  local ids = setHand(room, p(1), {
    { "qiao__slash", Card.Spade, 8 },
    { "qiao__peach", Card.Heart, 9 },
  })
  local b1, b2 = ids[1], ids[2]
  clearCards(room, p(2), "h")
  local equip = addEquip(room, p(2), "qiao__chixiao_sword", Card.Heart, 9)
  local hp2 = p(2).hp

  -- 弃牌请求本身就是发动确认，没有单独的 askToSkillInvoke 回复。
  FkTest.setNextReplies(p(1), { FkTest.ReplyDiscard({ b1, b2 }) })
  triggerPhase(room, p(2), Player.Start)
  lu.assertEquals(p(2).hp, hp2 - 1)
  lu.assertEquals(room:getCardArea(equip), Card.DiscardPile)

  -- 相等：1张基本牌对1张装备牌，改为摸一张牌。
  clearCards(room, p(3), "h")
  local equipA = addEquip(room, p(3), "qiao__chixiao_sword", Card.Heart, 9)
  addEquip(room, p(3), "qiao__linxiao_yuyu", Card.Spade, 5)
  local basic = setHand(room, p(1), { { "qiao__slash", Card.Spade, 10 } })[1]
  FkTest.setNextReplies(p(1), { FkTest.ReplyDiscard({ basic }) })
  FkTest.setNextReplies(p(3), { FkTest.ReplyDiscard({ equipA }) })
  triggerPhase(room, p(3), Player.Start)
  lu.assertEquals(#p(1):getCardIds(Player.Hand), 1)
  lu.assertEquals(p(1):usedSkillTimes(XIAOGUO, Player.HistoryGame), 2)
end

-- 骁果：取消唯一弃牌请求即不发动，不弃基本牌、不弃装备、不造成伤害 ------
function Testqiao_wei_damage:testXiaoguoCancelDoesNotActivate()
  local room = FkTest.room
  grant(p(1), XIAOGUO)
  local basic = setHand(room, p(1), { { "qiao__slash", Card.Spade, 8 } })[1]
  clearCards(room, p(2), "h")
  local equip = addEquip(room, p(2), "qiao__chixiao_sword", Card.Heart, 9)
  local hp2 = p(2).hp

  FkTest.setNextReplies(p(1), { "" })
  triggerPhase(room, p(2), Player.Start)

  lu.assertEquals(p(1):usedSkillTimes(XIAOGUO, Player.HistoryGame), 0)
  lu.assertEquals(room:getCardArea(basic), Card.PlayerHand)
  lu.assertEquals(room:getCardArea(equip), Card.PlayerEquip)
  lu.assertEquals(p(2).hp, hp2)
end

function Testqiao_wei_damage:testXiaoguoCostRequestNamesTargetAndFollowUp()
  local room = FkTest.room
  grant(p(1), XIAOGUO)
  setHand(room, p(1), {
    { "qiao__slash", Card.Spade, 8 },
    { "qiao__peach", Card.Heart, 9 },
  })
  clearCards(room, p(2), "he")

  local request
  skill_test.withSkillRequests(room, XIAOGUO, {
    askToSkillInvoke = function()
      error("骁果不应再单独询问是否发动")
    end,
    askToDiscard = function(self, who, params, original)
      if who.id ~= p(1).id then return original(self, who, params) end
      request = params
      return {}
    end,
  }, function()
    triggerPhase(room, p(2), Player.Start)
  end)

  lu.assertNotNil(request, "骁果应发起一次弃牌请求")
  lu.assertEquals(request.cancelable, true)
  lu.assertEquals(request.skip, true)
  lu.assertEquals(request.min_num, 1)
  lu.assertEquals(request.max_num, 2)
  -- Ltk.processPrompt 的参数位依次是 #键:来源:目标:参数；%dest 取第 3 段目标。
  lu.assertEquals(request.prompt,
    "#qiao__skill_wei016_1-discard::" .. p(2).id)
  local text = Fk:translate("#qiao__skill_wei016_1-discard")
  lu.assertNil(text:find("%arg", 1, true))
  lu.assertTrue(text:find("%dest", 1, true) ~= nil,
    "提示应使用 %dest 指向目标：" .. text)
  lu.assertTrue(text:find("造成1点伤害", 1, true) ~= nil,
    "提示应写明后续伤害：" .. text)
  lu.assertTrue(text:find("摸一张牌", 1, true) ~= nil,
    "提示应写明另一后续：" .. text)
  -- 请求返回空（无合法成本）不发动。
  lu.assertEquals(p(1):usedSkillTimes(XIAOGUO, Player.HistoryGame), 0)
end

return { name = "qiao_wei_damage" }
