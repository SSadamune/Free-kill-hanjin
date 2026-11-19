-- Formal six-kingdom standard content acceptance.
--
-- These tests read the same generated data that the release package uses. They
-- never substitute tests/support/qiao_content.lua for formal content: the
-- normal room test disables every other general pack, so the pool contains only
-- the 90 formal cards (minus default same-name collapse).
local support = __dofile("../../../tests/support/hegemony.lua")
local Ban = require "packages.qiao.pkg.qiao_mode.rules.faction_ban"
local Commander = require "packages.qiao.pkg.qiao_mode.rules.commander_retinue"
local Guest = require "packages.qiao.pkg.qiao_mode.rules.guest_factions"
local Selection = require "packages.qiao.pkg.qiao_mode.rules.selection"
local PairHp = require "packages.qiao.pkg.qiao_mode.rules.pair_hp"
local Data = require "packages.qiao.pkg.qiao_generals.data.standard"
local Han = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_han"
local Wei = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wei"
local Wu = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wu"

local SIX = { "han", "wei", "shu", "wu", "qun", "jin" }
local LEGACY_IMPLEMENTED = {
  ["qiao__skill_han001_1"] = true,
  ["qiao__skill_han001_2"] = true,
  ["qiao__skill_jin001_1"] = true,
  ["qiao__skill_jin001_2"] = true,
}

local function isImplemented(name)
  local skel = Fk.skill_skels[name]
  return (skel ~= nil and skel.qiaoImplemented == true) or LEGACY_IMPLEMENTED[name] == true
end

