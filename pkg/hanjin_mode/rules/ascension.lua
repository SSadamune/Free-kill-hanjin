-- 汉晋升变通则：普通君主升变、君主死亡继位、野心家效忠升变共用的
-- 体力、明置、势力同步、标记和胜负处理。
--
-- 本模式不把君主版程序名写成含 "lord" 的名字，也不登记上游
-- HegUtil.lordGenerals。上游按名字识别的君主特例（有君无野、君主拉回
-- 超员野心家、君主死亡转野）因此不会抢先执行；汉晋在显式登记表上统一实现。
local H = require "packages.hegemony.util"
local Ban = require "packages.hanjin.pkg.hanjin_mode.rules.faction_ban"
local Guest = require "packages.hanjin.pkg.hanjin_mode.rules.guest_factions"
local Versions = require "packages.hanjin.pkg.hanjin_mode.rules.general_versions"
local PairHp = require "packages.hanjin.pkg.hanjin_mode.rules.pair_hp"
local M = {}

M.RULE_SKILL = "#hanjin_ascension_rule"
M.ASCEND_ACCEPT = "hanjin_lord_ascend"
M.ASCEND_KINGDOM = "hanjin_lord_ascend_kingdom"
M.WILD_ASCEND = "hanjin_wild_ascend"
M.TURNS_MARK = "hanjin_turns"
M.WILD_ASCENDED_MARK = "hanjin_wild_ascended"
M.COMPANION_MARK = "hanjin_ascension_companion"
M.YINYANG_MARK = "hanjin_ascension_yinyang"
M.LORD_DEATH_MARK = "hanjin_lord_death_done"

local function isUnknown(kingdom)
  return kingdom == nil or kingdom == "" or kingdom == "unknown"
end

function M.actual_main(player)
  return PairHp.actual_main(player)
end

function M.actual_deputy(player)
  return PairHp.actual_deputy(player)
end

function M.faction_of(player)
  if player == nil then return "unknown" end
  if player.kingdom == "wild" then return player.role or "wild" end
  return player.kingdom or "unknown"
end

--- 国战双将体力上限：主将贡献 + 副将贡献（均含主将/副将调整），向下取整。
--- 与开局接线共用 PairHp，因此应期的“☯️+2”在升变重算中也参与组合，而不是
--- 在既有体力上限上另加一次。
function M.pair_max_hp(main, deputy)
  return PairHp.max_hp(main, deputy) or 0
end

--- 势力人数预演。包含其他存活角色与已死亡的同势力角色；君主在场不豁免。
--- 角色已经属于目标势力时不再进行“首次确定势力”的转野判定。
function M.population_blocks(room, player, kingdom)
  if isUnknown(kingdom) or kingdom == "wild" then return true end
  if player.kingdom == kingdom then return false end
  local count = 0
  for _, other in ipairs(room.players) do
    if other ~= player and other.kingdom == kingdom then
      count = count + 1
    end
  end
  return count >= #room.players // 2
end

function M.has_lord(room, kingdom)
  if isUnknown(kingdom) or kingdom == "wild" then return false end
  for _, player in ipairs(room.alive_players) do
    if player.kingdom == kingdom and player.general ~= "anjiang"
      and Versions.is_lord(player.general)
      and Versions.lord_is_for(player.general, kingdom) then
      return true
    end
  end
  return false
end

function M.lord_player(room, kingdom)
  for _, player in ipairs(room.alive_players) do
    if player.kingdom == kingdom and player.general ~= "anjiang"
      and Versions.is_lord(player.general)
      and Versions.lord_is_for(player.general, kingdom) then
      return player
    end
  end
end

function M.other_unknown(room, player)
  return table.find(room.alive_players, function(other)
    return other ~= player and other.kingdom == "unknown"
  end) ~= nil
end

function M.is_first_turn(player)
  return (player:getMark(M.TURNS_MARK) or 0) == 0
end

