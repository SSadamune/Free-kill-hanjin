-- 群势力标准包 D 批次：帷幕、悲歌、倾城、黄巾雷使的核心行为。
-- 本文件尚未加入 tests/all.lua；负责人确认测试执行者后以
-- `python scripts/test.py --file tests/qun_judgement.lua` 定向运行。
-- 夹具：真实汉晋国战房间 + 明确白板双将；输入走官方回复队列或限定技能桩。
local support = __dofile("../../../tests/support/hegemony.lua")

local WEIMU = "hanjin__skill_qun007_3"
local BEIGE = "hanjin__skill_qun012_1"
local QINGCHENG = "hanjin__skill_qun018_2"
local HUANGJIN = "hanjin__retinue_skill_huangjin_leishi"
local HISTORY = "hanjin__qun_damage_history"
local SLASH = "hanjin__slash"
local KINGDOMS = { "qun", "qun", "qun", "qun", "qun", "qun", "qun", "qun" }

local function room() return FkTest.room end
local function p(n) return room().players[n] end

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function grant(player, name)
  inRoom(function() player.room:handleAddLoseSkills(player, name, nil, false, true) end)
end

local function clearHand(player)
  inRoom(function()
    local ids = player:getCardIds("he")
    if #ids > 0 then
      room():moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false)
    end
  end)
end

local function give(player, name, suit, number)
  local id
  inRoom(function()
    local card = room():printCard(name, suit or Card.Spade, number or 7)
    room():obtainCard(player, card, false, fk.ReasonJustMove)
    id = card.id
  end)
  return id
end

--- 把一张牌放在牌堆顶，作为下一次判定的判定牌。
local function seedJudgeCard(name, suit, number)
  local id
  inRoom(function()
    local card = room():printCard(name, suit or Card.Heart, number or 9)
    table.removeOne(room().draw_pile, card.id)
    table.insert(room().draw_pile, 1, card.id)
    room().card_place[card.id] = Card.DrawPile
    id = card.id
  end)
  return id
end

local function setPlayPhase(player)
  inRoom(function()
    room().current = player
    player.phase = Player.Play
    room():setBanner("RoundCount", 1)
  end)
end

local function firstHandId(player)
  return inRoom(function() return player:getCardIds("h")[1] end)
end

--- p1 使用一张真实手牌【杀】指定 p2；结算内不额外应答的请求由调用方排队。
local function useSlash(from, to)
  inRoom(function()
    local slash = room():printCard(SLASH, Card.Spade, 7)
    room():obtainCard(from, slash, false, fk.ReasonJustMove)
    room():useCard(UseCardData:new {
      from = from,
      tos = { to },
      card = slash,
      extra_data = {},
    })
  end)
end

Testhanjin_qun_judgement = { tearDown = support.clearRoom }

Testhanjin_qun_judgement.setup = function()
  local r = support.initHanjinRoom()
  inRoom(function()
    local skill_test = __dofile("../../../tests/support/skill_test.lua")
    skill_test.installBlankGenerals(r, KINGDOMS)
    -- mode.lua 接线后由模式在 logic:start 常驻安装；测试在此补齐同一事实记录器。
    if not r:hasSkill(HISTORY) then r:addSkill(HISTORY) end
  end)
end

-- 帷幕：成为黑色锦囊目标时取消该目标，未取消的红色延时锦囊仍按普通牌移动。
function Testhanjin_qun_judgement:testWeimuCancelsOnlyBlackTrickTarget()
  local p1, p2 = p(1), p(2)
  grant(p2, WEIMU)
  local black = inRoom(function()
    return room():printCard("hanjin__indulgence", Card.Spade, 6)
  end)
  inRoom(function()
    room():useCard(UseCardData:new {
      from = p1, tos = { p2 }, card = black, extra_data = {},
    })
  end)
  lu.assertEquals(inRoom(function() return room():getCardArea(black.id) end), Card.DiscardPile)

  local red = inRoom(function()
    return room():printCard("hanjin__indulgence", Card.Heart, 6)
  end)
  inRoom(function()
    room():useCard(UseCardData:new {
      from = p1, tos = { p2 }, card = red, extra_data = {},
    })
  end)
  lu.assertEquals(inRoom(function() return room():getCardArea(red.id) end), Card.PlayerJudge)
  lu.assertTrue(inRoom(function() return table.contains(p2:getCardIds(Player.Judge), red.id) end))
