-- 群势力标准包第一批（本批 A）：除疠、离间、闭月、猛撼、雷击、雄异、死谏、随势。
-- 本文件已加入 tests/all.lua，纳入默认国战套件。
-- 规则依据：rules/standard-generals.md 群区、rules/generals/qun016-tianfeng.md、
-- docs/development/implementation/generals/qun-standard.md。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")

local CHULI = "hanjin__skill_qun001_2"
local LIJIAN = "hanjin__skill_qun003_1"
local BIYUE = "hanjin__skill_qun003_2"
local MENGHAN = "hanjin__skill_qun008_2"
local LEIJI = "hanjin__skill_qun010_1"
local XIONGYI = "hanjin__skill_qun013_2"
local SIJIAN = "hanjin__skill_qun016_1"
local SUISHI = "hanjin__skill_qun016_2"
local QINGCHENG = "hanjin__skill_qun018_2"

local DEFAULT_KINGDOMS = { "qun", "qun", "wei", "wei", "shu", "shu", "wu", "wu" }

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

--- 临时替换房间请求方法；恢复写在 pcall 之后，异常时先恢复再抛出。
local function withStubs(skillName, overrides, fn)
  local originals = {}
  for name, fnOverride in pairs(overrides) do
    originals[name] = room()[name]
    room()[name] = function(self, player, params, ...)
      return fnOverride(player, params, originals[name], ...)
    end
  end
  local ok, err = pcall(fn)
  for name, original in pairs(originals) do
    room()[name] = original
  end
  if not ok then error(err, 0) end
end

local function triggerPhaseStart(player, phase)
  inRoom(function()
    player.phase = phase
    room().logic:trigger(fk.EventPhaseStart, player, PhaseData:new {
      who = player, reason = "game_rule", phase = phase,
    })
  end)
end

--- 出牌阶段的直接设置：主动技的 on_use 会复核 player.phase。
local function setPlayPhase(player)
  inRoom(function()
    room().current = player
    player.phase = Player.Play
  end)
end

--- 真实主动技入口：与客户端按钮回包一致，走 handleUseCardReply。
local function runActiveSkill(player, skillName, targetIds, subcards)
  inRoom(function()
    room():handleUseCardReply(player, {
      card = { skill = skillName, subcards = subcards or {} },
      targets = targetIds or {},
    }, nil)
  end)
end

local function useCard(from, card, targets)
  inRoom(function()
    room():useCard(UseCardData:new {
      from = from, tos = targets or {}, card = card, extra_data = {},
    })
  end)
end

--- 在牌堆顶放一张已知牌，作为下一次判定的判定牌。
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

--- 观察正式【决斗】的使用者、目标与原生不可抵消列表。
--- global 效果会对每名角色各触发一次，同一事件会回调多次；按 event.id 去重，
--- 只在首次回调记录一条，避免一次用牌被 8 名角色重复采集。
local function installDuelProbe(name)
  local seen = {}
  local last_event
  local skel = fk.CreateSkill { name = name }
  skel:addEffect(fk.CardUsing, {
    global = true,
    can_trigger = function(self, event, target, player, data)
      return data.card ~= nil and data.card.name == "hanjin__duel"
    end,
    on_cost = Util.TrueFunc,
    on_use = function(self, event, target, player, data)
      if last_event == event.id then return end
      last_event = event.id
      table.insert(seen, {
        name = data.card.name,
        from = data.from and data.from.id,
        tos = table.map(data.tos or {}, function(v) return v.id end),
        unoffsetable = table.map(data.unoffsetableList or {}, function(v) return v.id end),
      })
    end,
  })
  local skill = skel:createSkill()
  Fk.skills[name] = skill
  inRoom(function() room():addSkill(skill) end)
  return seen
end

Testhanjin_qun_basic = { tearDown = support.clearRoom }

Testhanjin_qun_basic.setup = function()
  local r = support.initHanjinRoom()
  inRoom(function() skill_test.installBlankGenerals(r, DEFAULT_KINGDOMS) end)
end

