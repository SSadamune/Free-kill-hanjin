local C = require "packages.hanjin.pkg.hanjin_mode.rules.commander_retinue"

-- 手动的共享视为技：选择一名已明置统领的来源，视为使用其标注的牌；
-- 代价为移除自己的一张无士兵武将牌。只在“使用”窗口开放，不在“打出”窗口开放。
local skill = fk.CreateSkill {
  name = C.ABILITY_SKILL,
}

local function sourceChoices(player)
  return C.markSources(player)
end

skill:addEffect("viewas", {
  pattern = ".",
  prompt = "#hanjin_commander_ability",
  card_filter = Util.FalseFunc,
  interaction = function(self, player)
    local choices = sourceChoices(player)
    if #choices == 0 then return nil end
    return UI.ComboBox {
      choices = choices,
      all_choices = choices,
      default = choices[1],
    }
  end,
  view_as = function(self, player, cards)
    local key = self.interaction and self.interaction.data
    if type(key) ~= "string" or key == "" then
      local choices = sourceChoices(player)
      if #choices == 1 then key = choices[1] end
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
    return C.hasAvailableMark(player)
  end,
  enabled_at_response = function(self, player, response)
    return not response and C.hasAvailableMark(player)
  end,
  enabled_at_nullification = function(self, player, data)
    -- 无懈可击属于“使用”而不是纯“打出”；只有来源牌确实能形成合法无懈时才开放。
    return C.hasNullificationSource(player)
  end,
})

Fk:loadTranslationTable {
  [C.ABILITY_SKILL] = "统领",
  ["#hanjin_commander_ability"] = "统领：选择一名明置统领，移除自己的一张无士兵武将牌，视为使用其标注的牌",
  ["#hanjin_commander_choose_cost"] = "选择移除以支付统领代价的武将牌",
  ["#hanjin_commander_choose_retinue"] = "选择要转换成的翼从",
  ["#HanjinRetinueGained"] = "%from 的 %arg 转换为翼从 %arg2",
}

return skill