--- 死亡继位候选人：主将（明置或暗置）能升变为死者所属势力的君主，
--- 且不会因加入后超员而转为野心家。
function M.lord_candidate(room, player, deadKingdom)
  if player == nil or player.dead then return nil end
  local main = M.actual_main(player)
  if main == nil then return nil end
  if player.general ~= "anjiang" and Versions.is_lord(main) then return nil end
  local lord = Versions.lord_version(main)
  if lord == nil or not Versions.lord_is_for(lord, deadKingdom) then return nil end
  if player.kingdom == "wild" then return nil end
  if not isUnknown(player.kingdom) and player.kingdom ~= deadKingdom then return nil end
  if player.general == "anjiang" and player:prohibitReveal() then return nil end
  if M.population_blocks(room, player, deadKingdom) then return nil end
  return { general = lord, kingdom = deadKingdom }
end

--- 准备阶段的野心家效忠候选。每个合法势力分别检查配将、人数与时机条件。
function M.wild_candidates(room, player)
  if player == nil or player.dead or player.general ~= "anjiang" then return {} end
  if player:getMark(M.WILD_ASCENDED_MARK) ~= 0 then return {} end
  local main = M.actual_main(player)
  if main == nil or Fk.generals[main] == nil or Fk.generals[main].kingdom ~= "wild" then return {} end
  if player:prohibitReveal() then return {} end
  local deputy = M.actual_deputy(player)
  if deputy == nil or Fk.generals[deputy] == nil then return {} end
  local allowed = room:getBanner("all_kingdoms") or {}
  local firstTurn = M.is_first_turn(player)
  local otherUnknown = M.other_unknown(room, player)
  local result, seen = {}, {}
  for _, loyalty in ipairs(Versions.loyalty_versions(main)) do
    local loyaltyGeneral = Fk.generals[loyalty]
    if loyaltyGeneral ~= nil then
      local kingdoms = Guest.pairKingdoms(room, loyalty, deputy, allowed)
      if #kingdoms == 0 then
        -- Fallback for content placed directly by tests without a room pool
        -- resolution; production games always have the Guest map.
        kingdoms = Ban.pairKingdoms(loyaltyGeneral, Fk.generals[deputy], allowed)
      end
      for _, kingdom in ipairs(kingdoms) do
        local key = loyalty .. ":" .. kingdom
        if not seen[key]
          and not M.population_blocks(room, player, kingdom)
          and (firstTurn or otherUnknown or M.has_lord(room, kingdom)) then
          seen[key] = true
          table.insert(result, { general = loyalty, kingdom = kingdom })
        end
      end
    end
  end
  return result
end

local function setPrivateRole(room, player, kingdom)
  room:setPlayerProperty(player, "role_shown", true)
  room:setPlayerProperty(player, "role", "hidden")
  player.role = kingdom
  room:notifyProperty(player, player, "role")
end

