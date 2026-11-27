-- EM(SHU001) 刘备 · 激诏
-- 限定技：濒死时回复至2，失去章武、获得仁德；然后可摸等同体力上限的牌，
-- 并将手牌弃至体力上限。
local skill = fk.CreateSkill {
  name = "qiao__skill_em_shu001_3",
  tags = { Skill.Limited },
}
skill.qiaoImplemented = true

local USED = "qiao__skill_em_shu001_3-used"
skill.qiaoLimitedUseMark = USED
local ZHANGWU = "qiao__skill_em_shu001_1"
local RENDE = "qiao__skill_shu001_1"
skill.qiao_limited_used_marks = { USED }

skill:addEffect(fk.EnterDying, {
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and player:hasSkill(skill.name)
      and player:getMark(USED) == 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_em_shu001_3-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, USED, 1)
    if player.hp < 2 then
      room:recover {
        who = player, num = 2 - player.hp, recoverBy = player,
        skillName = skill.name,
      }
    end
    if player.dead then return end
    room:handleAddLoseSkills(player, "-" .. ZHANGWU, nil, false, true)
    room:handleAddLoseSkills(player, RENDE, skill.name, false, true)
    if player.dead then return end
    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_em_shu001_3-draw",
    }) then return end
    local max = player.maxHp
    player:drawCards(max, skill.name)
    local excess = #player:getCardIds("h") - max
    if excess > 0 then
      room:askToDiscard(player, {
        min_num = excess, max_num = excess, include_equip = false,
        skill_name = skill.name,
        prompt = "#qiao__skill_em_shu001_3-discard",
        cancelable = false,
      })
    end
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_em_shu001_3"] = "激诏",
  [":qiao__skill_em_shu001_3"] = "限定技，当你处于濒死时，你可以回复体力至2点并失去“章武”，获得“仁德”，然后你可以摸等同体力上限的牌，将手牌弃置至体力上限。",
  ["#qiao__skill_em_shu001_3-invoke"] = "激诏：回复至2点，失去章武并获得仁德",
  ["#qiao__skill_em_shu001_3-draw"] = "激诏：是否摸等同体力上限的牌？",
  ["#qiao__skill_em_shu001_3-discard"] = "激诏：将手牌弃至体力上限",
}

return skill
