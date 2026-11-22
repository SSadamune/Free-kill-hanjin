-- 群势力标准包：用牌/目标技能批次的核心真实主流程测试。
-- 覆盖：无双与短兵的响应数叠加、乱武真实用杀且包含最近目标、狂斧按本次
-- 用牌结果结算。本文件已加入 tests/all.lua，纳入默认国战套件。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local client_room = __dofile("../../../tests/support/client_room.lua")

local WUSHUANG = "qiao__skill_qun002_1"
local XIAOMENG = "qiao__skill_qun002_2"
local DUANBING = "qiao__skill_wu016_1"
local LUANJI = "qiao__skill_qun004_1"
local SHUANGXIONG = "qiao__skill_qun005_1"
local LUANWU = "qiao__skill_qun007_2"
local KUANGFU = "qiao__skill_qun017_1"
local XIAONI = "qiao__skill_qun027_2"
local RULE = "qiao__qun_cards_rule"
local STATE = "qiao__qun_cards_state"

local DEFAULT_KINGDOMS = { "qun", "qun", "qun", "qun", "qun", "qun", "qun", "qun" }

local function room() return FkTest.room end
local function p(n) return room().players[n] end
local function inRoom(fn) local r; FkTest.runInRoom(function() r = fn() end); return r end
local function grant(player, name)
  inRoom(function() player.room:handleAddLoseSkills(player, name, nil, false, true) end)
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
local function clearCards(player)
  inRoom(function()
    local ids = player:getCardIds("hej")
    if #ids > 0 then room():moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false) end
  end)
end
local function setKingdom(player, kingdom)
  inRoom(function()
    player.kingdom = kingdom
    room():setPlayerProperty(player, "kingdom", kingdom)
    room():setPlayerMark(player, "__heg_kingdom", kingdom)
    room():setPlayerMark(player, "__heg_wild", 0)
  end)
end
local function prepare()
  Fk.currentResponsePattern = nil
  local r = support.initQiaoRoom()
  inRoom(function()
    skill_test.installBlankGenerals(r, DEFAULT_KINGDOMS)
    -- 模式未接线时由测试显式安装独立房间规则；Codex 接线后避免重复安装。
    if not r:hasSkill(RULE) then r:addSkill(RULE) end
  end)
  return r
end
local function teardown() Fk.currentResponsePattern = nil; support.clearRoom() end
-- 与客户端按钮回包一致的主动技真实入口；避免依赖 PlayCard 请求的回复消费。
local function runActiveSkill(player, skillName, targetIds, subcards)
  inRoom(function()
    room():handleUseCardReply(player, {
      card = { skill = skillName, subcards = subcards or {} },
      targets = targetIds or {},
    }, nil)
  end)
end

Testqiao_qun_cards = { setup = prepare, tearDown = teardown }

-- 无双按当前响应数 +1，短兵再 +1：目标需要三张【闪】；只给两张仍会受到伤害。
function Testqiao_qun_cards:testWushuangStacksWithDuanbing()
  local p1, p2 = p(1), p(2)
  grant(p1, WUSHUANG)
  grant(p1, DUANBING)
  clearCards(p1)
  clearCards(p2)
  local slash = give(p1, "qiao__slash", Card.Spade, 8)
  local jink1 = give(p2, "qiao__jink", Card.Heart, 2)
  local jink2 = give(p2, "qiao__jink", Card.Diamond, 3)
  inRoom(function()
    room().current = p1
    p1.phase = Player.Play
    p1.hp = p1.maxHp
    p2.hp = p2.maxHp
  end)
  FkTest.setNextReplies(p1, { "" })
  FkTest.setNextReplies(p2, {
    FkTest.ReplyCard(Fk:getCardById(jink1)),
    FkTest.ReplyCard(Fk:getCardById(jink2)),
    "",
  })
  inRoom(function()
    room():useCard(UseCardData:new {
      from = p1,
      tos = { p2 },
      card = Fk:getCardById(slash),
      extra_data = {},
    })
  end)
  lu.assertEquals(p2.hp, p2.maxHp - 1)
end

