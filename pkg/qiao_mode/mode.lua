local Session = require "packages.qiao.pkg.qiao_mode.rules.session"
local SlashUseTiming = require "packages.qiao.pkg.qiao_mode.rules.slash_use_timing"
local EquipmentExchange = require "packages.qiao.pkg.qiao_mode.rules.equipment_exchange"
local Modes = require "packages.qiao.pkg.qiao_mode.modes"
local Cards = require "packages.qiao.pkg.qiao_mode.rules.cards"
local Ban = require "packages.qiao.pkg.qiao_mode.rules.faction_ban"
local Selection = require "packages.qiao.pkg.qiao_mode.rules.selection"
local Commander = require "packages.qiao.pkg.qiao_mode.rules.commander_retinue"
local Guest = require "packages.qiao.pkg.qiao_mode.rules.guest_factions"
local Pool = require "packages.qiao.pkg.qiao_mode.rules.general_pool"
local Versions = require "packages.qiao.pkg.qiao_mode.rules.general_versions"
local Ascension = require "packages.qiao.pkg.qiao_mode.rules.ascension"
local PairHp = require "packages.qiao.pkg.qiao_mode.rules.pair_hp"
local WeiHistory = require "packages.qiao.pkg.qiao_mode.rules.wei_history"
local WuHistory = require "packages.qiao.pkg.qiao_mode.rules.wu_history"
local Discard = require "packages.qiao.pkg.qiao_mode.rules.general_discard"
local Variants = require "packages.qiao.pkg.qiao_mode.rules.variants"
local KingdomSize = require "packages.qiao.pkg.qiao_mode.rules.kingdom_size"
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"
local ActiveSkillLimits = require "packages.qiao.pkg.qiao_mode.rules.active_skill_limits"
local MandatoryCards = require "packages.qiao.pkg.qiao_mode.rules.mandatory_cards"
local FaqRules = require "packages.qiao.pkg.qiao_mode.rules.faq_core_rules"
local SkillPrelight = require "packages.qiao.pkg.qiao_mode.rules.skill_prelight"
local TriggerSelection = require "packages.qiao.pkg.qiao_mode.rules.trigger_selection"
local W = require "ui_emu.preferences"
local M = {}

-- 大小势力/玉玺公共查询：服务器与客户端都只在本模式安装。
function M.installRules()
  KingdomSize.install()
  Ascension.installFoundingCountries()
  FaqRules.install()
  SlashUseTiming.installCardChecks()
end

local function getGeneral(name) return assert(Fk.generals[name], "Unknown general: " .. name) end

local function canPair(room, main, deputy)
  return Selection.canPair(room, main, deputy)
end

local MAX_OFFERS = 10

local function offerCount(value, kingdomLimit)
  return math.max(kingdomLimit + 1, math.min(value or 7, MAX_OFFERS))
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

