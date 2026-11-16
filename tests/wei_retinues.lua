-- WEI/QUN 翼从：并州狼骑、虎卫军、牛金。定向验收。
-- 2026-11-14 真实运行 3/3。
--   python scripts/test.py --file tests/wei_retinues.lua --timeout 120
local support = __dofile("../../../tests/support/hegemony.lua")

local BZ = "hanjin__retinue_skill_bingzhou_langqi"
local HW = "hanjin__retinue_skill_huweijun"
local NJ = "hanjin__retinue_skill_niujin"

-- p1/p2 魏（发动者与回合结束的同势力目标），p3 群为击杀敌人，
-- p4 蜀保留另一存活势力，避免击杀导致游戏结束或同势力击杀弃牌。
local DEFAULT_KINGDOMS = { "wei", "wei", "qun", "shu", "wei", "wei", "wei", "wei" }

Testhanjin_wei_retinues = {}

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function p(n) return FkTest.room.players[n] end
local function p1() return p(1) end
local function p2() return p(2) end
local function p3() return p(3) end

local function clearCards(room, player)
  local ids = player:getCardIds("he")
  if #ids > 0 then
    inRoom(function()
      room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false)
    end)
  end
end

local function setHand(room, player, specs)
  clearCards(room, player)
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
    local card = room:printCard(name, suit or Card.Spade, number or 1)
    room:moveCardTo(card, Card.PlayerEquip, player, fk.ReasonJustMove, "test", nil, false)
    id = card.id
  end)
  return id
end

local function initializeGenerals(room)
  inRoom(function()
    for i, pl in ipairs(room.players) do
      local kingdom = DEFAULT_KINGDOMS[i]
      pl:revealGeneral(false, true)
      pl:revealGeneral(true, true)
      room:changeHero(pl, "hanjin_test__" .. kingdom .. "_2", true, true, false, false, false)
      room:changeHero(pl, "hanjin_test__" .. kingdom .. "_1", true, false, false, false, false)
      pl.kingdom = kingdom
      room:setPlayerProperty(pl, "kingdom", kingdom)
      room:setPlayerMark(pl, "__heg_general", pl.general)
      room:setPlayerMark(pl, "__heg_deputy", pl.deputyGeneral)
      room:setPlayerMark(pl, "__heg_kingdom", kingdom)
      room:setPlayerMark(pl, "__heg_init_kingdom", kingdom)
      room:setPlayerMark(pl, "__heg_wild", 0)
      -- 标记写入后按白板双将重算体力上限，避免硬编码。
      pl.maxHp = pl:getGeneralMaxHp()
      pl.hp = pl.maxHp
    end
  end)
end

local function grant(player, skillName)
  inRoom(function()
    player.room:handleAddLoseSkills(player, skillName, skillName, false, true)
  end)
end

local function prepare()
  local room = support.initHanjinRoom()
  initializeGenerals(room)
  return room
end

Testhanjin_wei_retinues.setup = function() prepare() end
Testhanjin_wei_retinues.tearDown = support.clearRoom

--- 记录实际使用事件（用于确认决斗使用者/牛金窗口用牌）。
local function installUseProbe(room, uses)
  local skel = fk.CreateSkill { name = "#hanjin_wei_retinue_use_probe" }
  skel:addEffect(fk.CardUseFinished, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return data.card ~= nil
    end,
    on_refresh = function(self, event, target, player, data)
      table.insert(uses, {
        name = data.card.name,
        from = data.from,
        tos = table.simpleClone(data.tos or {}),
      })
    end,
  })
  local skill = skel:createSkill()
  Fk.skills[skel.name] = skill
  inRoom(function() room:addSkill(skill) end)
end

--- 记录牛金奖励实际摸牌（按 move.skillName 去重，每名接收者只统计一次）。
local function installMoveProbe(room, record)
  local skel = fk.CreateSkill { name = "#hanjin_wei_retinue_move_probe" }
  skel:addEffect(fk.AfterCardsMove, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      for _, move in ipairs(data or {}) do
        if player == move.to and move.skillName == NJ then return true end
      end
      return false
    end,
    on_refresh = function(self, event, target, player, data)
      for _, move in ipairs(data or {}) do
        if player == move.to and move.skillName == NJ then
          record.moves = record.moves + 1
          record.cards = record.cards + #(move.moveInfo or {})
        end
      end
    end,
  })
  local skill = skel:createSkill()
  Fk.skills[skel.name] = skill
  inRoom(function() room:addSkill(skill) end)
end