-- 乱武要求真实使用【杀】且目标包含最近角色；其余角色取消则各失去 1 点体力。
function Testqiao_qun_cards:testLuanwuRealSlashIncludesNearest()
  local p1, p2 = p(1), p(2)
  grant(p1, LUANWU)
  for i = 1, 8 do clearCards(p(i)) end
  local slash = give(p2, "qiao__slash", Card.Spade, 9)
  inRoom(function()
    room().current = p1
    p1.phase = Player.Play
    for i = 1, 8 do p(i).hp = p(i).maxHp end
  end)
  -- p2 用真实【杀】指定 p1（与 p2 距离最近）；p1 不用【闪】。
  FkTest.setNextReplies(p2, { FkTest.ReplyCard(Fk:getCardById(slash), { p1 }) })
  for i = 3, 8 do FkTest.setNextReplies(p(i), { "" }) end
  FkTest.setNextReplies(p1, { "" })
  local uses = 0
  local name = "#qun_cards_test_slash_using"
  local skel = fk.CreateSkill { name = name }
  skel:addEffect(fk.CardUsing, {
    global = true,
    can_trigger = function(self, event, target, owner, data)
      return target == owner and owner == p2 and data ~= nil
        and data.from == p2 and data.card ~= nil and data.card.trueName == "slash"
    end,
    on_cost = Util.TrueFunc,
    on_use = function() uses = uses + 1 end,
  })
  local probe = skel:createSkill()
  Fk.skills[name] = probe
  inRoom(function() room():addSkill(probe) end)
  runActiveSkill(p1, LUANWU, {}, {})
  lu.assertEquals(p1.hp, p1.maxHp - 1)
  lu.assertEquals(p2.hp, p2.maxHp)
  -- 乱武要求真实使用【杀】，但该使用不占通常次数，不能以 usedCardTimes 计。
  lu.assertEquals(uses, 1)
  lu.assertEquals(room():getCardArea(slash), Card.DiscardPile)
  for i = 3, 8 do lu.assertEquals(p(i).hp, p(i).maxHp - 1) end
end

