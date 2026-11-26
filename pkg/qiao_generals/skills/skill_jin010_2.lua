-- JIN010 张春华 · 扼绝
--
-- 造成伤害时且没有手牌，可以失去自己的一个其他技能，然后令本次伤害 +1。
-- 可选的武将技能按武将牌、翼从实例或角色获授来源分别失去。
-- 已建立的效果仍按自身时限结算。
local Selection = require "packages.qiao.pkg.qiao_mode.rules.trigger_selection"
local S = require "packages.qiao.pkg.qiao_generals.util.jin_sources"

local skill = fk.CreateSkill {
  name = "qiao__skill_jin010_2",
}
skill.qiaoImplemented = true

local function choices(player)
  return S.choices(player)
end

local function optionLabel(index, choice)
  local source
  if choice.retinueId ~= nil then
    source = choice.retinuePosition == "main" and "主将位翼从"
      or choice.retinuePosition == "deputy" and "副将位翼从" or "翼从"
  elseif choice.general ~= nil then
    source = (choice.deputy == true and "副将" or "主将")
      .. "：" .. Fk:translate(choice.general)
  elseif choice.source ~= nil then
    source = "外部来源：" .. Fk:translate(choice.source.name)
  else
    source = "外部来源"
  end
  return "[" .. index .. "] " .. Fk:translate(choice.skill) .. "（" .. source .. "）"
end

skill:addEffect(fk.DamageCaused, {
  can_trigger = function(self, event, target, player, data)
    if target ~= player or player.dead or not player:hasSkill(skill.name) then return false end
    if data == nil or data.damage == nil or data.damage < 1 then return false end
    if not player:isKongcheng() then return false end
    return #choices(player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    if not player:isKongcheng() then return false end
    local list = choices(player)
    if #list == 0 then return false end
    local labels = table.map(list, function(choice, index)
      return optionLabel(index, choice)
    end)
    local chosen = Selection.askOption(player.room, player, {
      choices = labels,
      skill_name = skill.name,
      prompt = "#qiao__skill_jin010_2-choice",
      cancelable = true,
    })
    local index = tonumber(chosen and chosen:match("^%[(%d+)%]") or "")
    if index == nil or list[index] == nil then return false end
    event:setCostData(self, { choice = list[index] })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local cost = event:getCostData(self) or {}
    if cost.choice == nil or player.dead then return end
    if S.lose(player.room, player, cost.choice) then
      data.damage = data.damage + 1
    end
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_jin010_2"] = "扼绝",
  ["#qiao__skill_jin010_2-choice"] = "扼绝：选择失去一个技能",
}

return skill
