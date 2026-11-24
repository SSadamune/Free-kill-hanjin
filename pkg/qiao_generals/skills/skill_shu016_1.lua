-- SHU016 甘夫人 · 淑慎
--
-- 规则基线：docs/rules/standard-generals.md 蜀区 SHU016。
-- 当你回复1点体力后，你可以选择一名其他角色，令其回复1点体力，或与其各摸一张牌。
-- 每实际回复1点提供一次独立机会；目标已满体力时不能选择回复分支。
local Invoke = require "packages.qiao.pkg.qiao_generals.util.invoke_targets"
local Selection = require "packages.qiao.pkg.qiao_mode.rules.trigger_selection"
local skill = fk.CreateSkill {
  name = "qiao__skill_shu016_1",
}
skill.qiaoImplemented = true

local OPT_RECOVER = "#qiao__skill_shu016_1-recover"
local OPT_DRAW = "#qiao__skill_shu016_1-draw"

local function others(player)
  return table.filter(player.room:getPresentPlayers(), function(p)
    return p ~= player and not p:isRemoved()
  end)
end

skill:addEffect(fk.HpRecover, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and not player.dead
      and (data.num or 0) > 0 and #others(player) > 0
  end,
  trigger_times = function(self, event, target, player, data)
    return math.max(data.num or 0, 0)
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local candidates = others(player)
    if #candidates == 0 then return false end
    local chosen = Invoke.ask(room, player, {
      min_num = 1,
      max_num = 1,
      targets = candidates,
      skill_name = skill.name,
      prompt = "#qiao__skill_shu016_1-target",
      invoke_prompt = "#qiao__skill_shu016_1-invoke",
    })
    local to = chosen and chosen[1]
    if to == nil or to.dead or to:isRemoved() then return false end
    local choices = { OPT_DRAW }
    if to.hp < to.maxHp then table.insert(choices, 1, OPT_RECOVER) end
    local choice = Selection.askOption(room, player, {
      choices = choices,
      all_choices = { OPT_RECOVER, OPT_DRAW },
      skill_name = skill.name,
      prompt = "#qiao__skill_shu016_1-choice:" .. to.id,
    })
    if choice == nil then return false end
    event:setCostData(self, { to = to, choice = choice })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self) or {}
    local to = cost.to
    if to == nil or to.dead or to:isRemoved() or player.dead then return end
    if cost.choice == OPT_RECOVER then
      if to.hp < to.maxHp then
        room:recover {
          who = to,
          num = 1,
          recoverBy = player,
          skillName = skill.name,
        }
      end
    else
      player:drawCards(1, skill.name)
      if to:isAlive() and not to:isRemoved() then to:drawCards(1, skill.name) end
    end
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_shu016_1"] = "淑慎",
  [":qiao__skill_shu016_1"] = "当你回复1点体力后，你可以选择一名其他角色，令其回复1点体力或与其各摸一张牌。",
  ["#qiao__skill_shu016_1-invoke"] = "淑慎：选择一名其他角色，令其回复体力或各摸一张牌",
  ["#qiao__skill_shu016_1-target"] = "淑慎：选择一名其他角色",
  ["#qiao__skill_shu016_1-choice"] = "淑慎：令其回复1点体力，或与其各摸一张牌",
  [OPT_RECOVER] = "令其回复1点体力",
  [OPT_DRAW] = "与其各摸一张牌",
}

return skill
