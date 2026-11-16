-- HAN005 何进：谋诛、构难。默认国战套件用例（加入 tests/all.lua 后生效）。
-- 规则依据：rules/standard-generals.md 汉区 HAN005、
-- docs/development/implementation/card-use-targets.md。
local support = __dofile("../../../tests/support/hegemony.lua")

local MZ = "hanjin__skill_han005_1"
local GN = "hanjin__skill_han005_2"
local MARK = "hanjin_skill_han005_2_source-noclear"
local DEFAULT_KINGDOMS = { "han", "han", "wei", "wei", "shu", "shu", "wei", "han" }

Testhanjin_han005 = {}

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function p1() return FkTest.room.players[1] end
local function p2() return FkTest.room.players[2] end
local function p3() return FkTest.room.players[3] end

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
    for _, spec in ipairs(specs or {}) do
      local card = room:printCard(spec[1], spec[2] or Card.Spade, spec[3] or 1)
      room:obtainCard(player, card, false, fk.ReasonJustMove)
      table.insert(ids, card.id)
    end
  end)
  return ids
end

local function setKingdom(room, player, kingdom)
  inRoom(function()
    player.kingdom = kingdom
    room:setPlayerProperty(player, "kingdom", kingdom)
    room:setPlayerMark(player, "__heg_kingdom", kingdom)
  end)
end

local function installTestSkill(room, name, effects)
  local skel = fk.CreateSkill { name = name }
  for _, spec in ipairs(effects) do
    skel:addEffect(spec[1], spec[2])
  end
  local skill = skel:createSkill()
  Fk.skills[name] = skill
  inRoom(function() room:addSkill(skill) end)
end

local function runPlayPhase(room, player, replies)
  FkTest.setNextReplies(player, replies)
  inRoom(function()
    GameEvent.Turn:create(TurnData:new(player, "game_rule", { Player.Play })):exec()
  end)
end

local function virtualUse(target, name)
  return {
    card = { skill = "virtual_viewas", subcards = {} },
    targets = { target.id },
    interaction_data = name,
  }
end

local function initializeGenerals(room)
  inRoom(function()
    for i, p in ipairs(room.players) do
      local kingdom = DEFAULT_KINGDOMS[i]
      p:revealGeneral(false, true)
      p:revealGeneral(true, true)
      room:changeHero(p, "hanjin_test__" .. kingdom .. "_2", true, true, false, false, false)
      room:changeHero(p, "hanjin_test__" .. kingdom .. "_1", true, false, false, false, false)
      p.kingdom = kingdom
      room:setPlayerProperty(p, "kingdom", kingdom)
      room:setPlayerMark(p, "__heg_general", p.general)
      room:setPlayerMark(p, "__heg_deputy", p.deputyGeneral)
      room:setPlayerMark(p, "__heg_kingdom", kingdom)
      room:setPlayerMark(p, "__heg_init_kingdom", kingdom)
      room:setPlayerMark(p, "__heg_wild", 0)
    end
    room:changeHero(p1(), "hanjin__han005", true, false, false, false, false)
    room:setPlayerMark(p1(), "__heg_general", "hanjin__han005")
    for _, p in ipairs(room.players) do p.hp = p.maxHp end
  end)
  return room
end

local function prepare()
  return initializeGenerals(support.initHanjinRoom())
end

Testhanjin_han005.setup = function() prepare() end
Testhanjin_han005.tearDown = support.clearRoom

