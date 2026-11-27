local skill = fk.CreateSkill { name = "qiao__skill_jin037_2", attached_skill_name = "qiao__chuming_other&" }

-- 酒进入结算后材料仍在处理区，在引擎的用后清理前交给受酒者。
skill:addEffect(fk.CardUseFinished, {
  global = true, is_delay_effect = true, mute = true,
  can_refresh = function(self, event, target, p, data)
    return target == p and data.extra_data and data.extra_data.qiao_chuming_recipient ~= nil
      and table.contains(data.card.skillNames, skill.name)
  end,
  on_refresh = function(self, event, target, p, data)
    local room = p.room
    local to = room:getPlayerById(data.extra_data.qiao_chuming_recipient)
    local ids = room:getSubcardsByRule(data.card, { Card.Processing })
    if to and not to.dead and #ids > 0 then
      room:moveCardTo(ids, Card.PlayerHand, to, fk.ReasonGive, skill.name, nil, true, p)
    end
  end,
})
return skill
