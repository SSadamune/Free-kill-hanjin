-- JIN005 柔克/顺流、JIN013 克清、JIN014 文虎（翼从）：真实主流程定向用例。
-- 本文件尚未加入 tests/all.lua；由负责测试接线的批次在测试槽中运行并登记。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")

local ROUKE = "qiao__skill_jin005_1"
local SHUNLIU = "qiao__skill_jin005_2"
local KEQING = "qiao__skill_jin013_2"
local WENHU = "qiao__retinue_skill_wenhu"

local OPT_HAND = "#qiao__retinue_skill_wenhu-hand"
local OPT_EQUIP = "#qiao__retinue_skill_wenhu-equip"

local TARGET_MARK_KEQING = "qiao_jin013_2_targets"
local SOURCE_MARK_KEQING = "@[qiao_keqing]"

Testqiao_jin_chain = {}
Testqiao_jin_chain.tearDown = support.clearRoom

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function p(n) return FkTest.room.players[n] end

local function clearCards(room, player)
  local ids = player:getCardIds("hej")
  if #ids > 0 then
    inRoom(function()
      room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false)
    end)
  end
end

local function giveHand(room, player, specs)
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

local function place(room, player, area, name, suit, number)
  local id
  inRoom(function()
    local card = room:printCard(name, suit or Card.Spade, number or 1)
    room:moveCardTo(card, area, player, fk.ReasonJustMove, "test", nil, false)
    id = card.id
  end)
  return id
end

local function addProbe(room, name, event, handler)
  local skel = fk.CreateSkill { name = name }
  skel:addEffect(event, {
    global = true,
    can_refresh = handler.can_refresh,
    on_refresh = handler.on_refresh,
  })
  local probe = skel:createSkill()
  Fk.skills[name] = probe
  inRoom(function() room:addSkill(probe) end)
end

-- 柔克：首张杀实际改为冰杀；未造成伤害后，至多两名角色横置/重置；手牌上限读取
-- 当前横置总数。
function Testqiao_jin_chain:testRoukeChangesFirstSlashAndFollowsUp()
  local room = support.initQiaoRoom()
  inRoom(function()
    skill_test.installBlankGenerals(room, { "jin", "jin", "jin", "jin" })
    skill_test.installDualGenerals(room, p(1), {
      main = "qiao_heg__jin005",
      deputy = "qiao_test__jin_2",
      kingdom = "jin",
    })
    room.current = p(1)
    p(1).phase = Player.Play
  end)
  for i = 1, 4 do clearCards(room, p(i)) end

  local slash = giveHand(room, p(2), { { "qiao__slash", Card.Heart, 7 } })[1]
  local jink = giveHand(room, p(3), { { "qiao__jink", Card.Spade, 3 } })[1]
  inRoom(function()
    p(2):setChainState(false)
    p(3):setChainState(true)
  end)

  local usedCard, actor
  addProbe(room, "#qiao_jin_chain_rouke_actor", fk.SkillEffect, {
    can_refresh = function(self, event, target, player, data)
      return target == player and data.skill.name == ROUKE
    end,
    on_refresh = function(self, event, target, player, data) actor = data.who end,
  })
  addProbe(room, "#qiao_jin_chain_rouke_probe", fk.CardUseFinished, {
    can_refresh = function(self, event, target, player, data)
      return target == p(2) and data.card ~= nil
    end,
    on_refresh = function(self, event, target, player, data)
      usedCard = data.card.name
    end,
  })

  FkTest.setNextReplies(p(2), { "1" })
  -- 羊祜只为后续选择目标，p2 横置、p3 重置直接按其当前状态处理。
  FkTest.setNextReplies(p(1), { FkTest.ReplyChoosePlayer({ p(2), p(3) }) })
  -- p3 以闪响应冰杀，使此牌不造成伤害。
  FkTest.setNextReplies(p(3), { FkTest.ReplyCard(Fk:getCardById(jink)) })

  -- 首张杀事实依赖本回合 UseCard 历史，必须在真实 Phase/Turn 事件范围内使用。
  local fired = false
  local playSkel = fk.CreateSkill { name = "#qiao_jin_chain_rouke_play" }
  playSkel:addEffect(fk.EventPhaseStart, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return not fired and target == p(2) and data.phase == Player.Play
    end,
    on_refresh = function(self, event, target, player, data)
      fired = true
      room:useCard {
        from = p(2),
        tos = { p(3) },
        card = Fk:getCardById(slash),
      }
    end,
  })
  local playProbe = playSkel:createSkill()
  Fk.skills[playSkel.name] = playProbe
  inRoom(function()
    room:addSkill(playProbe)
    GameEvent.Turn:create(TurnData:new(p(2), "game_rule", { Player.Play })):exec()
  end)
  lu.assertTrue(fired)

  lu.assertEquals(usedCard, "qiao__ice__slash")
  lu.assertIs(actor, p(2))
  lu.assertFalse(require("packages.qiao.pkg.qiao_mode.rules.skill_prelight").canPrelight(ROUKE))
  lu.assertTrue(p(2).chained)
  lu.assertFalse(p(3).chained)
  -- p2 是当前唯一横置角色；只有柔克持有者羊祜的手牌上限增加。
  inRoom(function()
    lu.assertEquals(p(1):getMaxCards(), math.max(p(1).hp, 0) + 1)
    lu.assertEquals(p(2):getMaxCards(), math.max(p(2).hp, 0))
  end)