end

-- 悲歌 · 红桃：弃一张牌后由受伤者判定，判定为红桃则其回复1点体力。
function Testhanjin_qun_judgement:testBeigeHeartRecoversDamagedPlayer()
  local p1, p2, p3 = p(1), p(2), p(3)
  grant(p3, BEIGE)
  clearHand(p2)
  clearHand(p3)
  local paid = give(p3, SLASH, Card.Club, 2)
  seedJudgeCard("hanjin__jink", Card.Heart, 9)
  inRoom(function() p2.hp = 3 end)
  FkTest.setNextReplies(p3, { "1", FkTest.ReplyDiscard({ paid }) })
  FkTest.setNextReplies(p2, { "" })

  useSlash(p1, p2)
  -- 杀造成1点伤害（3→2），红桃判定回复1点（2→3）。
  lu.assertEquals(inRoom(function() return p2.hp end), 3)
  lu.assertFalse(inRoom(function() return table.contains(p3:getCardIds("he"), paid) end))
end

-- 悲歌 · 黑桃：来源叠置是定向操作，已叠置不能再翻回平置。
function Testhanjin_qun_judgement:testBeigeSpadeStacksSourceWithoutFlippingBack()
  local p1, p2, p3 = p(1), p(2), p(3)
  grant(p3, BEIGE)
  clearHand(p2)
  clearHand(p3)
  give(p3, SLASH, Card.Club, 2)
  give(p3, SLASH, Card.Club, 3)
  seedJudgeCard("hanjin__jink", Card.Spade, 9)
  inRoom(function() p2.hp = 3 end)
  FkTest.setNextReplies(p3, { "1", FkTest.ReplyDiscard({ firstHandId(p3) }) })
  FkTest.setNextReplies(p2, { "" })
  useSlash(p1, p2)
  lu.assertFalse(inRoom(function() return p1.faceup end))

  -- 第二次黑桃判定：已经叠置，不再翻回。
  inRoom(function() p2.hp = 3 end)
  seedJudgeCard("hanjin__jink", Card.Spade, 8)
  FkTest.setNextReplies(p3, { "1", FkTest.ReplyDiscard({ firstHandId(p3) }) })
  FkTest.setNextReplies(p2, { "" })
  useSlash(p1, p2)
  lu.assertFalse(inRoom(function() return p1.faceup end))
end

