-- WEI002/JIN009 司马懿 · 应期：配将体力贡献接线。
-- 规则依据：rules/generals/wei002-simayi.md、rules/generals/jin009-simayi.md
-- 与 rules/general-principles.md“配将体力贡献与武将状态”。
--
-- 引擎以半格表示体力（1.5 → 3、2.0 → 4），双将上限为两贡献之和 // 2。
-- 应期的“☯️+2”是 2 个半格（1 点体力上限），不是两枚可消耗阴阳鱼标记；
-- 开局即计入，不待明置；普通交换/移除/替换不重算，升变走公共流程。
local support = __dofile("../../../tests/support/hegemony.lua")

local WEI002 = "qiao_heg__wei002" -- 贡献 3 半格；资料登记为晋客将
local JIN009 = "qiao_heg__jin009" -- 贡献 3 半格；资料登记为魏客将
local GUEST = "qiao_heg__wei001"  -- 贡献 4 半格；资料登记汉/群客将
local PLAIN = "qiao_heg__wei003"  -- 贡献 4 半格；单势力、无客将

local function pairHp()
  return require "packages.qiao.pkg.qiao_mode.rules.pair_hp"
end

local function ascension()
  return require "packages.qiao.pkg.qiao_mode.rules.ascension"
end

local function guestFactions()
  return require "packages.qiao.pkg.qiao_mode.rules.guest_factions"
end

local function factionBan()
  return require "packages.qiao.pkg.qiao_mode.rules.faction_ban"
end

local function room() return FkTest.room end
local function p1() return room().players[1] end

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

--- 复刻 chooseGenerals 的正式接线：主/副将 → 选将标记 → 两牌暗置。
local function installHiddenPair(player, main, deputy)
  inRoom(function()
    local r = room()
    r:setPlayerGeneral(player, main, true)
    r:setDeputyGeneral(player, deputy)
    r:setPlayerMark(player, "__heg_general", main)
    r:setPlayerMark(player, "__heg_deputy", deputy)
    r:setPlayerGeneral(player, "anjiang", true)
    r:setDeputyGeneral(player, "anjiang")
    r:setPlayerMark(player, "__heg_kingdom", "wei")
    r:setPlayerMark(player, "__heg_init_kingdom", "wei")
  end)
end

Testqiao_wei_pair_hp = {}

Testqiao_wei_pair_hp.setup = function()
  support.createRoom {
    mode = "qiao_heg_mode",
    realSelection = true,
    settings = {
      qiao_candidate_kingdoms = { "wei", "jin", "han", "qun" },
      qiao_kingdom_limit = 4,
      qiao_wild_count = 0,
    },
  }
end
Testqiao_wei_pair_hp.tearDown = support.clearRoom

function Testqiao_wei_pair_hp:testOpeningHalfUnitsAndBothYingqiVersions()
  local P = pairHp()
  -- 身份/来源接线：两版司马懿引用同一个应期技能 ID，晋不另设骨架或识别项。
  local YINGQI = "qiao__skill_wei002_3"
  for _, generalName in ipairs({ WEI002, JIN009 }) do
    local count = 0
    for _, name in ipairs(Fk.generals[generalName]:getSkillNameList()) do
      if name == YINGQI then count = count + 1 end
    end
    lu.assertEquals(count, 1, "应期应只注册一次：" .. generalName)
    lu.assertTrue(P.has_yingqi(generalName))
  end
  lu.assertNil(Fk.skill_skels["qiao__skill_jin009_3"])
  lu.assertNil(P.YINGQI_SKILLS["qiao__skill_jin009_3"])
  -- 两处卡面文本统一到魏文本；同 ID 下晋条目不会把翻译覆盖成旧“阴阳鱼+2”。
  lu.assertEquals(Fk:translate(":" .. YINGQI),
    "锁定技，若你配将为多势力或客将，☯️+2。")

  -- 无☯️修正为 3 + 4 = 7 半格；应期 +2 后为 9 半格 → 4 点上限，余 1 个半格。
  lu.assertEquals(P.base_half_hp(WEI002, GUEST), 7)
  lu.assertEquals(P.half_hp(WEI002, GUEST), 9)
  lu.assertEquals(P.max_hp(WEI002, GUEST), 4)
  lu.assertEquals(P.half_left(WEI002, GUEST), 1)
  lu.assertEquals(P.yinyang(WEI002, GUEST), 2)

  -- 两版本各自主将/副将，与客将配将组成四组合，都走真实开局广播。
  for _, combo in ipairs({
    { main = WEI002, deputy = GUEST },
    { main = GUEST, deputy = WEI002 },
    { main = JIN009, deputy = GUEST },
    { main = GUEST, deputy = JIN009 },
  }) do
    local p = p1()
    installHiddenPair(p, combo.main, combo.deputy)
    -- 引擎真实开局调用的体力上限广播；即使主将仍暗置也必须已计入应期。
    inRoom(function() room().logic:broadcastGeneral() end)
    lu.assertEquals(p.general, "anjiang")
    lu.assertEquals(p:getMark("__heg_general"), combo.main)
    lu.assertEquals(p:getMark("__heg_deputy"), combo.deputy)
    lu.assertEquals(p.maxHp, 4)
    lu.assertEquals(p.hp, 4)
    lu.assertEquals(p:getMark("HalfMaxHpLeft"), 1)
    -- 体力贡献修正不发放可消耗阴阳鱼标记。
    lu.assertEquals(p:getMark("@!!yinyangfish"), 0)
    lu.assertEquals(p:getMark(ascension().YINYANG_MARK), 0)
  end
