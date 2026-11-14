-- WU003 吕蒙 · 谋断
--
-- 结束阶段，若你于本回合使用过四种花色或三种类别的牌，你可以移动场上
-- 一张牌；若两项均符合且你没有“涉猎”，你获得“涉猎”。
--
-- “本回合”是整回合，不限于出牌阶段；花色/类别只按真实 UseCard 事件统计。
-- 获得涉猎只授予技能，不在此次结算中额外发动涉猎（rules/generals/
-- wu003-lvmeng.md）。授予不使用谋断作为来源，失去谋断不会回收后天技能。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wu003_2",
}
skill.hanjinImplemented = true

local W = require "packages.hanjin.pkg.hanjin_generals.util.wu_phases"
local SHELIE = "hanjin__skill_wu003_3"

local function conditions(player)
  local suits, types = {}, {}
  for _, record in ipairs(W.usedThisTurn(player)) do
    if record.suit == Card.Spade or record.suit == Card.Heart
      or record.suit == Card.Club or record.suit == Card.Diamond then
      suits[record.suit] = true
    end
    types[record.type] = true
  end
  local suitCount, typeCount = 0, 0
  for _ in pairs(suits) do suitCount = suitCount + 1 end
  for _ in pairs(types) do typeCount = typeCount + 1 end
  return suitCount >= 4, typeCount >= 3
end

skill:addEffect(fk.EventPhaseStart, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    if target ~= player or not player:hasSkill(skill.name) then return false end
    if data.phase ~= Player.Finish then return false end
    local suits, types = conditions(player)
    return suits or types
  end,
  on_cost = function(self, event, target, player)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_wu003_2-invoke",
    })
  end,
  on_use = function(self, event, target, player)
    local room = player.room
    if player.dead then return end
    W.moveCardInBoard(room, player, skill.name)
    if player.dead then return end

    local suits, types = conditions(player)
    if suits and types and not player:hasSkill(SHELIE) then
      room:handleAddLoseSkills(player, SHELIE, nil, true, false)
    end
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_wu003_2"] = "谋断",
  ["#hanjin__skill_wu003_2-invoke"] = "谋断：你可以移动场上一张牌；若两项均符合且没有“涉猎”，你获得“涉猎”",
}

return skill
