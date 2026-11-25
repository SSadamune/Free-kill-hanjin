-- 六势力变包（注册核对 + 汉/魏/蜀 6 将）定向回归测试。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local client_room = __dofile("../../../tests/support/client_room.lua")
local Data = require "packages.qiao.pkg.qiao_generals.data.bian"
local Guest = require "packages.qiao.pkg.qiao_mode.rules.guest_factions"
local Commander = require "packages.qiao.pkg.qiao_mode.rules.commander_retinue"
local BattleRoyal = require "packages.qiao.pkg.qiao_mode.rules.battle_royal"
local Discard = require "packages.qiao.pkg.qiao_mode.rules.general_discard"
local Change = require "packages.qiao.pkg.qiao_mode.rules.general_change"
local O = require "packages.qiao.pkg.qiao_mode.rules.only_as"

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function p(i) return FkTest.room.players[i] end

local function resetGeneralPool(room, pile, kingdoms)
  room.disabled_generals = {}
  Discard.reset(room)
  room:setTag(Guest.key, nil)
  room:setBanner("all_kingdoms", kingdoms or { "han", "wei", "shu", "wu", "qun", "jin" })
  room.general_pile = table.simpleClone(pile)
end

Testqiao_bian_han_wei_shu = {
  setup = function()
    Fk.currentResponsePattern = nil
    support.initQiaoRoom()
  end,
  tearDown = function()
    Fk.currentResponsePattern = nil
    support.clearRoom()
  end,
}