--- 执行一次升变。所有升变共用此流程，调用者负责在调用前复核资格。
function M.ascend(room, player, newMain, kingdom, options)
  options = options or {}
  assert(not player.dead, "A dead player cannot ascend")
  assert(not isUnknown(kingdom) and kingdom ~= "wild", "Ascension needs a regular kingdom")
  local newGeneral = Fk.generals[newMain]
  assert(newGeneral ~= nil, "Unknown ascension general: " .. tostring(newMain))
  assert(options.kind ~= "lord" or Versions.is_lord(newMain), "Lord ascension needs a lord version")
  assert(options.kind ~= "loyalty" or Versions.is_loyalty(newMain),
    "Loyalty ascension needs a loyalty version")

  local oldMain = M.actual_main(player)
  local deputy = M.actual_deputy(player)
  local oldPairMax = M.pair_max_hp(oldMain, deputy)
  local oldBothRevealed = player.general ~= "anjiang" and player.deputyGeneral ~= "anjiang"
    and player.deputyGeneral ~= ""

  room:changeHero(player, newMain, false, false, false, false, false)
  room:setPlayerMark(player, "__heg_general", newMain)
  room:setPlayerMark(player, "hasShownMainGeneral", 1)
  room:setPlayerMark(player, "__heg_kingdom", kingdom)
  if player:getMark(M.WILD_ASCENDED_MARK) == nil then room:setPlayerMark(player, M.WILD_ASCENDED_MARK, 0) end
  if options.kind == "loyalty" then
    room:setPlayerMark(player, M.WILD_ASCENDED_MARK, 1)
  end
  if options.clearWild then
    room:setPlayerMark(player, "__heg_wild", 0)
    room:setPlayerMark(player, "_wild_gained", 0)
    room:setPlayerMark(player, "__heg_join_wild", 0)
    room:setPlayerMark(player, "__heg_construct_wild", 0)
  end
  if oldMain ~= nil then room:setPlayerMark(player, "hanjin_previous_general", oldMain) end

  room:changeKingdom(player, kingdom)
  setPrivateRole(room, player, kingdom)
  room:sendLog {
    type = "#RevealGeneral",
    from = player.id,
    arg = "mainGeneral",
    arg2 = newMain,
  }
  room:sendLog {
    type = "#HanjinAscension",
    from = player.id,
    arg = oldMain or "",
    arg2 = newMain,
    arg3 = kingdom,
  }

  -- 明置主将，但不触发普通 GeneralRevealed；珠联璧合与阴阳鱼在此统一判定，
  -- 避免一次升变和普通明置事件重复发放消耗型标记。
  room.logic:trigger(fk.GeneralShown, player, { m = newMain })

  local newPairMax = M.pair_max_hp(newMain, deputy)
  if newPairMax > oldPairMax then
    room:setPlayerProperty(player, "maxHp", player.maxHp + 1)
    room:recover {
      who = player,
      num = 1,
      recoverBy = player,
      skillName = M.RULE_SKILL,
    }
  end

  local bothRevealed = player.general ~= "anjiang" and player.deputyGeneral ~= "anjiang"
    and player.deputyGeneral ~= ""
  if not oldBothRevealed and bothRevealed and deputy ~= nil then
    local mainGeneral = Fk.generals[newMain]
    local deputyGeneral = Fk.generals[deputy]
    if mainGeneral ~= nil and deputyGeneral ~= nil then
      if mainGeneral:isCompanionWith(deputyGeneral) and player:getMark(M.COMPANION_MARK) == 0 then
        room:setPlayerMark(player, M.COMPANION_MARK, 1)
        H.addHegMark(player, "companion")
      end
      local totalHp = PairHp.half_hp(newMain, deputy)
      if totalHp ~= nil and totalHp % 2 == 1 and player:getMark(M.YINYANG_MARK) == 0 then
        room:setPlayerMark(player, M.YINYANG_MARK, 1)
        H.addHegMark(player, "yinyangfish")
      end
    end
  end
  return true, { old_main = oldMain, old_pair_max = oldPairMax, new_pair_max = newPairMax }
end

--- 君主死亡时先把暗置武将牌翻至正面。此动作不是“明置”，不触发 GeneralShown。
function M.flip_lord_for_death(room, victim)
  for _, isDeputy in ipairs({ false, true }) do
    local position = isDeputy and victim.deputyGeneral or victim.general
    if position == "anjiang" then
      local name = victim:getMark(isDeputy and "__heg_deputy" or "__heg_general")
      if type(name) == "string" and Fk.generals[name] ~= nil then
        room:changeHero(victim, name, false, isDeputy, false, false, false)
        room:setPlayerMark(victim, isDeputy and "__heg_deputy" or "__heg_general", name)
        if not isDeputy then room:setPlayerMark(victim, "hasShownMainGeneral", 1) end
      end
    end
  end
  if victim.kingdom == "unknown" then
    local main = M.actual_main(victim)
    local general = main and Fk.generals[main]
    if general ~= nil and general.kingdom ~= "wild" then
      room:setPlayerProperty(victim, "kingdom", general.kingdom)
    end
  end
end

