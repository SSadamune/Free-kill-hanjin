local skill = fk.CreateSkill {
  name = "hanjin__six_swords_skill",
  tags = { Skill.Compulsory },
  attached_equip = "hanjin__six_swords",
}

local H = require "packages.hegemony.util"

skill:addEffect("atkrange", {
  correct_func = function(self, from, to)
    if from.kingdom ~= "unknown" then
      return #table.filter(Fk:currentRoom().alive_players, function(p)
        return from ~= p and H.compareKingdomWith(from, p)
          and table.find(p:getEquipments(Card.SubtypeWeapon), function(c)
            return Fk:getCardById(c).name == self.attached_equip
          end)
      end)
    end
  end,
})

Fk:loadTranslationTable {
  ["hanjin__six_swords_skill"] = "吴六剑",
}

return skill
