local C = require "packages.hanjin.pkg.hanjin_mode.rules.commander_retinue"

-- 手动的共享视为技：选择一名已明置统领的来源，视为使用其标注的牌；
-- 代价为移除自己的一张无士兵武将牌。只在“使用”窗口开放，不在“打出”窗口开放。
local skill = fk.CreateSkill {
  name = C.ABILITY_SKILL,
}

skill:addEffect("viewas", {
  pattern = ".",
  prompt = "#hanjin_commander_ability",
  card_filter = Util.FalseFunc,
  interaction = function(self, player)
    local entries = C.availableSourceEntries(player)
    if #entries == 0 then return nil end
    -- custom interaction keeps the source buttons in the use-card panel. The
    -- stable `key` is the authoritative server value; `label` is display-only.
    return {
      type = "custom",
      default = entries[1].key,
      qml = {
        url = "packages/hanjin/pkg/hanjin_mode/qml/CommanderSourceButtons.qml",
        prop = {
          sources = entries,
          currentKey = entries[1].key,
        },
      },
    }
  end,
  view_as = function(self, player, cards)
    local key = self.interaction and self.interaction.data
    if type(key) ~= "string" or key == "" or C.commanders[key] == nil then
      -- The first entry is the default even when several sources exist; the
      -- client may not have synchronized interaction.data yet on first paint.
      if player == nil or type(player.getMark) ~= "function" then return nil end
      local entries = C.availableSourceEntries(player)
      key = entries[1] and entries[1].key or nil
    end
    if type(key) ~= "string" or key == "" then return nil end
    -- 客户端 view_as 不能读取服务端来源 tag；构造牌后由服务端 before_use 复核。
    return C.viewAsCardForClient(player, key)
  end,
  before_use = function(self, player, use)
    local key = use.card and use.card:getMark(C.CARD_SOURCE_MARK)
    if type(key) ~= "string" or key == "" then return skill.name end
    local spec = C.commanders[key]
    if spec == nil or use.card.name ~= spec.card then return skill.name end
    local source = C.source(player.room, key)
    if source == nil or not C.sourceAuthorizedFor(player.room, source, player) then
      return skill.name
    end
    local isDeputy = C.chooseCostPosition(player, source)
    if isDeputy == nil then return skill.name end
    if not C.payCost(player, source, isDeputy) then return skill.name end
  end,
  enabled_at_play = function(self, player)
    return C.hasUsableSource(player, "play")
  end,
  enabled_at_response = function(self, player, response)
    return not response and C.hasUsableSource(player, "response")
  end,
  enabled_at_nullification = function(self, player, data)
    -- 无懈可击属于“使用”而不是纯“打出”；只有来源牌确实能形成合法无懈时才开放。
    return C.hasUsableSource(player, "nullification")
  end,
})

Fk:loadTranslationTable {
  [C.ABILITY_SKILL] = "统领",
  ["#hanjin_commander_ability"] = "统领：选择一名明置统领，移除自己的一张无士兵武将牌，视为使用其标注的牌",
  ["#hanjin_commander_choose_cost"] = "选择移除以支付统领代价的武将牌",
  ["#hanjin_commander_choose_retinue"] = "选择要转换成的翼从",
  ["mainGeneral"] = "主将",
  ["deputyGeneral"] = "副将",
  ["#HanjinRetinueGained"] = "%from 的 %arg 转换为翼从 %arg2",
}

-- Keep the source list client-side for the view-as construction, but do not
-- render the internal source keys as a long player mark. `ClientBase` asks this
-- spec before notifying QML; "#hidden" stores/removes only the UI copy, while
-- `Player:getMark` still carries the list for viewAsCardForClient/reconnect.
Fk:addQmlMark {
  name = "hanjin_commander_sources",
  how_to_show = function() return "#hidden" end,
}

return skill