end

-- 柔克：改牌后、本次用牌结束前失去技能，已建立的“然后”仍按实际改牌来源处理。
function Testqiao_jin_chain:testRoukeFollowUpSurvivesSkillLoss()
  local room = support.initQiaoRoom()
  inRoom(function()
    skill_test.installBlankGenerals(room, { "jin", "jin", "jin", "jin" })
    skill_test.installDualGenerals(room, p(1), {
      main = "qiao_heg__jin005",
      deputy = "qiao_test__jin_2",
      kingdom = "jin",
    })
    room.current = p(1)
    p(1).phase = Player.Play
  end)
  for i = 1, 4 do clearCards(room, p(i)) end

  local slash = giveHand(room, p(2), { { "qiao__slash", Card.Club, 8 } })[1]
  local jink = giveHand(room, p(3), { { "qiao__jink", Card.Diamond, 8 } })[1]
  inRoom(function()
    p(2):setChainState(false)
    p(3):setChainState(true)
  end)

  -- 改牌完成后、本次用牌结束前让羊祜失去柔克；后续监听器必须仍然存在。
  addProbe(room, "#qiao_jin_chain_rouke_loss_probe", fk.CardUsing, {
    can_refresh = function(self, event, target, player, data)
      return target == p(2) and data.card ~= nil
        and data.card.name == "qiao__ice__slash"
    end,
    on_refresh = function(self, event, target, player, data)
      room:handleAddLoseSkills(p(1), "-" .. ROUKE, nil, false, true)
    end,
  })

  FkTest.setNextReplies(p(2), { "1" })
  FkTest.setNextReplies(p(1), { FkTest.ReplyChoosePlayer({ p(2) }) })
  FkTest.setNextReplies(p(3), { FkTest.ReplyCard(Fk:getCardById(jink)) })

  local fired = false
  local playSkel = fk.CreateSkill { name = "#qiao_jin_chain_rouke_loss_play" }
  playSkel:addEffect(fk.EventPhaseStart, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return not fired and target == p(2) and data.phase == Player.Play
    end,
    on_refresh = function(self, event, target, player, data)
      fired = true
      room:useCard {
        from = p(2),
        tos = { p(3) },
        card = Fk:getCardById(slash),
      }
    end,
  })
  local playProbe = playSkel:createSkill()
  Fk.skills[playSkel.name] = playProbe
  inRoom(function()
    room:addSkill(playProbe)
    GameEvent.Turn:create(TurnData:new(p(2), "game_rule", { Player.Play })):exec()
  end)

  lu.assertTrue(fired)
  lu.assertFalse(p(1):hasSkill(ROUKE))
  lu.assertTrue(p(2).chained)
end

