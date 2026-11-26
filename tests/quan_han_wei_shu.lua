-- 六势力权包回归（上）：注册元数据、汉晋军令公共规则、汉/魏/蜀六将与翼从无当飞军。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local client_room = __dofile("../../../tests/support/client_room.lua")

local H = require "packages.hegemony.util"
local Commander = require "packages.qiao.pkg.qiao_mode.rules.commander_retinue"
local Guest = require "packages.qiao.pkg.qiao_mode.rules.guest_factions"
local Junling = require "packages.qiao.pkg.qiao_mode.rules.junling"
local SkillButtons = require "packages.qiao.pkg.qiao_mode.rules.skill_buttons"
local SkillStatus = require "packages.qiao.pkg.qiao_mode.skill_status"
local Quan = require "packages.qiao.pkg.qiao_generals.util.quan_common"
local R = require "packages.qiao.pkg.qiao_generals.util.retinue_instances"

local function room() return FkTest.room end
local function p(n) return FkTest.room.players[n] end
local function inRoom(fn)
  local ret
  FkTest.runInRoom(function() ret = fn() end)
  return ret
end

local function clearAllZones(player)
  for _, zone in ipairs({ "h", "e", "j" }) do
    local ids = player:getCardIds(zone)
    if #ids > 0 then
      room():moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false)
    end
  end
end

local function give(player, name, suit, number)
  local card
  inRoom(function()
    card = room():printCard(name, suit or Card.Spade, number or 7)
    room():obtainCard(player, card, false, fk.ReasonJustMove)
  end)
  return card
end

local function equip(player, name, suit, number)
  local card
  inRoom(function()
    card = room():printCard(name, suit or Card.Spade, number or 7)
    room():moveCardTo(card, Card.PlayerEquip, player, fk.ReasonJustMove, "test", nil, true)
  end)
  return card
end

local function prepareRoom(kingdoms)
  Fk.currentResponsePattern = nil
  local r = support.initQiaoRoom()
  inRoom(function()
    skill_test.installBlankGenerals(r, kingdoms or { "han", "wei", "shu", "wu", "qun", "jin", "han", "wei" })
    for _, pl in ipairs(r.players) do
      clearAllZones(pl)
    end
    r.current = r.players[1]
    r:setBanner("RoundCount", 1)
  end)
  return r
end

Testqiao_quan_han_wei_shu = {
  setup = function() prepareRoom() end,
  tearDown = function()
    Fk.currentResponsePattern = nil
    support.clearRoom()
  end,
}

function Testqiao_quan_han_wei_shu:testHan003LiuhongYujue()
  local liuhong, target, victim = p(1), p(2), p(3)
  inRoom(function()
    skill_test.installDualGenerals(room(), liuhong, { main = "qiao_heg__han003", deputy = "qiao_test__han_2", kingdom = "han" })
    skill_test.installDualGenerals(room(), target, { main = "qiao_heg__wei005", deputy = "qiao_heg__wei004", kingdom = "wei" })
  end)
  give(liuhong, "qiao__slash", Card.Spade, 2)
  give(liuhong, "qiao__slash", Card.Spade, 3)
  give(liuhong, "qiao__slash", Card.Spade, 4)

  -- 分支1：执行军令 -> 本回合下次造成伤害后摸两张（刘宏暗置后依然生效，且仅限一次）
  local origAsk = Junling.ask
  Junling.ask = function() return true end
  skill_test.withSkillRequests(room(), "qiao__skill_han003_1", {
    askToDiscard = function(self, who, params)
      local id = who:getCardIds("h")[1]
      self:throwCard({ id }, params.skill_name, who, who)
      return { id }
    end,
  }, function()
    inRoom(function()
      room().current = target
      target.phase = Player.Play
      room().logic:trigger(fk.EventPhaseStart, target, {})
    end)
  end)
  lu.assertEquals(target:getMark(Quan.YUJUE_DRAW_MARK), 1)
  local states = SkillStatus.forPlayer(target)
  lu.assertTrue(table.find(states, function(s) return s.id == Quan.YUJUE_DRAW_MARK end) ~= nil)

  local handBefore = target:getHandcardNum()
  inRoom(function()
    liuhong:hideGeneral(false)
    room():damage { from = target, to = victim, damage = 1, skillName = "test" }
    lu.assertEquals(target:getHandcardNum(), handBefore + 2, "刘宏暗置后鬻爵已建立摸2仍生效")
    room():damage { from = target, to = victim, damage = 1, skillName = "test" }
    lu.assertEquals(target:getHandcardNum(), handBefore + 2, "第二次造成伤害不再重复摸牌")
  end)

  -- 分支2：不执行 -> 暗置其一将且本回合不能明置；再次不执行（已有暗置）-> 定向叠置
  inRoom(function() liuhong:revealGeneral(false) end)
  Junling.ask = function() return false end
  skill_test.withSkillRequests(room(), "qiao__skill_han003_1", {
    askToDiscard = function(self, who, params)
      local id = who:getCardIds("h")[1]
      self:throwCard({ id }, params.skill_name, who, who)
      return { id }
    end,
    askToChoice = function(self, who, params) return params.choices[1] end,
  }, function()
    inRoom(function()
      room().current = target
      target.phase = Player.Play
      room().logic:trigger(fk.EventPhaseStart, target, {})
    end)
  end)
  lu.assertEquals(target.general, "anjiang")
  lu.assertTrue(target:prohibitReveal(false), "被鬻爵暗置的将牌本回合不能明置")
  lu.assertTrue(target.faceup)

  -- 再次对已有暗置武将牌的 target 发动且不执行 -> 改为定向叠置
  skill_test.withSkillRequests(room(), "qiao__skill_han003_1", {
    askToDiscard = function(self, who, params)
      local id = who:getCardIds("h")[1]
      self:throwCard({ id }, params.skill_name, who, who)
      return { id }
    end,
  }, function()
    inRoom(function()
      room().logic:trigger(fk.EventPhaseStart, target, {})
    end)
  end)
  Junling.ask = origAsk
  lu.assertFalse(target.faceup, "已有暗置将牌时改为叠置")
