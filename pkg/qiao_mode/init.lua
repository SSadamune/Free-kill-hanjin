local Modes = require "packages.qiao.pkg.qiao_mode.modes"
local extension = Package:new("qiao_mode", Package.SpecialPack)
extension.extensionName = "qiao"
extension:loadSkillSkelsByPath("./packages/qiao/pkg/qiao_mode/skills")

-- Register after all extensions are installed; qiao may load before hegemony.
-- Do not create a second boardgame: Fk:loadPackages() iterates Fk.boardgames and
-- postLoads every entry.  A new board entry would make the same engine postLoad
-- twice, duplicating game modes and card types. The room page selection below
-- shares the registered board's engine, classes, and settings.
Fk:addPostLoadFunc(function()
  local base = assert(Fk.game_modes.new_heg_mode, "Qiao requires the hegemony extension")
  local factory = require "packages.qiao.pkg.qiao_mode.mode"
  local board = assert(Fk:getBoardGame(base.name), "Qiao requires the hegemony boardgame")
  board.client_klass = require "packages.qiao.pkg.qiao_mode.client"
  local qiaoBoard = setmetatable({
    page = { url = "packages/qiao/pkg/qiao_mode/qml/QiaoRoom.qml" },
  }, { __index = board })
  local getBoardGame = Fk.getBoardGame
  function Fk:getBoardGame(name)
    if Modes.isHanjin(name) then return qiaoBoard end
    return getBoardGame(self, name)
  end
  for _, name in ipairs(Modes.names) do
    local mode = factory.create(base, name)
    mode.game_name = base.game_name
    extension:addGameMode(mode)
    Fk:addGameMode(mode)
  end
  Fk:loadDisabled()
end)

Fk:loadTranslationTable {
  ["qiao_wolves"] = "群狼环鼎",
  ["help: qiao_wolves"] = "开启历史事件与奇珍规则。",
  ["qiao_mode"] = "国战平行时空",
  ["han"] = "汉",
  [Modes.collection] = "大合集",
  [":" .. Modes.collection] = "魏、蜀、吴、群固定纳入备选势力。可设置是否纳入汉、晋，以及是否禁用势力和启用客将替换规则。",
  [Modes.free] = "自由模式",
  [":" .. Modes.free] = "可自定义备选势力、允许势力上限及国战附加规则，使用汉晋武将和游戏牌。",
  ["qiao_faction_ban_enabled"] = "势力禁用规则",
  ["help: qiao_faction_ban_enabled"] = "随机选择四个势力备选，其余势力将被禁用",
  ["qiao_guest_replacement"] = "客将替换规则",
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
      if #selected == 0 then return true end
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
