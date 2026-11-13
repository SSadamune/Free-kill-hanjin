-- 魏势力主动/距离技能：长驱、伪溃、强袭、驱虎。
-- 夹具使用明确白板双将并重算 hp，避免随机真实双将的技能在嵌套【杀】时额外询问。
-- 输入通过官方 FkTest 回复队列；不替换 useVirtualCard/room:useCard/damage。
local support = __dofile("../../../tests/support/hegemony.lua")

local WEIKUI = "hanjin__skill_wei011_1"
local QIANGXI = "hanjin__skill_wei012_1"
local QUHU = "hanjin__skill_wei013_1"
local H = require "packages.hanjin.pkg.hanjin_mode.rules.wei_history"

local DEFAULT_KINGDOMS = { "wei", "wei", "wei", "wei", "wei", "wei", "wei", "wei" }

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

local function clearCards(player)
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

local function activate(player, name, targets)
  inRoom(function()
    room():handleUseCardReply(player, FkTest.ReplyUseSkill(name, targets, {}))
  end)
end

local function setPlayPhase(player)
  inRoom(function()
    room().current = player
    player.phase = Player.Play
    room():setBanner("RoundCount", 1)
  end)
end

local function initializeGenerals(room)
  inRoom(function()
    for i, pl in ipairs(room.players) do
      local kingdom = DEFAULT_KINGDOMS[i] or "wei"
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
      -- changeHero 期间 getGeneralMaxHp() 读取 __heg_general/__heg_deputy；
      -- 标记写入白板双将后重算，避免体力上限随随机初始双将变化。
      pl.maxHp = pl:getGeneralMaxHp()
      pl.hp = pl.maxHp
    end
  end)
end

--- 记录真实 CardUseFinished，不替换使用流程。
local function installUseProbe(uses)
  local key = "__hanjin_wei_active_use_probe"
  local skel = fk.CreateSkill { name = "#hanjin_wei_active_use_probe" }
  skel:addEffect(fk.CardUseFinished, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return type(data) == "table" and not data[key]
        and data.card ~= nil and data.card.trueName == "slash"
    end,
    on_refresh = function(self, event, target, player, data)
      data[key] = true
      table.insert(uses, {
        from = data.from,
        tos = table.simpleClone(data.tos or {}),
        card = data.card,
        skillName = data.card.skillName,
        extraUse = data.extraUse == true,
      })
    end,
  })
  local skill = skel:createSkill()
  Fk.skills[skel.name] = skill
  inRoom(function() room():addSkill(skill) end)
end

local function prepare()
  local room = support.initHanjinRoom()
  initializeGenerals(room)
  return room
end

Testhanjin_wei_active = { setup = prepare, tearDown = support.clearRoom }

function Testhanjin_wei_active:testChangquRecorderInstalledAndClientVisible()
  local p1, p2 = p(1), p(2)
  lu.assertTrue(room():hasSkill(H.HISTORY_SKILL))
  lu.assertTrue(room():hasSkill(H.WEIKUI_DISTANCE_SKILL))
  inRoom(function() room():damage { from = p1, to = p2, damage = 1 } end)
  lu.assertTrue(table.contains(p1:getTableMark(H.MARK), p2.id))
  local clientPlayer = ClientInstance:getPlayerById(p1.id)
  lu.assertNotNil(clientPlayer)
  lu.assertTrue(H.damaged(clientPlayer, p2.id))
  inRoom(function() room().logic:trigger(fk.TurnStart, p2, {}) end)
  lu.assertEquals(p1:getTableMark(H.MARK), {})
end

function Testhanjin_wei_active:testQiangxiPaysHpAndDamagesOncePerTargetPerPhase()
  local p1, p2 = p(1), p(2)
  grant(p1, QIANGXI)
  clearCards(p1)
  setPlayPhase(p1)
  inRoom(function() p1.hp = p1.maxHp; p2.hp = p2.maxHp end)
  local before = p2.hp
  activate(p1, QIANGXI, { p2 })
  lu.assertEquals(p1.hp, p1.maxHp - 1)
  lu.assertEquals(p2.hp, before - 1)
  lu.assertTrue(table.contains(p1:getTableMark("hanjin__skill_wei012_1-targets-phase"), p2.id))
end

