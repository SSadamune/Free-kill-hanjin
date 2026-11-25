-- 六势力变包（吴/群/晋 6 将 + 飞熊军翼从多实例）定向回归测试。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local client_room = __dofile("../../../tests/support/client_room.lua")
local A = require "packages.qiao.pkg.qiao_mode.rules.adaptation"
local Visibility = require "packages.qiao.pkg.qiao_mode.rules.card_visibility"
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
local Discard = require "packages.qiao.pkg.qiao_mode.rules.general_discard"
local Change = require "packages.qiao.pkg.qiao_mode.rules.general_change"
local Guest = require "packages.qiao.pkg.qiao_mode.rules.guest_factions"
local Retinues = require "packages.qiao.pkg.qiao_generals.util.retinue_instances"
local Bian = require "packages.qiao.pkg.qiao_generals.util.bian_common"

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

Testqiao_bian_wu_qun_jin = {
  setup = function()
    Fk.currentResponsePattern = nil
    support.initQiaoRoom()
  end,
  tearDown = function()
    Fk.currentResponsePattern = nil
    support.clearRoom()
  end,
}

-- WU021 凌统：旋略（一次失多装备仅触发 1 次）+ 勇进（至多 3 张各不同装备 + 双坐骑空栏校验 + 联动旋略）
function Testqiao_bian_wu_qun_jin:testWu021XuanlueAndYongjinThreeDistinctAndDualMount()
  local room = FkTest.room
  local lingtong, ally, foe = p(1), p(2), p(3)
  local w1, a1, dual, foeHorse, foeHand1, foeHand2
  inRoom(function()
    skill_test.installBlankGenerals(room, { "wu", "wu", "wei", "shu" })
    skill_test.installDualGenerals(room, lingtong, {
      main = "qiao_heg__wu021", deputy = "qiao_test__wu_2", kingdom = "wu", hp = 4,
    })
    for _, who in ipairs(room.players) do who:throwAllCards("he") end
    w1 = room:printCard("qiao__qinggang_sword", Card.Spade, 6)
    a1 = room:printCard("qiao__eight_diagram", Card.Spade, 2)
    dual = room:printCard("qiao__liulongcanjia", Card.Heart, 13)
    foeHorse = room:printCard("qiao__chitu", Card.Heart, 5)
    foeHand1 = room:printCard("qiao__jink", Card.Diamond, 2)
    foeHand2 = room:printCard("qiao__jink", Card.Diamond, 3)
    room:moveCardTo({ w1, a1 }, Player.Equip, lingtong, fk.ReasonJustMove, "test", nil, true, lingtong)
    room:moveCardTo(foeHorse, Player.Equip, foe, fk.ReasonJustMove, "test", nil, true, foe)
    room:obtainCard(foe, { foeHand1, foeHand2 }, false, fk.ReasonJustMove)
  end)

  -- 一次同时弃置凌统 2 张装备，旋略只触发 1 次。
  local xuanlueCount = 0
  skill_test.withSkillRequests(room, "qiao__skill_wu021_1", {
    askToChoosePlayers = function() xuanlueCount = xuanlueCount + 1; return { foe } end,
    askToChooseCard = function() return foeHand1.id end,
  }, function()
    inRoom(function()
      room:throwCard({ w1.id, a1.id }, "test", lingtong, foe)
    end)
  end)
  lu.assertEquals(xuanlueCount, 1, "单次移动同时失去多张装备牌时旋略只触发一次")
  lu.assertEquals(#foe:getCardIds("h"), 1)

  -- 勇进：给凌统装双坐骑 dual 与武器 w1；foe 有进攻坐骑（双坐骑不能移给 foe），ally 空栏可接收。
  inRoom(function()
    room:moveCardTo({ w1, dual }, Player.Equip, lingtong, fk.ReasonJustMove, "test", nil, true, lingtong)
    lingtong.phase = Player.Play
  end)

  -- 校验双坐骑空栏 helper：foe 已有单坐骑不可接收 dual，ally 双空栏可接收。
  lu.assertFalse(Bian.canMoveEquipTo(lingtong, foe, dual.id), "已有单坐骑的角色不能接收双副类别坐骑")
  lu.assertTrue(Bian.canMoveEquipTo(lingtong, ally, dual.id), "双坐骑栏均空时可接收双副类别坐骑")

  local stepFrom, stepCard, stepTo = 0, 0, 0
  xuanlueCount = 0
  skill_test.withSkillRequests(room, "qiao__skill_wu021_1", {
    askToChoosePlayers = function() xuanlueCount = xuanlueCount + 1; return {} end,
  }, function()
    skill_test.withSkillRequests(room, "qiao__skill_wu021_2", {
      askToChoosePlayers = function(self, who, params)
        if params.prompt:find("-from", 1, true) then
          stepFrom = stepFrom + 1
          if stepFrom == 1 then return { lingtong } end
          if stepFrom == 2 then
            -- 第二次移牌时，已移到 ally 的 w1 不能再成为可移动源！
            lu.assertFalse(table.contains(params.targets, ally), "已移动过的同一张装备牌不能再移")
            return { lingtong }
          end
          return {}
        else
          stepTo = stepTo + 1
          if stepTo == 1 then return { ally } end
          if stepTo == 2 then
            lu.assertFalse(table.contains(params.targets, foe), "双坐骑候选接收者应排除已有单坐骑的 foe")
            return { ally }
          end
          return {}
        end
      end,
      askToChooseCards = function(self, who, params)
        stepCard = stepCard + 1
        return { w1.id }
      end,
    }, function()
      inRoom(function()
        Fk.skills["qiao__skill_wu021_2"]:onUse(room, { from = lingtong, tos = {}, cards = {} })
      end)
    end)
  end)
  lu.assertTrue(table.contains(ally:getCardIds("e"), w1.id), "第1张武器应移至 ally")
  lu.assertTrue(table.contains(ally:getCardIds("e"), dual.id), "第2张双坐骑应移至 ally")
  lu.assertEquals(xuanlueCount, 2, "依次移动凌统自己的两件装备应分别即时触发旋略")
end

-- 审阅回归（第 9 项）：凌统勇进排除已明置【聚宝】保护的宝物牌，避免无合法装备仍可发动消耗限定技。
function Testqiao_bian_wu_qun_jin:testWu021YongjinSkipsRevealedJubaoTreasure()
  local room = FkTest.room
  local lingtong, lordSun = p(1), p(2)
  local canServer, canClient
  inRoom(function()
    skill_test.installBlankGenerals(room, { "wu", "wu", "han", "wei" })
    skill_test.installDualGenerals(room, lingtong, {
      main = "qiao_heg__wu021", deputy = "qiao_test__wu_2", kingdom = "wu", hp = 4,
    })
    skill_test.installDualGenerals(room, lordSun, {
      main = "qiao_heg__em_wu001", deputy = "qiao_test__wu_2", kingdom = "wu", hp = 4,
    })
    for _, who in ipairs(room.players) do who:throwAllCards("e") end
    local pearl = room:printCard("qiao__luminous_pearl", Card.Heart, 6)
    room:moveCardTo(pearl, Player.Equip, lordSun, fk.ReasonPut, "test", nil, true, lordSun)
    lingtong.phase = Player.Play
    canServer = Fk.skills["qiao__skill_wu021_2"]:canUse(lingtong)
  end)
  client_room.run(room, function(clients)
    canClient = Fk.skills["qiao__skill_wu021_2"]:canUse(clients[1])
  end)
  lu.assertFalse(canServer, "场上仅有明置聚宝保护的宝物时勇进不可发动（服务端）")
  lu.assertFalse(canClient, "场上仅有明置聚宝保护的宝物时勇进不可发动（客户端）")
end

return { name = "qiao_bian_wu_qun_jin" }
