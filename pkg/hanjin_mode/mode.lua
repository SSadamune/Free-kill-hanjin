local Ban = require "packages.hanjin.pkg.hanjin_mode.rules.faction_ban"
local Session = require "packages.hanjin.pkg.hanjin_mode.rules.session"
local Cards = require "packages.hanjin.pkg.hanjin_mode.rules.cards"
local Selection = require "packages.hanjin.pkg.hanjin_mode.rules.selection"
local W = require "ui_emu.preferences"
local M = {}

local function getGeneral(name) return assert(Fk.generals[name], "Unknown general: " .. name) end

local function canPair(main, deputy, allowed)
  return main ~= deputy and #Ban.pairKingdoms(getGeneral(main), getGeneral(deputy), allowed) > 0
end

-- Reserve a legal pair for every seat, then fill the remaining offers without duplicates.
local function deal(room, players, count, allowed)
  local pool = table.simpleClone(room.general_pile)
  room:shuffleTable(pool)
  local offers = {}
  count = math.min(count, #pool // #players)
  assert(count >= 2, "Not enough generals for all national-war players")
  for _, player in ipairs(players) do
    local main, deputy
    for _, a in ipairs(pool) do
      for _, b in ipairs(pool) do
        if canPair(a, b, allowed) then main, deputy = a, b; break end
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
  local flat = {}
  for _, player in ipairs(players) do table.insertTable(flat, offers[player]) end
  room.general_pile = pool
  return flat, offers
end

function M.create(base)
  local function getLogic()
    local parent = base.logic()
    local logic = parent:subclass("HanjinHegLogic")
    function logic:chooseGenerals()
      local room = self.room
      local pick = function(list, n) return room:tableRandomPick(list, n) end
      local previous = Session.consume(room)
      local plan = Ban.plan(Ban.collectKingdoms(room.general_pile, getGeneral), previous, pick)
      local cap = room:getSettings("hanjin_wild_count")
      if cap == nil then cap = 4 end
      local kept, excluded = Ban.filterGenerals(room.general_pile, plan.allowed, cap, pick, getGeneral)
      room.general_pile = kept
      -- Also hide banned generals from same-name conversion and later random general requests.
      table.insertTableIfNeed(room.disabled_generals, excluded)
      room:setBanner("all_kingdoms", plan.allowed)
      room:setBanner("hanjin_banned_kingdoms", plan.banned)
      room:setTag("hanjin_excluded_generals", excluded)
      local translated = function(list) return table.concat(table.map(list, function(k) return Fk:translate(k) end), "/") end
      room:sendLog { type = "#HanjinFactionBan", arg = translated(plan.banned), arg2 = translated(plan.allowed) }
      local lord = room:getLord()
      room:setCurrent(lord)
      lord.role = "hidden"
      local flat, offers = deal(room, room.players, math.max(room:getSettings("generalNum") or 5, 5), plan.allowed)
      local answers, extras = Selection.ask(room, room.players, offers, plan.allowed)
      local unused = table.simpleClone(flat)
      local fallbacks = {}
      for _, player in ipairs(room.players) do
        local answer = answers[player] or {}
        local function offered(name)
          local g = Fk.generals[name]
          return g and Fk:canUseGeneral(name) and table.find(offers[player], function(original)
            return original == name or not room:getSettings("disableSameConvert") and getGeneral(original).trueName == g.trueName
          end)
        end
        local main, deputy = answer[1], answer[2]
        if not (offered(main) and offered(deputy) and canPair(main, deputy, plan.allowed)
          and (room:getSettings("disableSameConvert") or getGeneral(main).trueName ~= getGeneral(deputy).trueName)) then
          table.insert(fallbacks, player.id)
          main, deputy = nil, nil
          for _, a in ipairs(offers[player]) do
            for _, b in ipairs(offers[player]) do
              if canPair(a, b, plan.allowed) then main, deputy = a, b; break end
            end
            if main then break end
          end
        end
        local kingdoms = Ban.pairKingdoms(getGeneral(main), getGeneral(deputy), plan.allowed)
        local kingdom = extras[player] and extras[player].kingdom
        if not table.contains(kingdoms, kingdom) then kingdom = pick(kingdoms, 1)[1] end
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
    main_mode = base.main_mode, rule = base.rule, logic = getLogic,
    whitelist = whitelist, ui_settings = settings,
    winner_getter = base.getWinner, surrender_func = base.surrenderFunc,
    is_counted = base.countInFunc, reward_punish = base.deathRewardAndPunish,
    friend_enemy_judge = base.friendEnemyJudge,
    feasible = function(self, settings)
      if not GameMode.feasible(self, settings) then return false end
      local generals, cards = 0, 0
      for _, name in ipairs(self.whitelist) do
        local pack = Fk.packages[name]
        if pack then generals = generals + #pack.generals; cards = cards + #pack.cards end
      end
      -- Empty formal content is intentional. Do not silently borrow reference generals/cards.
      return generals >= settings.playerNum * 2 and cards >= settings.playerNum * 4
    end,
    build_draw_pile = function(self)
      local draw, void = GameMode.buildDrawPile(self)
      local room = Fk:currentRoom()
      return Cards.apply(room, draw, void, room:getBanner("hanjin_banned_kingdoms") or {})
    end,
  }
end

return M
