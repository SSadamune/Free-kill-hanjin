-- Test-only independent content for the general exchange rule.  It is never
-- referenced by init.lua and never enters the release content.  The generals
-- are hidden so they cannot leak into any mode's selection pool; tests place
-- them explicitly with Room:changeHero.
if Fk.packages.hanjin_exchange_test then
  return Fk.packages.hanjin_exchange_test._exchange_content
end

local pack = Package:new("hanjin_exchange_test", Package.CardPack)
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
  return skill
end

local names = {
  limited = "hanjin_exchange_test__limited",
  round = "hanjin_exchange_test__round",
  branch = "hanjin_exchange_test__branch",
  switch = "hanjin_exchange_test__switch",
  mainonly = "hanjin_exchange_test__mainonly",
  deputyonly = "hanjin_exchange_test__deputyonly",
  pile = "hanjin_exchange_test__pile",
  pile_other = "hanjin_exchange_test__pile_other",
  shared = "hanjin_exchange_test__shared",
  retinue = "hanjin_exchange_test__retinue_skill",
}

createSkill { name = names.limited, max_game_use_time = 1 }
createSkill { name = names.round, max_round_use_time = 1 }
createSkill {
  name = names.branch,
  history_branch = "alpha",
  max_branches_use_time = { alpha = { [Player.HistoryRound] = 1 } },
}
createSkill { name = names.switch, tags = { Skill.Switch } }
createSkill { name = names.mainonly, tags = { Skill.MainPlace } }
createSkill { name = names.deputyonly, tags = { Skill.DeputyPlace } }
createSkill { name = names.pile, derived_piles = "hanjin_exchange_tian" }
createSkill { name = names.pile_other, derived_piles = "hanjin_exchange_other" }
createSkill { name = names.shared }
createSkill { name = names.retinue }

local function general(key, kingdom, hp, skills, options)
  local name = "hanjin_exchange_test__" .. key
  local result = General:new(pack, name, kingdom, hp)
  result.hidden = true
  if skills then result:addSkills(skills) end
  for field, value in pairs(options or {}) do result[field] = value end
  -- Test packages are created after the engine's normal package install, so
  -- register the general explicitly when it is not already known.
  if not Fk.generals[name] then Fk:addGeneral(result) end
  return result
end

local G = {
  wei_a = general("wei_a", "wei", 4, { names.limited, names.mainonly }),
  wei_b = general("wei_b", "wei", 4, { names.round, names.branch, names.switch }),
  wei_c = general("wei_c", "wei", 4, { names.limited, names.shared }),
  shared_deputy = general("shared_deputy", "wei", 4, { names.shared }),
  deputy = general("deputy", "wei", 4, { names.deputyonly }),
  pile_a = general("pile_a", "wei", 4, { names.pile }),
  pile_b = general("pile_b", "wei", 4, { names.pile }),
  pile_c = general("pile_c", "wei", 4, { names.pile }),
  pile_other = general("pile_other", "wei", 4, { names.pile_other }),
  hp = general("hp", "wei", 4, nil, { mainMaxHpAdjustedValue = 2 }),
  plain = general("plain", "wei", 4),
  plain2 = general("plain2", "wei", 4),
  lord = general("lord_wei", "wei", 4),
  wild = general("wild_wei", "wild", 4),
  retinue = general("retinue", "wei", 4, { names.retinue }),
  shu = general("shu_a", "shu", 4),
}

local Exchange = require "packages.hanjin.pkg.hanjin_mode.rules.general_exchange"
Exchange.registerSoldierGeneral(G.retinue.name, "retinue")

Fk:loadTranslationTable {
  [names.limited] = "测试限定技",
  [names.round] = "测试轮次技",
  [names.branch] = "测试分支技",
  [names.switch] = "测试转换技",
  [names.mainonly] = "测试主将技",
  [names.deputyonly] = "测试副将技",
  [names.pile] = "测试牌堆技",
  [names.shared] = "测试同名技",
  [names.retinue] = "测试翼从技",
}

Fk:loadDisabled()

local content = {
  pack = pack,
  skills = names,
  generals = G,
  pile = "hanjin_exchange_tian",

  --- Place a revealed general into one position.  Call inside FkTest.runInRoom.
  place = function(room, player, isDeputy, generalName)
    room:changeHero(player, generalName, false, isDeputy, false, false, false)
    room:setPlayerMark(player, isDeputy and "__heg_deputy" or "__heg_general", generalName)
    if not isDeputy then
      room:setPlayerMark(player, "__heg_wild",
        Fk.generals[generalName] and Fk.generals[generalName].kingdom == "wild" and 1 or 0)
    end
  end,

  --- Place both positions and set the player's current kingdom.
  setup = function(room, player, main, deputy, kingdom)
    local place = function(isDeputy, generalName)
      if generalName then
        room:changeHero(player, generalName, false, isDeputy, false, false, false)
        room:setPlayerMark(player, isDeputy and "__heg_deputy" or "__heg_general", generalName)
        if not isDeputy then
          room:setPlayerMark(player, "__heg_wild",
            Fk.generals[generalName] and Fk.generals[generalName].kingdom == "wild" and 1 or 0)
        end
      end
    end
    place(false, main)
    place(true, deputy)
    if kingdom then room:setPlayerProperty(player, "kingdom", kingdom) end
    return player
  end,

  --- Draw `count` physical cards into a named pile.
  putPile = function(room, player, pileName, count)
    local ids = room:getNCards(count)
    player:addToPile(pileName, ids, true)
    return ids
  end,

  use = function(room, player, skillName, skillData)
    if not skillData and skillName == names.branch then
      -- The engine only uses a skill-declared history branch when a cost_data
      -- table is supplied to this direct invocation helper.
      skillData = { from = player, cost_data = { history_branch = "alpha" } }
    end
    room:useSkill(player, assert(Fk.skills[skillName]), function() end, skillData)
  end,
}

pack._exchange_content = content
return content
