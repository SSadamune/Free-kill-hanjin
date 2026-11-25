-- WEI010 徐晃 · 断粮
--
-- 规则基线：docs/rules/standard-generals.md 魏区 WEI010。
-- 一张黑色非锦囊牌当【兵粮寸断】使用；描述未限定手牌区域，不额外增加区域限制。
-- 其他角色跳过摸牌阶段后，可以令一名角色摸一张牌。这里监听真实的
-- fk.EventPhaseSkipped（阶段已被跳过之后），不依赖兵粮寸断这一具体来源：
-- 任何原因造成的摸牌阶段跳过都可以触发。
local Invoke = require "packages.qiao.pkg.qiao_generals.util.invoke_targets"
local skill = fk.CreateSkill {
  name = "qiao__skill_wei010_1",
}

local SUPPLY_SHORTAGE = "qiao__supply_shortage"

skill:addEffect("viewas", {
  pattern = "supply_shortage|.|.|.|" .. SUPPLY_SHORTAGE,
  enabled_at_response = function(self, player, response) return not response end,
  prompt = "#qiao__skill_wei010_1-prompt",
  handly_pile = true,
  filter_pattern = {
    min_num = 1,
    max_num = 1,
    -- 牌名|点数|花色|区域|完整牌名|类别：黑色且为基本牌或装备牌（排除锦囊）。
    -- 区域与完整牌名两字段必须显式写通配符 "."；留空会被解析成空匹配表，
    -- 导致任何位置、任何牌名都无法匹配（见 exppattern.parseMatcher）。
    pattern = ".|.|black|.|.|basic,equip",
  },
  view_as = function(self, player, cards)
    if #cards ~= 1 then return nil end
    local card = Fk:cloneCard(SUPPLY_SHORTAGE)
    card.skillName = skill.name
    card:addSubcards(cards)
    return card
  end,
})

skill:addEffect(fk.EventPhaseSkipped, {
  global = true,
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return target ~= player and player:hasSkill(skill.name) and not player.dead
      and data.phase == Player.Draw and target:isAlive() and not target:isRemoved()
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local chosen = Invoke.ask(room, player, {
      min_num = 1,
      max_num = 1,
      targets = room:getPresentPlayers(),
      skill_name = skill.name,
      prompt = "#qiao__skill_wei010_1-draw",
      invoke_prompt = "#qiao__skill_wei010_1-invoke::" .. target.id,
    })
    if #chosen == 0 then return false end
    event:setCostData(self, { tos = chosen })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local chosen = event:getCostData(self).tos
    local to = chosen and chosen[1]
    if to == nil or to.dead or to:isRemoved() then return end
    to:drawCards(1, skill.name)
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_wei010_1"] = "断粮",
  [":qiao__skill_wei010_1"] = "你可以将一张黑色非锦囊牌当【兵粮寸断】使用。其他角色跳过摸牌阶段后，你可以令一名角色摸一张牌。",
  ["#qiao__skill_wei010_1-prompt"] = "断粮：将一张黑色非锦囊牌当【兵粮寸断】使用",
  ["#qiao__skill_wei010_1-invoke"] = "断粮：%dest 跳过了摸牌阶段，你可以令一名角色摸一张牌",
  ["#qiao__skill_wei010_1-draw"] = "断粮：选择一名角色摸一张牌",
}

skill.qiaoImplemented = true

return skill
