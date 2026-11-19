-- SHU016 甘夫人 · 神智
--
-- 规则基线：docs/rules/standard-generals.md 蜀区 SHU016。
-- 准备阶段，你可以弃置所有手牌，然后若弃牌数大于等于体力值，你回复1点体力。
-- 发动消耗至少一张手牌，且必须能足额弃置全部手牌；结算按实际弃置张数与
-- 当时体力值比较。
local skill = fk.CreateSkill {
  name = "qiao__skill_shu016_2",
}
skill.qiaoImplemented = true

local function handIds(player)
  return player:getCardIds(Player.Hand)
end

local function canDiscardAll(player)
  local ids = handIds(player)
  if #ids == 0 then return false end
  for _, id in ipairs(ids) do
    if player:prohibitDiscard(id) then return false end
  end
  return true
end

skill:addEffect(fk.EventPhaseStart, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and not player.dead
      and data.phase == Player.Start and canDiscardAll(player)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_shu016_2-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local ids = handIds(player)
    if #ids == 0 then return end
    for _, id in ipairs(ids) do
      if player:prohibitDiscard(id) then return end
    end
    local count = #ids
    room:throwCard(ids, skill.name, player, player)
    if player.dead then return end
    if count >= player.hp then
      room:recover {
        who = player,
        num = 1,
        recoverBy = player,
        skillName = skill.name,
      }
    end
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_shu016_2"] = "神智",
  [":qiao__skill_shu016_2"] = "准备阶段，你可以弃置所有手牌，然后若弃牌数大于等于体力值，你回复1点体力。",
  ["#qiao__skill_shu016_2-invoke"] = "神智：弃置所有手牌，若不少于体力值则回复1点体力",
}

return skill
