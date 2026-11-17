-- Test-only independent objects. Never synced or included by the release entry point.
if Fk.packages.qiao_test_content then return end
local pack = Package:new("qiao_test_content", Package.CardPack)
pack.extensionName = "qiao"
pack.game_modes_whitelist = { "qiao_heg_mode" }
Fk.packages[pack.name] = pack
table.insert(Fk.package_names, pack.name)

for _, kingdom in ipairs({ "wei", "shu", "wu", "qun", "han", "jin", "wild" }) do
  for index = 1, 10 do
    local name = "qiao_test__" .. kingdom .. "_" .. index
    local general = General:new(pack, name, kingdom, 4)
    Fk.generals[name] = general
  end
end

local function add(name, cardType, subtype, suit, number, copies, extra)
  local spec = { name = name, type = cardType, sub_type = subtype }
  for key, value in pairs(extra or {}) do spec[key] = value end
  if subtype == Card.SubtypeWeapon then spec.attack_range = 2 end
  local prototype = fk.CreateCard(spec):createCardPrototype()
  prototype.package = pack
  for _ = 1, copies or 1 do
    local card = prototype:clone(suit, number)
    pack:addCard(card)
    Fk:addCard(card)
  end
end

add("qiao_test__blank_basic", Card.TypeBasic, Card.SubtypeNone, Card.Spade, 7, 64)
-- View-as candidates for the independent test commanders. These are not formal
-- HanJin cards; they only exercise the public commander/retinue rule API.
add("qiao_test__slash", Card.TypeBasic, Card.SubtypeNone, Card.Spade, 1, 4)
add("qiao_test__duel", Card.TypeTrick, Card.SubtypeNone, Card.Club, 1, 4)
add("qiao_test__nullification", Card.TypeTrick, Card.SubtypeNone, Card.Heart, 2, 4,
  { is_passive = true })
local Cards = require "packages.qiao.pkg.qiao_mode.rules.cards"
local definitions = table.clone(Cards.equipment)
for name, spec in pairs(definitions) do
  -- Only clone formal HanJin identities; test-only registrations already have
  -- their own cards and may deliberately carry a different identity.
  if name:startsWith("qiao__") then
    local subtype = ({ wei = Card.SubtypeDefensiveRide, jin = Card.SubtypeDefensiveRide,
      qun = Card.SubtypeArmor, wu = Card.SubtypeTreasure })[spec.kingdom] or Card.SubtypeWeapon
    local testName = name:gsub("^qiao__", "qiao_test__")
    local replacement = spec.replacement and spec.replacement:gsub("^qiao__", "qiao_test__")
    add(testName, Card.TypeEquip, subtype, Card.Spade, 2)
    if replacement then add(replacement, Card.TypeEquip, subtype, Card.Spade, 2) end
    Cards.registerEquipment(testName, spec.kingdoms or spec.kingdom, replacement)
  end
end
add("qiao_test__faction_trick", Card.TypeTrick, Card.SubtypeNone, Card.Heart, 3)
Cards.registerTrick("qiao_test__faction_trick", "wei")

-- Independent test retinues. Their skills are intentionally simple observable
-- effects, and the generals stay hidden from the normal general pool.
local retinueSkillA = fk.CreateSkill {
  name = "qiao_test__retinue_skill_a",
  tags = { Skill.Compulsory },
}
retinueSkillA:addEffect(fk.Damaged, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(retinueSkillA.name)
  end,
  on_use = function(self, event, target, player, data)
    player.room:addPlayerMark(player, "qiao_test_retinue_damaged")
  end,
})

local retinueSkillB = fk.CreateSkill {
  name = "qiao_test__retinue_skill_b",
  tags = { Skill.Compulsory },
}
retinueSkillB:addEffect(fk.HpRecover, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(retinueSkillB.name)
  end,
  on_use = function(self, event, target, player, data)
    player.room:addPlayerMark(player, "qiao_test_retinue_recovered")
  end,
})

local function registerTestSkill(skeleton)
  local skill = skeleton:createSkill()
  skill.package = pack
  Fk:addSkill(skill)
  return skill.name
end
local retinueSkillAName = registerTestSkill(retinueSkillA)
local retinueSkillBName = registerTestSkill(retinueSkillB)

local retinues = {
  { "qiao_test__retinue_alpha", "wei", retinueSkillAName },
  { "qiao_test__retinue_beta", "wei", retinueSkillBName },
  -- 偏将（限一翼从）的独立测试对应物，分别对应正式包的偏将语义。
  { "qiao_test__retinue_zhoucang", "shu", retinueSkillAName, limited = true },
  { "qiao_test__retinue_niujin", "wei", retinueSkillBName, limited = true },
  { "qiao_test__retinue_quaxiaojiang", "wu", retinueSkillAName, limited = true },
}
for _, spec in ipairs(retinues) do
  local general = General:new(pack, spec[1], spec[2], 4)
  general.hidden = true
  general:addSkill(spec[3])
  Fk.generals[spec[1]] = general
