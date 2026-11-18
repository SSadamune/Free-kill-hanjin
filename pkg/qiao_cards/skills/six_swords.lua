local skill = fk.CreateSkill {
  name = "qiao__six_swords_skill",
  tags = { Skill.Compulsory },
  attached_equip = "qiao__six_swords",
}

local H = require "packages.hegemony.util"

skill:addEffect("atkrange", {
  correct_func = function(self, from, to)
    -- 移出游戏的角色视为不存在：既不能提供吴六剑加成，也不计入同势力角色数。
    if from.kingdom ~= "unknown" and not from:isRemoved() then
      return #table.filter(Fk:currentRoom():getPresentPlayers(), function(p)
        return from ~= p and not p:isRemoved() and H.compareKingdomWith(from, p)
          and table.find(p:getEquipments(Card.SubtypeWeapon), function(c)
            return Fk:getCardById(c).name == self.attached_equip
          end)
      end)
    end
  end,
})

Fk:loadTranslationTable {
  ["qiao__six_swords_skill"] = "吴六剑",
}

return skill
