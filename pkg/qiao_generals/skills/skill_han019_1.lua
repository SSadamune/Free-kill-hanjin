-- HAN019 吉平 · 烈医
--
-- 对一名角色造成伤害后，可令其回复至多2点；实际回复后，本回合防止自己
-- 后续造成的所有伤害。回复被防止时不建立后续防止。
local Selection = require "packages.qiao.pkg.qiao_mode.rules.trigger_selection"

local skill = fk.CreateSkill {
  name = "qiao__skill_han019_1",
}
skill.qiaoImplemented = true

local PREVENT_RULE = "qiao__han019_1_rule"
local PREVENT_TAG = "qiao_han019_1_prevent"
local HEAL_ONE = "qiao__skill_han019_1-heal1"
local HEAL_TWO = "qiao__skill_han019_1-heal2"

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
    local to = data.to
    if to:isRemoved() then return false end
    local choices = { HEAL_ONE }
    if to:getLostHp() >= 2 then table.insert(choices, HEAL_TWO) end
    local choice = Selection.askOption(player.room, player, {
      choices = choices,
      all_choices = { HEAL_ONE, HEAL_TWO },
      skill_name = skill.name,
      prompt = "#qiao__skill_han019_1-amount::" .. to.id,
    })
    if choice == nil then return false end
    event:setCostData(self, choice == HEAL_TWO and 2 or 1)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local to = data.to
    if to == nil or to.dead or to:isRemoved() or to.hp >= to.maxHp then return end
    local num = math.min(event:getCostData(self), to:getLostHp())
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
  ["qiao__skill_han019_1"] = "烈医",
  [":qiao__skill_han019_1"] = "当你对一名角色造成伤害后，你可以令其回复至多2点体力，然后防止你本回合你再造成伤害。",
  ["#qiao__skill_han019_1-amount"] = "烈医：令 %dest 回复1点或2点体力",
  [HEAL_ONE] = "回复1点",
  [HEAL_TWO] = "回复2点",
}

return skill