-- 顺流：属性伤害后先弃受伤者，再弃当时所有横置角色；受伤者已在 ChangeHp 重置，
-- 不按伤害前快照重复纳入，也不使用 DamageFinished。
function Testqiao_jin_chain:testShunliuDiscardsDamagedAndChainedPlayers()
  local room = support.initQiaoRoom()
  inRoom(function()
    skill_test.installBlankGenerals(room, { "jin", "jin", "jin", "jin" })
    skill_test.installDualGenerals(room, p(1), {
      main = "qiao_test__jin_1",
      deputy = "qiao_heg__jin005",
      kingdom = "jin",
    })
    room.current = p(1)
    p(1).phase = Player.Play
  end)
  for i = 1, 4 do clearCards(room, p(i)) end

  local victimCard = giveHand(room, p(2), { { "qiao__slash", Card.Heart, 2 } })[1]
  local chainedCard = giveHand(room, p(3), { { "qiao__jink", Card.Spade, 4 } })[1]
  inRoom(function()
    -- 受伤者不横置，避免火焰伤害触发铁索传导，单独验证“受伤者 + 当时横置者”。
    p(2):setChainState(false)
    p(3):setChainState(true)
  end)
  lu.assertTrue(p(1):hasSkill(SHUNLIU))

  -- 羊祜选择受伤者与横置角色各一张牌。askToChooseCard 的请求不是
  -- ReplyChooseCards 的技能牌格式，使用限定本技能的请求覆盖。
  local picks = { [p(2).id] = victimCard, [p(3).id] = chainedCard }
  FkTest.setNextReplies(p(1), { "1" })
  skill_test.withSkillRequests(room, SHUNLIU, {
    askToChooseCard = function(self, player, params, original)
      return picks[params.target.id]
    end,
  }, function()
    inRoom(function()
      room:damage {
        from = p(1),
        to = p(2),
        damage = 1,
        damageType = fk.FireDamage,
        skillName = "test",
      }
    end)
  end)

  lu.assertFalse(p(2).chained)
  lu.assertTrue(p(3).chained)
  lu.assertEquals(room:getCardArea(victimCard), Card.DiscardPile)
  lu.assertEquals(room:getCardArea(chainedCard), Card.DiscardPile)
end

