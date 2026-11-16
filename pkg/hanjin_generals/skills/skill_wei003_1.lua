-- WEI003 夏侯惇 · 刚烈
--
-- 当你受到伤害后，你可以判定，若为：红色，你对来源造成1点伤害；黑色，你
-- 弃置来源的一张牌。来源须仍在场；判定后来源死亡或没有可弃的牌时，
-- 对应分支不再执行。伤害为无牌来源的普通伤害。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wei003_1",
}
skill.hanjinImplemented = true

skill:addEffect(fk.Damaged, {
  anim_type = "masochism",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and data.from ~= nil and not data.from.dead
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei003_1-invoke:" .. data.from.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local from = data.from
    if from == nil then return end
    local judge = {
      who = player,
      reason = skill.name,
      pattern = ".",
    }
    room:judge(judge)
    if judge.card == nil or from.dead then return end
    if judge.card.color == Card.Red then
      room:damage {
        from = player,
        to = from,
        damage = 1,
        skillName = skill.name,
      }
    elseif judge.card.color == Card.Black then
      if #from:getCardIds("he") == 0 then return end
      local card = room:askToChooseCard(player, {
        target = from,
        flag = "he",
        skill_name = skill.name,
        prompt = "#hanjin__skill_wei003_1-discard:" .. from.id,
      })
      if card == nil or card == -1 then return end
      if not table.contains(from:getCardIds("he"), card) then return end
      room:throwCard({ card }, skill.name, from, player)
    end
  end,
})

Fk:loadTranslationTable {
  ["#hanjin__skill_wei003_1-invoke"] = "刚烈：你可以判定，红色对 %src 造成1点伤害，黑色弃置其一张牌",
  ["#hanjin__skill_wei003_1-discard"] = "刚烈：弃置 %src 的一张牌",
}

return skill
