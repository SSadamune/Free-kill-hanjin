local A = require "packages.hanjin.pkg.hanjin_mode.rules.adaptation"
local skill = fk.CreateSkill {
  name = "hanjin__bronze_sparrow_skill",
  tags = { Skill.Compulsory },
  attached_equip = "hanjin__bronze_sparrow",
}

Fk:loadTranslationTable {
  ["hanjin__bronze_sparrow_skill"] = "铜雀",
}

-- The reference 铜雀 lets the first adaptation card each turn ignore one
-- condition. HanJin adaptation uses use-scoped ignore tokens rather than the
-- upstream `variation_type` marker, so the adapter grants exactly one token.
skill:addEffect(fk.PreCardUse, {
  mute = true,
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and player:usedSkillTimes(skill.name, Player.HistoryTurn) == 0
      and A.isAdaptationCard(data.card, data)
  end,
  on_use = function(self, event, target, player, data)
    player:setSkillUseHistory(skill.name, 1, Player.HistoryTurn)
    A.grantIgnore(data, skill.name)
  end,
})

return skill