-- 克清：建立效果后，目标使用牌时若横置由其自己弃一张；王濬失去技能后效果仍在，
-- 直到来源死亡或再次发动。
function Testqiao_jin_chain:testKeqingPersistsAfterSkillLoss()
  local room = support.initQiaoRoom()
  local src
  inRoom(function()
    skill_test.installBlankGenerals(room, { "jin", "jin", "jin", "jin" })
    -- 用非君主位作为王濬来源，避免测试中击杀君主触发游戏结束。
    src = (room:getLord() == p(1)) and p(4) or p(1)
    skill_test.installDualGenerals(room, src, {
      main = "qiao_heg__jin013",
      deputy = "qiao_test__jin_2",
      kingdom = "jin",
    })
    room.current = src
    src.phase = Player.Play
    p(2):setChainState(true)
  end)
  for i = 1, 4 do clearCards(room, p(i)) end

  inRoom(function()
    room:handleUseCardReply(src, FkTest.ReplyUseSkill(KEQING, { p(2) }))
  end)
  lu.assertTrue(table.contains(src:getTableMark(TARGET_MARK_KEQING), p(2).id))
  lu.assertTrue(table.contains(p(2):getTableMark(SOURCE_MARK_KEQING), src.id))

  -- 第一次真实使用：目标自己弃一张。
  local firstUse = giveHand(room, p(2), { { "qiao__slash", Card.Heart, 5 } })[1]
  local firstCost = giveHand(room, p(2), { { "qiao__jink", Card.Spade, 5 } })[1]
  FkTest.setNextReplies(p(2), { FkTest.ReplyDiscard({ firstCost }) })
  inRoom(function()
    room:useCard {
      from = p(2),
      tos = { p(3) },
      card = Fk:getCardById(firstUse),
    }
  end)
  lu.assertEquals(room:getCardArea(firstCost), Card.DiscardPile)

  -- 失去克清技能（来源未死）：已建立效果保留。主技能不能用 source_skill 参数，
  -- 否则只会从衍生素材中查找而不会移除玩家技能。
  inRoom(function()
    room:handleAddLoseSkills(src, "-" .. KEQING, nil, false, true)
  end)
  lu.assertFalse(src:hasSkill(KEQING))

  local secondUse = giveHand(room, p(2), { { "qiao__slash", Card.Club, 6 } })[1]
  local secondCost = giveHand(room, p(2), { { "qiao__jink", Card.Diamond, 6 } })[1]
  FkTest.setNextReplies(p(2), { FkTest.ReplyDiscard({ secondCost }) })
  inRoom(function()
    room:useCard {
      from = p(2),
      tos = { p(3) },
      card = Fk:getCardById(secondUse),
    }
  end)
  lu.assertEquals(room:getCardArea(secondCost), Card.DiscardPile)

  -- 来源死亡明确终止：测试夹具中 killPlayer 会先触发游戏结束，改用真实 dead
  -- 状态后继续真实用牌流程；克清在下次使用时清理已死来源，不再弃牌。
  inRoom(function()
    src.dead = true
    table.removeOne(room.alive_players, src)
  end)
  local thirdUse = giveHand(room, p(2), { { "qiao__slash", Card.Spade, 7 } })[1]
  local thirdCard = giveHand(room, p(2), { { "qiao__jink", Card.Heart, 7 } })[1]
  inRoom(function()
    room:useCard {
      from = p(2),
      tos = { p(3) },
      card = Fk:getCardById(thirdUse),
    }
  end)
  lu.assertTrue(src.dead)
  lu.assertTrue(p(2):isAlive())
  lu.assertEquals(room:getCardArea(thirdCard), Card.PlayerHand)
  local mark = p(2):getTableMark(SOURCE_MARK_KEQING)
  lu.assertTrue(mark == 0 or (type(mark) == "table" and #mark == 0))
end

-- 冰属性已由正式包注册为可传导属性：真实冰杀造成伤害时，横置的受伤者先重置。
function Testqiao_jin_chain:testIceSlashDamageResetsChainedVictim()
  local room = support.initQiaoRoom()
  inRoom(function()
    skill_test.installBlankGenerals(room, { "jin", "jin", "jin", "jin" })
    room.current = p(1)
    p(1).phase = Player.Play
  end)
  for i = 1, 4 do clearCards(room, p(i)) end

  local ice = giveHand(room, p(1), { { "qiao__ice__slash", Card.Spade, 6 } })[1]
  local hp = p(2).hp
  inRoom(function() p(2):setChainState(true) end)
  inRoom(function()
    room:useCard {
      from = p(1),
      tos = { p(2) },
      card = Fk:getCardById(ice),
    }
  end)
  lu.assertFalse(p(2).chained)
  lu.assertEquals(p(2).hp, hp - 1)
end

-- 文虎：完整弃置手牌区与装备区，X=2；视为使用目标上限为2的决斗。
function Testqiao_jin_chain:testWenhuDiscardsWholeZonesAndDuelTargetLimit()
  local room = support.initQiaoRoom()
  inRoom(function()
    skill_test.installBlankGenerals(room, { "jin", "jin", "jin", "jin" })
    room:handleAddLoseSkills(p(1), WENHU, WENHU, false, true)
    room.current = p(1)
    p(1).phase = Player.Play
  end)
  for i = 1, 4 do clearCards(room, p(i)) end

  giveHand(room, p(1), {
    { "qiao__slash", Card.Heart, 3 },
    { "qiao__jink", Card.Spade, 3 },
  })
  local equip = place(room, p(1), Card.PlayerEquip, "qiao__chixiao_sword", Card.Spade, 3)
  local judge = place(room, p(1), Card.PlayerJudge, "qiao__indulgence", Card.Heart, 6)

  local duel
  addProbe(room, "#qiao_jin_chain_wenhu_probe", fk.CardUseFinished, {
    can_refresh = function(self, event, target, player, data)
      return target == p(1) and data.card ~= nil and data.card.name == "qiao__duel"
    end,
    on_refresh = function(self, event, target, player, data)
      duel = data
    end,
  })

  FkTest.setNextReplies(p(1), {
    {
      card = { skill = "virtual_viewas", subcards = {} },
      targets = { p(2).id, p(3).id },
      interaction_data = "qiao__duel",
    },
  })
  inRoom(function()
    local reply = FkTest.ReplyUseSkill(WENHU)
    reply.interaction_data = "qiao_option_pair:::" .. OPT_HAND .. ":" .. OPT_EQUIP
    room:handleUseCardReply(p(1), reply)
  end)

  lu.assertEquals(#p(1):getCardIds("h"), 0)
  lu.assertEquals(#p(1):getCardIds("e"), 0)
  lu.assertEquals(room:getCardArea(judge), Card.PlayerJudge)
  lu.assertNotNil(duel)
  lu.assertEquals(#duel.tos, 2)
  lu.assertTrue(table.contains(duel.tos, p(2)))
  lu.assertTrue(table.contains(duel.tos, p(3)))
  lu.assertNotNil(equip)
end

return { name = "qiao_jin_chain" }
