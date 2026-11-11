local H = require "packages.hegemony.util"
local skill = fk.CreateSkill {
  name = "hanjin__peace_spell_skill",
  tags = { Skill.Compulsory },
  attached_equip = "hanjin__peace_spell",
}

skill:addEffect(fk.DetermineDamageInflicted, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and data.damageType ~= fk.NormalDamage
  end,
  on_use = function(self, event, target, player, data)
    data:preventDamage()
  end,
})

skill:addEffect("maxcards", {
  correct_func = function(self, player)
    if player:hasSkill(self.name) then
      if player.kingdom == "unknown" then return 1 end
      local num = H.getSameKingdomPlayersNum(Fk:currentRoom(), player)
      return (num or 0) + #player:getPile("heavenly_army")
    end
  end,
})

skill:addEffect(fk.AfterCardsMove, {
  can_trigger = function(self, event, target, player, data)
    if player.dead then return end
    for _, move in ipairs(data) do
      if move.from == player then
        for _, info in ipairs(move.moveInfo) do
          if info.fromArea == Card.PlayerEquip
            and Fk:getCardById(info.cardId).name == self.attached_equip then
            return Fk.skills[self.name]:isEffectable(player)
          end
        end
      end
    end
  end,
  on_use = function(self, event, target, player)
    player:drawCards(2, self.name)
    if player.hp > 1 and player:isAlive() then
      player.room:loseHp(player, 1, self.name)
    end
  end,
})

Fk:loadTranslationTable {
  ["hanjin__peace_spell_skill"] = "太平要术",
}

return skill
