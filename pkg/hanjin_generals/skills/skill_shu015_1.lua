local skill = fk.CreateSkill {
  name = "hanjin__skill_shu015_1",
  tags = { Skill.Compulsory },
}
skill.hanjinImplemented = true

local NANMAN = "savage_assault"

Fk:loadTranslationTable {
  ["hanjin__skill_shu015_1"] = "巨象",
  [":hanjin__skill_shu015_1"] = "锁定技，【南蛮入侵】对你无效；当其他角色使用的【南蛮入侵】结算结束后，你获得之。",
}

skill:addEffect(fk.TargetConfirmed, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and data.card ~= nil
      and data.card.trueName == NANMAN
  end,
  on_use = function(self, event, target, player, data)
    data:setNullified(player)
  end,
})

-- 只在该南蛮整张结算结束后拿一次；自身使用不获得；无实体/已不可取得则不凭空给牌。
skill:addEffect(fk.CardUseFinished, {
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(skill.name) and data.card ~= nil
      and data.card.trueName == NANMAN and data.from ~= player
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cards = Card:getIdList(data.card)
    if #cards == 0 then return end
    if table.every(cards, function(id)
      local area = room:getCardArea(id)
      return area == Card.DiscardPile or area == Card.Processing
    end) then
      room:obtainCard(player, cards, true, fk.ReasonJustMove, player)
    end
  end,
})

return skill
