local C = require "packages.qiao.pkg.qiao_mode.rules.commander_retinue"
local T = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"

-- 手动的共享视为技：选择一名已明置统领的来源，视为使用其标注的牌；
-- 代价为移除自己的一张无士兵武将牌。只在“使用”窗口开放，不在“打出”窗口开放。
local skill = fk.CreateSkill {
  name = C.ABILITY_SKILL,
  dynamic_desc = function(self, player, lang)
    if player then return C.description(player, nil, lang) end
  end,
}

skill:addEffect("viewas", {
  pattern = ".",
  prompt = function(self, player)
    local key = self.interaction and self.interaction.data
    if type(key) ~= "string" or C.commanders[key] == nil then
      local entries = C.availableSourceEntries(player)
      key = entries[1] and entries[1].key
    end
    return C.description(player, key, nil, true)
  end,
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
        url = "packages/qiao/pkg/qiao_mode/qml/CommanderSourceButtons.qml",
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
  on_use = function(self, room, effect, card, params)
    if card == nil then return "" end
    local extra = params and params.extra_data
    if params and (params.is_response or (params.pattern and not card:matchVSPattern(params.pattern))) then
      return skill.name
    end
    if card.is_passive and extra and extra.not_passive then return skill.name end
    local use = { from = effect.from, tos = effect.tos, card = card }
    if extra then use.extra_data = table.simpleClone(extra) end
    return self:beforeUse(effect.from, use, true) or use
  end,
  before_use = function(self, player, use, validateTargets)
    local key = use.card and use.card:getMark(C.CARD_SOURCE_MARK)
    if type(key) ~= "string" or key == "" then return skill.name end
    local spec = C.commanders[key]
    if spec == nil or use.card.name ~= spec.card then return skill.name end
    local room = player.room
    local source = C.source(room, key)
    if source == nil or not C.sourceAuthorizedFor(room, source, player) then
      return skill.name
    end
    local policy = source.bypass_distances and T.bypassDistance() or T.default()
    local function canUse()
      if use.card.is_passive then
        return not player:prohibitUse(use.card) and not player:prohibitResponse(use.card)
      end
      if not player:canUse(use.card, use.extra_data) then return false end
      -- 正式请求下，通用校验区分上游补入的固定目标与漏选的自选目标。
      if not validateTargets and #(use.tos or {}) == 0 then return true end
      return T.validateTargets(room, player, use, policy, "selection")
    end
    local candidates = table.filter(C.costCandidates(player, source), function(deputy)
      return C.checkCost(player, deputy, canUse)
    end)
    local isDeputy = C.chooseCostPosition(player, source, candidates)
    if isDeputy == nil or not C.checkCost(player, isDeputy, canUse) then return skill.name end
    T.attachUse(room, use, policy)
    if not C.payCost(player, source, isDeputy) then
      T.releaseToken(room, use)
      return skill.name
    end
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

skill:addEffect("targetmod", {
  bypass_distances = function(self, player, cardSkill, card, to)
    if card == nil or card.trueName ~= "slash" then return false end
    if not table.contains(card.skillNames, C.ABILITY_SKILL) then return false end
    local source = C.commanders[card:getMark(C.CARD_SOURCE_MARK)]
    return source ~= nil and source.card == card.name and source.bypass_distances == true
  end,
})

Fk:loadTranslationTable {
  [C.ABILITY_SKILL] = "统领",
  [":" .. C.ABILITY_SKILL] = "当你需要使用牌时，若你的主副将均无士兵，你可以选择一项同势力已明置统领提供的能力，"
    .. "移除自己的一张武将牌（不能是本次提供能力的统领），视为使用其标注的牌。"
    .. "仅可选择当前时机能合法使用的牌。限一统领能力每局所有角色合计限一次。",
  ["#qiao_commander_ability"] = "统领：选择一名明置统领，移除自己的一张无士兵武将牌，视为使用其标注的牌",
  ["#qiao_commander_choose_cost"] = "选择移除以支付统领代价的武将牌",
  ["#qiao_commander_choose_retinue"] = "选择要转换成的翼从",
  ["mainGeneral"] = "主将",
  ["deputyGeneral"] = "副将",
  ["#QiaoRetinueGained"] = "%from 的 %arg 转换为翼从 %arg2",
}

-- Keep the source list client-side for the view-as construction, but do not
-- render the internal source keys as a long player mark. `ClientBase` asks this
-- spec before notifying QML; "#hidden" stores/removes only the UI copy, while
-- `Player:getMark` still carries the list for viewAsCardForClient/reconnect.
Fk:addQmlMark {
  name = "qiao_commander_sources",
  how_to_show = function() return "#hidden" end,
}

return skill
