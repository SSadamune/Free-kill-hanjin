local Session = require "packages.hanjin.pkg.hanjin_mode.rules.session"
local Cards = require "packages.hanjin.pkg.hanjin_mode.rules.cards"
local Ban = require "packages.hanjin.pkg.hanjin_mode.rules.faction_ban"
local Selection = require "packages.hanjin.pkg.hanjin_mode.rules.selection"
local Commander = require "packages.hanjin.pkg.hanjin_mode.rules.commander_retinue"
local Guest = require "packages.hanjin.pkg.hanjin_mode.rules.guest_factions"
local Pool = require "packages.hanjin.pkg.hanjin_mode.rules.general_pool"
local Versions = require "packages.hanjin.pkg.hanjin_mode.rules.general_versions"
local Ascension = require "packages.hanjin.pkg.hanjin_mode.rules.ascension"
local Discard = require "packages.hanjin.pkg.hanjin_mode.rules.general_discard"
local W = require "ui_emu.preferences"
local M = {}

local function getGeneral(name) return assert(Fk.generals[name], "Unknown general: " .. name) end

local function canPair(room, main, deputy)
  return Selection.canPair(room, main, deputy)
end

-- Reserve a legal pair for every seat, then fill the remaining offers without duplicates.
local function deal(room, players, count)
  local pool = table.simpleClone(room.general_pile)
  room:shuffleTable(pool)
  local offers = {}
  count = math.min(count, #pool // #players)
  assert(count >= 2, "Not enough generals for all national-war players")
  for _, player in ipairs(players) do
    local main, deputy
    for _, a in ipairs(pool) do
      for _, b in ipairs(pool) do
        if canPair(room, a, b) then main, deputy = a, b; break end
      end
      if main then break end
    end
    assert(main, "Not enough legal general pairs after faction bans")
    offers[player] = { main, deputy }
    table.removeOne(pool, main)
    table.removeOne(pool, deputy)
  end
  for _, player in ipairs(players) do
    for _ = 3, count do table.insert(offers[player], table.remove(pool)) end
    room:shuffleTable(offers[player])
  end
  room.general_pile = pool
  return offers
end

function M.create(base)
  local function getLogic()
    local parent = base.logic()
    local logic = parent:subclass("HanjinHegLogic")
    function logic:chooseGenerals()
      local room = self.room
      local pick = function(list, n) return room:tableRandomPick(list, n) end
      Discard.install()
      Discard.reset(room)
      -- Retinues are granted by the commander rules, never dealt as normal generals.
      Commander.excludeRetinuesFromPile(room)
      local previous = Session.consume(room)
      local cap = room:getSettings("hanjin_wild_count")
      if cap == nil then cap = 4 end
      -- BAN-001 input is the host's candidate selection, never the pile.
      local config = Ban.resolveSettings(function(key) return room:getSettings(key) end)
      room:setBanner("hanjin_candidate_kingdoms", config.candidates)
      room:setBanner("hanjin_kingdom_limit", config.limit)
      room:setTag("hanjin_candidate_kingdoms", config.candidates)
      room:setTag("hanjin_kingdom_limit", config.limit)
      local wildNames = table.filter(room.general_pile, function(name)
        return getGeneral(name).kingdom == "wild"
      end)
      -- The shared version plan owns the wild cap, the four-player replacement
      -- rule and loyalty-version faction filtering. Guest factions resolve on
      -- top of its kept list.
      local plan = Versions.plan(room, room.general_pile, previous, cap, pick, getGeneral,
        { candidates = config.candidates, limit = config.limit })
      room:setBanner("all_kingdoms", plan.allowed)
      room:setBanner("hanjin_banned_kingdoms", plan.banned)
      local built = Pool.resolve(room, plan, { wildNames = wildNames, getGeneral = getGeneral })
      Pool.apply(room, built)
      -- Also hide banned/excluded generals from same-name conversion and later random general requests.
      room:setTag("hanjin_excluded_generals", built.excluded)
      local translated = function(list) return table.concat(table.map(list, function(k) return Fk:translate(k) end), "/") end
      room:sendLog { type = "#HanjinFactionBan", arg = translated(plan.banned), arg2 = translated(plan.allowed) }
      local lord = room:getLord()
      room:setCurrent(lord)
      lord.role = "hidden"
      local offers = deal(room, room.players, math.max(room:getSettings("generalNum") or 5, 5))
      -- Per-game audit of voluntary re-draws and failed replacements.
      room:setTag("hanjin_guest_redraws_v1", {})
      room:setTag("hanjin_guest_redraw_failures_v1", {})
      -- Voluntary re-draw of guest candidates, including chained replacements,
      -- before the final main/deputy commitment.
      Selection.redraw(room, room.players, offers)
      local answers, kingdoms, fallbacks = Selection.choose(room, room.players, offers)
      local unused = {}
      for _, player in ipairs(room.players) do table.insertTable(unused, offers[player]) end
      for _, player in ipairs(room.players) do
        local answer = answers[player]
        local main, deputy = answer[1], answer[2]
        local kingdom = kingdoms[player]
        local legal = Guest.pairKingdoms(room, main, deputy)
        if not table.contains(legal, kingdom) then kingdom = legal[1] end
        for _, name in ipairs({ main, deputy }) do
          local original = table.find(unused, function(n)
            return n == name or not room:getSettings("disableSameConvert") and getGeneral(n).trueName == getGeneral(name).trueName
          end)
          assert(original, "Selected generals must consume different offered cards")
          table.removeOne(unused, original)
        end
        room:setPlayerGeneral(player, main, true)
        room:setDeputyGeneral(player, deputy)
        room:setPlayerMark(player, "__heg_general", main)
        room:setPlayerMark(player, "__heg_deputy", deputy)
        if getGeneral(main).kingdom == "wild" then room:setPlayerMark(player, "__heg_wild", 1) end
        room:setPlayerGeneral(player, "anjiang", true)
        room:setDeputyGeneral(player, "anjiang")
        room:setPlayerMark(player, "__heg_kingdom", kingdom)
        room:setPlayerMark(player, "__heg_init_kingdom", kingdom)
      end
      room:setTag("hanjin_selection_fallbacks", fallbacks)
      room:returnToGeneralPile(unused, "random")
    end
    return logic
  end

  -- Preserve upstream options except the switch which would disable the mandatory bans.
  local settings = table.clone(base.ui_settings)
  for _, group in ipairs(settings) do
    group._children = table.filter(group._children, function(item) return item._settingsKey ~= "notBanToFourKingdoms" end)
  end

  local function modeOf(uiSettings)
    return (uiSettings and uiSettings._mode) or {}
  end
  -- One switch per known regular kingdom. Future kingdoms registered through
  -- Ban.registerKingdom before mode creation are appended here automatically.
  local candidateSpec = { title = "hanjin_candidate_kingdoms" }
  for _, kingdom in ipairs(Ban.kingdoms) do
    table.insert(candidateSpec, W.SwitchRow {
      _settingsKey = Ban.candidatePrefix .. kingdom,
      title = "hanjin_candidate_" .. kingdom,
      value = function(uiSettings)
        return Ban.candidateValue(modeOf(uiSettings), kingdom)
      end,
    })
  end
  table.insert(candidateSpec, W.SpinRow {
    _settingsKey = Ban.limitKey, title = "hanjin_kingdom_limit", from = 1,
    to = function(uiSettings)
      return math.max(Ban.candidateCount(modeOf(uiSettings)), 1)
    end,
    value = function(uiSettings)
      local mode = modeOf(uiSettings)
      local value = mode[Ban.limitKey]
      if value == nil then return math.min(4, Ban.candidateCount(mode)) end
      return value
    end,
  })
  table.insert(settings, W.PreferenceGroup(candidateSpec))

  table.insert(settings, W.PreferenceGroup {
    title = "hanjin_rule_settings",
    W.SpinRow {
      _settingsKey = "hanjin_wild_count", title = "hanjin_wild_count", from = 0,
      to = function()
        local count = 0
        for _, g in pairs(Fk.generals) do
          if g.kingdom == "wild" and g.package.extensionName == "hanjin" then count = count + 1 end
        end
        return math.max(count, 4)
      end,
      value = function(settings)
        local value = (settings._mode or {}).hanjin_wild_count
        return value == nil and 4 or value
      end,
    },
  })
  local whitelist = { "hanjin_generals", "hanjin_cards", "hanjin_mode" }
  return fk.CreateGameMode {
    name = Session.mode, minPlayer = base.minPlayer, maxPlayer = base.maxPlayer,
    main_mode = base.main_mode, rule = Commander.RULE_SKILL, logic = getLogic,
    whitelist = whitelist, ui_settings = settings,
    winner_getter = Ascension.get_winner, surrender_func = base.surrenderFunc,
    is_counted = base.countInFunc, reward_punish = base.deathRewardAndPunish,
    friend_enemy_judge = base.friendEnemyJudge,
    feasible = function(self, settings)
      if not GameMode.feasible(self, settings) then return false end
      local function getSetting(key)
        if settings._mode and settings._mode[key] ~= nil then return settings._mode[key] end
        if settings._game and settings._game[key] ~= nil then return settings._game[key] end
        return settings[key]
      end
      if not pcall(Ban.resolveSettings, getSetting) then return false end
      local generals, cards = 0, 0
      for _, name in ipairs(self.whitelist) do
        local pack = Fk.packages[name]
        if pack then
          generals = generals + #table.filter(pack.generals, function(g)
            return not Commander.isRetinue(g.name)
          end)
          cards = cards + #pack.cards
        end
      end
      -- Empty formal content is intentional. Do not silently borrow reference generals/cards.
      return generals >= settings.playerNum * 2 and cards >= settings.playerNum * 4
    end,
    build_draw_pile = function(self)
      local draw, void = GameMode.buildDrawPile(self)
      local room = Fk:currentRoom()
      -- Candidate-excluded factions are as unavailable as banned factions for
      -- faction equipment/tricks, even when |C| <= L means no additional bans.
      local allowed = room:getBanner("all_kingdoms") or {}
      local unavailable = table.filter(Ban.kingdoms, function(kingdom)
        return not table.contains(allowed, kingdom)
      end)
      return Cards.apply(room, draw, void, unavailable)
    end,
  }
end

return M
