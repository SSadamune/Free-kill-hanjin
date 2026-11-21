-- 汉晋 FAQ 公共硬规则回归：
-- 1. 10 人局每国最多 4 人（第 5 人起转野，统一明置、效忠与升变预演）；
-- 2. 7 人及以上局，7 号位及之后的角色开局各自拥有 1 次独立手气卡；
-- 3. 4 人及以下局限制君主升变/继位，首亮角色不获得先驱（主动技能授先驱不受影响）；
-- 4. 阴阳鱼标记通用获得上限为 5 枚，且严格隔离于汉晋模式。
local H = require "packages.hegemony.util"
local A = require "packages.qiao.pkg.qiao_mode.rules.ascension"
local FaqRules = require "packages.qiao.pkg.qiao_mode.rules.faq_core_rules"
local support = __dofile("../../../tests/support/hegemony.lua")
local content = __dofile("../../../tests/support/ascension_content.lua")

local G = content.generals
local addedClientIds = {}
local removedClientSpecs = {}

local function cleanupRoom()
  support.clearRoom()
  for i = #addedClientIds, 1, -1 do
    local id = addedClientIds[i]
    if ClientInstance:getPlayerById(id) then
      ClientInstance:removePlayer({ id })
    end
    addedClientIds[i] = nil
  end
  for i = #removedClientSpecs, 1, -1 do
    local spec = removedClientSpecs[i]
    if not ClientInstance:getPlayerById(spec[1]) then
      ClientInstance:addPlayer(spec)
    end
    removedClientSpecs[i] = nil
  end
end

local function createQiaoRoomWithPlayers(count, settings, configure)
  local ids = {}
  local want = {}
  for i = 1, count do
    ids[i] = i
    want[i] = true
  end
  local backend = FkTest.createFakeRoom(ids)

  -- 将 ClientInstance.players 精确对齐为 1..count，兼容 <8 人与 >8 人房间。
  local existing = table.simpleClone(ClientInstance.players)
  for _, cp in ipairs(existing) do
    local pid = cp.player:getId()
    if not want[pid] then
      table.insert(removedClientSpecs, {
        pid, cp.player:getScreenName(), cp.player:getAvatar(), true, 0,
      })
      ClientInstance:removePlayer({ pid })
    end
  end
  local players = backend:getPlayers()
  for i = 0, players:length() - 1 do
    local pl = players:at(i)
    local pid = pl:getId()
    if not ClientInstance:getPlayerById(pid) then
      ClientInstance:addPlayer({ pid, pl:getScreenName(), pl:getAvatar(), true, 0 })
      table.insert(addedClientIds, pid)
    end
  end

  return support.createRoom {
    mode = "qiao_heg_mode",
    realSelection = true,
    backend = backend,
    settings = settings,
    configure = configure,
  }
end

local function setupAllHidden(room, kingdom)
  for _, pl in ipairs(room.players) do
    content.setupHidden(room, pl, "qiao_test__" .. kingdom .. "_1",
      "qiao_test__" .. kingdom .. "_2", kingdom)
    room:setPlayerMark(pl, "_vanguard_gained", 0)
  end
end

Testfaq_core_rules = {}
Testfaq_core_rules.tearDown = cleanupRoom