end

function Testqiao_wei_pair_hp:testPlainPartnerKeepsEngineContribution()
  local P = pairHp()
  lu.assertEquals(#guestFactions().guestKingdoms(PLAIN), 0)
  lu.assertEquals(#factionBan().affiliations(Fk.generals[PLAIN]), 1)
  lu.assertEquals(P.yinyang(WEI002, PLAIN), 0)
  lu.assertEquals(P.half_hp(WEI002, PLAIN), 7)

  local p = p1()
  installHiddenPair(p, WEI002, PLAIN)
  inRoom(function() room().logic:broadcastGeneral() end)
  lu.assertEquals(p.maxHp, 3)
  lu.assertEquals(p.hp, 3)
  lu.assertEquals(p:getMark("HalfMaxHpLeft"), 1)
end

function Testqiao_wei_pair_hp:testIdentityUsesPrintedDataNotBanFilter()
  local P, G, Ban = pairHp(), guestFactions(), factionBan()
  local r = room()
  -- 本局魏可用：曹操按原势力结算，不是本局解析出的客将。
  lu.assertTrue(table.contains(r:getBanner("all_kingdoms"), "wei"))
  lu.assertEquals(G.factionsOf(r, GUEST).source, "original")
  -- 客将身份来自资料登记，应期不要求本局已启用客将势力。
  lu.assertTrue(P.is_guest(GUEST))
  lu.assertEquals(P.yinyang(WEI002, GUEST), 2)

  -- 牌面多势力按牌面认定，与禁选结果无关。
  local printed = { kingdom = "wei", subkingdom = "jin" }
  lu.assertEquals(#Ban.affiliations(printed), 2)
  lu.assertTrue(P.is_multi_faction(printed))
  lu.assertTrue(P.qualifies(printed))
  lu.assertEquals(P.yinyang(WEI002, printed), 2)

  -- 普通单势力武将不满足应期条件。
  lu.assertFalse(P.qualifies({ kingdom = "wei" }))
  lu.assertEquals(P.yinyang(WEI002, { kingdom = "wei" }), 0)
end

function Testqiao_wei_pair_hp:testAscensionReusesPairContribution()
  local P, A = pairHp(), ascension()
  local p = p1()
  installHiddenPair(p, WEI002, GUEST) -- 3 + 4 + 2 = 9 → 4
  inRoom(function() room().logic:broadcastGeneral() end)
  inRoom(function() room():setPlayerProperty(p, "kingdom", "wei") end)
  lu.assertEquals(p.maxHp, 4)
  lu.assertEquals(p.hp, 4)

  -- 升变到同为 1.5 体力的 JIN009：新组合仍含应期（9 半格 → 4），与升变前
  -- 持平，不应再加体力。若升变前的组合按“无修正”计算（7 → 3），会被误判为
  -- 3 → 4 而多给 1 点。
  inRoom(function() A.ascend(room(), p, JIN009, "jin", {}) end)
  lu.assertEquals(p:getMark("__heg_general"), JIN009)
  lu.assertEquals(p.maxHp, 4)
  lu.assertEquals(p.hp, 4)
  lu.assertEquals(p:getMark(A.YINYANG_MARK), 0)

  -- 升变到无应期的 2.0 体力主将：新组合 4 + 4 = 8 → 4，仍持平。
  inRoom(function() A.ascend(room(), p, PLAIN, "wei", {}) end)
  lu.assertEquals(p:getMark("__heg_general"), PLAIN)
  lu.assertEquals(p.maxHp, 4)
  lu.assertEquals(p.hp, 4)
end

return { name = "qiao_wei_pair_hp" }
