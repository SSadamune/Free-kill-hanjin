local Modes = require "packages.qiao.pkg.qiao_mode.modes"
local Mode = require "packages.qiao.pkg.qiao_mode.mode"
local Client = require "packages.qiao.pkg.qiao_mode.client"
local Session = require "packages.qiao.pkg.qiao_mode.rules.session"
local extension = Package:new("qiao_mode", Package.SpecialPack)
extension.extensionName = "qiao"
extension:loadSkillSkelsByPath("./packages/qiao/pkg/qiao_mode/skills")

local unusedGameSettings = {
  generalNum = true,
  generalTimeout = true,
  timeoutAsGeneralTimeout = true,
  enableDeputy = true,
}

-- Register after all extensions are installed; qiao may load before hegemony.
-- Do not create a second boardgame: Fk:loadPackages() iterates Fk.boardgames and
-- postLoads every entry. The views below share the registered board's engine and classes.
Fk:addPostLoadFunc(function()
  local base = assert(Fk.game_modes.new_heg_mode, "Qiao requires the hegemony extension")
  Mode.installRules()
  Session.installServer()
  local board = assert(Fk:getBoardGame(base.name), "Qiao requires the hegemony boardgame")
  board.client_klass = Client
  local boards = {}
  for _, name in ipairs(Modes.names) do
    local settings = table.clone(board.ui_settings)
    for _, group in ipairs(settings) do
      if group.title == "Properties" then group._qml = Mode.gamePropertiesQml end
      -- The stock room summary uses the same descriptors and reads saved values even for disabled rows.
      group._children = table.filter(group._children, function(row)
        local key = row._settingsKey
        return not unusedGameSettings[key]
          and (key ~= "luckTime" or name == Modes.free)
          and (key ~= "enableFreeAssign" or name ~= Modes.locked)
      end)
    end
    boards[name] = setmetatable({
      page = { url = "packages/qiao/pkg/qiao_mode/qml/QiaoRoom.qml" },
      ui_settings = settings,
    }, { __index = board })
  end
  local getBoardGame = Fk.getBoardGame
  function Fk:getBoardGame(name)
    return boards[name] or getBoardGame(self, name)
  end
  for _, name in ipairs(Modes.names) do
    local mode = Mode.create(base, name)
    mode.game_name = base.game_name
    extension:addGameMode(mode)
    Fk:addGameMode(mode)
  end
  Fk:loadDisabled()
end)