function Testhanjin_han005:testMouzhuGiveThenDifferentKingdomTargetNoDiscard()
  local room = FkTest.room
  setKingdom(room, p1(), "han")
  setKingdom(room, p3(), "han")
  setKingdom(room, p2(), "wei")
  setHand(room, p2(), {})
  local mine = setHand(room, p1(), {
    { "hanjin__slash", Card.Spade, 1 },
    { "hanjin__jink", Card.Heart, 2 },
  })
  local theirs = setHand(room, p3(), {
    { "hanjin__slash", Card.Club, 3 },
    { "hanjin__jink", Card.Diamond, 4 },
  })

  FkTest.setNextReplies(p3(), {
    FkTest.ReplyChooseCards({ theirs[1] }),
    virtualUse(p2(), "hanjin__slash"),
  })
  FkTest.setNextReplies(p2(), { "" })
  runPlayPhase(room, p1(), {
    FkTest.ReplyUseSkill(MZ, { p3() }, {}),
    "",
  })

  -- 交牌后 p3 手牌 1、何进 3，故视为使用杀；目标 p2 为魏，不弃牌。
  lu.assertEquals(#p1():getCardIds("h"), 3)
  lu.assertEquals(#p3():getCardIds("h"), 1)
  lu.assertIs(p2().hp, p2().maxHp - 1)
  lu.assertEquals(#mine, 2)
end

function Testhanjin_han005:testMouzhuSameKingdomTargetForcesDiscard()
  local room = FkTest.room
  setKingdom(room, p1(), "han")
  setKingdom(room, p3(), "han")
  -- 合法夹具：p2 为与何进同势力的汉，且与 p3 相邻，默认距离内有合法【杀】
  -- 目标；真实造成伤害后才能验证“目标与何进势力相同”的弃牌分支。
  setKingdom(room, p2(), "han")
  setHand(room, p2(), {})
  lu.assertNotEquals(p2().general, "anjiang")
  lu.assertNotEquals(p2().deputyGeneral, "anjiang")
  local p2Hp = p2().hp
  local mine = setHand(room, p1(), {
    { "hanjin__slash", Card.Spade, 1 },
    { "hanjin__jink", Card.Heart, 2 },
  })
  local theirs = setHand(room, p3(), {
    { "hanjin__slash", Card.Club, 3 },
    { "hanjin__jink", Card.Diamond, 4 },
  })

  FkTest.setNextReplies(p3(), {
    FkTest.ReplyChooseCards({ theirs[1] }),
    virtualUse(p2(), "hanjin__slash"),
    FkTest.ReplyDiscard({ theirs[2] }),
  })
  FkTest.setNextReplies(p2(), { "" })
  runPlayPhase(room, p1(), {
    FkTest.ReplyUseSkill(MZ, { p3() }, {}),
    "",
  })

  -- 交牌后 p3 手牌 1、何进 3，故视为使用杀；杀真实命中同势力 p2 后弃牌。
  lu.assertEquals(p2().hp, p2Hp - 1)
  lu.assertEquals(#p3():getCardIds("h"), 0)
  lu.assertEquals(#p1():getCardIds("h"), 3)
  lu.assertEquals(#mine, 2)
end

function Testhanjin_han005:testGounanNormalSlashBothDirectionsAndAttributeSlashExcluded()
  local room = FkTest.room
  setKingdom(room, p1(), "han")
  setKingdom(room, p2(), "wei")
  setKingdom(room, p3(), "shu")
  setHand(room, p1(), {})
  setHand(room, p2(), {})
  setHand(room, p3(), {})
  inRoom(function()
    p2().maxHp = 20
    p2().hp = 20
    p3().maxHp = 20
    p3().hp = 20
  end)

  local damages = {}
  installTestSkill(room, "#han005_damage_probe", {
    { fk.Damage, {
      global = true,
      can_refresh = function(self, event, target, player) return target ~= nil and target == player end,
      on_refresh = function(self, event, target, player, data)
        table.insert(damages, data.damage)
      end,
    } },
  })

  -- 暗将死亡仍应触发构难：公共死亡流程先翻正，再建立来源常驻印记。
  inRoom(function() p1():hideGeneral(false) end)
  inRoom(function() room:killPlayer { who = p1(), killer = p2() } end)
  lu.assertTrue(p1().dead)
  lu.assertEquals(p2():getMark(MARK), 1)

  FkTest.setNextReplies(p3(), { "" })
  inRoom(function()
    room:useCard {
      from = p2(),
      tos = { p3() },
      card = Fk:cloneCard("hanjin__slash", Card.Spade, 1),
    }
  end)

  FkTest.setNextReplies(p2(), { "" })
  inRoom(function()
    room:useCard {
      from = p3(),
      tos = { p2() },
      card = Fk:cloneCard("hanjin__slash", Card.Club, 2),
    }
  end)

  FkTest.setNextReplies(p2(), { "" })
  inRoom(function()
    room:useCard {
      from = p3(),
      tos = { p2() },
      card = Fk:cloneCard("hanjin__fire__slash", Card.Heart, 3),
    }
  end)

  lu.assertEquals(#damages, 3)
  lu.assertEquals(damages[1], 2) -- 来源造成普通杀伤害 +1
  lu.assertEquals(damages[2], 2) -- 来源受到普通杀伤害 +1
  lu.assertEquals(damages[3], 1) -- 火杀被排除
end

return { name = "hanjin_han005" }