function Testqiao_bian_han_wei_shu:testBianRegistrationPrefixesCompanionsGuests()
  lu.assertEquals(Data.generalCount, 1)
  lu.assertEquals(Data.retinueCount, 0)
  lu.assertEquals(Data.commanderCount, 0)
  lu.assertEquals(Data.skillCount, 2)
  for _, entry in ipairs(Data.generals) do
    local g = assert(Fk.generals[entry.id], "缺少变包武将：" .. entry.id)
    lu.assertEquals(g.package.name, "qiao_zhenshi")
    lu.assertEquals(g.prefix, "qiao_prefix_bian")
    lu.assertEquals(Fk:translate(g.prefix), "变")
    lu.assertEquals(g.maxHp, entry.hp)
    for _, sk in ipairs(entry.skills) do
      local skel = assert(Fk.skill_skels[sk.id], "缺少技能骨架：" .. sk.id)
      lu.assertTrue(skel.qiaoImplemented == true)
      lu.assertTrue(#skel.effects > 0)
      lu.assertEquals(Fk:translate(sk.id), sk.name)
      lu.assertEquals(Fk:translate(":" .. sk.id), sk.text)
    end
  end
  -- 珠联与客将核对
end

-- HAN023 伍琼&种辑：除奸（无距离/无次数且不计次 + 阶段末延时伤害不因暗置撤销）
function Testqiao_bian_han_wei_shu:testHan023ChujianBypassSlashAndPhaseEndDamage()
  local room = FkTest.room
  local han, enemy, bystander = p(1), p(4), p(2)
  local s1, s2, s3
  inRoom(function()
    skill_test.installBlankGenerals(room, { "han", "wei", "shu", "wu", "qun", "jin", "wei", "shu" })
    skill_test.installDualGenerals(room, han, {
      main = "qiao_heg__han023", deputy = "qiao_test__han_2", kingdom = "han", hp = 3,
    })
    -- 令 enemy 体力全场最大（4 > 3），且距离 han 超过 1。
    for _, who in ipairs(room.players) do
      who.hp = (who == enemy) and 4 or 3
      who:throwAllCards("he")
    end
    s1 = room:printCard("qiao__slash", Card.Spade, 2)
    s2 = room:printCard("qiao__slash", Card.Club, 3)
    s3 = room:printCard("qiao__slash", Card.Heart, 4)
    room:obtainCard(enemy, { s1, s2, s3 }, false, fk.ReasonJustMove)
    room:setCurrent(enemy)
    enemy.phase = Player.Play
  end)

  skill_test.withSkillRequests(room, "qiao__skill_han023_1", {
    askToSkillInvoke = function() return true end,
  }, function()
    inRoom(function()
      room.logic:trigger(fk.EventPhaseStart, enemy, PhaseData:new { who = enemy, phase = Player.Play })
    end)
  end)

  local canFarFirst, canFarSecond, canHitOtherAfter, usedNormalCount
  inRoom(function()
    lu.assertTrue(enemy:distanceTo(han) > 1, "默认距离应大于 1")
    canFarFirst = enemy:canUseTo(s1, han)
    -- 连续对伍琼&种辑使用两张杀：均无视距离与次数且不计入通常次数。
    room:useCard { from = enemy, tos = { han }, card = s1 }
    usedNormalCount = enemy:usedCardTimes("slash", Player.HistoryPhase)
    canFarSecond = enemy:canUseTo(s2, han)
    room:useCard { from = enemy, tos = { han }, card = s2 }
    -- 仍保留原本的 1 次对其他距离内角色出杀的通常次数（若相距 1）。
    canHitOtherAfter = enemy:usedCardTimes("slash", Player.HistoryPhase) == 0
    -- 中途暗置伍琼&种辑后，已建立的阶段末延时伤害仍应触发。
    han:hideGeneral(false)
  end)
  lu.assertTrue(canFarFirst, "除奸后对伍琼&种辑出杀应无视距离")
  lu.assertEquals(usedNormalCount, 0, "仅对除奸目标出杀不应计入通常出杀次数")
  lu.assertTrue(canFarSecond, "除奸后对伍琼&种辑应可继续出杀")
  lu.assertTrue(canHitOtherAfter)

  local hpBefore = enemy.hp
  inRoom(function()
    room.logic:trigger(fk.EventPhaseEnd, enemy, PhaseData:new { who = enemy, phase = Player.Play })
  end)
  lu.assertEquals(enemy.hp, hpBefore - 1, "出牌阶段结束时即使来源已暗置仍应造成1点伤害")
end

-- HAN023 伍琼&种辑：心疾（个人鏖战与暗置退出 + 濒死失救减上限回血至1 + 上限1死亡）
function Testqiao_bian_han_wei_shu:testHan023XinjiPersonalBattleRoyalAndDyingSelfSave()
  local room = FkTest.room
  local han, other = p(1), p(2)
  local peach1, peach2
  inRoom(function()
    skill_test.installBlankGenerals(room, { "han", "wei", "shu", "wu" })
    skill_test.installDualGenerals(room, han, {
      main = "qiao_heg__han023", deputy = "qiao_test__han_2", kingdom = "han", hp = 3,
    })
    peach1 = room:printCard("qiao__peach", Card.Heart, 6)
    peach2 = room:printCard("qiao__peach", Card.Heart, 7)
    room:obtainCard(han, peach1, false, fk.ReasonJustMove)
    room:obtainCard(other, peach2, false, fk.ReasonJustMove)
  end)

  lu.assertFalse(BattleRoyal.entered(room), "全局不应被拉入鏖战")
  lu.assertTrue(BattleRoyal.inBattleRoyal(room, han), "明置伍琼&种辑本人应处于鏖战状态")
  lu.assertFalse(BattleRoyal.inBattleRoyal(room, other), "其他角色不应进入鏖战")
  lu.assertTrue(O.isForbidden(han, peach1), "伍琼&种辑的实体桃应被禁止直接当桃使用")
  lu.assertFalse(O.isForbidden(other, peach2), "其他角色的实体桃应仍可正常使用")

  -- 暗置后退出个人鏖战
  inRoom(function() han:hideGeneral(false) end)
  lu.assertFalse(BattleRoyal.inBattleRoyal(room, han), "暗置心疾且全局未鏖战时应退出鏖战")
  lu.assertFalse(O.isForbidden(han, peach1))

  -- 重新明置后进入濒死并求桃失败：减 1 体力上限并回复至 1 体力存活。
  inRoom(function()
    han:revealGeneral(false)
    han:throwAllCards("he")
    other:throwAllCards("he")
    han.maxHp = 3
    han.hp = 1
    room:loseHp(han, 1, "test")
  end)
  lu.assertFalse(han.dead, "体力上限大于 1 时失救应减上限并回血至 1 存活")
  lu.assertEquals(han.maxHp, 2)
  lu.assertEquals(han.hp, 1)

  -- 体力上限为 1 时失救：减上限至 0 直接死亡，不能回复至 1。
  inRoom(function()
    han.maxHp = 1
    han.hp = 1
    room:loseHp(han, 1, "test")
  end)
  lu.assertTrue(han.dead, "体力上限为 1 时减上限至 0 应直接死亡")
end

-- 审阅回归（第 6 项）：心疾暂时无效时桃恢复可用，恢复有效后个人鏖战立即恢复，全局鏖战仍覆盖。
function Testqiao_bian_han_wei_shu:testHan023XinjiInvalidationRestoreAndGlobalBattleRoyal()
  local room = FkTest.room
  local han = p(1)
  local peach
  inRoom(function()
    skill_test.installBlankGenerals(room, { "han", "wei", "wu", "shu" })
    skill_test.installDualGenerals(room, han, {
      main = "qiao_heg__han023", deputy = "qiao_test__han_2", kingdom = "han", hp = 3,
    })
    peach = room:printCard("qiao__peach", Card.Heart, 6)
    room:obtainCard(han, peach, false, fk.ReasonJustMove)
  end)
  lu.assertTrue(O.isForbidden(han, peach))
  lu.assertTrue(BattleRoyal.inBattleRoyal(room, han))

  inRoom(function() room:invalidateSkill(han, "qiao__skill_han023_2", "", "test") end)
  lu.assertFalse(O.isForbidden(han, peach), "心疾暂时无效时桃应恢复按通常方式使用")
  lu.assertFalse(BattleRoyal.inBattleRoyal(room, han))
  client_room.run(room, function(clients)
    lu.assertFalse(O.isForbidden(clients[1], peach), "客户端同步视图下桃也应恢复可用")
  end)

  inRoom(function() room:validateSkill(han, "qiao__skill_han023_2", "", "test") end)
  lu.assertTrue(O.isForbidden(han, peach), "心疾恢复有效后个人鏖战应立即恢复")
  lu.assertTrue(BattleRoyal.inBattleRoyal(room, han))

  inRoom(function()
    BattleRoyal.enter(room)
    room:invalidateSkill(han, "qiao__skill_han023_2", "", "test")
  end)
  lu.assertTrue(O.isForbidden(han, peach), "全局已进入鏖战时即使心疾失效仍受全局鏖战约束")
end

return { name = "qiao_bian_han_wei_shu" }