-- 狂斧弃置自己的装备且本次【杀】造成伤害：摸两张牌。
function Testqiao_qun_cards:testKuangfuOwnEquipmentDamageDrawsTwo()
  local p1, p2 = p(1), p(2)
  grant(p1, KUANGFU)
  clearCards(p1)
  clearCards(p2)
  local equip = give(p1, "qiao__chitu", Card.Heart, 5)
  inRoom(function()
    room():moveCardTo({ equip }, Card.PlayerEquip, p1, fk.ReasonPut, "test", nil, true)
    room().current = p1
    p1.phase = Player.Play
    p1.hp = p1.maxHp
    p2.hp = p2.maxHp
  end)
  FkTest.setNextReplies(p2, { "" })
  FkTest.setNextReplies(p1, { FkTest.ReplyChoosePlayer({ p2 }) })
  skill_test.withSkillRequests(room(), KUANGFU, {
    askToChooseCard = function(self, player, params, original)
      if params.skill_name == KUANGFU then return equip end
      return original(self, player, params)
    end,
  }, function()
    runActiveSkill(p1, KUANGFU, {}, {})
  end)
  lu.assertEquals(p2.hp, p2.maxHp - 1)
  lu.assertEquals(#p1:getCardIds("h"), 2)
end

-- 乱击响应摸牌由独立房间规则完成：response.from 定位本次使用者，且不需要
-- 袁绍仍持有乱击。
function Testqiao_qun_cards:testLuanjiDrawRuleUsesResponseFromWithoutSkill()
  local p1, p2 = p(1), p(2)
  clearCards(p1)
  clearCards(p2)
  local jink = give(p2, "qiao__jink", Card.Heart, 2)
  local aoe = Fk:cloneCard("qiao__archery_attack")
  aoe.skillName = LUANJI
  local before = #p2:getCardIds("h")
  local asked = 0
  skill_test.withSkillRequests(room(), LUANJI, {
    askToSkillInvoke = function()
      asked = asked + 1
      return true
    end,
  }, function()
    inRoom(function()
      room().logic:trigger(fk.CardRespondFinished, p2, {
        card = Fk:getCardById(jink),
        responseToEvent = { card = aoe, from = p1 },
      })
    end)
  end)
  lu.assertEquals(asked, 1) -- 房间规则只对 target 本人询问一次
  lu.assertEquals(#p2:getCardIds("h"), before + 1)
end

-- 狂斧的后续摸牌由独立房间规则按 use.extra_data 的 user 结算，不需要潘凤仍
-- 持有狂斧。
function Testqiao_qun_cards:testKuangfuRuleSettlesWithoutSkill()
  local p1, p2 = p(1), p(2)
  clearCards(p1)
  clearCards(p2)
  local slash = Fk:cloneCard("qiao__slash")
  slash.skillName = KUANGFU
  inRoom(function()
    room().logic:trigger(fk.CardUseFinished, p1, {
      from = p1,
      card = slash,
      tos = { p2 },
      damageDealt = { [p2] = 1 },
      extra_data = { qiao_qun017 = { user = p1.id, self = true } },
    })
  end)
  lu.assertEquals(#p1:getCardIds("h"), 2)
end

-- 乱击花色记录由房间规则每回合清理，即使袁绍已失去乱击也不会跨回合残留。
function Testqiao_qun_cards:testLuanjiSuitMarkClearsAfterSkillLost()
  local p1 = p(1)
  grant(p1, LUANJI)
  inRoom(function()
    room():setPlayerMark(p1, "@[qiao_luanji_suits]", { Card.Heart })
    room():handleAddLoseSkills(p1, "-" .. LUANJI, nil, false, true)
    room().logic:trigger(fk.TurnEnd, p1, {})
  end)
  lu.assertEquals(#p1:getTableMark("@[qiao_luanji_suits]"), 0)
end

-- 虓猛：吕布使用转化【决斗】，由当前回合角色（不是吕布）追加一名不同势力目标，
-- 整次决斗真实结算到新增目标。
function Testqiao_qun_cards:testXiaomengCurrentTurnAddsDifferentKingdomToConvertedDuel()
  local p1, p2, p3, p4 = p(1), p(2), p(3), p(4)
  grant(p1, XIAOMENG)
  setKingdom(p3, "wei")
  setKingdom(p4, "shu")
  for _, q in ipairs({ p1, p3, p4 }) do clearCards(q) end
  local sub = give(p1, "qiao__jink", Card.Spade, 4)
  inRoom(function()
    room().current = p2
    p1.hp = p1.maxHp
    p2.hp = p2.maxHp
    p3.hp = p3.maxHp
    p4.hp = p4.maxHp
  end)
  local duel = Fk:cloneCard("qiao__duel")
  duel.skillName = SHUANGXIONG
  duel:addSubcard(sub)
  FkTest.setNextReplies(p2, { FkTest.ReplyChoosePlayer({ p4 }) })
  FkTest.setNextReplies(p3, { "" })
  FkTest.setNextReplies(p4, { "" })
  inRoom(function()
    room():useCard(UseCardData:new {
      from = p1,
      tos = { p3 },
      card = duel,
      extra_data = {},
    })
  end)
  lu.assertEquals(p1:usedCardTimes("duel", Player.HistoryGame), 1)
  lu.assertEquals(p3.hp, p3.maxHp - 1)
  lu.assertEquals(p4.hp, p4.maxHp - 1)
  lu.assertEquals(p2.hp, p2.maxHp)
end

-- 双雄：真实摸牌阶段结束弃红牌，本回合将黑色牌当【决斗】使用；决斗令自己
-- 受到伤害后，结束阶段收回该伤害牌的实体牌。覆盖转化权限与独立收牌。
function Testqiao_qun_cards:testShuangxiongConvertDuelAndRetrieveDamageCard()
  local p1, p2 = p(1), p(2)
  grant(p1, SHUANGXIONG)
  clearCards(p1)
  clearCards(p2)
  local red = give(p1, "qiao__peach", Card.Heart, 3)
  local black = give(p1, "qiao__jink", Card.Spade, 5)
  local p2Slash = give(p2, "qiao__slash", Card.Spade, 8)
  inRoom(function()
    room().current = p1
    p1.hp = p1.maxHp
    p2.hp = p2.maxHp
  end)

  -- 真实回合会先摸两张牌；测试专用探针在出牌阶段开始时清掉随机摸牌，
  -- 只保留要转化的黑色牌，并以正式 handleUseCardReply 入口完成转化使用，
  -- 随后结束该阶段，避免额外的 PlayCard 请求消费回复。
  local name = "#qun_cards_test_keep_black"
  local skel = fk.CreateSkill { name = name }
  skel:addEffect(fk.EventPhaseStart, {
    global = true,
    can_trigger = function(self, event, target, owner, data)
      return target == p1 and owner == p1 and data.phase == Player.Play
    end,
    on_cost = Util.TrueFunc,
    on_use = function(self, event, target, owner, data)
      local ids = table.filter(p1:getCardIds("h"), function(id) return id ~= black end)
      if #ids > 0 then
        room():moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false)
      end
      room():handleUseCardReply(p1, {
        card = { skill = STATE, subcards = { black } },
        targets = { p2.id },
      }, nil)
      data.phase_end = true
    end,
  })
  local probe = skel:createSkill()
  Fk.skills[name] = probe
  inRoom(function() room():addSkill(probe) end)

  FkTest.setNextReplies(p2, { FkTest.ReplyCard(Fk:getCardById(p2Slash)) })
  FkTest.setNextReplies(p1, {
    FkTest.ReplyDiscard({ red }), -- 弃置红牌
    "",                           -- 决斗中不打出【杀】
  })
  -- 摸牌阶段结束的弃牌请求已并入发动确认；结束阶段的收牌仍单独确认发动，
  -- 直接确认以免“无【杀】可响应”时响应请求被跳过导致收牌回复错位。
  skill_test.withSkillRequests(room(), SHUANGXIONG, {
    askToSkillInvoke = function() return true end,
  }, function()
    inRoom(function()
      GameEvent.Turn:create(TurnData:new(p1, "game_rule", {
        Player.Draw, Player.Play, Player.Finish,
      })):exec()
    end)
  end)
  lu.assertEquals(p1.hp, p1.maxHp - 1)
  lu.assertEquals(room():getCardArea(black), Card.PlayerHand)
  lu.assertTrue(table.contains(p1:getCardIds("h"), black))
end

-- 骁逆：一次多目标【杀】中一名目标用【闪】，另一名受伤；用牌结束后由未受伤
-- 的原目标弃置两张牌。
function Testqiao_qun_cards:testXiaoniMultiTargetDiscardsFromUndamagedTarget()
  local p1, p2, p3 = p(1), p(2), p(3)
  inRoom(function()
    room():changeHero(p1, "qiao_heg__qun027", false, false, false, false, false)
  end)
  setKingdom(p(1), "qun")
  setKingdom(p(2), "wei")
  inRoom(function()
    p3:hideGeneral(false)
    p3:hideGeneral(true)
  end)
  setKingdom(p(3), "unknown")
  setKingdom(p(4), "qun")
  for _, q in ipairs({ p1, p2, p3 }) do clearCards(q) end
  local jink = give(p3, "qiao__jink", Card.Heart, 2)
  local c1 = give(p3, "qiao__slash", Card.Spade, 3)
  local c2 = give(p3, "qiao__peach", Card.Heart, 4)
  local c3 = give(p3, "qiao__analeptic", Card.Diamond, 5)
  inRoom(function()
    room().current = p1
    p1.phase = Player.Play
    p1.hp = p1.maxHp
    p2.hp = p2.maxHp
    p3.hp = p3.maxHp
  end)
  local reply
  client_room.run(room(), function(clients)
    local board = assert(Fk:getBoardGame("qiao_heg_mode"))
    local ClientPlay = board.client_klass:new(ClientInstance.client).request_handlers.PlayCard
    local handler = ClientPlay:new(clients[1])
    handler:setup()
    lu.assertTrue(handler:skillButtonValidity(XIAONI))
    handler:selectSkill(XIAONI, { selected = true })
    lu.assertFalse(handler:feasible(), "未选人不能确认骁逆")
    lu.assertFalse(handler:targetValidity(p(4).id), "不能指定同势力角色")
    lu.assertTrue(handler:targetValidity(p2.id))
    lu.assertTrue(handler:targetValidity(p3.id), "可指定距离大于一且势力未确定的角色")
    handler:selectTarget(p2.id, { selected = true })
    handler:selectTarget(p3.id, { selected = true })
    lu.assertTrue(handler:feasible())
    local original = ClientInstance.notifyUI
    ClientInstance.notifyUI = function(_, command, data)
      if command == "ReplyToServer" then reply = data end
    end
    local ok, err = pcall(handler.doOKButton, handler)
    ClientInstance.notifyUI = original
    if not ok then error(err, 0) end
    handler:_finish()
  end)
  lu.assertNotNil(reply)
  lu.assertEquals(reply.targets, { p2.id, p3.id })
  lu.assertEquals(p1:usedSkillTimes(XIAONI, Player.HistoryGame), 0)
  FkTest.setNextReplies(p2, { "" })
  FkTest.setNextReplies(p3, { FkTest.ReplyCard(Fk:getCardById(jink)) })
  local askedCards = false
  skill_test.withSkillRequests(room(), XIAONI, {
    askToChooseCards = function(self, player, params, original)
      if params.skill_name == XIAONI and params.target == p3 then
        askedCards = true
        return { c1, c2 }
      end
      return original(self, player, params)
    end,
  }, function()
    inRoom(function() room():handleUseCardReply(p1, reply, nil) end)
  end)
  lu.assertEquals(p1:usedSkillTimes(XIAONI, Player.HistoryGame), 1)
  lu.assertTrue(askedCards) -- 房间规则确实以 askToChooseCards 选未受伤目标的两张牌
  lu.assertEquals(p2.hp, p2.maxHp - 1)
  lu.assertEquals(p3.hp, p3.maxHp)
  lu.assertTrue(table.contains(p3:getCardIds("h"), c3))
  lu.assertFalse(table.contains(p3:getCardIds("h"), c1))
  lu.assertFalse(table.contains(p3:getCardIds("h"), c2))
end

-- 一张材料只允许【奇策】声明一个决斗目标。【虓猛】在声明后追加的目标同样结算。
function Testqiao_qun_cards:testQiceOneCardDuelAcceptsXiaomengExtraTarget()
  local user, first, extra = p(1), p(3), p(4)
  local qice = "qiao__skill_wei020_1"
  grant(user, qice)
  grant(user, XIAOMENG)
  setKingdom(first, "wei")
  setKingdom(extra, "shu")
  for _, player in ipairs({ user, first, extra }) do clearCards(player) end
  local material = give(user, "qiao__jink", Card.Heart, 4)
  inRoom(function()
    room().current = user
    user.phase = Player.Play
  end)
  local firstHp, extraHp = first.hp, extra.hp
  FkTest.setNextReplies(user, { FkTest.ReplyChoosePlayer({ extra }) })
  FkTest.setNextReplies(first, { "" })
  FkTest.setNextReplies(extra, { "" })
  local completed = inRoom(function()
    local skill = Fk.skills[qice]
    skill.interaction.data = "qiao__duel"
    lu.assertTrue(skill:feasible(user, { first }, {}))
    lu.assertFalse(skill:feasible(user, { first, extra }, {}))
    skill_test.withSkillRequests(room(), qice, {
      askToChoice = function() return "Cancel" end,
    }, function()
      room():handleUseCardReply(user, {
        card = { skill = qice, subcards = {} }, interaction_data = "qiao__duel",
        targets = { first.id },
      })
    end)
    return true
  end)
  lu.assertTrue(completed)
  lu.assertEquals(user:usedCardTimes("duel", Player.HistoryGame), 1)
  lu.assertEquals(room():getCardArea(material), Card.DiscardPile)
  lu.assertEquals(first.hp, firstHp - 1)
  lu.assertEquals(extra.hp, extraHp - 1)
end

return { name = "qiao_qun_cards" }