-- 倾城：本阶段一次，交换双方全部手牌。
function Testhanjin_qun_judgement:testQingchengSwapsAllHandcardsOncePerPhase()
  local p1, p2 = p(1), p(2)
  grant(p1, QINGCHENG)
  clearHand(p1)
  clearHand(p2)
  local a = give(p1, SLASH, Card.Spade, 2)
  local b = give(p1, SLASH, Card.Spade, 3)
  local c = give(p2, SLASH, Card.Club, 4)
  setPlayPhase(p1)
  inRoom(function()
    room():handleUseCardReply(p1, FkTest.ReplyUseSkill(QINGCHENG, { p2 }, {}))
  end)
  inRoom(function()
    local mine = p1:getCardIds("h")
    local theirs = p2:getCardIds("h")
    lu.assertEquals(#mine, 1)
    lu.assertEquals(mine[1], c)
    lu.assertEquals(#theirs, 2)
    lu.assertTrue(table.contains(theirs, a))
    lu.assertTrue(table.contains(theirs, b))
  end)
  lu.assertEquals(inRoom(function() return p1:usedSkillTimes(QINGCHENG, Player.HistoryPhase) end), 1)
end

-- 黄巾雷使 · 黑色：本回合首个非手牌伤害 +1。
function Testhanjin_qun_judgement:testHuangjinBlackIncreasesFirstNonHandcardDamage()
  local p1, p2, p3 = p(1), p(2), p(3)
  grant(p3, HUANGJIN)
  clearHand(p3)
  local paid = give(p3, SLASH, Card.Club, 2)
  seedJudgeCard("hanjin__jink", Card.Spade, 9)
  FkTest.setNextReplies(p3, { "1", FkTest.ReplyDiscard({ paid }) })
  inRoom(function()
    local before = p2.hp
    room():damage { from = p1, to = p2, damage = 1 }
    lu.assertEquals(p2.hp, before - 2)
  end)
end

-- 黄巾雷使 · 红色：伤害来源获得最终判定牌。
function Testhanjin_qun_judgement:testHuangjinRedGivesJudgeCardToSource()
  local p1, p2, p3 = p(1), p(2), p(3)
  grant(p3, HUANGJIN)
  clearHand(p3)
  local paid = give(p3, SLASH, Card.Club, 2)
  local judgeId = seedJudgeCard("hanjin__jink", Card.Heart, 9)
  FkTest.setNextReplies(p3, { "1", FkTest.ReplyDiscard({ paid }) })
  inRoom(function()
    local before = p2.hp
    room():damage { from = p1, to = p2, damage = 1 }
    lu.assertEquals(p2.hp, before - 1)
  end)
  lu.assertTrue(inRoom(function() return table.contains(p1:getCardIds("h"), judgeId) end))
end

-- 黄巾雷使 · 晚获翼从：本回合首个机会已在没有持有者时消耗，之后取得也不重开。
function Testhanjin_qun_judgement:testHuangjinLateAcquisitionDoesNotReopenFirstChance()
  local p1, p2, p3 = p(1), p(2), p(3)
  lu.assertTrue(inRoom(function() return room():hasSkill(HISTORY) end))
  -- 无持有者时的首个合格伤害：记录器已常驻，机会被消耗。
  inRoom(function() room():damage { from = p1, to = p2, damage = 1 } end)

  grant(p3, HUANGJIN)
  clearHand(p3)
  give(p3, SLASH, Card.Club, 2)
  local asked = 0
  local original = room().askToSkillInvoke
  room().askToSkillInvoke = function(self, player, params)
    if params and params.skill_name == HUANGJIN then
      asked = asked + 1
      return true
    end
    return original(self, player, params)
  end
  local ok, err = pcall(function()
    inRoom(function()
      local before = p2.hp
      room():damage { from = p1, to = p2, damage = 1 }
      lu.assertEquals(p2.hp, before - 1)
    end)
    lu.assertEquals(asked, 0)
  end)
  room().askToSkillInvoke = original
  assert(ok, err)
end

-- 黄巾雷使 · 直接渠道：使用手牌的【杀】伤害不开放机会；同回合随后由技能
-- 造成的伤害才是首次符合描述的伤害。
function Testhanjin_qun_judgement:testHuangjinIgnoresHandcardSlashDamage()
  local p1, p2, p3 = p(1), p(2), p(3)
  grant(p3, HUANGJIN)
  clearHand(p2)
  clearHand(p3)
  local paid = give(p3, SLASH, Card.Club, 2)
  give(p2, "hanjin__jink", Card.Heart, 2)
  seedJudgeCard("hanjin__jink", Card.Spade, 9)

  local asked = 0
  local original = room().askToSkillInvoke
  room().askToSkillInvoke = function(self, player, params)
    if params and params.skill_name == HUANGJIN then
      asked = asked + 1
      return true
    end
    return original(self, player, params)
  end
  FkTest.setNextReplies(p2, { "" })
  FkTest.setNextReplies(p3, { FkTest.ReplyDiscard({ paid }) })
  local ok, err = pcall(function()
    useSlash(p1, p2)
    -- 手牌【杀】的直接牌效伤害：不触发、也不消耗本回合首次机会。
    lu.assertEquals(asked, 0)
    inRoom(function()
      local before = p2.hp
      room():damage { from = p1, to = p2, damage = 1 }
      lu.assertEquals(p2.hp, before - 2)
    end)
    lu.assertEquals(asked, 1)
  end)
  room().askToSkillInvoke = original
  assert(ok, err)
end

return { name = "hanjin_qun_judgement" }
