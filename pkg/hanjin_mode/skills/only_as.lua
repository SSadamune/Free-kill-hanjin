local O = require "packages.hanjin.pkg.hanjin_mode.rules.only_as"

-- 模式级共享转化入口：在出牌阶段与响应窗口列出当前来源并集提供的用途。
-- 客户端只依赖同步 mark 与全局牌面定义；服务端在 before_use 与
-- PreCardUse/PreCardRespond 复核来源、底牌、目标和请求模式。
local skill = fk.CreateSkill {
  name = O.SKILL,
}

skill:addEffect("viewas", {
  pattern = ".",
  prompt = "#hanjin_only_as",
  handly_pile = true,
  interaction = function(self, player)
    local choices = O.interactionChoices(player)
    if #choices == 0 then return nil end
    return UI.ComboBox { choices = choices }
  end,
  card_filter = function(self, player, to_select, selected)
    if #selected ~= 0 then return false end
    local target = self.interaction and self.interaction.data
    if type(target) ~= "string" then return false end
    return O.cardSelectable(player, to_select, target)
  end,
  view_as = function(self, player, cards)
    local target = self.interaction and self.interaction.data
    if #cards ~= 1 or type(target) ~= "string" then return nil end
    return O.buildCard(player, cards[1], target, skill.name)
  end,
  before_use = function(self, player, use)
    local ok = O.validateUse(player.room, player, use, {})
    if not ok then return skill.name end
  end,
  enabled_at_play = function(self, player)
    return O.hasAvailable(player, "use")
  end,
  enabled_at_response = function(self, player, response)
    -- AskForUseCard 也会使用 enabled_at_response，但 response=false；
    -- 不能把使用询问当成“打出”窗口。
    return O.hasAvailable(player, response and "response" or "use")
  end,
})

Fk:loadTranslationTable {
  [O.SKILL] = "只能当",
  [":" .. O.SKILL] = "你可以将受到“只能当”效果限制的实体牌，按该效果提供的用途使用或打出；"
    .. "多个效果提供的用途可以并存。实体牌牌名不变。",
  ["#hanjin_only_as"] = "只能当：选择要转化成的牌名",
}

return skill
