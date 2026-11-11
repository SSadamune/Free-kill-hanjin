-- Test-only independent content for 第二君主 and 野心家效忠.  It is never
-- referenced by init.lua and never enters release content.  The pack is added to
-- the HanJin mode whitelist only in the test process so the real opening-pool
-- flow can see the wild originals and their allegiance versions.
if Fk.packages.hanjin_ascension_test then
  return Fk.packages.hanjin_ascension_test._ascension_content
end

__dofile("../../../tests/support/hanjin_content.lua")

local pack = Package:new("hanjin_ascension_test", Package.CardPack)
pack.extensionName = "hanjin"
Fk.packages[pack.name] = pack
table.insert(Fk.package_names, pack.name)

local function createSkill(spec)
  local skeleton = fk.CreateSkill(spec)
  pack:loadSkillSkels { skeleton }
  local skill = skeleton:createSkill()
  skill.package = pack
  Fk.skill_skels[skeleton.name] = skeleton
  Fk:addSkill(skill)
  return skill.name
end

local skills = {
  normal = createSkill { name = "hanjin_ascension_test__normal_skill" },
  monarch = createSkill { name = "hanjin_ascension_test__monarch_skill" },
  loyalty = createSkill { name = "hanjin_ascension_test__loyalty_skill" },
}

local function general(key, kingdom, hp, options)
  local name = "hanjin_ascension_test__" .. key
  local result = General:new(pack, name, kingdom, hp)
  result.hidden = false
  for field, value in pairs(options or {}) do result[field] = value end
  if not Fk.generals[name] then Fk:addGeneral(result) end
  return result
end

local G = {
  wei_normal = general("wei_normal", "wei", 3),
  wei_monarch = general("wei_monarch", "wei", 5),
  wei_normal2 = general("wei_normal2", "wei", 4),
  wei_monarch2 = general("wei_monarch2", "wei", 3),
  wei_normal3 = general("wei_normal3", "wei", 4),
  wei_monarch3 = general("wei_monarch3", "wei", 4),
  wei_deputy = general("wei_deputy", "wei", 4),
  shu_plain = general("shu_plain", "shu", 4),
  qun_plain = general("qun_plain", "qun", 4),
  wild_simple = general("wild_simple", "wild", 3),
  loyalty_simple = general("loyalty_simple", "wei", 5),
  wild_dual = general("wild_dual", "wild", 4),
  loyalty_dual = general("loyalty_dual", "wei", 4, { subkingdom = "jin" }),
  wild_blocked = general("wild_blocked", "wild", 4),
  loyalty_blocked = general("loyalty_blocked", "shu", 4),
}
G.wei_normal:addSkills({ skills.normal })
G.wei_monarch:addSkills({ skills.monarch })
G.loyalty_simple:addSkills({ skills.loyalty })
G.wei_normal:addCompanions(G.wei_deputy.name)
G.wei_monarch:addCompanions(G.wei_deputy.name)

-- Monarch versions must never appear in the normal pool.
G.wei_monarch.hidden = true
G.wei_monarch2.hidden = true
G.wei_monarch3.hidden = true

local Versions = require "packages.hanjin.pkg.hanjin_mode.rules.general_versions"
Versions.register { normal = G.wei_normal.name, lord = G.wei_monarch.name }
Versions.register { normal = G.wei_normal2.name, lord = G.wei_monarch2.name }
Versions.register { normal = G.wei_normal3.name, lord = G.wei_monarch3.name }
Versions.register { normal = G.wild_simple.name, loyalty = G.loyalty_simple.name }
Versions.register { normal = G.wild_dual.name, loyalty = G.loyalty_dual.name }
Versions.register { normal = G.wild_blocked.name, loyalty = G.loyalty_blocked.name }

Fk:loadTranslationTable {
  [pack.name] = "汉晋升变测试",
  [G.wei_normal.name] = "测试普通将·一",
  [G.wei_monarch.name] = "测试君主将·一",
  [G.wei_normal2.name] = "测试普通将·二",
  [G.wei_monarch2.name] = "测试君主将·二",
  [G.wei_normal3.name] = "测试普通将·三",
  [G.wei_monarch3.name] = "测试君主将·三",
  [G.wei_deputy.name] = "测试副将",
  [G.wild_simple.name] = "测试野心家将",
  [G.loyalty_simple.name] = "测试效忠将",
  [G.wild_dual.name] = "测试双势力野心家将",
  [G.loyalty_dual.name] = "测试双势力效忠将",
  [G.wild_blocked.name] = "测试被禁效忠将的原版",
  [G.loyalty_blocked.name] = "测试被禁效忠将",
  [skills.normal] = "测试普通技",
  [skills.monarch] = "测试君主技",
  [skills.loyalty] = "测试效忠技",
}

table.insert(Fk.game_modes.hanjin_heg_mode.whitelist, pack.name)
Fk:loadDisabled()

local content = {
  pack = pack,
  skills = skills,
  generals = G,
}

--- Place one position without revealing it; call inside FkTest.runInRoom.
function content.place(room, player, isDeputy, name)
  room:changeHero(player, name, false, isDeputy, false, false, false)
  room:setPlayerMark(player, isDeputy and "__heg_deputy" or "__heg_general", name)
  if not isDeputy then
    room:setPlayerMark(player, "__heg_wild",
      Fk.generals[name] and Fk.generals[name].kingdom == "wild" and 1 or 0)
  end
end

--- Set a hidden pair with an initial kingdom and pair-consistent HP.
function content.setupHidden(room, player, main, deputy, kingdom)
  content.place(room, player, false, main)
  if deputy ~= nil then content.place(room, player, true, deputy) end
  player:hideGeneral(false)
  if deputy ~= nil then player:hideGeneral(true) end
  room:setPlayerProperty(player, "kingdom", "unknown")
  room:setPlayerMark(player, "__heg_kingdom", kingdom)
  room:setPlayerMark(player, "__heg_init_kingdom", kingdom)
  room:setPlayerMark(player, "hasShownMainGeneral", 0)
  local maxHp = require("packages.hanjin.pkg.hanjin_mode.rules.ascension").pair_max_hp(main, deputy)
  room:setPlayerProperty(player, "maxHp", maxHp)
  room:setPlayerProperty(player, "hp", maxHp)
  return player
end

--- Set a revealed pair and kingdom.
function content.setupRevealed(room, player, main, deputy, kingdom)
  content.place(room, player, false, main)
  if deputy ~= nil then content.place(room, player, true, deputy) end
  room:setPlayerProperty(player, "kingdom", kingdom)
  room:setPlayerMark(player, "__heg_kingdom", kingdom)
  room:setPlayerMark(player, "__heg_init_kingdom", kingdom)
  room:setPlayerMark(player, "hasShownMainGeneral", 1)
  local maxHp = require("packages.hanjin.pkg.hanjin_mode.rules.ascension").pair_max_hp(main, deputy)
  room:setPlayerProperty(player, "maxHp", maxHp)
  room:setPlayerProperty(player, "hp", maxHp)
  return player
end

pack._ascension_content = content
return content