function Testfaq_core_rules:testTenPlayerRevealOverflowAndBoundaries()
  local room = createQiaoRoomWithPlayers(10)
  local p = room.players
  local wildPromptCalls = 0
  local originalAskToChoice = room.askToChoice
  room.askToChoice = function(self, target, params, ...)
    if params and params.prompt == "#wild-choose" then
      wildPromptCalls = wildPromptCalls + 1
    end
    return originalAskToChoice(self, target, params, ...)
  end

  local ok, err = pcall(function()
    FkTest.runInRoom(function()
      setupAllHidden(room, "wei")
      -- 1~3 号位先明置主将，正常为魏
      for i = 1, 3 do
        p[i]:revealGeneral(false)
        lu.assertEquals(p[i].kingdom, "wei")
      end
      -- 第 4 名暗置魏角色明置主将，仍合法为魏
      p[4]:revealGeneral(false)
      lu.assertEquals(p[4].kingdom, "wei")
      -- 已属魏势力的第 4 人再明置副将，不得误转野
      p[4]:revealGeneral(true)
      lu.assertEquals(p[4].kingdom, "wei")

      -- 第 5 名原本 unknown 的魏角色单亮主将：10 人局上限为 4，必须转野且不弹建国
      p[5]:revealGeneral(false)
      lu.assertEquals(p[5].kingdom, "wild")
      lu.assertEquals(p[5].role, "wild")
      lu.assertEquals(wildPromptCalls, 0, "普通溢出转野不得弹出野心家建国")

      -- 第 6 名原本 unknown 的魏角色同时双亮：同样转野且不弹建国
      p[6]:revealGenerals()
      lu.assertEquals(p[6].kingdom, "wild")
      lu.assertEquals(p[6].role, "wild")
      lu.assertEquals(wildPromptCalls, 0)

      -- 已死亡的同势力角色仍占势力名额：第 1 人阵亡后，第 7 人明置仍应转野
      p[1].dead = true
      table.removeOne(room.alive_players, p[1])
      p[7]:revealGeneral(false)
      lu.assertEquals(p[7].kingdom, "wild")
      lu.assertEquals(p[7].role, "wild")
    end)
  end)
  room.askToChoice = originalAskToChoice
  assert(ok, err)
end

function Testfaq_core_rules:testTenPlayerPopulationBlocksAscensionAndLoyalty()
  local room = createQiaoRoomWithPlayers(10)
  local p = room.players
  FkTest.runInRoom(function()
    setupAllHidden(room, "wei")
    lu.assertEquals(A.max_kingdom_players(room), 4)
    for i = 1, 3 do
      p[i]:revealGeneral(false)
    end
    -- 仅 3 名魏时，第 4 人尚未超员
    lu.assertFalse(A.population_blocks(room, p[4], "wei"))

    -- 第 4 名魏就位后，第 5 人在 10 人局必须被升变与效忠预演拦截
    p[4]:revealGeneral(false)
    lu.assertTrue(A.population_blocks(room, p[5], "wei"))

    -- 5 号位安装测试用野心家专属主将（可效忠魏）+ 暗置魏副将，效忠候选应排除魏
    content.setupHidden(room, p[5], G.wild_simple.name, G.wei_deputy.name, "wei")
    room:setBanner("all_kingdoms", { "wei", "shu", "wu", "qun" })
    local candidates = A.wild_candidates(room, p[5])
    local hasWei = table.find(candidates, function(c) return c.kingdom == "wei" end)
    lu.assertNil(hasWei, "10 人局已有 4 名魏时，第 5 人不得效忠魏")
  end)
end

