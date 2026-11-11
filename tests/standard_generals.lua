-- Formal six-kingdom standard content acceptance.
--
-- These tests read the same generated data that the release package uses. They
-- never substitute tests/support/hanjin_content.lua for formal content: the
-- normal room test disables every other general pack, so the pool contains only
-- the 90 formal cards (minus default same-name collapse).
local support = __dofile("../../../tests/support/hegemony.lua")
local Ban = require "packages.hanjin.pkg.hanjin_mode.rules.faction_ban"
local Commander = require "packages.hanjin.pkg.hanjin_mode.rules.commander_retinue"
local Guest = require "packages.hanjin.pkg.hanjin_mode.rules.guest_factions"
local Selection = require "packages.hanjin.pkg.hanjin_mode.rules.selection"
local Data = require "packages.hanjin.pkg.hanjin_generals.data.standard"

local SIX = { "han", "wei", "shu", "wu", "qun", "jin" }

local function formalOnlyDisabledPacks()
  local result = {}
  for name, pack in pairs(Fk.packages) do
    if name ~= "hanjin_generals" and #pack.generals > 0 then
      table.insert(result, name)
    end
  end
  table.sort(result)
  return result
end

local function create(options)
  options = options or {}
  local settings = table.clone(options.settings or {})
  if options.formalOnly then settings.disabledPack = formalOnlyDisabledPacks() end
  return support.createRoom {
    mode = "hanjin_heg_mode",
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
    support.clearRoom()
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
  for _, data in ipairs(Data.generals) do
    lu.assertNil(seen[data.number], "Duplicate number " .. data.number)
    seen[data.number] = true
    byKingdom[data.kingdom] = (byKingdom[data.kingdom] or 0) + 1
    hp[data.hp] = (hp[data.hp] or 0) + 1

    local general = assert(Fk.generals[data.id], "Missing " .. data.id)
    lu.assertEquals(general.package.name, "hanjin_generals")
    lu.assertEquals(general.kingdom, data.kingdom)
    lu.assertEquals(general.trueName, data.name)
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
      lu.assertEquals(#skel.effects, 0, "Skill must have no effect: " .. skill.id)
      lu.assertEquals(#skel.effect_spec_list, 0, "Skill must have no effect spec: " .. skill.id)
      lu.assertEquals(#skel.tests, 0, "Display skill must not carry tests: " .. skill.id)
      lu.assertEquals(#Fk.skills[skill.id].related_skills, 0, "Display skill must not chain effects")
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
    lu.assertEquals(#skel.effects, 0)
    lu.assertEquals(#skel.effect_spec_list, 0)
    lu.assertEquals(#Fk.skills[data.skill.id].related_skills, 0)
  end
  lu.assertEquals(retinueTotal, 14)
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
  lu.assertEquals(Fk.generals["hanjin__han006"].deputyMaxHpAdjustedValue, -1) -- 定著
  lu.assertEquals(Fk.generals["hanjin__shu004"].mainMaxHpAdjustedValue, -1)   -- 空城
  lu.assertEquals(Fk.generals["hanjin__wu005"].mainMaxHpAdjustedValue, -1)    -- 反间
  lu.assertEquals(Fk.generals["hanjin__jin005"].deputyMaxHpAdjustedValue, -1) -- 顺流

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
  lu.assertEquals(maxHpFor("hanjin__wei003", "hanjin__han006"), 3)
  lu.assertEquals(maxHpFor("hanjin__han006", "hanjin__wei003"), 4)
  -- SHU004 空城 and WU005 反间 are 2.0-cards with a main-only -1. Pairing each
  -- with another 4 half-HP card makes the reduction visible (7//2 vs 8//2).
  lu.assertEquals(maxHpFor("hanjin__shu004", "hanjin__wei003"), 3)
  lu.assertEquals(maxHpFor("hanjin__wei003", "hanjin__shu004"), 4)
  lu.assertEquals(maxHpFor("hanjin__wu005", "hanjin__wei003"), 3)
  -- JIN005 顺流 is a 2.0-card with a deputy-only -1.
  lu.assertEquals(maxHpFor("hanjin__wei003", "hanjin__jin005"), 3)
  lu.assertEquals(maxHpFor("hanjin__jin005", "hanjin__wei003"), 4)
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
      hanjin_wild_count = 0,
      hanjin_candidate_kingdoms = { "han", "qun" },
      hanjin_kingdom_limit = 2,
    },
  }
  lu.assertEquals(room:getBanner("hanjin_banned_kingdoms"), {})
  lu.assertEquals(room:getBanner("all_kingdoms"), { "han", "qun" })

  -- 曹操 is printed Wei but has Han/Qun guest factions, so it enters this room
  -- through a guest faction even though Wei is not allowed. It may already be
  -- dealt to a player, so check the whole in-game set, not only the pile.
  lu.assertTrue(inGame(room, "hanjin__wei001"))
  local cao = Guest.factionsOf(room, "hanjin__wei001")
  lu.assertEquals(cao.source, "guest")
  lu.assertEquals(cao.kingdoms, { "han", "qun" })
  -- 夏侯惇 has no guest faction and must be excluded.
  lu.assertFalse(inGame(room, "hanjin__wei003"))

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
  lu.assertEquals(Selection.prompt(room, { "hanjin__wei001" }),
    "#HanjinChooseGeneralsGuest:::曹操（汉/群）")
end

function Teststandard_generals:testFormalRoomStartsWithBanSelectionAndHalfHp()
  local room = create { formalOnly = true }
  lu.assertEquals(room:getSettings("gameMode"), "hanjin_heg_mode")
  lu.assertEquals(#room:getBanner("hanjin_candidate_kingdoms"), 6)
  lu.assertEquals(room:getBanner("hanjin_kingdom_limit"), 4)
  lu.assertEquals(#room:getBanner("hanjin_banned_kingdoms"), 2)
  lu.assertEquals(#room:getBanner("all_kingdoms"), 4)
  lu.assertTrue(#room.general_pile > 0)
  for _, name in ipairs(room.general_pile) do
    local general = assert(Fk.generals[name])
    lu.assertEquals(general.package.name, "hanjin_generals")
    lu.assertFalse(Commander.isRetinue(name))
  end

  local allowed = room:getBanner("all_kingdoms")
  for _, player in ipairs(room.players) do
    local main = player:getMark("__heg_general")
    local deputy = player:getMark("__heg_deputy")
    lu.assertNotEquals(main, deputy)
    lu.assertFalse(Commander.isRetinue(main))
    lu.assertFalse(Commander.isRetinue(deputy))
    lu.assertEquals(Fk.generals[main].package.name, "hanjin_generals")
    lu.assertEquals(Fk.generals[deputy].package.name, "hanjin_generals")
    lu.assertFalse(table.contains(room.general_pile, main))
    lu.assertFalse(table.contains(room.general_pile, deputy))
    lu.assertEquals(#player:getCardIds("h"), 4)
    lu.assertTrue(table.contains(allowed, player:getMark("__heg_kingdom")))
    lu.assertTrue(#Guest.pairKingdoms(room, main, deputy) > 0)

    local a, b = Fk.generals[main], Fk.generals[deputy]
    local sum = a.maxHp + a.mainMaxHpAdjustedValue + b.maxHp + b.deputyMaxHpAdjustedValue
    lu.assertEquals(player.maxHp, sum // 2)
    lu.assertEquals(player:getMark("HalfMaxHpLeft"), sum % 2)
  end
end

function Teststandard_generals:testSameNameConversionAndCompanions()
  local companionRows = 0
  for _, data in ipairs(Data.generals) do
    if data.companionText ~= "—" then companionRows = companionRows + 1 end
  end
  lu.assertEquals(companionRows, 46)
  local room = create {
    formalOnly = true,
    settings = {
      hanjin_wild_count = 0,
      hanjin_candidate_kingdoms = SIX,
      hanjin_kingdom_limit = 6,
    },
  }
  lu.assertTrue(table.contains(Fk:getSameGenerals("hanjin__wei002"), "hanjin__jin009"))
  lu.assertTrue(table.contains(Fk:getSameGenerals("hanjin__shu004"), "hanjin__shu011"))
  lu.assertFalse(Selection.canPair(room, "hanjin__wei002", "hanjin__jin009"))
  lu.assertFalse(Selection.canPair(room, "hanjin__shu004", "hanjin__shu011"))

  -- A printed 司马懿 card may be replaced by the other printed version during
  -- final selection, while the two-card pair itself remains legal.
  lu.assertTrue(Selection.offered(room, { "hanjin__wei002" }, "hanjin__jin009"))
  local valid = assert(Selection.validate(room, { "hanjin__wei002", "hanjin__jin003" },
    { "hanjin__jin009", "hanjin__jin003" }))
  lu.assertEquals(valid.main, "hanjin__jin009")
  lu.assertEquals(valid.deputy, "hanjin__jin003")
  lu.assertFalse(valid.fallback)

  -- 珠联璧合 keeps both explicitly named same-name versions.
  lu.assertTrue(Fk.generals["hanjin__shu001"]:isCompanionWith(Fk.generals["hanjin__shu004"]))
  lu.assertTrue(Fk.generals["hanjin__shu001"]:isCompanionWith(Fk.generals["hanjin__shu011"]))
  lu.assertTrue(Fk.generals["hanjin__jin010"]:isCompanionWith(Fk.generals["hanjin__wei002"]))
  lu.assertTrue(Fk.generals["hanjin__jin010"]:isCompanionWith(Fk.generals["hanjin__jin009"]))
  lu.assertTrue(Fk.generals["hanjin__wei001"]:isCompanionWith(Fk.generals["hanjin__wei012"]))
  lu.assertTrue(Fk.generals["hanjin__wei001"]:isCompanionWith(Fk.generals["hanjin__wei005"]))
  -- Partners outside this 90-card pack stay recorded as printed names.
  lu.assertTrue(table.contains(Fk.generals["hanjin__han012"].companions, "董卓"))
  lu.assertTrue(table.contains(Fk.generals["hanjin__wei009"].companions, "高览"))
  lu.assertTrue(table.contains(Fk.generals["hanjin__wu015a"].companions, "张纮"))
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
    lu.assertEquals(Fk:translate("hanjin_commander_source:" .. source.general), source.sourceText)
  end
  lu.assertEquals(limitedSources, { "伏完", "曹仁", "关羽", "太史慈", "文鸯" })
  local retinueCount = 0
  for _ in pairs(retinues) do retinueCount = retinueCount + 1 end
  lu.assertEquals(retinueCount, 14)
  for _, data in ipairs(Data.retinues) do lu.assertTrue(retinues[data.id]) end
end

function Teststandard_generals:testModeIsFeasibleFromFormalContentOnly()
  local mode = assert(Fk.game_modes.hanjin_heg_mode)
  lu.assertFalse(table.contains(Fk.game_mode_disabled.hanjin_heg_mode, "hanjin_generals"))
  lu.assertFalse(table.contains(mode.whitelist, "hegemony_standard"))
  lu.assertFalse(table.contains(mode.whitelist, "hegemony_cards"))
  -- The formal package alone has the required 90 playable generals and enough
  -- cards for eight players; test support content is not part of this count.
  local formal = 0
  for _, general in ipairs(Fk.packages.hanjin_generals.generals) do
    if not Commander.isRetinue(general.name) then formal = formal + 1 end
  end
  lu.assertEquals(formal, 90)
  lu.assertTrue(#Fk.packages.hanjin_cards.cards >= 8 * 4)
  lu.assertTrue(mode:feasible {
    playerNum = 8,
    gameMode = "hanjin_heg_mode",
    _mode = { hanjin_wild_count = 0 },
  })
  lu.assertTrue(mode:feasible {
    playerNum = 8,
    gameMode = "hanjin_heg_mode",
    _mode = { hanjin_candidate_kingdoms = { "han", "qun" }, hanjin_kingdom_limit = 2 },
  })
end

return { name = "standard_generals" }