function Testhanjin_wei_active:testWeikuiDiscardsWithoutJink()
  local p1, p2 = p(1), p(2)
  grant(p1, WEIKUI)
  clearCards(p1)
  clearCards(p2)
  local first = give(p2, "hanjin__slash")
  give(p2, "hanjin__slash")
  setPlayPhase(p1)
  inRoom(function() p1.hp = p1.maxHp end)

  -- viewCards 请求 -> 空回复；随后弃置目标手牌由发动者选择。
  FkTest.setNextReplies(p1, { "", first })
  local beforeHp, beforeHand = p1.hp, #p2:getCardIds("h")
  local ok, err = pcall(function() activate(p1, WEIKUI, { p2 }) end)
  assert(ok, err)
  lu.assertEquals(p1.hp, beforeHp - 1)
  lu.assertEquals(#p2:getCardIds("h"), beforeHand - 1)
end

function Testhanjin_wei_active:testWeikuiJinkBranchUsesRealSlash()
  local p1, p2 = p(1), p(2)
  grant(p1, WEIKUI)
  clearCards(p1)
  clearCards(p2)
  local jink = give(p2, "hanjin__jink", Card.Heart, 2)
  setPlayPhase(p1)
  inRoom(function() p1.hp = p1.maxHp; p2.hp = p2.maxHp end)

  local uses = {}
  installUseProbe(uses)

  -- 真实私看：包裹原 viewCards 记录全部调用，但仍调用实际实现。
  local viewed = {}
  local originalView = room().viewCards
  room().viewCards = function(self, player, params)
    table.insert(viewed, {
      player = player,
      cards = table.simpleClone(params.cards or {}),
    })
    return originalView(self, player, params)
  end

  FkTest.setNextReplies(p1, { "" })       -- viewCards 的确认
  FkTest.setNextReplies(p2, { "__cancel" }) -- 不对【杀】打出【闪】
  local beforeP1, beforeP2 = p1.hp, p2.hp
  local ok, err = pcall(function() activate(p1, WEIKUI, { p2 }) end)
  room().viewCards = originalView
  assert(ok, err)

  lu.assertEquals(#viewed, 1)
  lu.assertIs(viewed[1].player, p1)
  lu.assertTrue(table.contains(viewed[1].cards, jink))
  lu.assertEquals(p1.hp, beforeP1 - 1) -- 失去1点体力
  lu.assertEquals(p2.hp, beforeP2 - 1) -- 未打出【闪】，真实【杀】造成伤害
  lu.assertEquals(p1:getMark(H.WEIKUI_DISTANCE_MARK), p2.id)

  lu.assertEquals(#uses, 1)
  lu.assertIs(uses[1].from, p1)
  lu.assertEquals(#uses[1].tos, 1)
  lu.assertIs(uses[1].tos[1], p2)
  lu.assertEquals(uses[1].card.trueName, "slash")
end

function Testhanjin_wei_active:testQuhuTieUsesRealSlash()
  local p1, p2 = p(1), p(2)
  grant(p1, QUHU)
  clearCards(p1)
  clearCards(p2)
  local p1card = give(p1, "hanjin__slash", Card.Spade, 5)
  local p2card = give(p2, "hanjin__slash", Card.Heart, 5)
  setPlayPhase(p1)
  inRoom(function() p1.hp = 2; p2.hp = 3 end)

  local uses = {}
  installUseProbe(uses)

  -- 真实拼点：双方各出一张同点数牌 -> 平局；随后 p2 视为对 p1 使用【杀】。
  FkTest.setNextReplies(p1, {
    FkTest.ReplyChooseCards({ p1card }),
    "__cancel", -- 不对【杀】打出【闪】
  })
  FkTest.setNextReplies(p2, { FkTest.ReplyChooseCards({ p2card }) })

  local beforeP1, beforeP2 = p1.hp, p2.hp
  local ok, err = pcall(function() activate(p1, QUHU, { p2 }) end)
  assert(ok, err)

  lu.assertEquals(p1.hp, beforeP1 - 1)
  lu.assertEquals(p2.hp, beforeP2)
  lu.assertEquals(#uses, 1)
  lu.assertIs(uses[1].from, p2)
  lu.assertEquals(#uses[1].tos, 1)
  lu.assertIs(uses[1].tos[1], p1)
  lu.assertEquals(uses[1].card.trueName, "slash")
end

function Testhanjin_wei_active:testQuhuWinDealsDamageFromOpponent()
  local p1, p2, p3 = p(1), p(2), p(3)
  grant(p1, QUHU)
  clearCards(p1)
  clearCards(p2)
  give(p1, "hanjin__slash", Card.Spade, 7)
  give(p2, "hanjin__jink", Card.Heart, 2)
  setPlayPhase(p1)
  inRoom(function() p1.hp = 2; p2.hp = 3; p3.hp = p3.maxHp end)

  local oldPindian = p1.pindian
  p1.pindian = function() return { results = { [p2] = { winner = p1 } } } end
  local oldChoose = room().askToChoosePlayers
  room().askToChoosePlayers = function() return { p3 } end
  local ok, err = pcall(function() activate(p1, QUHU, { p2 }) end)
  p1.pindian = oldPindian
  room().askToChoosePlayers = oldChoose
  assert(ok, err)
  lu.assertEquals(p3.hp, p3.maxHp - 1)
  lu.assertEquals(p2.hp, 3)
end

return { name = "hanjin_wei_active" }