-- 除疠：两名候选势力互不相同；只有真正失去黑桃牌的角色摸一张。
function Testhanjin_qun_basic:testChuliTwoCandidatesSpadeDraws()
  local p1, p3, p5 = p(1), p(3), p(5) -- 1 qun, 3 wei, 5 shu
  clearCards(p1)
  clearCards(p3)
  clearCards(p5)
  grant(p1, CHULI)
  local mine = give(p1, "hanjin__jink", Card.Heart, 2)
  local spade = give(p3, "hanjin__jink", Card.Spade, 3)
  local heart = give(p5, "hanjin__jink", Card.Heart, 4)
  setPlayPhase(p1)

  local picks = {}
  picks[p1.id] = { mine }
  picks[p3.id] = { spade }
  picks[p5.id] = { heart }
  withStubs(CHULI, {
    askToChooseCard = function(_, params) return picks[params.target.id] end,
  }, function()
    runActiveSkill(p1, CHULI, { p3.id, p5.id })
  end)

  lu.assertEquals(p1:getHandcardNum(), 0) -- 自己弃置后不摸
  lu.assertEquals(p5:getHandcardNum(), 0) -- 红桃不摸
  lu.assertEquals(p3:getHandcardNum(), 1) -- 黑桃摸一张
  lu.assertEquals(room():getCardArea(spade), Card.DiscardPile)
  lu.assertEquals(room():getCardArea(heart), Card.DiscardPile)
end

