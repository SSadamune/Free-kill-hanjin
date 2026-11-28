local S = require "packages.qiao.pkg.qiao_bingqing.nu"
local skill = fk.CreateSkill { name = "qiao__retinue_skill_xianzhenying" }
local function costs(p)
  return table.filter(S.discardable(p), function(id)
    local card = Fk:getCardById(id)
    return card.trueName == "peach" or card.trueName == "analeptic" or card.type == Card.TypeEquip
  end)
end
skill:addEffect(fk.DamageCaused, {
  on_trigger = S.each,
  can_trigger = function(self, event, target, p, data)
    return p == target and p:hasSkill(skill.name) and data.card and data.card.trueName == "slash"
      and #costs(p) > 0
  end,
  on_cost = function(self, event, target, p)
    local cards = p.room:askToDiscard(p, { min_num = 1, max_num = 1, pattern = tostring(Exppattern { id = costs(p) }),
      skill_name = skill.name, include_equip = true, cancelable = true, skip = true, prompt = "#qiao_xianzhenying-discard" })
    event:setCostData(self, { cards = cards })
    return #cards == 1
  end,
  on_use = function(self, event, target, p, data)
    p.room:throwCard(event:getCostData(self).cards, skill.name, p, p)
    data:changeDamage(1)
  end,
})
Fk:loadTranslationTable { ["#qiao_xianzhenying-discard"] = "陷阵营：你可以弃置一张【桃】、【酒】或装备牌，令此伤害+1" }
return skill
