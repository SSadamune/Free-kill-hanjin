local skill = fk.CreateSkill {
  name = "qiao__skill_shu015_2",
}
skill.qiaoImplemented = true

Fk:loadTranslationTable {
  ["qiao__skill_shu015_2"] = "烈刃",
  [":qiao__skill_shu015_2"] = "当你使用【杀】对一个目标造成伤害后，你可以与其拼点：若你赢，你获得其一张牌。",
  ["#qiao__skill_shu015_2-invoke"] = "烈刃：是否与%src拼点？",
  ["#qiao__skill_shu015_2-card"] = "烈刃：选择 %src 的一张牌获得",
}

skill:addEffect(fk.DamageFinished, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(skill.name) or data.from ~= player or data.card == nil
      or data.card.trueName ~= "slash" or data.to == nil or data.to.dead
      or data.to:isRemoved() or not player:canPindian(data.to) then
      return false
    end
    local current = player.room.logic:getCurrentEvent()
    local useEvent = current and current:findParent(GameEvent.UseCard, true)
    local use = useEvent and useEvent.data
    -- 必须是本次【杀】的真实目标，链伤路人不能触发。
    return use ~= nil and use:hasTarget(data.to)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_shu015_2-invoke:" .. data.to.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local to = data.to
    if player.dead or to == nil or to.dead or to:isRemoved() or not player:canPindian(to) then return end
    local pindian = player:pindian({ to }, skill.name)
    local result = pindian and pindian.results and pindian.results[to]
    local winner = result and result.winner
    if winner ~= player then return end
    local cards = to:getCardIds("he")
    if #cards == 0 then return end
    local chosen = room:askToChooseCards(player, {
      target = to,
      flag = "he",
      min = 1,
      max = 1,
      skill_name = skill.name,
      prompt = "#qiao__skill_shu015_2-card:" .. to.id,
      cancelable = false,
    })
    local id = chosen and chosen[1]
    if id ~= nil then
      room:obtainCard(player, id, false, fk.ReasonPrey, player, skill.name)
    end
  end,
})

return skill