function Testhanjin_wei_retinues:testBingzhouDuelByTargetFixedDistanceAndOncePerPhase()
  local room = FkTest.room
  grant(p1(), BZ)
  setHand(room, p1(), {})
  setHand(room, p2(), {})
  local uses = {}
  installUseProbe(room, uses)

  inRoom(function()
    local old = p1().phase
    p1().phase = Player.Play
    room:handleUseCardReply(p1(), FkTest.ReplyUseSkill(BZ, { p2() }))
    p1().phase = old
  end)

  -- 决斗由目标角色对并州狼骑持有者使用。
  local duel = table.find(uses, function(use)
    return use.name == "hanjin__duel" and use.from == p2()
  end)
  lu.assertNotNil(duel)
  lu.assertIs(duel.tos[1], p1())
  -- 双向距离1，且关系以表记录。
  lu.assertEquals(p1():distanceTo(p2()), 1)
  lu.assertEquals(p2():distanceTo(p1()), 1)
  local pairs = p1():getMark("@[hanjin_bingzhou_pairs]")
  lu.assertTrue(type(pairs) == "table" and table.contains(pairs, p2().id))
  -- 阶段次数限制。
  lu.assertEquals(p1():usedSkillTimes(BZ, Player.HistoryPhase), 1)
  inRoom(function()
    local old = p1().phase
    p1().phase = Player.Play
    lu.assertFalse(Fk.skills[BZ]:canUse(p1()))
    p1().phase = old
  end)
end

function Testhanjin_wei_retinues:testHuweijunOtherTurnDamageAllowsMove()
  local room = FkTest.room
  grant(p1(), HW)
  setHand(room, p1(), {})
  setHand(room, p2(), {})
  local equip = addEquip(room, p2(), "hanjin__chixiao_sword")
  addEquip(room, p1(), "hanjin__vine", Card.Heart, 4)
  -- 在 p2 的真实 Turn 事件范围内由 p1 造成实际伤害；回合末再检查历史。
  local probeName = "#hanjin_wei_retinue_turn_damage_probe"
  local skel = fk.CreateSkill { name = probeName }
  local done = false
  skel:addEffect(fk.EventPhaseStart, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return not done and target == p2() and target.phase == Player.Start
    end,
    on_refresh = function(self, event, target, player, data)
      done = true
      room:damage { from = p1(), to = p3(), damage = 2, skillName = "test" }
    end,
  })
  local probe = skel:createSkill()
  Fk.skills[probeName] = probe
  inRoom(function() room:addSkill(probe) end)

  FkTest.setNextReplies(p1(), {
    "1",
    { card = { skill = "choose_players_to_move_card_in_board", subcards = {} },
      targets = { p1().id, p2().id } },
    { cardId = equip, pos = 1 },
  })
  inRoom(function()
    GameEvent.Turn:create(TurnData:new(p2(), "game_rule", {
      Player.Start, Player.Finish,
    })):exec()
  end)
  lu.assertTrue(done)
  lu.assertEquals(room:getCardOwner(equip).id, p1().id)
end

function Testhanjin_wei_retinues:testNiujinUsesCardKillsAndDrawsThree()
  local room = FkTest.room
  grant(p1(), NJ)
  lu.assertTrue(p1():hasSkill(NJ))
  local slash = setHand(room, p1(), { { "hanjin__slash" } })[1]
  addEquip(room, p1(), "hanjin__qinggang_sword", Card.Spade, 2)
  setHand(room, p2(), {})
  setHand(room, p3(), {})
  inRoom(function()
    p3().maxHp = p3():getGeneralMaxHp()
    p3().hp = 1
  end)
  local uses = {}
  installUseProbe(room, uses)
  local reward = { moves = 0, cards = 0 }
  installMoveProbe(room, reward)
  FkTest.setNextReplies(p1(), {
    "1",
    { "basic" },
    FkTest.ReplyCard(Fk:getCardById(slash), { p3() }),
    { "#hanjin__retinue_skill_niujin-stop" },
  })
  inRoom(function()
    room.logic:trigger(fk.TurnEnd, p2(), TurnData:new(p2(), "game_rule", { Player.Start }))
  end)

  local usedSlash = table.find(uses, function(use)
    return use.name == "hanjin__slash" and use.from == p1()
  end)
  lu.assertNotNil(usedSlash)
  lu.assertTrue(p3().dead)
  -- 牛金奖励必须恰好一次、恰好3张；另加标准国战击杀不同势力角色的正常奖励1张。
  lu.assertEquals(reward.moves, 1)
  lu.assertEquals(reward.cards, 3)
  lu.assertEquals(#p1():getCardIds("h"), 4)
  lu.assertEquals(p1():usedSkillTimes(NJ, Player.HistoryGame), 1)
end

return { name = "hanjin_wei_retinues" }
