local extension = Package:new("hanjin_mode", Package.SpecialPack)
extension.extensionName = "hanjin"
extension:loadSkillSkelsByPath("./packages/hanjin/pkg/hanjin_mode/skills")

-- Register after all extensions are installed; hanjin may load before hegemony.
-- Do not create a second boardgame: Fk:loadPackages() iterates Fk.boardgames and
-- postLoads every entry.  A new board entry would make the same engine postLoad
-- twice, duplicating game modes and card types.  The existing board keeps its
-- engine/room/page/settings; only the extension client is installed, and the
-- client delegates every non-HanJin room or skill back to the base handlers.
Fk:addPostLoadFunc(function()
  local base = assert(Fk.game_modes.new_heg_mode, "Hanjin requires the hegemony extension")
  local mode = require("packages.hanjin.pkg.hanjin_mode.mode").create(base)
  local board = assert(Fk:getBoardGame(base.name), "Hanjin requires the hegemony boardgame")
  board.client_klass = require "packages.hanjin.pkg.hanjin_mode.client"
  mode.game_name = base.game_name
  extension:addGameMode(mode)
  Fk:addGameMode(mode)
  Fk:loadDisabled()
end)

Fk:loadTranslationTable {
  ["hanjin_wolves"] = "群狼环鼎",
  ["help: hanjin_wolves"] = "默认关闭。无论开关，鏖战均为【桃】只能当【杀】或【闪】使用或打出；"
    .. "开启后仅额外启用历史事件（含赋礼、不进则退等）及奇珍规则。",
  ["hanjin_mode"] = "紫乔汉晋·规则",
  ["han"] = "汉",
  ["hanjin_heg_mode"] = "紫乔汉晋国战",
  [":hanjin_heg_mode"] = "继承国战规则；房主预先选择本局候选势力及允许上限，候选外不可选，"
    .. "并遵守同房间上一局胜负及禁选记录。可设置野心家专属武将数量；客将候选可在最终选将前自愿重抽。",
  ["hanjin_candidate_kingdoms"] = "备选势力",
  ["help: hanjin_candidate_kingdoms"] = "房主预先选择本局可出现的常规势力；默认魏蜀吴群汉晋六势力。"
    .. "候选外的主势力、客将势力及效忠版势力均不可选。",
  ["hanjin_candidate_wei"] = "魏",
  ["hanjin_candidate_shu"] = "蜀",
  ["hanjin_candidate_wu"] = "吴",
  ["hanjin_candidate_qun"] = "群",
  ["hanjin_candidate_han"] = "汉",
  ["hanjin_candidate_jin"] = "晋",
  ["hanjin_kingdom_limit"] = "本局允许势力上限",
  ["help: hanjin_kingdom_limit"] = "正整数，且不超过已选候选数；默认4，候选少于4项时取候选数。"
    .. "候选多于上限时，按上一局必禁/必留规则随机禁到上限。",
  ["hanjin_offer_count"] = "每人备选武将数",
  ["hanjin_rule_settings"] = "紫乔汉晋规则",
  ["hanjin_wild_count"] = "野心家专属武将数量",
  ["help: hanjin_wild_count"] = "随机保留至多此数量的野心家专属武将；未保留的原版按本局允许势力替换为效忠版。"
    .. "默认4；设为0时原版全部排除，其效忠版仍可入池。",
  ["#HanjinFactionBan"] = "本局禁选势力：%arg；允许势力：%arg2",
  ["#HanjinChooseGenerals"] = "选择主将与副将",
  ["#HanjinChooseGeneralsBans"] = "选择主将与副将　本局禁用势力：%arg",
  ["#HanjinChooseKingdom"] = "选择你的初始势力",
  ["#HanjinGuestRedrawn"] = "%from 重抽客将：%arg → %arg2",
}

-- Client-side pairing rule for the final selection dialog. The server sends the
-- per-room compatibility map as extra data, so guest candidates are judged by
-- the faction resolution for this game rather than the engine's static data.
if not Fk.choose_general_rule.hanjin_heg_pair then
  Fk:addChooseGeneralRule {
    name = "hanjin_heg_pair",
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
    prompt = function() return "#HanjinChooseGenerals" end,
  }
end

return extension
