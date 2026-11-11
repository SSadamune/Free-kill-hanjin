local H = require "packages.hegemony.util"
local skill = fk.CreateSkill {
  name = "hanjin__jade_seal_skill",
  attached_equip = "hanjin__jade_seal",
  tags = { Skill.Compulsory },
}

skill:addEffect(fk.EventPhaseStart, {
  anim_type = "control",
  can_trigger = function(self, event, target, player)
    return target == player and player:hasSkill(skill.name)
      and player.phase == Player.Play and H.isBigKingdomPlayer(player)
  end,
  on_cost = function(self, event, target, player)
    local room = player.room
    local card = Fk:cloneCard("hanjin__known_both")
    local maxNum = card.skill:getMaxTargetNum(player, card)
    local targets = {}
    for _, p in ipairs(room:getOtherPlayers(player, false)) do
      if player:canUseTo(card, p) then table.insert(targets, p) end
    end
    if #targets == 0 or maxNum == 0 then return end
    local to = room:askToChoosePlayers(player, {
      targets = targets, min_num = 1, max_num = maxNum,
      prompt = "#jade_seal-ask", skill_name = skill.name, cancelable = false,
    })
    if #to > 0 then
      event:setCostData(self, { tos = to })
      return true
    end
  end,
  on_use = function(self, event, target, player)
    player.room:useVirtualCard("hanjin__known_both", nil, player,
      event:getCostData(self).tos, "hanjin__jade_seal_skill")
  end,
})

skill:addEffect(fk.DrawNCards, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player)
    return target == player and player:hasSkill(skill.name) and H.isBigKingdomPlayer(player)
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    data.n = data.n + 1
  end,
})

skill:addEffect("bigkingdom", {
  fixed_func = function(self, player)
    return player:hasSkill(skill.name) and player.kingdom ~= "unknown"
  end,
})

Fk:loadTranslationTable {
  ["hanjin__jade_seal_skill"] = "玉玺",
  ["#jade_seal-ask"] = "受到【玉玺】的效果，视为你使用一张【知己知彼】",
}

return skill
