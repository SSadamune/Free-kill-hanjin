local skill = fk.CreateSkill { name = "qiao__skill_shu091_1" }
local mark = "@qiao_duduan-turn"
local function allowed(p, name)
  return not table.contains(p:getTableMark(mark), name)
end
local function seal(p, name)
  p.room:addTableMarkIfNeed(p, mark, name)
  p:drawCards(2, skill.name)
end
skill:addEffect("active", {
  card_num = 0, target_num = 0,
  can_use = function(self, p)
    return p.phase == Player.Play and allowed(p, "slash") and p:canUse(Fk:cloneCard("qiao__slash"))
  end,
  on_use = function(self, room, effect) seal(effect.from, "slash") end,
})
local function requested(p, data)
  if data.result or not data.pattern or data.pattern == "." then return {} end
  local options = {}
  local pattern = Exppattern:Parse(data.pattern)
  for _, name in ipairs({ "slash", "jink" }) do
    if allowed(p, name) and pattern:matchExp(name .. "|0|nosuit|none") then table.insert(options, name) end
  end
  return options
end
for _, timing in ipairs({ fk.AskForCardUse, fk.AskForCardResponse }) do
  skill:addEffect(timing, {
    can_trigger = function(self, event, target, p, data)
      return p == target and p:hasSkill(skill.name) and #requested(p, data) > 0
    end,
    on_cost = function(self, event, target, p, data)
      local choices = requested(p, data)
      table.insert(choices, "Cancel")
      local choice = p.room:askToChoice(p, { choices = choices, skill_name = skill.name, prompt = "#qiao_duduan" })
      event:setCostData(self, { name = choice })
      return choice ~= "Cancel"
    end,
    on_use = function(self, event, target, p) seal(p, event:getCostData(self).name) end,
  })
end
local function prohibited(self, p, card) return not allowed(p, card.trueName) end
skill:addEffect("prohibit", { prohibit_use = prohibited, prohibit_response = prohibited })
Fk:loadTranslationTable { [mark] = "度断", ["#qiao_duduan"] = "度断：选择本回合禁止使用和打出的牌名，然后摸两张牌" }
return skill
