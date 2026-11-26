-- 六势力权包回归（下）：吴/群/晋六将与偏将胡车儿（限一）。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local client_room = __dofile("../../../tests/support/client_room.lua")

local H = require "packages.hegemony.util"
local Junling = require "packages.qiao.pkg.qiao_mode.rules.junling"
local SkillStatus = require "packages.qiao.pkg.qiao_mode.skill_status"
local Quan = require "packages.qiao.pkg.qiao_generals.util.quan_common"
local Wu = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wu"
local R = require "packages.qiao.pkg.qiao_generals.util.retinue_instances"
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
local Duanchang = require "packages.qiao.pkg.qiao_mode.rules.qun_duanchang"

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
    skill_test.installBlankGenerals(r, kingdoms or { "wu", "wu", "qun", "qun", "jin", "jin", "han", "wei" })
    for _, pl in ipairs(r.players) do
      clearAllZones(pl)
    end
    r.current = r.players[1]
    r:setBanner("RoundCount", 1)
  end)
  return r
end

Testqiao_quan_wu_qun_jin = {
  setup = function() prepareRoom() end,
  tearDown = function()
    Fk.currentResponsePattern = nil
    support.clearRoom()
  end,
}

function Testqiao_quan_wu_qun_jin:testWu019LukangJueyanAndKeshou()
  local lukang, enemy = p(1), p(7)
  inRoom(function()
    skill_test.installDualGenerals(room(), lukang, { main = "qiao_heg__wu019", deputy = "qiao_test__wu_2", kingdom = "wu" })
    room().current = lukang
    lukang.phase = Player.Start
  end)
  -- 给陆抗判定区塞一张【乐不思蜀】测试决堰选判定区牌当冰杀
  local ind
  inRoom(function()
    ind = room():printCard("qiao__indulgence", Card.Heart, 6)
    room():moveCardTo(ind, Card.PlayerJudge, lukang, fk.ReasonJustMove, "test", nil, true)
  end)
  local baseRange = lukang:getAttackRange()
  local allocs = { "#qiao__skill_wu019_1-draw", "#qiao__skill_wu019_1-slash", "#qiao__skill_wu019_1-range" }
  local allocIdx = 0
  skill_test.withSkillRequests(room(), "qiao__skill_wu019_1", {
    askToSkillInvoke = function() return true end,
    askToChooseCard = function() return ind.id end,
    askToChoosePlayers = function() return { enemy } end,
    askToOptions = function()
      allocIdx = allocIdx + 1
      return { allocs[allocIdx] }
    end,
    askToUseCard = function() return nil end, -- 不出闪
  }, function()
    inRoom(function()
      room().logic:trigger(fk.EventPhaseStart, lukang, {})
    end)
  end)
  lu.assertEquals(#lukang:getCardIds("j"), 0, "判定区牌已被当冰杀用出")
  lu.assertEquals(lukang:getMark(Quan.JUEYAN_DRAW_MARK), 1)
  lu.assertEquals(lukang:getMark(Quan.JUEYAN_SLASH_MARK), 1)
  lu.assertEquals(lukang:getMark(Quan.JUEYAN_RANGE_MARK), 1)
  lu.assertEquals(lukang:getAttackRange(), baseRange + 1, "决堰攻击范围+1应生效")
  local slashMax = inRoom(function()
    return Fk.skills["slash_skill"]:getMaxUseTime(lukang, Player.HistoryPhase, Fk:cloneCard("qiao__slash"))
  end)
  lu.assertEquals(slashMax, 2, "决堰出杀次数+1应生效")
  local states = SkillStatus.forPlayer(lukang)
  lu.assertTrue(table.find(states, function(s) return s.id == Quan.JUEYAN_DRAW_MARK end) ~= nil)

  -- 恪守：限使用不限打出；孤军（本势力仅存活自己 1 人）应变在 0 鱼时获得 1 鱼，有鱼时可消耗 1 鱼摸 1 牌
  inRoom(function()
    -- 将 p(2) 改为汉势力，使陆抗成为吴势力唯一存活角色（满足孤军条件）
    p(2).kingdom = "han"
    room():setPlayerProperty(p(2), "kingdom", "han")
  end)
  local keshou = assert(Fk.skills["qiao__skill_wu019_2"])
  local k1 = give(lukang, "qiao__slash", Card.Spade, 2)
  local k2 = give(lukang, "qiao__slash", Card.Club, 3)
  Fk.currentResponsePattern = "jink"
  lu.assertFalse(keshou:enabledAtResponse(lukang, true), "恪守仅限使用，不可用于纯打出响应")
  lu.assertTrue(keshou:enabledAtResponse(lukang, false), "恪守可用于使用【闪】窗口")
  local jinkCard = keshou:viewAs(lukang, { k1.id, k2.id })
  lu.assertNotNil(jinkCard)
  lu.assertEquals(jinkCard.name, "qiao__jink")
  -- 使用该转化闪响应【杀】（带真实 toCard）且此时孤军 -> 触发 qiao_keshou_yinyangfish 获得1枚阴阳鱼
  inRoom(function()
    room():setPlayerMark(lukang, "@!!yinyangfish", 0)
    room():useCard { from = lukang, tos = {}, toCard = Fk:cloneCard("qiao__slash"), card = jinkCard }
  end)
  lu.assertEquals(lukang:getMark("@!!yinyangfish"), 1, "孤军恪守0鱼时应获得1枚阴阳鱼")

  -- 已有1枚阴阳鱼时再孤军使用恪守（响应无懈可击），选择消耗阴阳鱼摸1牌
  local k3 = give(lukang, "qiao__slash", Card.Heart, 4)
  local k4 = give(lukang, "qiao__slash", Card.Diamond, 5)
  Fk.currentResponsePattern = "nullification"
  local nullCard = keshou:viewAs(lukang, { k3.id, k4.id })
  lu.assertNotNil(nullCard)
  lu.assertEquals(nullCard.name, "qiao__nullification")
  skill_test.withSkillRequests(room(), "qiao__skill_wu019_2", {
    askToOptions = function() return { "#qiao__skill_wu019_2-consume-draw" } end,
  }, function()
    inRoom(function()
      room():useCard { from = lukang, tos = {}, toCard = Fk:cloneCard("qiao__dismantlement"), card = nullCard }
    end)
  end)
  Fk.currentResponsePattern = nil
  lu.assertEquals(lukang:getMark("@!!yinyangfish"), 0, "消耗阴阳鱼后标记归零")
  lu.assertEquals(lukang:getHandcardNum(), 1, "消耗阴阳鱼摸1牌生效")
end

local function checkKeshouWithCargo(pattern, cargoCount, incoming)
  local lukang, attacker = p(1), p(2)
  local skillName = "qiao__skill_wu019_2"
  inRoom(function()
    skill_test.installDualGenerals(room(), lukang, { main = "qiao_heg__wu019", deputy = "qiao_test__wu_2", kingdom = "wu" })
    room().current, attacker.phase = attacker, Player.Play
  end)
  local ox = equip(lukang, "qiao__wooden_ox", Card.Diamond, 5)
  local first = give(lukang, "qiao__peach", Card.Heart, 3).id
  local second = give(lukang, "qiao__analeptic", Card.Club, 6).id
  inRoom(function()
    lukang:addToPile("$sa_carriage", cargoCount == 2 and { first, second } or { second }, false, "qiao__wooden_ox_skill")
  end)

  local reply
  client_room.run(room(), function(clients)
    local board = Fk:getBoardGame(room():getSettings("gameMode"))
    local client = board.client_klass:new(ClientInstance.client)
    local handler = client.request_handlers.AskForUseCard:new(clients[lukang.seat], { nil, pattern, "", true, {} })
    Fk.currentResponsePattern = pattern
    handler:setup()
    lu.assertTrue(handler:skillButtonValidity(skillName))
    handler:selectSkill(skillName, { selected = true })
    for _, id in ipairs({ first, second }) do
      lu.assertNotNil(handler.scene:getAllItems("CardItem")[id], "恪守应展开可用的辎")
      lu.assertTrue(handler:cardValidity(id))
      handler:selectCard(id, { selected = true })
    end
    lu.assertTrue(handler:feasible())
    local notify = ClientInstance.notifyUI
    ClientInstance.notifyUI = function(_, command, data)
      if command == "ReplyToServer" then reply = data end
    end
    local ok, err = pcall(function() handler:doOKButton() end)
    ClientInstance.notifyUI = notify
    assert(ok, err)
    handler:_finish()
  end)
  lu.assertNotNil(reply)
  local hp = lukang.hp
  FkTest.setNextReplies(lukang, { reply })
  inRoom(function()
    room():useCard { from = attacker, tos = { lukang }, card = Fk:cloneCard(incoming) }
  end)
  lu.assertEquals(lukang.hp, hp, "转化牌应实际抵消来牌")
  lu.assertEquals(room():getCardArea(first), Card.DiscardPile)
  lu.assertEquals(room():getCardArea(second), Card.DiscardPile)
  lu.assertEquals(lukang:getPile("$sa_carriage"), {})
  lu.assertEquals(lukang:getCardIds("e"), { ox.id })
end

function Testqiao_quan_wu_qun_jin:testKeshouJinkWithTwoCargo()
  checkKeshouWithCargo("jink", 2, "qiao__slash")
end

function Testqiao_quan_wu_qun_jin:testKeshouNullificationWithHandAndCargo()
  checkKeshouWithCargo("nullification", 1, "qiao__duel")
end

function Testqiao_quan_wu_qun_jin:testWu024WuguotaiBuyiAndGanlu()
  local wuguotai, wuAlly, caojie = p(1), p(2), p(7)
  inRoom(function()
    skill_test.installDualGenerals(room(), wuguotai, { main = "qiao_heg__wu024", deputy = "qiao_test__wu_2", kingdom = "wu" })
    skill_test.installDualGenerals(room(), wuAlly, { main = "qiao_heg__wu009", deputy = "qiao_test__wu_2", kingdom = "wu" })
    skill_test.installDualGenerals(room(), caojie, { main = "qiao_heg__han021", deputy = "qiao_test__han_2", kingdom = "han" })
  end)

  -- 补益：同势力角色脱离濒死（含自伤来源），发起军令不执行 -> 回复1血
  local origAsk = Junling.ask
  local junlingTargetId
  Junling.ask = function(from, to)
    junlingTargetId = to.id
    return false
  end
  inRoom(function()
    room():loseHp(wuAlly, wuAlly.hp - 1, "test") -- 剩 1 血
  end)
  skill_test.withSkillRequests(room(), "qiao__skill_wu024_1", {
    askToSkillInvoke = function() return true end,
  }, function()
    inRoom(function()
      -- 构造已脱离濒死的 AfterDying 事件（hp=1，damage.from = wuAlly 自伤）
      room().logic:trigger(fk.AfterDying, wuAlly, {
        who = wuAlly,
        damage = { from = wuAlly, to = wuAlly, damage = 1 },
      })
    end)
  end)
  Junling.ask = origAsk
  lu.assertEquals(junlingTargetId, wuAlly.id, "补益允许对自伤来源发起军令")
  lu.assertEquals(wuAlly.hp, 2, "补益不执行军令应令濒死角色回复1点体力")

  -- 甘露：装备数差<=已损体力值；与曹节【守玺】及废除栏位联动
  inRoom(function()
    room():loseHp(wuguotai, 1, "test") -- lostHp = 1
    room().current = wuguotai
    wuguotai.phase = Player.Play
  end)
  local eqA1 = equip(caojie, "qiao__crossbow", Card.Spade, 1)
  local eqA2 = equip(caojie, "qiao__chitu", Card.Heart, 5)
  local eqB1 = equip(wuAlly, "qiao__zhuahuangfeidian", Card.Diamond, 13)
  local cjSpade = give(caojie, "qiao__slash", Card.Spade, 9)
  local ganlu = assert(Fk.skills["qiao__skill_wu024_2"])

  -- 客户端校验：|2 - 1| = 1 <= lostHp(1) 合法
  client_room.run(room(), function(clients)
    local me = clients[1]
    lu.assertTrue(ganlu:canUse(me))
    lu.assertTrue(ganlu:targetFilter(me, clients[7], {}))
    lu.assertTrue(ganlu:targetFilter(me, clients[2], { clients[7] }))
  end)

  -- 甘露结算中，曹节弃黑桃发动【守玺】防住黑桃诸葛连弩离开，其余两件正常互换
  skill_test.withSkillRequests(room(), "qiao__skill_han021_1", {
    askToDiscard = function(self, who, params)
      if params.pattern == ".|.|spade" then
        self:throwCard({ cjSpade.id }, params.skill_name, who, who)
        return { cjSpade.id }
      end
      return {}
    end,
  }, function()
    inRoom(function()
      room():useSkill(wuguotai, ganlu, function()
        ganlu:onUse(room(), { from = wuguotai, cards = {}, tos = { caojie, wuAlly } })
      end, { from = wuguotai, cards = {}, tos = { caojie, wuAlly } })
    end)
  end)
  lu.assertTrue(table.contains(caojie:getCardIds("e"), eqA1.id), "被守玺防止的装备应留在曹节装备区")
  lu.assertTrue(table.contains(caojie:getCardIds("e"), eqB1.id), "对方装备应换入曹节装备区")
  lu.assertTrue(table.contains(wuAlly:getCardIds("e"), eqA2.id), "未防住的装备应换入盟友装备区")
end

function Testqiao_quan_wu_qun_jin:testShouxiProtectsEquipmentUsedByAnotherFaction()
  local lukang, caojie, enemy = p(1), p(2), p(7)
  local jueyan, shouxi = "qiao__skill_wu019_1", "qiao__skill_han021_1"
  local sword = equip(lukang, "qiao__qinggang_sword", Card.Spade)
  local payment = give(caojie, "qiao__slash", Card.Spade)
  local defenses = 0
  inRoom(function()
    skill_test.installDualGenerals(room(), lukang, { main = "qiao_heg__wu019", deputy = "qiao_test__wu_2", kingdom = "wu" })
    room():handleAddLoseSkills(caojie, shouxi, nil, false, true)
    room():setCurrent(lukang)
    lukang.phase = Player.Start
  end)
  skill_test.withSkillRequests(room(), shouxi, {
    askToDiscard = function(r, who, params)
      defenses = defenses + 1
      lu.assertEquals(params.pattern, ".|.|spade")
      r:throwCard(payment.id, shouxi, who, who)
      return { payment.id }
    end,
  }, function()
    skill_test.withSkillRequests(room(), jueyan, {
      askToSkillInvoke = function() return true end,
      askToChooseCard = function() return sword.id end,
      askToChoosePlayers = function() return { enemy } end,
      askToOptions = function() return { "#qiao__skill_wu019_1-draw" } end,
    }, function()
      inRoom(function() room().logic:trigger(fk.EventPhaseStart, lukang, {}) end)
    end)
  end)
  lu.assertEquals(defenses, 1)
  lu.assertEquals(room():getCardArea(payment.id), Card.DiscardPile)
  lu.assertEquals(lukang:getEquipments(Card.SubtypeWeapon), { sword.id })
end

return { name = "qiao_quan_wu_qun_jin" }
