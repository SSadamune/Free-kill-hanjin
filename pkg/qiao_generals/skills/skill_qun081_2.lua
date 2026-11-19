-- QUN081 徐荣 · 杀绝
--
-- 任意角色进入濒死且体力<0时，可以获得造成此次濒死的伤害牌。直接读取本次
-- DyingData.damage 的牌，不查询“最近一次伤害”；只取得仍在处理区的实体材料。
local skill = fk.CreateSkill {
  name = "qiao__skill_qun081_2",
}
skill.qiaoImplemented = true

---@param room Room
---@param damage DamageData?
---@return integer[]
local function obtainableCards(room, damage)
  if damage == nil or damage.card == nil then return {} end
  return room:getSubcardsByRule(damage.card, { Card.Processing })
end

skill:addEffect(fk.EnterDying, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(skill.name) and not player.dead
      and target ~= nil and target.hp < 0
      and data ~= nil and data.damage ~= nil
      and #obtainableCards(player.room, data.damage) > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_qun081_2-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local ids = obtainableCards(room, data.damage)
    if #ids == 0 or player.dead then return end
    local damageCard = data.damage.card
    local card = Fk:cloneCard(damageCard.name, damageCard.suit, damageCard.number)
    card:addSubcards(ids)
    room:obtainCard(player, card, true, fk.ReasonPrey,
      data.damage.from or player, skill.name)
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_qun081_2"] = "杀绝",
  [":qiao__skill_qun081_2"] = "有角色进入濒死状态时，若其体力小于0，你可以获得造成此伤害的牌。",
  ["#qiao__skill_qun081_2-invoke"] = "杀绝：你可以获得造成此伤害的牌",
}

return skill
