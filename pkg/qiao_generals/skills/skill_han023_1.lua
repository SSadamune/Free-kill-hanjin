-- HAN023 伍琼&种辑 · 除奸
-- 其他角色的出牌阶段开始时，若其体力值或手牌数最大，你可以令其此阶段对你使用【杀】
-- 无距离和次数限制，然后此阶段结束时，你对其造成1点伤害。
local skill = fk.CreateSkill {
  name = "qiao__skill_han023_1",
}
skill.qiaoImplemented = true

local CHUJIAN_TARGET = "qiao_han023_chujian-phase"
local CHUJIAN_DELAY = "qiao_han023_chujian_delay-phase"

local function isMaxHpOrHand(room, target)
  local players = room:getPresentPlayers()
  if #players == 0 then return false end
  local maxHp, maxHand
  for _, p in ipairs(players) do
    if maxHp == nil or p.hp > maxHp then maxHp = p.hp end
    local hand = p:getHandcardNum()
    if maxHand == nil or hand > maxHand then maxHand = hand end
  end
  return target.hp == maxHp or target:getHandcardNum() == maxHand
end

skill:addEffect(fk.EventPhaseStart, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return target ~= nil and target ~= player and target.phase == Player.Play
      and not target.dead and not target:isRemoved()
      and player:hasSkill(skill.name)
      and isMaxHpOrHand(player.room, target)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_han023_1-invoke::" .. target.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:doIndicate(player.id, { target.id })
    room:addTableMarkIfNeed(target, CHUJIAN_TARGET, player.id)
    room:addTableMark(target, CHUJIAN_DELAY, player.id)
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "除奸",
  [":" .. skill.name] = "其他角色的出牌阶段开始时，若其体力值或手牌数最大，你可以令其此阶段对你使用【杀】无距离和次数限制，然后此阶段结束时，你对其造成1点伤害。",
  ["#qiao__skill_han023_1-invoke"] = "除奸：是否令 %dest 本出牌阶段对你用【杀】无距离和次数限制，阶段结束时对其造成1点伤害",
}

return skill
