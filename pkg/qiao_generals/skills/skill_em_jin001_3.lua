-- EM(JIN001) 司马炎 · 鼎沸
-- 限定技：结束阶段，若晋势力角色已损失体力之和大于体力之和，摸两张牌，
-- 然后失去太康并获得同文兴图。
local skill = fk.CreateSkill {
  name = "qiao__skill_em_jin001_3",
  tags = { Skill.Limited },
}
skill.qiaoImplemented = true

local TAIKANG = "qiao__skill_em_jin001_1"
local XINGTU = "qiao__skill_jin001_2"
local LIMIT = "qiao_jin001_dingfei_used"
local LOST = "qiao_jin001_taikang_lost"
skill.qiao_limited_used_marks = { LIMIT }

local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
Exchange.registerSkillProviderFilter(function(room, generalName, skillName)
  if generalName == "qiao_heg__em_jin001" and skillName == TAIKANG then
    return room:getTag(LOST) ~= true
  end
  return true
end)

local function condition(room)
  local lost, hp = 0, 0
  for _, p in ipairs(room:getPresentPlayers()) do
    if not p.dead and not p:isRemoved() and p.kingdom == "jin" then
      lost = lost + math.max(0, p.maxHp - p.hp)
      hp = hp + math.max(0, p.hp)
    end
  end
  return lost > hp
end

skill:addEffect(fk.EventPhaseStart, {
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and player.phase == Player.Finish
      and player:hasSkill(skill.name) and player:getMark(LIMIT) == 0
      and condition(player.room)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__jin001_dingfei-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, LIMIT, 1)
    player:drawCards(2, skill.name)
    if player.dead then return end
    room:setTag(LOST, true)
    room:handleAddLoseSkills(player, "-" .. TAIKANG, nil)
    room:handleAddLoseSkills(player, XINGTU, skill.name)
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "鼎沸",
  [":" .. skill.name] = "限定技，结束阶段，若晋势力角色已损失体力值之和大于其体力值之和，你可以摸两张牌，然后失去“太康”并获得“兴图”。",
  ["#qiao__jin001_dingfei-invoke"] = "鼎沸：是否摸两张牌并失去太康、获得兴图",
}

return skill
