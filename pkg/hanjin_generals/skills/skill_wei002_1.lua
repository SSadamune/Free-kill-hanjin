-- WEI002 司马懿 · 狼顾
--
-- 当你受到伤害后，你可以获得来源的一张牌。来源须仍在场且至少有一张手牌或
-- 装备牌；伤害来源为自己时只可能取得自己的装备区牌，不取得自己的手牌。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wei002_1",
}
skill.hanjinImplemented = true

skill:addEffect(fk.Damaged, {
  anim_type = "masochism",
  can_trigger = function(self, event, target, player, data)
    if target ~= player or not player:hasSkill(skill.name) then return false end
    local from = data.from
    if from == nil or from.dead then return false end
    if from == player then return #player:getCardIds(Player.Equip) > 0 end
    return not from:isNude()
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei002_1-invoke:" .. data.from.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local from = data.from
    if from == nil or from.dead then return end
    local flag = from == player and "e" or "he"
    local card = room:askToChooseCard(player, {
      target = from,
      flag = flag,
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei002_1-choose:" .. from.id,
    })
    if card == nil or card == -1 then return end
    if not table.contains(from:getCardIds(flag), card) then return end
    room:obtainCard(player, card, false, fk.ReasonPrey, player, skill.name)
  end,
})

Fk:loadTranslationTable {
  ["#hanjin__skill_wei002_1-invoke"] = "狼顾：你可以获得 %src 的一张牌",
  ["#hanjin__skill_wei002_1-choose"] = "狼顾：获得 %src 的一张牌",
}

return skill