function M.create(base, name)
  local collection = name == Modes.collection
  local resolveSettings = collection and Ban.resolveCollectionSettings or Ban.resolveSettings
  local function getLogic()
    local parent = base.logic()
    local logic = parent:subclass("QiaoHegLogic")
    function logic:chooseGenerals()
      local room = self.room
      Variants.apply(room)
      local pick = function(list, n) return room:tableRandomPick(list, n) end
      Discard.install()
      Discard.reset(room)
      -- Retinues are granted by the commander rules, never dealt as normal generals.
      Commander.excludeRetinuesFromPile(room)
      local previous = Session.consume(room)
      local cap = room:getSettings("qiao_wild_count")
      cap = math.min(cap or 4, 12)
      -- BAN-001 input is the host's candidate selection, never the pile.
      local config = resolveSettings(function(key) return room:getSettings(key) end)
      room:setBanner("qiao_candidate_kingdoms", config.candidates)
      room:setBanner("qiao_kingdom_limit", config.limit)
      room:setTag("qiao_candidate_kingdoms", config.candidates)
      room:setTag("qiao_kingdom_limit", config.limit)
      local wildNames = table.filter(room.general_pile, function(name)
        return getGeneral(name).kingdom == "wild"
      end)
      -- The shared version plan owns the wild cap, the four-player replacement
      -- rule and loyalty-version faction filtering. Guest factions resolve on
      -- top of its kept list.
      local plan = Versions.plan(room, room.general_pile, previous, cap, pick, getGeneral,
        { candidates = config.candidates, limit = config.limit, guestReplacement = Guest.replacementEnabled(room) })
      room:setBanner("all_kingdoms", plan.allowed)
      room:setBanner("qiao_banned_kingdoms", plan.banned)
      local built = Pool.resolve(room, plan, { wildNames = wildNames, getGeneral = getGeneral })
      Pool.apply(room, built)
      -- Also hide banned/excluded generals from same-name conversion and later random general requests.
      room:setTag("qiao_excluded_generals", built.excluded)
      local translated = function(list) return table.concat(table.map(list, function(k) return Fk:translate(k) end), "/") end
      room:sendLog { type = "#QiaoFactionBan", arg = translated(plan.banned), arg2 = translated(plan.allowed) }
      local lord = room:getLord()
      room:setCurrent(lord)
      lord.role = "hidden"
      local offers = deal(room, room.players, offerCount(room:getSettings("qiao_offer_count"), #plan.allowed))
      -- Per-game audit of voluntary re-draws and failed replacements.
      room:setTag("qiao_guest_redraws_v1", {})
      room:setTag("qiao_guest_redraw_failures_v1", {})
      local answers, kingdoms, fallbacks = Selection.choose(room, room.players, offers)
      local freeAssign = Selection.freeAssign(room)
      local unused, selected = {}, {}
      for _, player in ipairs(room.players) do table.insertTable(unused, offers[player]) end
      -- Resolve all normal results before any ensureFree call can change a
      -- shared name's stored affiliations.
      local normalPairs = {}
      for _, player in ipairs(room.players) do
        local answer = answers[player]
        normalPairs[player] = Guest.pairKingdoms(room, answer[1], answer[2])
      end
      for _, player in ipairs(room.players) do
        local answer = answers[player]
        local main, deputy = answer[1], answer[2]
        local kingdom = kingdoms[player]
        local freeAssigned = freeAssign and not table.contains(fallbacks, player.id)
        local normal = normalPairs[player]
        local freeFallback = freeAssigned and #normal == 0
        local legal = normal
        if freeFallback then
          legal = Guest.freePairKingdoms(room, main, deputy)
          if #legal == 0 then legal = { Guest.fallbackKingdom(room) } end
        end
        if not table.contains(legal, kingdom) then kingdom = legal[1] end
        -- Keep a normally resolved guest faction intact; only fill missing data
        -- when free assignment had to fall back outside the normal rule.
        if freeFallback then Guest.ensureFree(room, { main, deputy }) end
        selected[main], selected[deputy] = true, true
        for _, name in ipairs({ main, deputy }) do
          local original = table.find(unused, function(n)
            if freeAssigned then return n == name end
            return n == name or not room:getSettings("disableSameConvert") and getGeneral(n).trueName == getGeneral(name).trueName
          end)
          if original then
            table.removeOne(unused, original)
          elseif not freeAssigned then
            assert(false, "Selected generals must consume different offered cards")
          else
            -- An outside free-assigned card must not stay drawable from the pile.
            table.removeOne(room.general_pile, name)
          end
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
      room:setTag("qiao_selection_fallbacks", fallbacks)
      -- Under free assignment a selected exact card may have come from another
      -- player's offers; never put any selected card back into the general pile.
      if freeAssign then unused = Selection.pruneUnused(unused, selected) end
      room:returnToGeneralPile(unused, "random")
    end
    -- 开局体力上限：引擎（上游 HegLogic:broadcastGeneral）按双将组合写入
    -- maxHp / hp / HalfMaxHpLeft。这里在同一开局时点补上配将体力贡献修正
    -- （应期的半格及双 2.5 上限），不等待明置；普通交换/移除/替换不重算，
    -- 升变另走 ascension.lua 的公共流程。
    local baseBroadcastGeneral = parent.broadcastGeneral
    function logic:broadcastGeneral()
      if baseBroadcastGeneral then baseBroadcastGeneral(self) end
      for _, player in ipairs(self.room.players) do
        PairHp.apply_start(self.room, player)
      end
    end
    -- 长驱需要的“本回合实际伤害目标”由模式级全局记录器提供，必须在第一个事件
    -- 之前安装；与长驱武将是否已选、明置或之后换将无关。
    local baseStart = parent.start or GameLogic.start
    function logic:start()
      if collection then
        local settings = self.room.settings
        settings._mode = settings._mode or {}
        settings._mode.generalTimeout = settings._mode.generalTimeout or Selection.defaultTimeout
      end
      RemovedTargets.installServer(self.room)
      TriggerSelection.install(self.room)
      MandatoryCards.install(self.room)
      FaqRules.installServer(self.room)
      Ascension.installTurnReveal()
      require("packages.qiao.pkg.qiao_generals.util.mifuren_reveal").install(self.room)
      SkillPrelight.installServer()
      -- 普通出牌请求的主动技次数声明在 useSkill 前统一校验；只安装到本房间。
      ActiveSkillLimits.installServer(self.room)
      SlashUseTiming.installServer(self.room)
      EquipmentExchange.installServer(self)
      self.room:addSkill(WeiHistory.HISTORY_SKILL)
      self.room:addSkill(WeiHistory.WEIKUI_DISTANCE_SKILL)
      WuHistory.installServer(self.room)
      self.room:addSkill(WuHistory.HISTORY_SKILL)
      self.room:addSkill(WuHistory.DISTANCE_SKILL)
      self.room:addSkill("qiao__wu_turn_effects")
      self.room:addSkill("qiao__wu_dimeng_expiry")
      self.room:addSkill("#qiao_initial_prelight")
      self.room:addSkill("#qiao_minsi_display")
      self.room:addSkill("qiao__shu_lieyong_bonus")
      self.room:addSkill("qiao__shu_state_rule")
      self.room:addSkill("qiao__shu_savage_rule")
      self.room:addSkill("qiao__shu_tieqi_invalidity")
      self.room:addSkill("qiao__qun_dying_rule")
      self.room:addSkill("qiao__qun_cards_rule")
      self.room:addSkill("qiao__qun_damage_history")
      self.room:addSkill("qiao__qun_control_rule")
      self.room:addSkill("qiao__qun_duanchang_rule")
      self.room:addSkill("qiao__jin_resources_rule")
      self.room:addSkill("qiao__jin_deck_rule")
      self.room:addSkill("qiao__jin_information_rule")
      self.room:addSkill("#qiao_pindian_display")
      self.room:addSkill("qiao__jin_adaptation_rule")
      self.room:addSkill("qiao__jin_sources_rule")
      self.room:addSkill("qiao__zhen_shi_history_rule")
      require("packages.qiao.pkg.qiao_mode.rules.skill_sources").install(self.room)
      require("packages.qiao.pkg.qiao_mode.rules.marker_cards").install()
      self.room:addSkill("qiao__skill_jin022b_range")
      self.room:addSkill("qiao__general_card_skills_rule")
      self.room:addSkill("qiao__lord_flag_display")
      self.room:addSkill("qiao__em_jin001_double_rule")
      self.room:addSkill("qiao__linxiao_yuyu_rule")
      self.room:addSkill("qiao__dual_mount_rule")
      self.room:addSkill("qiao__faction_trick_rule")
      self.room:addSkill("qiao__luoshui_rule")
      self.room:addSkill("qiao__removed_player_rule")
      self.room:addSkill("qiao__zhoujun_turn_bonus")
      for _, player in ipairs(self.room.players) do
        player:addFakeSkill("qiao__alliance")
      end
      -- 晋将公开用牌历史：仅汉晋模式安装，供武库及客户端公开读取。
      local JinHistory = Fk.skills["#qiao_zhen_shi_jin_history"]
      if JinHistory ~= nil then self.room:addSkill(JinHistory) end
      local RetinueSources = require "packages.qiao.pkg.qiao_generals.util.retinue_instance_sources"
      RetinueSources.ensureRule(self.room)
      if baseStart then return baseStart(self) end
    end
    return logic
  end

  local settings = collection and {} or table.clone(base.ui_settings)
  for _, group in ipairs(settings) do
    group._children = table.filter(group._children, function(item)
      return item._settingsKey ~= "notBanToFourKingdoms" and item._settingsKey ~= "old_battle_royal"
    end)
  end

  local function modeOf(uiSettings)
    return (uiSettings and uiSettings._mode) or {}
  end
  local function uiKingdomLimit(settings)
    local mode = modeOf(settings)
    if collection then
      return resolveSettings(function(key) return mode[key] end).limit
    end
    return math.max(1, math.min(mode[Ban.limitKey] or 4, Ban.candidateCount(mode)))
  end

  local function checkbox(key, title)
    local row = W.SwitchRow {
      _settingsKey = key, title = title,
      value = function(uiSettings) return modeOf(uiSettings)[key] ~= false end,
    }
    row._qml = { url = "packages/qiao/pkg/qiao_mode/qml/CheckRow.qml" }
    return row
  end

  local candidateSpec = { title = "qiao_candidate_kingdoms" }
  if collection then candidateSpec.subTitle = "qiao_collection_candidates_help" end
  local candidateSwitches = collection and Ban.optionalCollectionKingdoms or Ban.kingdoms
  for _, kingdom in ipairs(candidateSwitches) do
    local title = (kingdom == "han" or kingdom == "jin") and "qiao_enable_" .. kingdom
      or Ban.candidatePrefix .. kingdom
    table.insert(candidateSpec, W.SwitchRow {
      _settingsKey = Ban.candidatePrefix .. kingdom,
      title = title,
      value = function(uiSettings)
        if collection then return modeOf(uiSettings)[Ban.candidatePrefix .. kingdom] ~= false end
        return Ban.candidateValue(modeOf(uiSettings), kingdom)
      end,
    })
  end
  -- RoomInfoContainer lists direct children only. The group carries the
  -- display value, while its nested switches keep their original settings.
  local candidateGroup = W.PreferenceGroup(candidateSpec)
  candidateGroup._qml = { url = "packages/qiao/pkg/qiao_mode/qml/CandidateGroup.qml" }
  candidateGroup._settingsKey = "qiao_candidate_summary"
  candidateGroup.value = function(uiSettings)
    if collection then
      local conf = modeOf(uiSettings)
      local candidates = resolveSettings(function(key) return conf[key] end).candidates
      return table.concat(table.map(candidates, Ban.kingdomLabel), "、")
    end
    local names = {}
    for _, kingdom in ipairs(Ban.kingdoms) do
      if Ban.candidateValue(modeOf(uiSettings), kingdom) then
        table.insert(names, Ban.kingdomLabel(kingdom))
      end
    end
    return table.concat(names, "、")
  end
  local candidateSettings = { candidateGroup }
  if collection then
    table.insert(candidateSettings, checkbox(Ban.enabledKey, Ban.enabledKey))
  else
    table.insert(candidateSettings, W.SpinRow {
      _settingsKey = Ban.limitKey, title = "qiao_kingdom_limit", from = 1,
      to = function(uiSettings)
        return math.max(Ban.candidateCount(modeOf(uiSettings)), 1)
      end,
      value = uiKingdomLimit,
    })
  end
  table.insert(candidateSettings, checkbox(Guest.settingKey, Guest.settingKey))
  table.insert(settings, W.PreferenceGroup(candidateSettings))

  local ruleSettings = {
    title = "qiao_rule_settings",
    W.SpinRow {
      _settingsKey = "qiao_offer_count", title = "qiao_offer_count",
      from = function(settings) return uiKingdomLimit(settings) + 1 end,
      to = MAX_OFFERS,
      value = function(settings)
        return offerCount(modeOf(settings).qiao_offer_count, uiKingdomLimit(settings))
      end,
    },
    W.SpinRow {
      _settingsKey = "generalTimeout", title = "Choose General timeout",
      from = 10, to = 300,
      value = function(settings)
        return modeOf(settings).generalTimeout or Selection.defaultTimeout
      end,
    },
    W.SpinRow {
      _settingsKey = "qiao_wild_count", title = "qiao_wild_count", from = 0,
      to = 12,
      value = function(settings)
        local value = (settings._mode or {}).qiao_wild_count
        return value == nil and 4 or value
      end,
    },
  }
  if not collection then
    table.insert(ruleSettings, 1, W.SwitchRow {
      _settingsKey = Variants.key, title = "qiao_wolves",
      value = function(settings) return modeOf(settings)[Variants.key] == true end,
    })
    table.insert(ruleSettings, 2, W.ComboRow {
      _settingsKey = FaqRules.seatLuckSetting, title = FaqRules.seatLuckSetting,
      model = { FaqRules.seatLuckNone, FaqRules.seatLuckCard },
      value = function(settings)
        return modeOf(settings)[FaqRules.seatLuckSetting] == FaqRules.seatLuckCard
          and FaqRules.seatLuckCard or FaqRules.seatLuckNone
      end,
    })
  end
  table.insert(settings, 1, W.PreferenceGroup(ruleSettings))
  local whitelist = { "qiao_generals", "qiao_cards", "qiao_mode" }
  return fk.CreateGameMode {
    name = name, minPlayer = base.minPlayer, maxPlayer = base.maxPlayer,
    main_mode = base.main_mode, rule = Commander.RULE_SKILL, logic = getLogic,
    whitelist = whitelist, ui_settings = settings,
    winner_getter = Ascension.get_winner, surrender_func = base.surrenderFunc,
    is_counted = base.countInFunc,
    reward_punish = function(self, victim, killer)
      local Counts=require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_qun"
      return Counts.withPhysicalCount(victim.room,function()
        return base.deathRewardAndPunish(self,victim,killer)
      end)
    end,
    friend_enemy_judge = base.friendEnemyJudge,
    feasible = function(self, settings)
      if not GameMode.feasible(self, settings) then return false end
      local function getSetting(key)
        if settings._mode and settings._mode[key] ~= nil then return settings._mode[key] end
        if settings._game and settings._game[key] ~= nil then return settings._game[key] end
        return settings[key]
      end
      if not pcall(resolveSettings, getSetting) then return false end
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
