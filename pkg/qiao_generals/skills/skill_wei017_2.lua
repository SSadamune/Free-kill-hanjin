-- WEI017 李典 · 忘隙
--
-- 一次伤害事件只触发一次，不按伤害点数拆分：李典对他人造成伤害后，或受到
-- 他人伤害后，李典摸一张并令对方摸一张。对方已死亡时仍结算李典自己的摸牌。
local skill = fk.CreateSkill {
  name = "qiao__skill_wei017_2",
}
skill.qiaoImplemented = true

--- 本次伤害事件中与李典相对的另一名角色；自伤或无来源伤害不触发。
---@param player ServerPlayer
---@param data DamageData
---@return ServerPlayer|nil
local function otherPlayer(player, data)
  if data == nil then return nil end
  if data.from == player and data.to ~= player then return data.to end
  if data.to == player and data.from ~= player then return data.from end
  return nil
end

local spec = {
  anim_type = "drawcard",
  -- 默认 trigger_times 为 1；不按 data.damage 增加次数。
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and player:hasSkill(skill.name)
      and data ~= nil and (data.damage or 0) > 0
      and otherPlayer(player, data) ~= nil
  end,
  on_cost = function(self, event, target, player, data)
    local other = otherPlayer(player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_wei017_2-invoke::" .. other.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    local other = otherPlayer(player, data)
    if player.dead then return end
    player:drawCards(1, skill.name)
    if other ~= nil and not other.dead and not other:isRemoved() then
      other:drawCards(1, skill.name)
    end
  end,
}

skill:addEffect(fk.Damage, spec)
skill:addEffect(fk.Damaged, spec)

Fk:loadTranslationTable {
  ["qiao__skill_wei017_2"] = "忘隙",
  [":qiao__skill_wei017_2"] = "当你对其他角色造成伤害后，或受到其他角色的伤害后，你可以摸一张牌并令其摸一张牌。",
  ["#qiao__skill_wei017_2-invoke"] = "忘隙：你可以摸一张牌，并令 %dest 摸一张牌",
}

return skill
