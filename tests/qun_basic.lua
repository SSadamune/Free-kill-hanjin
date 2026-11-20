-- 群势力标准包第一批（本批 A）：除疠、离间、闭月、猛撼、雷击、雄异、死谏、随势。
-- 本文件已加入 tests/all.lua，纳入默认国战套件。
-- 规则依据：docs/rules/standard-generals.md 群区、docs/rules/generals/qun016-tianfeng.md、
-- docs/development/implementation/generals/qun-standard.md。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local ReqPlayCard = require "ltk.core.request_type.play_card"

local CHULI = "qiao__skill_qun001_2"
local LIJIAN = "qiao__skill_qun003_1"
local BIYUE = "qiao__skill_qun003_2"
local MENGHAN = "qiao__skill_qun008_2"
local LEIJI = "qiao__skill_qun010_1"
local XIONGYI = "qiao__skill_qun013_2"
local SIJIAN = "qiao__skill_qun016_1"
local SUISHI = "qiao__skill_qun016_2"
local QINGCHENG = "qiao__skill_qun018_2"

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
      return data.card ~= nil and data.card.name == "qiao__duel"
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

Testqiao_qun_basic = { tearDown = support.clearRoom }

Testqiao_qun_basic.setup = function()
  local r = support.initQiaoRoom()
  inRoom(function() skill_test.installBlankGenerals(r, DEFAULT_KINGDOMS) end)
end

-- 除疠：两名候选势力互不相同；只有真正失去黑桃牌的角色摸一张。
function Testqiao_qun_basic:testChuliTwoCandidatesSpadeDraws()
  local p1, p3, p5 = p(1), p(3), p(5) -- 1 qun, 3 wei, 5 shu
  clearCards(p1)
  clearCards(p3)
  clearCards(p5)
  grant(p1, CHULI)
  local mine = give(p1, "qiao__jink", Card.Heart, 2)
  local spade = give(p3, "qiao__jink", Card.Spade, 3)
  local heart = give(p5, "qiao__jink", Card.Heart, 4)
  setPlayPhase(p1)

  local picks = {}
  picks[p3.id] = { spade }
  picks[p5.id] = { heart }
  withStubs(CHULI, {
    askToChooseCard = function(_, params) return picks[params.target.id] end,
  }, function()
    runActiveSkill(p1, CHULI, { p3.id, p5.id }, { mine })
  end)

  lu.assertEquals(p1:getHandcardNum(), 0) -- 自己弃置后不摸
  lu.assertEquals(p5:getHandcardNum(), 0) -- 红桃不摸
  lu.assertEquals(p3:getHandcardNum(), 1) -- 黑桃摸一张
  lu.assertEquals(room():getCardArea(spade), Card.DiscardPile)
  lu.assertEquals(room():getCardArea(heart), Card.DiscardPile)
end