-- 离间：使用正式 hanjin__duel，由后选男性使用、先选者为目标；
-- 原生 unoffsetable 覆盖该决斗，决斗内仍可打【杀】。
function Testhanjin_qun_basic:testLijianFormalDuelUsedBySelectedMale()
  local p1, p2, p3 = p(1), p(2), p(3)
  clearCards(p1)
  clearCards(p2)
  clearCards(p3)
  inRoom(function()
    p2.gender = General.Male
    p3.gender = General.Male
    p2.hp, p3.hp = p2.maxHp, p3.maxHp
  end)
  grant(p1, LIJIAN)
  local pay = give(p1, "hanjin__jink", Card.Heart, 2)
  setPlayPhase(p1)
  local seen = installDuelProbe("#qun_lijian_probe")
  FkTest.setNextReplies(p2, { "" })
  FkTest.setNextReplies(p3, { "" })

  runActiveSkill(p1, LIJIAN, { p2.id, p3.id }, { pay })

  lu.assertEquals(room():getCardArea(pay), Card.DiscardPile)
  lu.assertEquals(#seen, 1)
  lu.assertEquals(seen[1].name, "hanjin__duel") -- 正式牌，不是上游决斗
  lu.assertEquals(seen[1].from, p3.id)          -- 由后选男性使用
  lu.assertEquals(seen[1].tos[1], p2.id)
  lu.assertTrue(table.contains(seen[1].unoffsetable, p2.id)) -- 原生不可抵消
  lu.assertEquals(p2.hp, p2.maxHp - 1) -- 决斗内未出【杀】仍受伤
  lu.assertEquals(p3.hp, p3.maxHp)
end

-- 猛撼：弃置基本牌后目标获得此【杀】，已声明用牌继续结算。
function Testhanjin_qun_basic:testMenghanBasicObtainsSlashAndUseContinues()
  local p1, p2 = p(1), p(2)
  clearCards(p1)
  clearCards(p2)
  grant(p1, MENGHAN)
  local slash = give(p1, "hanjin__slash", Card.Spade, 7)
  local basic = give(p2, "hanjin__jink", Card.Heart, 5)
  inRoom(function() p2.hp = p2.maxHp end)
  FkTest.setNextReplies(p2, { "" })

  local invoked = 0
  withStubs(MENGHAN, {
    askToSkillInvoke = function() invoked = invoked + 1; return true end,
    askToChooseCard = function() return { basic } end,
  }, function()
    useCard(p1, Fk:getCardById(slash), { p2 })
  end)

  lu.assertEquals(invoked, 1)
  lu.assertEquals(p2.hp, p2.maxHp - 1)                    -- 用牌未被终止
  lu.assertTrue(table.contains(p2:getCardIds("h"), slash)) -- 其获得此【杀】
  lu.assertEquals(room():getCardArea(basic), Card.DiscardPile)
end

-- 雷击：一次「使用闪」与一次「打出闪」各只询问一次，黑桃造成 2 点雷电伤害。
function Testhanjin_qun_basic:testLeijiOneAskPerJinkAndSpadeDamage()
  local p1, p2, p3 = p(1), p(2), p(3)
  clearCards(p1)
  clearCards(p2)
  clearCards(p3)
  grant(p1, LEIJI)
  inRoom(function()
    p2.hp, p3.hp = p2.maxHp, p3.maxHp
  end)
  local jink1 = Fk:getCardById(give(p1, "hanjin__jink", Card.Heart, 2))
  local jink2 = Fk:getCardById(give(p1, "hanjin__jink", Card.Diamond, 3))
  seedJudgeCard("hanjin__jink", Card.Spade, 9)
  seedJudgeCard("hanjin__jink", Card.Spade, 8)

  local asks = 0
  withStubs(LEIJI, {
    askToChoosePlayers = function()
      asks = asks + 1
      return asks == 1 and { p2 } or { p3 }
    end,
  }, function()
    -- 使用【闪】
    inRoom(function()
      room().logic:trigger(fk.CardUsing, p1, UseCardData:new {
        from = p1, tos = {}, card = jink1,
      })
    end)
    lu.assertEquals(asks, 1)
    lu.assertEquals(p2.hp, p2.maxHp - 2)
    -- 打出【闪】：另一个入口，仍只询问一次
    inRoom(function()
      room().logic:trigger(fk.CardResponding, p1, RespondCardData:new {
        from = p1, card = jink2,
      })
    end)
    lu.assertEquals(asks, 2)
    lu.assertEquals(p3.hp, p3.maxHp - 2)
  end)
end

-- 雄异：同势力（含自己）各摸三张；并列最少时回复 1 点体力。
function Testhanjin_qun_basic:testXiongyiSameKingdomDrawsAndTieMinimumRecovers()
  local p1, p2 = p(1), p(2) -- 均为 qun，qun 人数与其余势力并列最少
  clearCards(p1)
  clearCards(p2)
  grant(p1, XIONGYI)
  setPlayPhase(p1)
  inRoom(function() p1.hp = p1.maxHp - 1 end)

  runActiveSkill(p1, XIONGYI, {})

  lu.assertEquals(p1:getHandcardNum(), 3)
  lu.assertEquals(p2:getHandcardNum(), 3)
  lu.assertEquals(p1.hp, p1.maxHp)              -- 并列最少 → 回复
  lu.assertFalse(Fk.skills[XIONGYI]:canUse(p1)) -- 限定技已用
end

-- 性别元数据：真实双将以女性为主将时，离间/倾城的目标过滤拒女性、接受男性。
-- 这里直接读两个技能的 target_filter，而不是镜像性别表。
function Testhanjin_qun_basic:testMaleOnlyFiltersUseRegisteredGeneralGender()
  local p1, p2, p3 = p(1), p(2), p(3)
  inRoom(function()
    skill_test.installDualGenerals(room(), p1, {
      main = "hanjin__qun003", deputy = "hanjin_test__wei_1", kingdom = "qun",
    })
    skill_test.installDualGenerals(room(), p2, {
      main = "hanjin__qun012", deputy = "hanjin_test__wei_2", kingdom = "qun",
    })
    skill_test.installDualGenerals(room(), p3, {
      main = "hanjin__qun002", deputy = "hanjin_test__wei_1", kingdom = "qun",
    })
  end)
  clearCards(p1)
  clearCards(p2)
  clearCards(p3)
  lu.assertTrue(p1:isFemale(), "貂蝉应是女性")
  lu.assertTrue(p2:isFemale(), "蔡文姬应是女性")
  lu.assertTrue(p3:isMale(), "吕布应是男性")

  local lijian = Fk.skills[LIJIAN]
  lu.assertFalse(lijian:targetFilter(p1, p2, {}, {}))
  lu.assertTrue(lijian:targetFilter(p1, p3, {}, {}))

  local qingcheng = Fk.skills[QINGCHENG]
  lu.assertNotNil(qingcheng, "倾城应已实装")
  lu.assertFalse(qingcheng:targetFilter(p1, p2, {}, {}))
  lu.assertTrue(qingcheng:targetFilter(p1, p3, {}, {}))
end

-- 闭月：结束阶段入口按摸牌前是否空手决定张数。
function Testhanjin_qun_basic:testBiyueEmptyHandDrawsTwo()
  local p1 = p(1)
  grant(p1, BIYUE)
  clearCards(p1)
  FkTest.setNextReplies(p1, { "1" })
  triggerPhaseStart(p1, Player.Finish)
  lu.assertEquals(p1:getHandcardNum(), 2)
end

function Testhanjin_qun_basic:testBiyueWithHandDrawsOne()
  local p1 = p(1)
  grant(p1, BIYUE)
  clearCards(p1)
  give(p1, "hanjin__slash", Card.Spade, 3)
  FkTest.setNextReplies(p1, { "1" })
  triggerPhaseStart(p1, Player.Finish)
  lu.assertEquals(p1:getHandcardNum(), 2) -- 原有 1 张 + 摸 1 张
end

-- 死谏：失去最后的手牌后，弃置一名其他角色的一张牌；只含手牌和装备。
function Testhanjin_qun_basic:testSijianLastHandcardDiscardsOtherCard()
  local p1, p2 = p(1), p(2)
  -- 先清空再授予死谏：清空手牌本身就是“失去最后的手牌”，会在授予后误触发。
  clearCards(p1)
  clearCards(p2)
  grant(p1, SIJIAN)
  local mine = give(p1, "hanjin__slash", Card.Spade, 3)
  local victim = give(p2, "hanjin__jink", Card.Heart, 4)
  give(p2, "hanjin__peach", Card.Heart, 5)

  local invoked = 0
  withStubs(SIJIAN, {
    askToSkillInvoke = function() invoked = invoked + 1; return true end,
    askToChoosePlayers = function() return { p2 } end,
    askToChooseCard = function() return { victim } end,
  }, function()
    inRoom(function() room():throwCard({ mine }, "test", p1, p1) end)
  end)

  lu.assertEquals(invoked, 1)
  lu.assertTrue(p1:isKongcheng())
  lu.assertEquals(room():getCardArea(victim), Card.DiscardPile)
end

-- 死谏：手里还有牌时失去一张手牌不触发，避免“空手任意移动”重复发动。
function Testhanjin_qun_basic:testSijianNotTriggeredWhileStillHoldingHandcards()
  local p1, p2 = p(1), p(2)
  clearCards(p1)
  clearCards(p2)
  grant(p1, SIJIAN)
  local one = give(p1, "hanjin__slash", Card.Spade, 3)
  give(p1, "hanjin__jink", Card.Heart, 4)
  give(p2, "hanjin__peach", Card.Heart, 5)

  local invoked = 0
  withStubs(SIJIAN, {
    askToSkillInvoke = function() invoked = invoked + 1; return true end,
  }, function()
    inRoom(function() room():throwCard({ one }, "test", p1, p1) end)
  end)

  lu.assertEquals(invoked, 0)
  lu.assertEquals(p1:getHandcardNum(), 1)
end

-- 随势：其他角色进入濒死时，来源与自己势力相同则摸一张牌。
function Testhanjin_qun_basic:testSuishiEnterDyingDrawsForSameKingdomKiller()
  local p1, p2 = p(1), p(2) -- 同为 qun
  grant(p1, SUISHI)
  clearCards(p1)
  clearCards(p2)
  local before = p1:getHandcardNum()
  inRoom(function()
    room():enterDying { who = p2, killer = p1, ignoreDeath = true }
  end)
  lu.assertEquals(p1:getHandcardNum(), before + 1)
end

-- 随势：同势力其他角色死亡时，本人在失去体力和弃置所有手牌中选择。
function Testhanjin_qun_basic:testSuishiDeathChoiceDiscardsAllHandcards()
  local p1, p2 = p(1), p(2) -- 同为 qun
  grant(p1, SUISHI)
  clearCards(p1)
  clearCards(p2)
  give(p1, "hanjin__slash", Card.Spade, 3)
  give(p1, "hanjin__jink", Card.Heart, 4)
  local hp = p1.hp

  skill_test.withSkillRequests(room(), SUISHI, {
    askToChoice = function()
      return "#hanjin__skill_qun016_2-discard"
    end,
  }, function()
    inRoom(function()
      room():killPlayer { who = p2, killer = p(3), extra_data = { ignorePunishment = true } }
    end)
  end)

  lu.assertTrue(p1:isKongcheng())
  lu.assertEquals(p1.hp, hp)
end

return { name = "hanjin_qun_basic" }