--- 死亡继位窗口。返回是否有人继位，以及死者所属势力。
function M.death_succession(room, victim)
  local main = M.actual_main(victim)
  if main == nil or not Versions.is_lord(main) then return false, nil end
  local kingdoms = Versions.lord_kingdoms(main)
  local deadKingdom = table.contains(kingdoms, victim.kingdom) and victim.kingdom or kingdoms[1]
  M.flip_lord_for_death(room, victim)
  if deadKingdom == nil then return false, nil end

  local candidates = table.filter(room.alive_players, function(player) return player ~= victim end)
  room:sortByAction(candidates)
  for _, candidate in ipairs(candidates) do
    if M.lord_candidate(room, candidate, deadKingdom) ~= nil then
      local choice = room:askToChoice(candidate, {
        choices = { M.ASCEND_ACCEPT, "Cancel" },
        skill_name = M.RULE_SKILL,
        prompt = "#HanjinSecondLordSuccession",
      })
      if choice == M.ASCEND_ACCEPT then
        -- 询问期间状态可能改变；提交时再次复核，失败则继续询问下一人。
        local current = M.lord_candidate(room, candidate, deadKingdom)
        if current ~= nil then
          M.ascend(room, candidate, current.general, current.kingdom, { kind = "succession" })
          return true, deadKingdom
        end
      end
    end
  end
  return false, deadKingdom
end

--- 君主死亡无人继位时的转野结算。已有野心家保持原势力，不因继位回归。
function M.convert_to_wild(room, victim, kingdom)
  if isUnknown(kingdom) then return end
  for _, player in ipairs(room.players) do
    if player ~= victim and player.kingdom ~= "wild" then
      local matches = player.kingdom == kingdom
        or player:getMark("__heg_kingdom") == kingdom
        or (player.dead and player.kingdom == kingdom)
      if matches then
        room:setPlayerMark(player, "__heg_kingdom", "wild")
        -- Set the server-side role even while the character is hidden, so a
        -- later reveal does not enter the upstream heg_* wild-founding chooser.
        player.role = "wild"
        if player.kingdom ~= "unknown" then
          room:setPlayerProperty(player, "kingdom", "wild")
          room:sendLog {
            type = "#HanjinLordDeathWild",
            from = player.id,
            arg = kingdom,
          }
        end
      end
    end
  end
end

function M.on_before_game_over(room, victim)
  if victim:getMark(M.LORD_DEATH_MARK) == 1 then return end
  local main = M.actual_main(victim)
  if main == nil or not Versions.is_lord(main) then return end
  room:setPlayerMark(victim, M.LORD_DEATH_MARK, 1)
  local inherited, kingdom = M.death_succession(room, victim)
  if not inherited then M.convert_to_wild(room, victim, kingdom) end
end

function M.reset(room)
  if room == nil then return end
  room:setTag("hanjin_ascension", nil)
  for _, player in ipairs(room.players) do
    room:setPlayerMark(player, M.TURNS_MARK, 0)
    room:setPlayerMark(player, M.WILD_ASCENDED_MARK, 0)
    room:setPlayerMark(player, M.COMPANION_MARK, 0)
    room:setPlayerMark(player, M.YINYANG_MARK, 0)
    room:setPlayerMark(player, M.LORD_DEATH_MARK, 0)
  end
end

function M.on_turn_start(room, player)
  if player.dead or not M.is_first_turn(player) or player.general ~= "anjiang" then return end
  local main = M.actual_main(player)
  if main == nil or Fk.generals[main] == nil or Fk.generals[main].kingdom == "wild" then return end
  local lord = Versions.lord_version(main)
  if lord == nil or player:prohibitReveal() then return end
  local allowed = room:getBanner("all_kingdoms") or {}
  local kingdoms = table.filter(Versions.lord_kingdoms(lord), function(kingdom)
    return table.contains(allowed, kingdom)
      and not M.has_lord(room, kingdom)
      and not M.population_blocks(room, player, kingdom)
  end)
  local initial = player:getMark("__heg_kingdom")
  if table.contains(kingdoms, initial) then kingdoms = { initial } end
  if #kingdoms == 0 then return end

  local choice
  if #kingdoms == 1 then
    choice = room:askToChoice(player, {
      choices = { M.ASCEND_ACCEPT, "Cancel" },
      skill_name = M.RULE_SKILL,
      prompt = "#HanjinSecondLordConvert",
    })
  else
    local choices = table.map(kingdoms, function(kingdom)
      return M.ASCEND_KINGDOM .. "::" .. kingdom
    end)
    table.insert(choices, "Cancel")
    choice = room:askToChoice(player, {
      choices = choices,
      skill_name = M.RULE_SKILL,
      prompt = "#HanjinSecondLordConvert",
    })
  end
  local kingdom = kingdoms[1]
  if choice ~= M.ASCEND_ACCEPT and choice ~= "Cancel" then
    local parts = choice:split("::")
    if parts[1] == M.ASCEND_KINGDOM and table.contains(kingdoms, parts[2]) then kingdom = parts[2] end
  end
  if choice == M.ASCEND_ACCEPT or choice:startsWith(M.ASCEND_KINGDOM .. "::") then
    if not M.has_lord(room, kingdom) and not M.population_blocks(room, player, kingdom) then
      M.ascend(room, player, lord, kingdom, { kind = "lord" })
    end
  end