Fk:loadTranslationTable {
  ["#qiao_temporary_effect_ended"] = "%from 的〖%arg〗效果结束",
  ["qiao_wolves"] = "群狼环鼎",
  ["help: qiao_wolves"] = "开启历史事件与奇珍规则。",
  ["qiao_locked_game_rule"] = "游戏规则",
  ["qiao_locked_landlord"] = "斗地主",
  ["help: qiao_locked_landlord"] = "固定三人，一名地主对两名农民，地主多两张备选武将牌。",
  ["qiao_locked_2v2"] = "2v2",
  ["help: qiao_locked_2v2"] = "四人分两方，座次随机，首位少一张初始手牌，末位多一张。",
  ["qiao_locked_human_vs_ai"] = "人机对抗",
  ["help: qiao_locked_human_vs_ai"] = "二至十人，真人与机器人分属不同势力，按人数分为两方或三方。",
  ["qiao_locked_battle_royal"] = "鏖战规则",
  ["help: qiao_locked_battle_royal"] = "开启后按国战人数和势力条件进入鏖战。",
  ["qiao_late_seat_compensation"] = "后置位补偿",
  ["help: qiao_late_seat_compensation"] = "选择手气卡后，7 人及以上的对局中，7 号位及之后的玩家各额外获得 1 次手气卡。",
  ["qiao_late_seat_none"] = "无",
  ["qiao_late_seat_luck_card"] = "手气卡",
  ["qiao_mode"] = "国战平行时空",
  ["qiao_skill_reference_back"] = "后退",
  ["han"] = "汉",
  ["jin"] = "晋",
  [Modes.collection] = "汉晋大合集",
  [":" .. Modes.collection] = "魏、蜀、吴、群固定纳入备选势力。可设置是否纳入汉、晋，以及是否禁用势力和启用客将替换规则。",
  [Modes.free] = "平行时空",
  [":" .. Modes.free] = "可自定义备选势力、允许势力上限及国战附加规则，使用汉晋武将和游戏牌。",
  [Modes.locked] = "锁定势力国战",
  [":" .. Modes.locked] = "每人从获配势力选主将、副将。斗地主固定三人，地主多两张备选武将牌，增加 1 点体力上限和体力，并获得〖飞扬〗和〖跋扈〗。2v2固定四人，1 号位少一张初始手牌，4 号位多一张。人机对抗允许2至10人，真人和机器人分属不同势力。人数相同或机器人多一名时各一势力，其余情况由人数较多的一方随机均分两个势力。人机对抗免同势力人数上限。三个规则默认关闭鏖战。",
  ["qiao_faction_ban_enabled"] = "势力禁用规则",
  ["help: qiao_faction_ban_enabled"] = "随机选择四个势力备选，其余势力将被禁用",
  ["qiao_guest_replacement"] = "客将替换规则",
  ["qiao_guest_illustrations"] = "客将",
  ["help: qiao_guest_replacement"] = "主势力均被禁用的武将可以作为客将出场",
  ["qiao_candidate_kingdoms"] = "备选势力",
  ["help: qiao_candidate_kingdoms"] = "候选外的势力不会出现。",
  ["qiao_collection_candidates_help"] = "魏、蜀、吴、群固定开启。",
  ["qiao_candidate_wei"] = "魏",
  ["qiao_candidate_shu"] = "蜀",
  ["qiao_candidate_wu"] = "吴",
  ["qiao_candidate_qun"] = "群",
  ["qiao_candidate_han"] = "汉",
  ["qiao_candidate_jin"] = "晋",
  ["qiao_enable_han"] = "开启汉势力",
  ["qiao_enable_jin"] = "开启晋势力",
  ["qiao_kingdom_limit"] = "本局允许势力上限",
  ["help: qiao_kingdom_limit"] = "备选势力超出上限时，禁用多出的势力。",
  ["qiao_offer_count"] = "每人备选武将数",
  ["qiao_rule_settings"] = "国战模式规则",
  ["qiao_wild_count"] = "野心家专属武将数量",
  ["help: qiao_wild_count"] = "将池中出现的野心家专属武将的数量上限",
  ["#QiaoFactionBan"] = "本局禁选势力：%arg；允许势力：%arg2",
  ["#QiaoChooseGenerals"] = "选择主将与副将",
  ["#QiaoChooseGeneralsBans"] = "选择主将与副将　本局禁用势力：%arg",
  ["qiao_selection_can_ascend"] = "可君主升变",
  ["qiao_selection_can_pledge_loyalty"] = "可效忠升变",
  ["qiao_lord_ascension"] = "君主升变",
  ["qiao_lord_ascension_enabled"] = "开启",
  ["qiao_lord_ascension_disabled"] = "禁用",
  ["qiao_lord_ascension_by_bans"] = "自由选择",
  ["help: qiao_lord_ascension_enabled"] = "启用君主升变规则",
  ["help: qiao_lord_ascension_disabled"] = "禁用君主升变规则",
  ["help: qiao_lord_ascension_by_bans"] = "能否君主升变取决于「禁将方案」的设置",
  ["$qiao_lord_ascension1"] = "君主升变",
  ["#QiaoLockedWrongPlayerCount"] = "开局取消：房间人数与锁定势力国战的游戏规则不符。",
  ["#QiaoLockedMissingHumanOrRobot"] = "开局取消：人机对抗须至少有一名真人和一名机器人。",
  ["#QiaoLockedInsufficientGenerals"] = "开局取消：当前禁将和备选势力无法为两方发足合法的武将牌。",
  ["#QiaoLockedFewerOffers"] = "将池不足，本局每人的基础备选武将牌统一减为 %arg 张。",
  ["#QiaoChooseLockedKingdom"] = "你是%arg2，势力为%arg，请选择主将与副将",
  ["#QiaoChooseLandlord"] = "你是地主（%arg2），势力为%arg，请选择主将与副将",
  ["#QiaoChooseFarmer"] = "你是农民（%arg2），势力为%arg，请选择主将与副将",
  ["#QiaoChooseKingdom"] = "选择你的初始势力",
  ["#QiaoGuestRedrawn"] = "%from 重抽客将：%arg → %arg2",
}

-- Client-side pairing rule for the final selection dialog. The server sends the
-- per-room compatibility map as extra data, so guest candidates are judged by
-- the faction resolution for this game rather than the engine's static data.
if not Fk.choose_general_rule.qiao_heg_pair then
  Fk:addChooseGeneralRule {
    name = "qiao_heg_pair",
    card_filter = function(to_select, selected, data, extra_data)
      if #selected == 0 then
        return not (extra_data and extra_data.locked) or extra_data.pairing[to_select] ~= nil
      end
      if #selected >= 2 then return false end
      -- Free assignment deliberately ignores the pairing map. The server still
      -- requires two distinct real cards, so the client only blocks a duplicate.
      if extra_data and extra_data.freeAssign then return to_select ~= selected[1] end
      local pairing = extra_data and extra_data.pairing or {}
      local wild = extra_data and extra_data.wild or {}
      -- Wild-exclusive generals may only be the main general.
      if wild[to_select] then return false end
      if wild[selected[1]] then return true end
      local partners = pairing[selected[1]]
      return partners ~= nil and table.contains(partners, to_select)
    end,
    feasible = function(selected, data, extra_data)
      if #selected ~= 2 then return false end
      if extra_data and extra_data.freeAssign then return selected[1] ~= selected[2] end
      local pairing = extra_data and extra_data.pairing or {}
      local wild = extra_data and extra_data.wild or {}
      if wild[selected[2]] then return false end
      if wild[selected[1]] then return true end
      local partners = pairing[selected[1]]
      return partners ~= nil and table.contains(partners, selected[2])
    end,
    default_choice = function(generals, extra_data)
      local pairing = extra_data and extra_data.pairing or {}
      local wild = extra_data and extra_data.wild or {}
      for _, first in ipairs(generals) do
        for _, second in ipairs(generals) do
          local partners = pairing[first]
          if first ~= second and not wild[second] and partners and table.contains(partners, second) then
            return { first, second }
          end
        end
      end
      if extra_data and extra_data.freeAssign then
        for _, first in ipairs(generals) do
          for _, second in ipairs(generals) do
            if first ~= second then return { first, second } end
          end
        end
      end
      return {}
    end,
    prompt = function() return "#QiaoChooseGenerals" end,
  }
end

return extension
