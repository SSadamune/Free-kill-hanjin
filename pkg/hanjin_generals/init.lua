-- 紫乔汉晋·标准武将包
--
-- 六势力各 15 张正式独立武将，另有 14 种翼从和 19 条统领来源。牌面数据全部
-- 来自 rules/standard-generals.md 的已确认表；普通技能与翼从技能目前只登记
-- 名称、原文和标签，骨架不含任何 effect，因此没有游戏效果。偏将的「限一」
-- 只在这里登记牌面标记，每局唯一取得与限一统领能力由公共规则实现。
local extension = Package:new("hanjin_generals")
extension.extensionName = "hanjin"
extension.game_modes_whitelist = { "hanjin_heg_mode" }

extension:loadSkillSkelsByPath("./packages/hanjin/pkg/hanjin_generals/skills")

local Data = require "packages.hanjin.pkg.hanjin_generals.data.standard"
local Guest = require "packages.hanjin.pkg.hanjin_mode.rules.guest_factions"
local Commander = require "packages.hanjin.pkg.hanjin_mode.rules.commander_retinue"

local translations = {
  ["hanjin_generals"] = "紫乔汉晋·武将",
}
for _, general in ipairs(Data.generals) do
  translations[general.id] = general.name
  translations["#" .. general.id] = general.title
  for _, skill in ipairs(general.skills) do
    translations[skill.id] = skill.name
    translations[":" .. skill.id] = skill.text
  end
end
for _, retinue in ipairs(Data.retinues) do
  translations[retinue.id] = retinue.name
  translations["#" .. retinue.id] = retinue.title
  translations[retinue.skill.id] = retinue.skill.name
  translations[":" .. retinue.skill.id] = retinue.skill.text
end
Fk:loadTranslationTable(translations)

-- Formal generals -----------------------------------------------------------
for _, data in ipairs(Data.generals) do
  local general = General:new(extension, data.id, data.kingdom, data.hp)
  -- Two printed versions can share a Chinese name (司马懿, 诸葛亮); the engine
  -- groups same-name conversion by `trueName`. The unique card id stays the key.
  general.trueName = data.name
  general.mainMaxHpAdjustedValue = data.mainHpAdjust or 0
  general.deputyMaxHpAdjustedValue = data.deputyHpAdjust or 0
  for _, skill in ipairs(data.skills) do
    if skill.related then
      general:addRelatedSkill(skill.id)
    else
      general:addSkill(skill.id)
    end
  end
  general:addCompanions(data.companions)
  -- Preserve the original table's names even when the named partner is not one
  -- of these 90 cards (董卓/高览/张纮). They can never match a current general,
  -- but the printed relation stays visible and auditable.
  general:addCompanions(data.companionsUnresolved)
  if #data.guests > 0 then Guest.registerGuest(data.id, data.guests) end
end

-- Formal retinues -----------------------------------------------------------
-- A retinue is granted only by the commander rules. `registerRetinue` hides it
-- from the normal pool and registers it with the exchange module as a soldier.
for _, data in ipairs(Data.retinues) do
  local general = General:new(extension, data.id, "unknown", 4)
  general.trueName = data.name
  general:addSkill(data.skill.id)
end

extension.standard = Data

-- Registration needs the installed engine (Fk.generals / Fk.all_card_types), so
-- it runs after all packages are installed but before the mode package creates
-- the game mode (see init.lua require order).
Fk:addPostLoadFunc(function()
  for _, retinue in ipairs(Data.retinues) do
    Commander.registerRetinue(retinue.id, {
      name = retinue.name,
      limited = retinue.limited,
    })
  end
  local limitedCommanders = {}
  for _, data in ipairs(Data.generals) do
    if data.commander then
      limitedCommanders[data.id] = data.commander.limited == true
    end
  end
  for _, source in ipairs(Data.commanders) do
    Commander.registerCommander(source.general, {
      card = source.card,
      suit = source.suit,
      bypass_distances = source.bypass_distances,
      adaptation = source.adaptation,
      card_text = source.cardText,
      source_text = source.sourceText,
      retinues = { source.retinue },
      limited = limitedCommanders[source.general] == true,
    })
  end

  -- Fail loudly if the generated data and the installed content drift apart.
  local formal, retinues, retinue_skills, commanders, skills = 0, 0, 0, 0, 0
  for _, data in ipairs(Data.generals) do
    local general = assert(Fk.generals[data.id], "Missing formal general: " .. data.id)
    assert(general.package == extension, "Wrong package for " .. data.id)
    assert(general.maxHp == data.hp, "Wrong hp for " .. data.id)
    assert(general.mainMaxHpAdjustedValue == (data.mainHpAdjust or 0),
      "Wrong main hp adjustment for " .. data.id)
    assert(general.deputyMaxHpAdjustedValue == (data.deputyHpAdjust or 0),
      "Wrong deputy hp adjustment for " .. data.id)
    for _, companion in ipairs(data.companions) do
      assert(table.contains(general.companions, companion),
        "Missing companion relation for " .. data.id)
    end
    for _, companion in ipairs(data.companionsUnresolved) do
      assert(table.contains(general.companions, companion),
        "Missing printed companion name for " .. data.id)
    end
    if data.commander then
      local source = assert(Commander.commanders[data.id],
        "Missing commander registration for " .. data.id)
      assert(source.card == data.commander.card, "Wrong commander card for " .. data.id)
      assert(source.card_text == data.commander.cardText,
        "Wrong commander card text for " .. data.id)
      assert(source.source_text == data.commander.sourceText,
        "Wrong commander source text for " .. data.id)
      assert(table.contains(source.retinues, data.commander.retinue),
        "Wrong commander retinue for " .. data.id)
      -- 来源能力自身的限一与偏将/翼从限一是独立登记。
      assert(source.limited == (data.commander.limited == true),
        "Wrong limited ability flag for " .. data.id)
    end
    for _, skill in ipairs(data.skills) do
      local skel = assert(Fk.skill_skels[skill.id], "Missing skill skeleton: " .. skill.id)
      assert(#skel.effects == 0, "Formal display skill must have no effect: " .. skill.id)
      skills = skills + 1
    end
    formal = formal + 1
  end
  for _, data in ipairs(Data.retinues) do
    assert(Commander.isRetinue(data.id), "Unregistered retinue: " .. data.id)
    local general = assert(Fk.generals[data.id], "Missing retinue general: " .. data.id)
    assert(general.hidden, "Retinue must be hidden: " .. data.id)
    local skill = assert(Fk.skill_skels[data.skill.id], "Missing retinue skill: " .. data.skill.id)
    assert(#skill.effects == 0, "Retinue display skill must have no effect: " .. data.skill.id)
    retinues = retinues + 1
    retinue_skills = retinue_skills + 1
  end
  for _, source in ipairs(Data.commanders) do
    assert(Commander.isCommander(source.general), "Unregistered commander: " .. source.general)
    assert(Fk.all_card_types[source.card], "Missing commander card type: " .. source.card)
    local data = Commander.commanders[source.general]
    assert(data.card_text == source.cardText, "Wrong commander card text: " .. source.general)
    assert(data.source_text == source.sourceText, "Wrong commander source text: " .. source.general)
    commanders = commanders + 1
  end
  assert(formal == Data.generalCount, "Formal general count mismatch")
  assert(retinues == Data.retinueCount, "Retinue count mismatch")
  assert(retinue_skills == Data.retinueSkillCount, "Retinue skill count mismatch")
  assert(commanders == Data.commanderCount, "Commander source count mismatch")
  assert(skills == Data.skillCount, "Formal skill count mismatch")
end)

return extension
