-- HAN019 吉平 · 蛊毒
--
-- 每回合一次，防止其他角色的一次整次回复；当前回合结束其失去1点体力，若仍
-- 存活，移除提供此技能的这张将牌。延时记录由独立静态规则执行。
local skill = fk.CreateSkill {
  name = "hanjin__skill_han019_2",
}
skill.hanjinImplemented = true

local RULE = "hanjin__han019_venom_rule"
local PENDING = "hanjin_han019_venom_pending"

local function ensureRule(room)
  if room ~= nil and not room:hasSkill(RULE) then room:addSkill(RULE) end
end

---@param player ServerPlayer
---@return string, boolean
local function sourceGeneral(player)
  local main = player.general
  local deputy = player.deputyGeneral
  local mainName = main == "anjiang" and player:getMark("__heg_general") or main
  local deputyName = deputy == "anjiang" and player:getMark("__heg_deputy") or deputy
  if mainName and Fk.generals[mainName]
    and table.contains(Fk.generals[mainName]:getSkillNameList(), skill.name) then
    return mainName, false
  end
  if deputyName and Fk.generals[deputyName]
    and table.contains(Fk.generals[deputyName]:getSkillNameList(), skill.name) then
    return deputyName, true
  end
  return "", false
end

skill:addEffect(fk.PreHpRecover, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    return target ~= player and target ~= nil and not target.dead
      and player:hasSkill(skill.name) and not player.dead
      and data ~= nil and not data.prevented and (data.num or 0) > 0
      and player:usedSkillTimes(skill.name, Player.HistoryTurn) == 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_han019_2-invoke::" .. target.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    data:preventRecover()
    local name, isDeputy = sourceGeneral(player)
    ensureRule(room)
    local list = room:getTag(PENDING) or {}
    table.insert(list, {
      holder = player.id,
      target = target.id,
      source = name,
      isDeputy = isDeputy,
    })
    room:setTag(PENDING, list)
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_han019_2"] = "蛊毒",
  [":hanjin__skill_han019_2"] = "每回合限一次，其他角色回复体力时，你可以防止之。若如此做，当前回合结束时其失去1点体力，然后若其仍存活，你移除此武将牌。",
  ["#hanjin__skill_han019_2-invoke"] = "蛊毒：防止 %dest 的本次回复",
}

return skill