local function formalOnlyDisabledPacks()
  local result = {}
  for name, pack in pairs(Fk.packages) do
    if name ~= "qiao_generals" and (#pack.generals > 0 or name == "qiao_test_content") then
      table.insert(result, name)
    end
  end
  -- support.createRoom installs this test-only pack after the setting is
  -- computed; name it explicitly so formal content tests never draw it.
  if not table.contains(result, "qiao_test_content") then
    table.insert(result, "qiao_test_content")
  end
  table.sort(result)
  return result
end

local function create(options)
  options = options or {}
  local settings = table.clone(options.settings or {})
  if options.formalOnly then settings.disabledPack = formalOnlyDisabledPacks() end
  return support.createRoom {
    mode = "qiao_heg_mode",
    realSelection = true,
    settings = settings,
  }
end

local function inGame(room, name)
  if table.contains(room.general_pile, name) then return true end
  for _, player in ipairs(room.players) do
    if player:getMark("__heg_general") == name
      or player:getMark("__heg_deputy") == name then return true end
  end
  return false
end

local function gameNames(room)
  local names = table.simpleClone(room.general_pile)
  for _, player in ipairs(room.players) do
    table.insertIfNeed(names, player:getMark("__heg_general"))
    table.insertIfNeed(names, player:getMark("__heg_deputy"))
  end
  return names
end

Teststandard_generals = {
  tearDown = function()
    Ban.resetKingdoms()
    if FkTest.room ~= nil then support.clearRoom() end
  end,
}

function Teststandard_generals:testRegistryHasNinetyGeneralsAndFourteenRetinues()
  lu.assertEquals(Data.generalCount, 90)
  lu.assertEquals(Data.retinueCount, 14)
  lu.assertEquals(Data.commanderCount, 19)
  lu.assertEquals(Data.skillCount, 160)
  lu.assertEquals(#Data.generals, 90)
  lu.assertEquals(#Data.retinues, 14)
  lu.assertEquals(#Data.commanders, 19)

  local byKingdom, seen = {}, {}
  local hp = { [3] = 0, [4] = 0, [5] = 0 }
  local ClientUtil = require "ltk.client.util"
  for _, data in ipairs(Data.generals) do
    lu.assertNil(seen[data.number], "Duplicate number " .. data.number)
    seen[data.number] = true
    byKingdom[data.kingdom] = (byKingdom[data.kingdom] or 0) + 1
    hp[data.hp] = (hp[data.hp] or 0) + 1

    local general = assert(Fk.generals[data.id], "Missing " .. data.id)
    lu.assertEquals(general.package.name, "qiao_generals")
    lu.assertEquals(general.kingdom, data.kingdom)
    lu.assertEquals(general.trueName, data.name)
    lu.assertEquals(general.prefix, "qiao_prefix_std")
    lu.assertEquals(Fk:translate(general.prefix), "标")
    lu.assertEquals(ClientUtil:getGeneralData(data.id).prefix, "qiao_prefix_std")
    lu.assertEquals(general.maxHp, data.hp)
    lu.assertEquals(general.hp, data.hp)
    lu.assertEquals(Fk:translate(data.id), data.name)
    lu.assertEquals(Fk:translate("#" .. data.id), data.title)
  end
  for _, kingdom in ipairs(SIX) do lu.assertEquals(byKingdom[kingdom], 15) end
  lu.assertEquals(hp[3], 39) -- 1.5 contribution
  lu.assertEquals(hp[4], 45) -- 2.0 contribution
  lu.assertEquals(hp[5], 6)  -- 2.5 contribution
end

-- 性别元数据：17 名女性、73 名男性，均由正式武将数据显式登记。
-- 只统计 Data.generals（90 张正式将），翼从仍隐藏且不进入该统计。
function Teststandard_generals:testFormalGeneralGendersAreExplicit()
  local expectedFemale = {
    ["qiao_heg__han007"] = true,
    ["qiao_heg__han008"] = true,
    ["qiao_heg__han011"] = true,
    ["qiao_heg__wei007"] = true,
    ["qiao_heg__shu007"] = true,
    ["qiao_heg__shu015"] = true,
    ["qiao_heg__shu016"] = true,
    ["qiao_heg__wu006"] = true,
    ["qiao_heg__wu008"] = true,
    ["qiao_heg__wu011"] = true,
    ["qiao_heg__qun003"] = true,
    ["qiao_heg__qun012"] = true,
    ["qiao_heg__qun018"] = true,
    ["qiao_heg__jin007"] = true,
    ["qiao_heg__jin008"] = true,
    ["qiao_heg__jin010"] = true,
    ["qiao_heg__jin012"] = true,
  }
  local female, male = 0, 0
  for _, data in ipairs(Data.generals) do
    local general = assert(Fk.generals[data.id], "Missing " .. data.id)
    lu.assertNotNil(data.gender, "Missing gender data for " .. data.id)
    lu.assertTrue(general.gender == General.Male or general.gender == General.Female,
      "Unregistered gender for " .. data.id)
    if general.gender == General.Female then
      female = female + 1
      lu.assertTrue(expectedFemale[data.id], "Unexpected female general " .. data.id)
    else
      male = male + 1
      lu.assertNil(expectedFemale[data.id], "Female general registered as male: " .. data.id)
    end
  end
  lu.assertEquals(female, 17)
  lu.assertEquals(male, 73)
  lu.assertEquals(Fk.generals["qiao_heg__qun003"].gender, General.Female) -- 貂蝉
  lu.assertEquals(Fk.generals["qiao_heg__qun002"].gender, General.Male)   -- 吕布
  -- 翼从不在 90 将性别统计内，且仍保持隐藏。
  lu.assertEquals(#Data.generals, 90)
  for _, retinue in ipairs(Data.retinues) do
    lu.assertTrue(Fk.generals[retinue.id].hidden, "Retinue must stay hidden: " .. retinue.id)
  end
end

function Teststandard_generals:testEverySkillIsDisplayOnlyWithExactTextAndOrder()
  local total, retinueTotal = 0, 0
  for _, data in ipairs(Data.generals) do
    local general = Fk.generals[data.id]
    local visible = {}
    for _, skill in ipairs(data.skills) do
      total = total + 1
      lu.assertEquals(Fk:translate(skill.id), skill.name)
      lu.assertEquals(Fk:translate(":" .. skill.id), skill.text)
      local skel = assert(Fk.skill_skels[skill.id], "Missing skeleton " .. skill.id)
      if isImplemented(skill.id) then
        lu.assertTrue(#skel.effects > 0, "Implemented skill needs an effect: " .. skill.id)
      else
        lu.assertEquals(#skel.effects, 0, "Skill must have no effect: " .. skill.id)
        lu.assertEquals(#skel.effect_spec_list, 0, "Skill must have no effect spec: " .. skill.id)
        lu.assertEquals(#skel.tests, 0, "Display skill must not carry tests: " .. skill.id)
        lu.assertEquals(#Fk.skills[skill.id].related_skills, 0, "Display skill must not chain effects")
      end
      for _, tag in ipairs(skill.tags) do
        lu.assertTrue(Fk.skills[skill.id]:hasTag(tag), "Missing tag " .. tag)
      end
      if skill.related then
        lu.assertTrue(table.contains(general.related_other_skills, skill.id))
      else
        lu.assertTrue(table.contains(general.other_skills, skill.id))
        table.insert(visible, skill.id)
      end
    end
    -- `getSkillNameList` returns the printed, normally acquired skill names.
    local names = general:getSkillNameList()
    lu.assertEquals(#names, #visible)
    for _, name in ipairs(visible) do lu.assertTrue(table.contains(names, name)) end
  end
  lu.assertEquals(total, 160)

  for _, data in ipairs(Data.retinues) do
    retinueTotal = retinueTotal + 1
    lu.assertEquals(Fk:translate(data.skill.id), data.name)
    lu.assertEquals(Fk:translate(":" .. data.skill.id), data.skill.text)
    local skel = assert(Fk.skill_skels[data.skill.id], "Missing retinue skeleton")
    if skel.qiaoImplemented == true then
      lu.assertTrue(#skel.effects > 0, "Implemented retinue skill needs an effect: " .. data.skill.id)
    else
      lu.assertEquals(#skel.effects, 0)
      lu.assertEquals(#skel.effect_spec_list, 0)
      lu.assertEquals(#Fk.skills[data.skill.id].related_skills, 0)
    end
  end
  lu.assertEquals(retinueTotal, 14)
end

function Teststandard_generals:testImplementedExceptionListMatchesRegisteredEffects()
  local names = {}
  for _, data in ipairs(Data.generals) do
    for _, skill in ipairs(data.skills) do
      if isImplemented(skill.id) then table.insert(names, skill.id) end
    end
  end
  table.sort(names)
  -- Parallel work may register more Han skills with the same marker; assert
  -- this round's required registrations and the effect contract below rather
  -- than freezing the whole list to a single round.
  for _, required in ipairs({
    "qiao__skill_han001_1",
    "qiao__skill_han001_2",
    "qiao__skill_han002_1",
    "qiao__skill_han002_2",
    "qiao__skill_han018_1",
    "qiao__skill_jin001_1",
    "qiao__skill_jin001_2",
  }) do
    lu.assertTrue(table.contains(names, required), "Missing implemented registration: " .. required)
  end
  for _, name in ipairs(names) do
    local skel = assert(Fk.skill_skels[name], "Missing implemented skeleton " .. name)
    lu.assertTrue(#skel.effects > 0, "Implemented skill needs an effect: " .. name)
  end
  local jin = assert(Fk.generals["qiao_heg__jin001"])
  lu.assertTrue(table.contains(jin:getSkillNameList(), "qiao__skill_jin001_1"))
  lu.assertTrue(table.contains(jin:getSkillNameList(), "qiao__skill_jin001_2"))
end

function Teststandard_generals:testHalfHpAndMainDeputyAdjustments()
  -- Card contribution is stored in the engine's half-unit scale: 1.5 -> 3,
  -- 2 -> 4, 2.5 -> 5. Only the four printed 主将技/副将技 fixed adjustments
  -- change the contribution; ordinary skill effects are not implemented.
  for _, data in ipairs(Data.generals) do
    local general = Fk.generals[data.id]
    lu.assertEquals(data.hp, math.floor(data.halfHp * 2))
    lu.assertEquals(general.maxHp, data.hp)
    lu.assertEquals(general.mainMaxHpAdjustedValue, data.mainHpAdjust)
    lu.assertEquals(general.deputyMaxHpAdjustedValue, data.deputyHpAdjust)
  end
  lu.assertEquals(Fk.generals["qiao_heg__han006"].deputyMaxHpAdjustedValue, -1) -- 定著
  lu.assertEquals(Fk.generals["qiao_heg__shu004"].mainMaxHpAdjustedValue, -1)   -- 空城
  lu.assertEquals(Fk.generals["qiao_heg__wu005"].mainMaxHpAdjustedValue, -1)    -- 反间
  lu.assertEquals(Fk.generals["qiao_heg__jin005"].deputyMaxHpAdjustedValue, -1) -- 顺流

  local room = create { formalOnly = true }
  local player = room.players[1]
  local function maxHpFor(main, deputy)
    local value
    FkTest.runInRoom(function()
      room:setPlayerMark(player, "__heg_general", main)
      room:setPlayerMark(player, "__heg_deputy", deputy)
      value = player:getGeneralMaxHp()
    end)
    return value
  end
  -- HAN006 定著 only reduces when it is the deputy. Its 2.0-card is 4 half-HP,
  -- so pair it with another 4 to make the -1 visible (7//2 vs 8//2).
  lu.assertEquals(maxHpFor("qiao_heg__wei003", "qiao_heg__han006"), 3)
  lu.assertEquals(maxHpFor("qiao_heg__han006", "qiao_heg__wei003"), 4)
  -- SHU004 空城 and WU005 反间 are 2.0-cards with a main-only -1. Pairing each
  -- with another 4 half-HP card makes the reduction visible (7//2 vs 8//2).
  lu.assertEquals(maxHpFor("qiao_heg__shu004", "qiao_heg__wei003"), 3)
  lu.assertEquals(maxHpFor("qiao_heg__wei003", "qiao_heg__shu004"), 4)
  lu.assertEquals(maxHpFor("qiao_heg__wu005", "qiao_heg__wei003"), 3)
  -- JIN005 顺流 is a 2.0-card with a deputy-only -1.
  lu.assertEquals(maxHpFor("qiao_heg__wei003", "qiao_heg__jin005"), 3)
  lu.assertEquals(maxHpFor("qiao_heg__jin005", "qiao_heg__wei003"), 4)
end

function Teststandard_generals:testGuestFactionsAndRealGuestResolution()
  local count = 0
  for _, data in ipairs(Data.generals) do
    lu.assertEquals(Guest.guestKingdoms(data.id), data.guests)
    if #data.guests > 0 then count = count + 1 end
  end
  lu.assertEquals(count, 51)

  local room = create {
    formalOnly = true,
    settings = {
      qiao_wild_count = 0,
      qiao_candidate_kingdoms = { "han", "qun" },
      qiao_kingdom_limit = 2,
    },
  }
  lu.assertEquals(room:getBanner("qiao_banned_kingdoms"), {})
  lu.assertEquals(room:getBanner("all_kingdoms"), { "han", "qun" })

  -- 曹操 is printed Wei but has Han/Qun guest factions, so it enters this room
  -- through a guest faction even though Wei is not allowed. It may already be
  -- dealt to a player, so check the whole in-game set, not only the pile.
  lu.assertTrue(inGame(room, "qiao_heg__wei001"))
  local cao = Guest.factionsOf(room, "qiao_heg__wei001")
  lu.assertEquals(cao.source, "guest")
  lu.assertEquals(cao.kingdoms, { "han", "qun" })
  -- 夏侯惇 has no guest faction and must be excluded.
  lu.assertFalse(inGame(room, "qiao_heg__wei003"))

  for _, name in ipairs(gameNames(room)) do
    local entry = assert(Guest.factionsOf(room, name))
    lu.assertTrue(entry.wild or table.find(entry.kingdoms, function(k)
      return table.contains({ "han", "qun" }, k)
    end) ~= nil)
  end
  for _, player in ipairs(room.players) do
    for _, key in ipairs({ "__heg_general", "__heg_deputy" }) do
      local entry = assert(Guest.factionsOf(room, player:getMark(key)))
      lu.assertTrue(entry.wild or table.find(entry.kingdoms, function(k)
        return table.contains({ "han", "qun" }, k)
      end) ~= nil)
    end
  end

  -- The selection prompt marks the guest card with its this-game factions.
  lu.assertEquals(Selection.prompt(room, { "qiao_heg__wei001" }),
    "#QiaoChooseGeneralsBans:::无")
end

function Teststandard_generals:testFormalRoomStartsWithBanSelectionAndHalfHp()
  local room = create { formalOnly = true }
  lu.assertEquals(room:getSettings("gameMode"), "qiao_heg_mode")
  lu.assertEquals(#room:getBanner("qiao_candidate_kingdoms"), 6)
  lu.assertEquals(room:getBanner("qiao_kingdom_limit"), 4)
  lu.assertEquals(#room:getBanner("qiao_banned_kingdoms"), 2)
  lu.assertEquals(#room:getBanner("all_kingdoms"), 4)
  lu.assertTrue(#room.general_pile > 0)
  for _, name in ipairs(room.general_pile) do
    local general = assert(Fk.generals[name])
    lu.assertEquals(general.package.name, "qiao_generals")
    lu.assertFalse(Commander.isRetinue(name))
  end

  local allowed = room:getBanner("all_kingdoms")
  for _, player in ipairs(room.players) do
    local main = player:getMark("__heg_general")
    local deputy = player:getMark("__heg_deputy")
    lu.assertNotEquals(main, deputy)
    lu.assertFalse(Commander.isRetinue(main))
    lu.assertFalse(Commander.isRetinue(deputy))
    lu.assertEquals(Fk.generals[main].package.name, "qiao_generals")
    lu.assertEquals(Fk.generals[deputy].package.name, "qiao_generals")
    lu.assertFalse(table.contains(room.general_pile, main))
    lu.assertFalse(table.contains(room.general_pile, deputy))
    lu.assertEquals(#player:getCardIds("h"), 4)
    lu.assertTrue(table.contains(allowed, player:getMark("__heg_kingdom")))
    lu.assertTrue(#Guest.pairKingdoms(room, main, deputy) > 0)

    -- 正式开局上限由配将贡献统一计算：引擎默认组合 + 应期等☯️修正。
    local total = PairHp.half_hp(main, deputy)
    lu.assertEquals(player.maxHp, total // 2)
    lu.assertEquals(player:getMark("HalfMaxHpLeft"), total % 2)
  end
end

function Teststandard_generals:testPairHpYingqiContribution()
  -- 应期 ☯️+2 = 2 个半格（1 点上限），与引擎默认组合公式分开核对。
  lu.assertEquals(PairHp.base_half_hp("qiao_heg__wei002", "qiao_heg__wei001"), 7)
  lu.assertEquals(PairHp.yinyang("qiao_heg__wei002", "qiao_heg__wei001"), 2)
  lu.assertEquals(PairHp.half_hp("qiao_heg__wei002", "qiao_heg__wei001"), 9)
  lu.assertEquals(PairHp.max_hp("qiao_heg__wei002", "qiao_heg__wei001"), 4)
  lu.assertEquals(PairHp.half_left("qiao_heg__wei002", "qiao_heg__wei001"), 1)
  -- 非多势力、非客将的配将不修正。
  lu.assertEquals(PairHp.yinyang("qiao_heg__wei002", "qiao_heg__wei003"), 0)
  lu.assertEquals(PairHp.max_hp("qiao_heg__wei002", "qiao_heg__wei003"), 3)
end

function Teststandard_generals:testSameNameConversionAndCompanions()
  local companionRows = 0
  for _, data in ipairs(Data.generals) do
    if data.companionText ~= "—" then companionRows = companionRows + 1 end
  end
  lu.assertEquals(companionRows, 47)
  local room = create {
    formalOnly = true,
    settings = {
      qiao_wild_count = 0,
      qiao_candidate_kingdoms = SIX,
      qiao_kingdom_limit = 6,
    },
  }
  lu.assertTrue(table.contains(Fk:getSameGenerals("qiao_heg__wei002"), "qiao_heg__jin009"))
  lu.assertTrue(table.contains(Fk:getSameGenerals("qiao_heg__shu004"), "qiao_heg__shu011"))
  lu.assertFalse(Selection.canPair(room, "qiao_heg__wei002", "qiao_heg__jin009"))
  lu.assertFalse(Selection.canPair(room, "qiao_heg__shu004", "qiao_heg__shu011"))

  -- A printed 司马懿 card may be replaced by the other printed version during
  -- final selection, while the two-card pair itself remains legal.
  lu.assertTrue(Selection.offered(room, { "qiao_heg__wei002" }, "qiao_heg__jin009"))
  local valid = assert(Selection.validate(room, { "qiao_heg__wei002", "qiao_heg__jin003" },
    { "qiao_heg__jin009", "qiao_heg__jin003" }))
  lu.assertEquals(valid.main, "qiao_heg__jin009")
  lu.assertEquals(valid.deputy, "qiao_heg__jin003")
  lu.assertFalse(valid.fallback)

  -- 珠联璧合 keeps both explicitly named same-name versions.
  lu.assertTrue(Fk.generals["qiao_heg__shu001"]:isCompanionWith(Fk.generals["qiao_heg__shu004"]))
  lu.assertTrue(Fk.generals["qiao_heg__shu001"]:isCompanionWith(Fk.generals["qiao_heg__shu011"]))
  lu.assertTrue(Fk.generals["qiao_heg__jin010"]:isCompanionWith(Fk.generals["qiao_heg__wei002"]))
  lu.assertTrue(Fk.generals["qiao_heg__jin010"]:isCompanionWith(Fk.generals["qiao_heg__jin009"]))
  lu.assertTrue(Fk.generals["qiao_heg__jin003"]:isCompanionWith(Fk.generals["qiao_heg__jin002"]))
  lu.assertTrue(Fk.generals["qiao_heg__wei001"]:isCompanionWith(Fk.generals["qiao_heg__wei012"]))
  lu.assertTrue(Fk.generals["qiao_heg__wei001"]:isCompanionWith(Fk.generals["qiao_heg__wei005"]))
  -- Partners outside this 90-card pack stay recorded as printed names.
  lu.assertTrue(table.contains(Fk.generals["qiao_heg__han012"].companions, "董卓"))
  lu.assertTrue(table.contains(Fk.generals["qiao_heg__wei009"].companions, "高览"))
  lu.assertTrue(table.contains(Fk.generals["qiao_heg__wu015a"].companions, "张纮"))
end

function Teststandard_generals:testRetinuesAreRegisteredButStayOutOfNormalPools()
  local room = create { formalOnly = true }
  local limited = {}
  for _, data in ipairs(Data.retinues) do
    local general = assert(Fk.generals[data.id])
    lu.assertTrue(Commander.isRetinue(data.id))
    lu.assertEquals(Commander.retinues[data.id].limited, data.limited)
    if data.limited then table.insert(limited, data.name) end
    lu.assertTrue(general.hidden)
    lu.assertFalse(Fk:canUseGeneral(data.id))
    lu.assertEquals(Fk:translate(data.id), data.name)
    lu.assertEquals(Fk:translate("#" .. data.id), data.title)
    lu.assertTrue(table.contains(general:getSkillNameList(), data.skill.id))
    lu.assertFalse(Selection.offered(room, { data.id }, data.id))
  end
  lu.assertEquals(limited, { "穆顺", "牛金", "周仓", "曲阿小将", "文虎" })
  for _, name in ipairs(room.general_pile) do lu.assertFalse(Commander.isRetinue(name)) end

  -- The mode filter removes a retinue even if another effect injects it.
  FkTest.runInRoom(function()
    table.insert(room.general_pile, Data.retinues[1].id)
    Commander.excludeRetinuesFromPile(room)
    lu.assertFalse(table.contains(room.general_pile, Data.retinues[1].id))
  end)
end

function Teststandard_generals:testNineteenCommanderSourcesUseOnlyFormalCards()
  lu.assertEquals(#Data.commanders, 19)
  local sources, retinues = {}, {}
  local limitedSources = {}
  for _, source in ipairs(Data.commanders) do
    lu.assertNil(sources[source.general])
    sources[source.general] = true
    retinues[source.retinue] = true
    lu.assertTrue(Commander.isCommander(source.general))
    local registered = assert(Commander.commanders[source.general])
    lu.assertEquals(registered.card, source.card)
    lu.assertEquals(registered.card_text, source.cardText)
    lu.assertEquals(registered.source_text, source.sourceText)
    lu.assertEquals(registered.retinues, { source.retinue })
    -- A source that provides a 偏将 also has the once-per-game view-as ability.
    lu.assertEquals(registered.limited, Commander.retinues[source.retinue].limited)
    if registered.limited then table.insert(limitedSources, source.name) end
    lu.assertTrue(Fk.all_card_types[source.card] ~= nil)
    lu.assertEquals(Fk:translate("qiao_commander_source:" .. source.general), source.sourceText)
  end
  lu.assertEquals(limitedSources, { "伏完", "曹仁", "关羽", "太史慈", "文鸯" })
  local retinueCount = 0
  for _ in pairs(retinues) do retinueCount = retinueCount + 1 end
  lu.assertEquals(retinueCount, 14)
  for _, data in ipairs(Data.retinues) do lu.assertTrue(retinues[data.id]) end
end

--- 非武将来源标签在真实 postLoad 注册后进入 Fk:getDescription；
--- 与客户端 getPlayerSkills 使用同一调用形态（技能名 + 观察者）。
function Teststandard_generals:testSourceLabelsDescribeNonGeneralSkills()
  local room = create { formalOnly = true }
  local player = room.players[1]
  local function labeled(name, label)
    local text = Fk:getDescription(name, nil, player)
    return type(text) == "string" and text:find("〔" .. label .. "〕", 1, true) ~= nil
  end

  -- 诏书入口与消费、君主旗：非武将牌来源。
  lu.assertTrue(labeled(Han.BANNER, "诏书"), "诏书入口应带来源标签")
  lu.assertTrue(labeled(Han.CONSUME, "诏书"), "诏书消费应带来源标签")
  lu.assertTrue(labeled(Wei.BANNER, "君主旗"), "霸者求贤状应带旗标签")
  lu.assertTrue(labeled(Wu.FLAG, "君主旗"), "缘江烽火图应带旗标签")
  lu.assertTrue(labeled("qiao__skill_em_jin001_banner", "君主旗"),
    "诸王敕封册应带旗标签")
  lu.assertTrue(labeled("qiao__skill_em_jin001_banner", "赐"),
    "诸王敕封册应另标赐的消费入口")

  -- 太康在武将牌上，诸王敕封册由太康授予，不是牌上技能。
  local simayan = assert(Fk.generals["qiao_heg__em_jin001"])
  lu.assertTrue(table.contains(simayan:getSkillNameList(), "qiao__skill_em_jin001_1"),
    "太康应是 EM(JIN001) 的牌上技能")
  lu.assertFalse(table.contains(simayan:getSkillNameList(), "qiao__skill_em_jin001_banner"),
    "诸王敕封册是太康授予的旗，不是牌上技能")

  -- 统领：标签包裹现有动态描述，不替换来源/翼从内容。
  local source = Data.commanders[1]
  lu.assertNotNil(Commander.commanders[source.general])
  FkTest.runInRoom(function()
    room:setPlayerMark(player, "qiao_commander_descriptions", {
      { key = source.general, retinues = { source.retinue }, active = true },
    })
  end)
  local dynamic = Commander.description(player, nil, nil)
  lu.assertTrue(#dynamic > 0, "统领动态描述应有内容")
  local ability = assert(Fk:getDescription(Commander.ABILITY_SKILL, nil, player))
  local skel = assert(Fk.skill_skels[Commander.ABILITY_SKILL], "统领技能骨架应已注册")
  lu.assertNotNil(skel.qiaoSourceLabel, "统领技能骨架应有来源标签标记")
  lu.assertTrue(labeled(Commander.ABILITY_SKILL, "统领"), "统领技能应带来源标签")
  -- 带 dynamic_desc 的骨架有两个取值入口；两条路径都必须保留标签与动态内容。
  local skeletonText = skel:getDynamicDescription(player, nil)
  lu.assertTrue(type(skeletonText) == "string" and skeletonText:find("〔统领〕", 1, true) ~= nil,
    "骨架动态描述应含标签")
  lu.assertTrue(ability:find(dynamic, 1, true) ~= nil,
    "标签应包裹而非替换统领动态描述：" .. ability)
  lu.assertTrue(skeletonText:find(dynamic, 1, true) ~= nil,
    "骨架动态描述不应丢失来源/翼从内容：" .. skeletonText)

  -- 翼从技能来自翼从牌，不是武将牌技能。
  local retinue = Data.retinues[1]
  lu.assertTrue(labeled(retinue.skill.id, "翼从"), "翼从技能应带翼从标签")

  -- 武将牌技能与装备技能不带来源标签。
  local taikang = assert(Fk:getDescription("qiao__skill_em_jin001_1", nil, player))
  lu.assertNil(taikang:find("〔", 1, true), "武将牌技能不应带来源标签：" .. taikang)
  local equip = assert(Fk:getDescription("qiao__liulongcanjia_skill", nil, player))
  lu.assertNil(equip:find("〔", 1, true), "装备技能不应带来源标签：" .. equip)

  -- 标签只进描述，不进入技能名（SkillButton 宽度不受影响）。
  for _, name in ipairs({ Han.BANNER, Commander.ABILITY_SKILL }) do
    local shown = Fk:getSkillName(name, nil, player)
    lu.assertNil(shown:find("〔", 1, true), "技能名不应含来源标签：" .. shown)
  end
end

function Teststandard_generals:testModeIsFeasibleFromFormalContentOnly()
  local mode = assert(Fk.game_modes.qiao_heg_mode)
  lu.assertFalse(table.contains(Fk.game_mode_disabled.qiao_heg_mode, "qiao_generals"))
  lu.assertFalse(table.contains(mode.whitelist, "hegemony_standard"))
  lu.assertFalse(table.contains(mode.whitelist, "hegemony_cards"))
  -- The formal package alone has the required 90 playable generals and enough
  -- cards for eight players; test support content is not part of this count.
  local formal = 0
  for _, general in ipairs(Fk.packages.qiao_generals.generals) do
    if not Commander.isRetinue(general.name) then formal = formal + 1 end
  end
  lu.assertEquals(formal, 90)
  lu.assertTrue(#Fk.packages.qiao_cards.cards >= 8 * 4)
  lu.assertTrue(mode:feasible {
    playerNum = 8,
    gameMode = "qiao_heg_mode",
    _mode = { qiao_wild_count = 0 },
  })
  lu.assertTrue(mode:feasible {
    playerNum = 8,
    gameMode = "qiao_heg_mode",
    _mode = { qiao_candidate_kingdoms = { "han", "qun" }, qiao_kingdom_limit = 2 },
  })
end

return { name = "standard_generals" }