end

Fk:loadTranslationTable {
  ["qiao_test__retinue_alpha"] = "测试翼从·甲",
  ["qiao_test__retinue_beta"] = "测试翼从·乙",
  ["qiao_test__retinue_zhoucang"] = "测试偏将·周仓",
  ["qiao_test__retinue_niujin"] = "测试偏将·牛金",
  ["qiao_test__retinue_quaxiaojiang"] = "测试偏将·曲阿小将",
  ["qiao_test__commander_alpha"] = "测试统领·甲",
  ["qiao_test__commander_beta"] = "测试统领·乙",
  ["qiao_test__commander_gamma"] = "测试统领·丙",
  ["qiao_test__commander_delta"] = "测试统领·丁",
  ["qiao_test__commander_guanyu"] = "测试统领·关羽",
  ["qiao_test__commander_caoren"] = "测试统领·曹仁",
  ["qiao_test__commander_taishici"] = "测试统领·太史慈",
  ["qiao_test__commander_duel"] = "测试统领·决斗",
  ["qiao_test__retinue_skill_a"] = "测试翼从技·甲",
  ["qiao_test__retinue_skill_b"] = "测试翼从技·乙",
  ["qiao_test__slash"] = "测试杀",
  ["qiao_test__duel"] = "测试决斗",
  ["qiao_test__nullification"] = "测试无懈可击",
}

local C = require "packages.qiao.pkg.qiao_mode.rules.commander_retinue"
C.registerRetinue("qiao_test__retinue_alpha", { name = "qiao_test__retinue_alpha" })
C.registerRetinue("qiao_test__retinue_beta", { name = "qiao_test__retinue_beta" })
C.registerRetinue("qiao_test__retinue_zhoucang", { name = "qiao_test__retinue_zhoucang", limited = true })
C.registerRetinue("qiao_test__retinue_niujin", { name = "qiao_test__retinue_niujin", limited = true })
C.registerRetinue("qiao_test__retinue_quaxiaojiang", { name = "qiao_test__retinue_quaxiaojiang", limited = true })

local commanders = {
  { "qiao_test__commander_alpha", "wei", "qiao__thunder__slash",
    { "qiao_test__retinue_alpha", "qiao_test__retinue_beta" } },
  { "qiao_test__commander_beta", "shu", "qiao_test__slash",
    { "qiao_test__retinue_beta" } },
  { "qiao_test__commander_gamma", "wu", "qiao_test__nullification",
    { "qiao_test__retinue_alpha" } },
  { "qiao_test__commander_delta", "jin", "qiao__thunder__slash",
    { "qiao_test__retinue_alpha" } },
  -- 与正式关羽/曹仁同牌名（酒）的两个限一来源：同名牌不同来源彼此独立。
  { "qiao_test__commander_guanyu", "shu", "qiao__analeptic",
    { "qiao_test__retinue_zhoucang" }, limited = true },
  { "qiao_test__commander_caoren", "wei", "qiao__analeptic",
    { "qiao_test__retinue_niujin" }, limited = true },
  -- 限一来源的无懈可击：覆盖“使用”窗口与响应用牌路径。
  { "qiao_test__commander_taishici", "shu", "qiao_test__nullification",
    { "qiao_test__retinue_quaxiaojiang" }, limited = true },
  -- 限一来源的普通锦囊：用于覆盖“已宣告使用后被抵消”的时序。
  { "qiao_test__commander_duel", "shu", "duel",
    { "qiao_test__retinue_niujin" }, limited = true },
  -- 来源能力限一与偏将限一必须能独立配置。
  { "qiao_test__commander_limited_only", "wei", "qiao_test__slash",
    { "qiao_test__retinue_alpha" }, limited = true },
  { "qiao_test__commander_unlimited_with_limited_retinue", "wei", "qiao_test__slash",
    { "qiao_test__retinue_zhoucang" }, limited = false },
}
for _, spec in ipairs(commanders) do
  local general = General:new(pack, spec[1], spec[2], 4)
  general.hidden = true
  Fk.generals[spec[1]] = general
  C.registerCommander(spec[1], {
    card = spec[3], retinues = spec[4], limited = spec.limited == true,
  })
end

table.insert(Fk.game_modes.qiao_heg_mode.whitelist, pack.name)
Fk:loadDisabled()
