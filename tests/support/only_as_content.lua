-- Test-only only-as content. Never loaded by the release entry point.
if Fk.packages.qiao_test_only_as then return end
local pack = Package:new("qiao_test_only_as", Package.CardPack)
pack.extensionName = "qiao"
local Modes = require "packages.qiao.pkg.qiao_mode.modes"
pack.game_modes_whitelist = Modes.names
Fk.packages[pack.name] = pack
table.insert(Fk.package_names, pack.name)
for _, mode in ipairs(Modes.names) do
  table.insert(Fk.game_modes[mode].whitelist, pack.name)
end

local O = require "packages.qiao.pkg.qiao_mode.rules.only_as"

local function register(skeleton)
  local skill = skeleton:createSkill()
  skill.package = pack
  Fk:addSkill(skill)
  return skill.name
end

-- 急救：回合外可以将一张红色牌当【桃】使用。用于验证“同名转化”不受
-- 原实体桃禁用限制；它仍走真实的转化/响应流程。
local jijiu = fk.CreateSkill {
  name = "qiao_test__jijiu",
}
jijiu:addEffect("viewas", {
  pattern = "peach",
  handly_pile = true,
  card_filter = function(self, player, to_select, selected)
    if #selected ~= 0 then return false end
    local card = Fk:getCardById(to_select)
    return card.color == Card.Red and table.contains(player:getHandlyIds(true), to_select)
  end,
  view_as = function(self, player, cards)
    if #cards ~= 1 then return nil end
    local card = Fk:cloneCard("qiao__peach")
    card.skillName = jijiu.name
    card:addSubcard(cards[1])
    return card
  end,
  enabled_at_play = Util.FalseFunc,
  -- 急救只允许“使用”【桃】，不提供纯“打出”窗口。
  enabled_at_response = function(self, player, response)
    return not response and Fk:currentRoom():getCurrent() ~= player
  end,
})
register(jijiu)

-- 龙胆（本系列桃当酒的测试对应物）：将实体【桃】当【酒】使用或打出。
-- 正式龙胆目前仍是空壳；这里只验证公共禁止机制不会拦截其它真实转化。
local longdan = fk.CreateSkill {
  name = "qiao_test__longdan_peach",
}
longdan:addEffect("viewas", {
  pattern = "analeptic",
  handly_pile = true,
  card_filter = function(self, player, to_select, selected)
    if #selected ~= 0 then return false end
    return Fk:getCardById(to_select).trueName == "peach"
      and table.contains(player:getHandlyIds(true), to_select)
  end,
  view_as = function(self, player, cards)
    if #cards ~= 1 then return nil end
    local card = Fk:cloneCard("qiao__analeptic")
    card.skillName = longdan.name
    card:addSubcard(cards[1])
    return card
  end,
  enabled_at_play = Util.TrueFunc,
  enabled_at_response = Util.TrueFunc,
})
register(longdan)

-- 测试用“红桃牌只能当【过河拆桥】使用”来源。拆只有使用权限，没有打出权限。
O.define("qiao_test_heart_dismantlement", {
  match = { suits = { Card.Heart } },
  conversions = {
    { name = "qiao__dismantlement", modes = { "use" }, order = 3 },
  },
  direct_zones = "any",
  view_zones = { "hand", "handly" },
})

-- 独立来源提供自己的转换入口，不借用鏖战或名为“只能当”的公共按钮。
local heart = fk.CreateSkill { name = "qiao_test__heart_conversion" }
O.addViewAsEffect(heart, "qiao_test_heart_dismantlement")
register(heart)
Fk:loadTranslationTable { [heart.name] = "测试红桃效果" }

-- 只有一个展示技的测试武将，用于验证来源随主将明暗/失去技能而失效。
local sourceSkill = fk.CreateSkill {
  name = "qiao_test__only_as_source_skill",
}
register(sourceSkill)
local sourceGeneral = General:new(pack, "qiao_test__only_as_source_holder", "wei", 4)
sourceGeneral.hidden = true
sourceGeneral:addSkill(sourceSkill.name)
Fk.generals[sourceGeneral.name] = sourceGeneral

Fk:loadTranslationTable {
  ["qiao_test__jijiu"] = "测试急救",
  [":qiao_test__jijiu"] = "回合外，你可以将一张红色牌当【桃】使用。",
  ["qiao_test__longdan_peach"] = "测试龙胆",
  [":qiao_test__longdan_peach"] = "你可以将一张【桃】当【酒】使用或打出。",
  ["qiao_test__only_as_source_skill"] = "测试来源技",
  ["qiao_test__only_as_source_holder"] = "测试来源武将",
}

return { jijiu = jijiu.name, longdan = longdan.name, heart = heart.name }