-- 离间：使用正式 qiao__duel，由后选男性使用、先选者为目标；
-- 原生 unoffsetable 覆盖该决斗，决斗内仍可打【杀】。
function Testqiao_qun_basic:testLijianFormalDuelUsedBySelectedMale()
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
  local pay = give(p1, "qiao__jink", Card.Heart, 2)
  setPlayPhase(p1)
  local seen = installDuelProbe("#qun_lijian_probe")
  FkTest.setNextReplies(p2, { "" })
  FkTest.setNextReplies(p3, { "" })

  runActiveSkill(p1, LIJIAN, { p2.id, p3.id }, { pay })

  lu.assertEquals(room():getCardArea(pay), Card.DiscardPile)
  lu.assertEquals(#seen, 1)
  lu.assertEquals(seen[1].name, "qiao__duel") -- 正式牌，不是上游决斗
  lu.assertEquals(seen[1].from, p3.id)          -- 由后选男性使用
  lu.assertEquals(seen[1].tos[1], p2.id)
  lu.assertTrue(table.contains(seen[1].unoffsetable, p2.id)) -- 原生不可抵消
  lu.assertEquals(p2.hp, p2.maxHp - 1) -- 决斗内未出【杀】仍受伤
  lu.assertEquals(p3.hp, p3.maxHp)
end

-- 猛撼：弃置基本牌后目标获得此【杀】，已声明用牌继续结算。
function Testqiao_qun_basic:testMenghanBasicObtainsSlashAndUseContinues()
  local p1, p2 = p(1), p(2)
  clearCards(p1)
  clearCards(p2)
  grant(p1, MENGHAN)
  local slash = give(p1, "qiao__slash", Card.Spade, 7)
  local basic = give(p2, "qiao__jink", Card.Heart, 5)
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
function Testqiao_qun_basic:testLeijiOneAskPerJinkAndSpadeDamage()
  local p1, p2, p3 = p(1), p(2), p(3)
  clearCards(p1)
  clearCards(p2)
  clearCards(p3)
  grant(p1, LEIJI)
  inRoom(function()
    p2.hp, p3.hp = p2.maxHp, p3.maxHp
  end)
  local jink1 = Fk:getCardById(give(p1, "qiao__jink", Card.Heart, 2))
  local jink2 = Fk:getCardById(give(p1, "qiao__jink", Card.Diamond, 3))
  seedJudgeCard("qiao__jink", Card.Spade, 9)
  seedJudgeCard("qiao__jink", Card.Spade, 8)

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
function Testqiao_qun_basic:testXiongyiSameKingdomDrawsAndTieMinimumRecovers()
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
function Testqiao_qun_basic:testMaleOnlyFiltersUseRegisteredGeneralGender()
  local p1, p2, p3 = p(1), p(2), p(3)
  inRoom(function()
    skill_test.installDualGenerals(room(), p1, {
      main = "qiao_heg__qun003", deputy = "qiao_test__wei_1", kingdom = "qun",
    })
    skill_test.installDualGenerals(room(), p2, {
      main = "qiao_heg__qun012", deputy = "qiao_test__wei_2", kingdom = "qun",
    })
    skill_test.installDualGenerals(room(), p3, {
      main = "qiao_heg__qun002", deputy = "qiao_test__wei_1", kingdom = "qun",
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
  inRoom(function()
    lu.assertFalse(qingcheng:targetFilter(p1, p2, {}, {}))
    lu.assertTrue(qingcheng:targetFilter(p1, p3, {}, {}))
  end)
end

-- 真实 ClientPlayer 夹具：参考 tests/commander_retinue.lua 的
-- testRealClientPlayerWithoutServerRoomCanUseCommanderSlash。不伪造 player.room：
-- 构建 clientRoom 并临时替换 Fk.currentRoom，恢复在 pcall 之后执行。
-- 每个 ClientPlayer 使用独立的牌区副本，场景内清空候选不会改到服务端状态。
local function withClientRoom(current, fn)
  local ClientPlayer = require "ltk.client.clientplayer"
  local clients = {}
  for _, original in ipairs(current.players) do
    local copy = ClientPlayer:new(original._splayer)
    for key, value in pairs(original) do
      if key ~= "room" and key ~= "class" and key ~= "serverplayer" then copy[key] = value end
    end
    local cards = {}
    for area, ids in pairs(copy.player_cards or {}) do cards[area] = table.simpleClone(ids) end
    copy.player_cards = cards
    table.insert(clients, copy)
  end
  for index, player in ipairs(clients) do
    player.next = clients[index % #clients + 1]
  end
  local clientRoom = setmetatable(
    { players = clients, alive_players = clients, current = clients[1] },
    { __index = current })
  local originalRoom = Fk.currentRoom
  Fk.currentRoom = function() return clientRoom end
  local ok, err = pcall(function() fn(clients, clientRoom) end)
  Fk.currentRoom = originalRoom
  if not ok then error(err) end
  return clients, clientRoom
end

local function clientPlayHandler(client, skillName)
  local handler = ReqPlayCard:new(client)
  handler.skill_name = skillName
  handler:setup()
  return handler
end

-- 除疠客户端可用性：真实 ClientPlayer 没有 room 字段，出牌阶段走
-- ReqPlayCard.setup → skillButtonValidity → ActiveSkill:canUse。
function Testqiao_qun_basic:testChuliClientAvailabilityWithoutPlayerRoom()
  local p1, p2 = p(1), p(2)
  clearCards(p1)
  clearCards(p2)
  grant(p1, CHULI)
  local mine = give(p1, "qiao__jink", Card.Heart, 2)
  give(p2, "qiao__jink", Card.Spade, 3)
  inRoom(function() p1.phase = Player.Play end)

  withClientRoom(room(), function(clients)
    local me = clients[1]
    lu.assertNil(me.room, "真实 ClientPlayer 不应有 room 字段")
    lu.assertEquals(me.class.name, "ClientPlayer")
    local handler = clientPlayHandler(me, CHULI)
    lu.assertTrue(handler:skillButtonValidity(CHULI), "有合法候选时除疠应可用")

    -- 本人无牌 → 禁用
    me.player_cards[Player.Hand] = {}
    lu.assertFalse(handler:skillButtonValidity(CHULI), "本人无牌应禁用")
    me.player_cards[Player.Hand] = { mine }

    -- 全体候选都清空 → 无合格候选，禁用
    for index = 2, #clients do
      clients[index].player_cards[Player.Hand] = {}
      clients[index].player_cards[Player.Equip] = {}
    end
    lu.assertFalse(handler:skillButtonValidity(CHULI), "无合格候选应禁用")
    handler:_finish()
  end)

  -- 已用次数：客户端自身的历史记录显示本阶段已发动 → 禁用。
  withClientRoom(room(), function(clients)
    local me = clients[1]
    me.skillUsedHistory = table.simpleClone(me.skillUsedHistory or {})
    me.skillUsedHistory[CHULI] = { [Player.HistoryPhase] = 1 }
    local handler = clientPlayHandler(me, CHULI)
    lu.assertFalse(handler:skillButtonValidity(CHULI), "本阶段已发动应禁用")
    handler:_finish()
  end)
end

-- 五个同类主动入口的真实客户端按钮校验：乱武、狂斧、祸水、倾城、骁逆。
-- 每个技能在当前场景至少一个合法用例；倾城另外触达目标筛选（男收女拒）。
function Testqiao_qun_basic:testQunActiveSkillButtonsOnRealClientPlayer()
  local p1, p2, p3, p4 = p(1), p(2), p(3), p(4)
  for _, player in ipairs({ p1, p2, p3, p4 }) do clearCards(player) end
  -- p4 换成女性主将（蔡文姬），用于倾城目标筛选的拒绝分支；势力保持 wei，
  -- 以便骁逆仍有「其他势力」候选。
  inRoom(function()
    skill_test.installDualGenerals(room(), p4, {
      main = "qiao_heg__qun012", deputy = "qiao_test__wei_2", kingdom = "wei",
    })
  end)
  clearCards(p4)
  give(p1, "qiao__jink", Card.Spade, 2)   -- 祸水支付用的黑牌
  give(p1, "qiao__peach", Card.Heart, 3)  -- 倾城的手牌数比较
  give(p2, "qiao__jink", Card.Heart, 4)
  give(p4, "qiao__jink", Card.Heart, 5)
  local equipId = give(p2, "jueying", Card.Spade, 5) -- 狂斧需要场上装备
  inRoom(function() room():moveCardIntoEquip(p2, equipId, "test", true, p2) end)
  inRoom(function() p1.phase = Player.Play end)

  local cases = {
    { name = "qiao__skill_qun007_2", label = "乱武" },
    { name = "qiao__skill_qun017_1", label = "狂斧" },
    { name = "qiao__skill_qun018_1", label = "祸水" },
    { name = "qiao__skill_qun018_2", label = "倾城" },
    { name = "qiao__skill_qun027_2", label = "骁逆" },
  }

  withClientRoom(room(), function(clients)
    local me = clients[1]
    lu.assertNil(me.room, "真实 ClientPlayer 不应有 room 字段")
    lu.assertEquals(me.class.name, "ClientPlayer")
    for _, case in ipairs(cases) do
      local handler = clientPlayHandler(me, case.name)
      lu.assertTrue(handler:skillButtonValidity(case.name), case.label .. " 在合法场景应可用")
      handler:_finish()
    end

    -- 倾城目标筛选：男性 p2 接受，女性 p4 拒绝。
    local qingcheng = Fk.skills[QINGCHENG]
    lu.assertNotNil(qingcheng, "倾城应已实装")
    lu.assertTrue(qingcheng:targetFilter(me, clients[2], {}, {}), "男性目标应接受")
    lu.assertFalse(qingcheng:targetFilter(me, clients[4], {}, {}), "女性目标应拒绝")
    lu.assertTrue(p4:isFemale(), "p4 主将蔡文姬应为女性")
  end)
end

--- 房间级禁止技能：所有【杀】的目标都被禁止。客户端按钮必须因此禁用，
--- 不能靠「存在存活角色」这类近似判断误开。
local function installProhibitSlashTargets()
  local name = "#qun_prohibit_slash_targets"
  if Fk.skills[name] == nil then
    local skel = fk.CreateSkill { name = name }
    skel:addEffect("prohibit", {
      is_prohibited = function(self, from, to, card)
        return card ~= nil and card.trueName == "slash"
      end,
    })
    local skill = skel:createSkill()
    Fk.skills[name] = skill
    inRoom(function() room():addSkill(skill) end)
  end
end

function Testqiao_qun_basic:testProhibitedSlashTargetsDisableClientButtons()
  local p1, p2 = p(1), p(2)
  clearCards(p1)
  clearCards(p2)
  give(p1, "qiao__jink", Card.Spade, 2)
  give(p2, "qiao__jink", Card.Heart, 4)
  local equipId = give(p2, "jueying", Card.Spade, 5)
  inRoom(function() room():moveCardIntoEquip(p2, equipId, "test", true, p2) end)
  inRoom(function() p1.phase = Player.Play end)
  installProhibitSlashTargets()

  withClientRoom(room(), function(clients)
    local me = clients[1]
    for _, name in ipairs({ "qiao__skill_qun017_1", "qiao__skill_qun027_2" }) do
      local handler = clientPlayHandler(me, name)
      lu.assertFalse(handler:skillButtonValidity(name),
        name .. "：全体目标被禁止时客户端应禁用")
      handler:_finish()
    end
  end)
end

-- 闭月：结束阶段入口按摸牌前是否空手决定张数。
function Testqiao_qun_basic:testBiyueEmptyHandDrawsTwo()
  local p1 = p(1)
  grant(p1, BIYUE)
  clearCards(p1)
  FkTest.setNextReplies(p1, { "1" })
  triggerPhaseStart(p1, Player.Finish)
  lu.assertEquals(p1:getHandcardNum(), 2)
end

function Testqiao_qun_basic:testBiyueWithHandDrawsOne()
  local p1 = p(1)
  grant(p1, BIYUE)
  clearCards(p1)
  give(p1, "qiao__slash", Card.Spade, 3)
  FkTest.setNextReplies(p1, { "1" })
  triggerPhaseStart(p1, Player.Finish)
  lu.assertEquals(p1:getHandcardNum(), 2) -- 原有 1 张 + 摸 1 张
end

-- 死谏：失去最后的手牌后，弃置一名其他角色的一张牌；只含手牌和装备。
function Testqiao_qun_basic:testSijianLastHandcardDiscardsOtherCard()
  local p1, p2 = p(1), p(2)
  -- 先清空再授予死谏：清空手牌本身就是“失去最后的手牌”，会在授予后误触发。
  clearCards(p1)
  clearCards(p2)
  grant(p1, SIJIAN)
  local mine = give(p1, "qiao__slash", Card.Spade, 3)
  local victim = give(p2, "qiao__jink", Card.Heart, 4)
  give(p2, "qiao__peach", Card.Heart, 5)

  local invoked = 0
  withStubs(SIJIAN, {
    askToSkillInvoke = function() invoked = invoked + 1; return true end,
    askToChoosePlayers = function() invoked = invoked + 1; return { p2 } end,
    askToChooseCard = function() return { victim } end,
  }, function()
    inRoom(function() room():throwCard({ mine }, "test", p1, p1) end)
  end)

  lu.assertEquals(invoked, 1)
  lu.assertTrue(p1:isKongcheng())
  lu.assertEquals(room():getCardArea(victim), Card.DiscardPile)
end

-- 死谏：手里还有牌时失去一张手牌不触发，避免“空手任意移动”重复发动。
function Testqiao_qun_basic:testSijianNotTriggeredWhileStillHoldingHandcards()
  local p1, p2 = p(1), p(2)
  clearCards(p1)
  clearCards(p2)
  grant(p1, SIJIAN)
  local one = give(p1, "qiao__slash", Card.Spade, 3)
  give(p1, "qiao__jink", Card.Heart, 4)
  give(p2, "qiao__peach", Card.Heart, 5)

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
function Testqiao_qun_basic:testSuishiEnterDyingDrawsForSameKingdomKiller()
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
function Testqiao_qun_basic:testSuishiDeathChoiceDiscardsAllHandcards()
  local p1, p2 = p(1), p(2) -- 同为 qun
  grant(p1, SUISHI)
  clearCards(p1)
  clearCards(p2)
  give(p1, "qiao__slash", Card.Spade, 3)
  give(p1, "qiao__jink", Card.Heart, 4)
  local hp = p1.hp

  skill_test.withSkillRequests(room(), SUISHI, {
    askToChoice = function()
      return "#qiao__skill_qun016_2-discard"
    end,
  }, function()
    inRoom(function()
      room():killPlayer { who = p2, killer = p(3), extra_data = { ignorePunishment = true } }
    end)
  end)

  lu.assertTrue(p1:isKongcheng())
  lu.assertEquals(p1.hp, hp)
end

return { name = "qiao_qun_basic" }