end

function M.on_preparation(room, player)
  if player.dead or player.general ~= "anjiang" then return end
  local candidates = M.wild_candidates(room, player)
  if #candidates == 0 then return end
  local choices = table.map(candidates, function(candidate)
    return M.WILD_ASCEND .. "::" .. candidate.kingdom .. "::" .. candidate.general
  end)
  table.insert(choices, "Cancel")
  local choice = room:askToChoice(player, {
    choices = choices,
    skill_name = M.RULE_SKILL,
    prompt = "#HanjinWildAllegiance",
  })
  if choice == "Cancel" then return end
  local parts = choice:split("::")
  if parts[1] ~= M.WILD_ASCEND then return end
  local kingdom, general = parts[2], parts[3]
  local found
  for _, candidate in ipairs(M.wild_candidates(room, player)) do
    if candidate.kingdom == kingdom and candidate.general == general then found = candidate; break end
  end
  if found == nil then return end
  M.ascend(room, player, found.general, found.kingdom, { kind = "loyalty", clearWild = true })
end

function M.on_turn_end(room, player)
  room:setPlayerMark(player, M.TURNS_MARK, (player:getMark(M.TURNS_MARK) or 0) + 1)
end

--- 判定存活角色与锚点是否属于同一预期势力。野心家（明置或暗置）始终独立；
--- 暗将只在已登记的预期势力与锚点一致时归并，unknown 不得互相算作同势力。
local function same_expected_faction(player, anchor, anchorKingdom)
  if player == anchor then return true end
  if player.kingdom == "wild" then return false end
  if isUnknown(player.kingdom) then
    local expected = player:getMark("__heg_kingdom")
    return type(expected) == "string" and not isUnknown(expected)
      and expected ~= "wild" and expected == anchorKingdom
  end
  return player.kingdom == anchorKingdom
end

--- 汉晋胜负判定。只取决于场上是否只剩唯一势力；君主与势力人数均不参与。
--- 各野心家始终为独立势力；暗置角色按预期势力归并，unknown 本身不是势力。
function M.get_winner(self, victim)
  local room = victim.room
  local alive = table.filter(room.alive_players, function(player) return not player.surrendered end)
  if #alive == 0 then return "" end
  if #alive == 1 then return alive end
  local anchor
  for _, player in ipairs(alive) do
    if not isUnknown(player.kingdom) then anchor = player; break end
  end
  -- 全部暗置时不能把 unknown 当成一个共同势力。
  if anchor == nil or anchor.kingdom == "wild" then return "" end
  local anchorKingdom = anchor.kingdom
  for _, player in ipairs(alive) do
    if not same_expected_faction(player, anchor, anchorKingdom) then return "" end
  end

  for _, player in ipairs(room.players) do
    if player.general == "anjiang" then
      room:setPlayerProperty(player, "general", player:getMark("__heg_general"))
    end
    if player.deputyGeneral == "anjiang" then
      room:setPlayerProperty(player, "deputyGeneral", player:getMark("__heg_deputy"))
    end
  end
  return alive
end

return M