function Testfaq_core_rules:testSeatSevenPlusIndependentLuckCardWhenBaseZero()
  local askedPrompts = {}
  local initialBefore = {}
  local redrawCount = { [7] = 0, [8] = 0 }
  local originalAsk = Request.ask
  Request.ask = function(self, ...)
    if self.focus_text == "AskForLuckCard" then
      for _, pl in ipairs(self.players) do
        local d = self.data[pl.id]
        askedPrompts[pl.seat] = d and d[2] or ""
      end
      local p7 = self.room.players[7]
      local p8 = self.room.players[8]
      initialBefore[7] = table.simpleClone(p7:getCardIds("h"))
      initialBefore[8] = table.simpleClone(p8:getCardIds("h"))
      local origDiscard = self.luck_data.discardInit
      self.luck_data.discardInit = function(r, pl)
        redrawCount[pl.seat] = (redrawCount[pl.seat] or 0) + 1
        return origDiscard(r, pl)
      end
      -- 7 号位确认重抽 1 次；8 号位清空回复队列走默认取消
      FkTest.setNextReplies(p7, { "1" })
      FkTest.cleanNextReplies(p8)
    end
    return originalAsk(self, ...)
  end

  local room
  local ok, err = pcall(function()
    room = createQiaoRoomWithPlayers(8, { luckTime = 0 })
  end)
  Request.ask = originalAsk
  assert(ok, err)

  -- 1~6 号位不应收到手气卡询问；7、8 号位各自收到 1 次独立手气卡
  for seat = 1, 6 do
    lu.assertNil(askedPrompts[seat], "房间 luckTime=0 时 1~6 号位不应弹手气卡")
  end
  lu.assertEquals(askedPrompts[7], "#AskForLuckCard:::1")
  lu.assertEquals(askedPrompts[8], "#AskForLuckCard:::1")

  -- 7 号位确认重抽恰好发生 1 次；8 号位默认取消不重抽且起始手牌不变
  lu.assertEquals(redrawCount[7], 1, "7 号位确认手气卡后应真实重抽 1 次")
  lu.assertEquals(redrawCount[8], 0, "8 号位取消手气卡后不应重抽")
  lu.assertEquals(#room.players[7]:getCardIds("h"), 4)
  lu.assertEquals(room.players[8]:getCardIds("h"), initialBefore[8], "8 号位取消手气卡后起始手牌不变")
end

function Testfaq_core_rules:testSeatSevenPlusStacksWithRoomLuckTimeAndSixPlayerNoBonus()
  local asked8 = {}
  local p7Redraws = 0
  local originalAsk = Request.ask
  Request.ask = function(self, ...)
    if self.focus_text == "AskForLuckCard" then
      for _, pl in ipairs(self.players) do
        local d = self.data[pl.id]
        asked8[pl.seat] = d and d[2] or ""
        if pl.seat == 7 then
          FkTest.setNextReplies(pl, { "1", "1" })
        else
          FkTest.cleanNextReplies(pl)
        end
      end
      local p7 = self.room.players[7]
      local origDiscard = self.luck_data.discardInit
      self.luck_data.discardInit = function(r, pl)
        if pl == p7 then p7Redraws = p7Redraws + 1 end
        return origDiscard(r, pl)
      end
    end
    return originalAsk(self, ...)
  end

  local ok1, err1 = pcall(function()
    createQiaoRoomWithPlayers(8, { luckTime = 1 })
  end)
  Request.ask = originalAsk
  assert(ok1, err1)
  cleanupRoom()

  for seat = 1, 6 do
    lu.assertEquals(asked8[seat], "#AskForLuckCard:::1")
  end
  lu.assertEquals(asked8[7], "#AskForLuckCard:::2")
  lu.assertEquals(asked8[8], "#AskForLuckCard:::2")
  lu.assertEquals(p7Redraws, 2, "房间 luckTime=1 时 7 号位应可连续重抽 2 次")

  -- 6 人局（luckTime = 0）不应触发任何手气卡询问
  local asked6 = 0
  Request.ask = function(self, ...)
    if self.focus_text == "AskForLuckCard" then asked6 = asked6 + 1 end
    return originalAsk(self, ...)
  end
  local ok2, err2 = pcall(function()
    createQiaoRoomWithPlayers(6, { luckTime = 0 })
  end)
  Request.ask = originalAsk
  assert(ok2, err2)
  lu.assertEquals(asked6, 0, "6 人局不应发放 7 号位独立手气卡")
end

function Testfaq_core_rules:testFourPlayerBlocksFirstShowVanguardAndLordAscension()
  -- 4 人局：单亮首亮不获先驱；主动技能授先驱不受影响；禁止君主普通升变与死亡继位
  local room = createQiaoRoomWithPlayers(4)
  local p = room.players
  FkTest.runInRoom(function()
    setupAllHidden(room, "han")
    content.setupHidden(room, p[1], "qiao_heg__han001", "qiao_test__han_2", "han")
    room:setBanner("all_kingdoms", { "han", "wei", "shu", "wu" })
    room:setTag("TheFirstToShowRewarded", nil)

    lu.assertFalse(FaqRules.allows_lord_ascension(room))
    lu.assertFalse(FaqRules.allows_first_show_vanguard(room))

    -- 首回合普通君主升变入口不得询问，不得升变为君刘协
    A.on_turn_start(room, p[1])
    lu.assertEquals(p[1].general, "anjiang", "4 人局不得触发普通君主升变")
    -- 死亡继位候选必须为空，直接调用 ascend(lord/succession) 亦被拒绝
    lu.assertNil(A.lord_candidate(room, p[1], "han"))
    lu.assertFalse(A.ascend(room, p[1], "qiao_heg__em_han001", "han", { kind = "lord" }))
    lu.assertFalse(A.ascend(room, p[1], "qiao_heg__em_han001", "han", { kind = "succession" }))

    -- 4 人局单亮首亮：记录首亮者但不给先驱标记
    p[1]:revealGeneral(false)
    lu.assertEquals(room:getTag("TheFirstToShowRewarded"), p[1].id)
    lu.assertEquals(p[1]:getMark("@!!vanguard"), 0, "4 人局首亮不得获得先驱")

    -- 主动技能授予先驱（如当先）不受 4 人局首亮禁用影响
    H.addHegMark(p[1], "vanguard", 1)
    lu.assertEquals(p[1]:getMark("@!!vanguard"), 1)
  end)
  cleanupRoom()

  -- 4 人局双亮首亮同样不获先驱
  local roomDual = createQiaoRoomWithPlayers(4)
  FkTest.runInRoom(function()
    setupAllHidden(roomDual, "wei")
    roomDual:setTag("TheFirstToShowRewarded", nil)
    roomDual.players[1]:revealGenerals()
    lu.assertEquals(roomDual.players[1]:getMark("@!!vanguard"), 0, "4 人局双亮首亮亦不得获得先驱")
  end)
  cleanupRoom()

  -- 5 人局对照：首亮正常获得先驱且允许君主升变
  local room5 = createQiaoRoomWithPlayers(5)
  FkTest.runInRoom(function()
    setupAllHidden(room5, "shu")
    room5:setTag("TheFirstToShowRewarded", nil)
    lu.assertTrue(FaqRules.allows_lord_ascension(room5))
    room5.players[1]:revealGeneral(false)
    lu.assertEquals(room5.players[1]:getMark("@!!vanguard"), 1, "5 人局首亮应正常获得先驱")
  end)
end

function Testfaq_core_rules:testYinyangFishUniversalCapAtFive()
  local room = support.initQiaoRoom()
  local p1 = room.players[1]
  FkTest.runInRoom(function()
    setupAllHidden(room, "wei")
    room:setPlayerMark(p1, "@!!yinyangfish", 0)

    -- 正常累加至上限 5，超出部分截断
    H.addHegMark(p1, "yinyangfish", 3)
    lu.assertEquals(p1:getMark("@!!yinyangfish"), 3)
    H.addHegMark(p1, "yinyangfish", 4)
    lu.assertEquals(p1:getMark("@!!yinyangfish"), 5, "单次过量获得阴阳鱼应截断至 5")
    H.addHegMark(p1, "yinyangfish", 1)
    lu.assertEquals(p1:getMark("@!!yinyangfish"), 5, "已满 5 枚后再获得仍保持 5")

    -- 消耗 1 枚降至 4 枚，再触发双亮应得 2 枚阴阳鱼时应截断补满至 5
    H.removeHegMark(room, p1, "yinyangfish", 1)
    lu.assertEquals(p1:getMark("@!!yinyangfish"), 4)
    room:setPlayerMark(p1, "HalfMaxHpLeft", 2)
    p1:revealGeneral(false)
    p1:revealGeneral(true)
    lu.assertEquals(p1:getMark("@!!yinyangfish"), 5, "双 2.5 双亮在已有 4 枚时应补至 5 不溢出")
    lu.assertTrue(p1:hasSkill("yinyangfish_skill&"))

    -- 珠联璧合与先驱不受阴阳鱼上限 5 约束
    local beforeCompanion = p1:getMark("@!!companion")
    local beforeVanguard = p1:getMark("@!!vanguard")
    H.addHegMark(p1, "companion", 6)
    H.addHegMark(p1, "vanguard", 6)
    lu.assertEquals(p1:getMark("@!!companion"), beforeCompanion + 6)
    lu.assertEquals(p1:getMark("@!!vanguard"), beforeVanguard + 6)
  end)
end

function Testfaq_core_rules:testModeIsolationInUpstreamHegemony()
  local room = support.initRoom()
  local p1 = room.players[1]
  FkTest.runInRoom(function()
    room:setPlayerMark(p1, "@!!yinyangfish", 0)
    H.addHegMark(p1, "yinyangfish", 6)
    lu.assertEquals(p1:getMark("@!!yinyangfish"), 6, "上游标准国战不应受汉晋阴阳鱼 5 上限约束")
  end)
end

return { name = "faq_core_rules" }