end

function Testqiao_quan_han_wei_shu:testHan021CaojieShouxiAndXuanhu()
  local caojie, ally, enemy = p(1), p(7), p(2)
  inRoom(function()
    skill_test.installDualGenerals(room(), caojie, { main = "qiao_heg__han021", deputy = "qiao_test__han_2", kingdom = "han" })
    skill_test.installDualGenerals(room(), ally, { main = "qiao_heg__han001", deputy = "qiao_test__han_2", kingdom = "han" })
    skill_test.installDualGenerals(room(), enemy, { main = "qiao_heg__wei005", deputy = "qiao_test__wei_2", kingdom = "wei" })
  end)
  local eqSpade = equip(ally, "qiao__crossbow", Card.Spade, 1)
  local eqHeart = equip(ally, "qiao__chitu", Card.Heart, 5)
  local cjSpade = give(caojie, "qiao__slash", Card.Spade, 9)
  local cjHeart = give(caojie, "qiao__peach", Card.Heart, 6)

  -- 守玺：异势力同时非弃置移动两张装备牌，逐张判定：弃黑桃防黑桃，放行红桃
  local askCalls = 0
  skill_test.withSkillRequests(room(), "qiao__skill_han021_1", {
    askToDiscard = function(self, who, params)
      askCalls = askCalls + 1
      if params.pattern == ".|.|spade" then
        self:throwCard({ cjSpade.id }, params.skill_name, who, who)
        return { cjSpade.id }
      end
      return {}
    end,
  }, function()
    inRoom(function()
      room():moveCards({
        from = ally,
        ids = { eqSpade.id, eqHeart.id },
        to = enemy,
        toArea = Card.PlayerHand,
        moveReason = fk.ReasonPrey,
        proposer = enemy,
        skillName = "test_prey",
      })
    end)
  end)
  lu.assertEquals(askCalls, 2, "多张装备应逐张触发询问")
  lu.assertTrue(table.contains(ally:getCardIds("e"), eqSpade.id), "黑桃装备应被防止移动留在装备区")
  lu.assertTrue(table.contains(enemy:getCardIds("h"), eqHeart.id), "红桃装备放弃防止则正常被获得")

  -- 弃置原因不触发守玺
  local discardTriggered = false
  local cjSpade2 = give(caojie, "qiao__slash", Card.Spade, 8)
  skill_test.withSkillRequests(room(), "qiao__skill_han021_1", {
    askToDiscard = function() discardTriggered = true; return {} end,
  }, function()
    inRoom(function()
      room():throwCard({ eqSpade.id }, "test_discard", ally, enemy)
    end)
  end)
  lu.assertFalse(discardTriggered, "弃置原因不得触发守玺")
  lu.assertNotNil(cjSpade2)

  -- 悬壶：判定区红牌入弃牌堆不计入；手牌红牌入弃牌堆计入，回合结束曹节选摸/弃使手牌数==体力值后回复1血
  inRoom(function()
    room():setPlayerMark(caojie, Quan.XUANHU_RED_MARK, 0)
    local judgeRed = room():printCard("qiao__indulgence", Card.Heart, 6)
    room():moveCardTo(judgeRed, Card.PlayerJudge, caojie, fk.ReasonJustMove, "test", nil, true)
    room():moveCardTo(judgeRed, Card.DiscardPile, nil, fk.ReasonDiscard, "test", nil, true)
    lu.assertEquals(caojie:getMark(Quan.XUANHU_RED_MARK), 0, "判定区红牌置入弃牌堆不计入悬壶")

    room():throwCard({ cjHeart.id }, "test", caojie, caojie)
    lu.assertEquals(caojie:getMark(Quan.XUANHU_RED_MARK), 1, "手牌区红牌置入弃牌堆计入悬壶")

    -- 准备受伤盟友：hp = 2，手牌 1 -> 选摸1变2 == hp -> 回1血变3
    if ally.hp > 2 then room():loseHp(ally, ally.hp - 2, "test") end
    clearAllZones(ally)
    local c = room():printCard("qiao__jink", Card.Club, 2)
    room():obtainCard(ally, c, false, fk.ReasonJustMove)
  end)
  local allyHpBefore = ally.hp
  skill_test.withSkillRequests(room(), "qiao__skill_han021_2", {
    askToChoosePlayers = function() return { ally } end,
    askToOptions = function(self, who, params) return { "#qiao__skill_han021_2-draw" } end,
  }, function()
    inRoom(function()
      room().logic:trigger(fk.TurnEnd, room().current, {})
    end)
  end)
  lu.assertEquals(ally:getHandcardNum(), allyHpBefore)
  lu.assertEquals(ally.hp, allyHpBefore + 1, "手牌数等于体力值应回复1点体力")
end

function Testqiao_quan_han_wei_shu:testArmyOrderFallsBackInUpstreamHegemony()
  support.clearRoom()
  local upstream = support.initRoom()
  local source, target = upstream.players[1], upstream.players[2]
  local initialHp = target.hp
  inRoom(function()
    local data = { from = source, tos = { target }, skillName = "test" }
    H.CommandPrepare("command3", data)
    H.CommandCB("command3", target, source, data)
  end)
  lu.assertEquals(target.hp, initialHp - 1)
end

return { name = "qiao_quan_han_wei_shu" }
