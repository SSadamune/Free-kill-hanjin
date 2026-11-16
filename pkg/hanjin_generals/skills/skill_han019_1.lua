-- HAN019 吉平 · 烈医
--
-- 对一名角色造成伤害后，可令其回复至多2点；实际回复后，本回合防止自己
-- 后续造成的所有伤害。回复被防止时不建立后续防止。
local skill = fk.CreateSkill {
  name = "hanjin__skill_han019_1",
}
skill.hanjinImplemented = true

local PREVENT_RULE = "hanjin__han019_1_rule"
local PREVENT_TAG = "hanjin_han019_1_prevent"
local HEAL_ONE = "hanjin__skill_han019_1-heal1"
local HEAL_TWO = "hanjin__skill_han019_1-heal2"

local function turnId(player)
  local current = player.room.logic:getCurrentEvent()
  local turn = current and current:findParent(GameEvent.Turn, true)
  return turn and turn.id or 0
end

skill:addEffect(fk.Damage, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and player:hasSkill(skill.name)
      and data ~= nil and data.from == player and data.to ~= nil
      and not data.to.dead and data.to.hp < data.to.maxHp
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_han019_1-invoke::" .. data.to.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local to = data.to
    if to == nil or to.dead or to:isRemoved() or to.hp >= to.maxHp then return end
    local maxHeal = math.min(2, to.maxHp - to.hp)
    if maxHeal < 1 then return end
    local num = maxHeal
    if maxHeal >= 2 then
      local choice = room:askToChoice(player, {
        choices = { HEAL_ONE, HEAL_TWO },
        skill_name = skill.name,
        prompt = "#hanjin__skill_han019_1-amount",
        cancelable = false,
      })
      num = choice == HEAL_ONE and 1 or 2
    end
    -- 使用公共 Recover 的真实执行结果；回复被防止/失败时不建立后续防伤。
    local recovered = room:recover {
      who = to, num = num, recoverBy = player, skillName = skill.name,
    }
    if recovered and not player.dead then
      if not room:hasSkill(PREVENT_RULE) then room:addSkill(PREVENT_RULE) end
      room:setTag(PREVENT_TAG, { player = player.id, turn = turnId(player) })
    end
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_han019_1"] = "烈医",
  [":hanjin__skill_han019_1"] = "当你对一名角色造成伤害后，你可以令其回复至多2点体力，然后防止你本回合你再造成伤害。",
  ["#hanjin__skill_han019_1-invoke"] = "烈医：令 %dest 回复至多2点体力",
  ["#hanjin__skill_han019_1-amount"] = "烈医：选择回复1点或2点体力",
  [HEAL_ONE] = "回复1点",
  [HEAL_TWO] = "回复2点",
}

return skill
