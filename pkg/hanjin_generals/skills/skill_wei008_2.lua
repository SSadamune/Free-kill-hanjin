-- WEI008 夏侯渊 · 设变
--
-- 规则基线：rules/standard-generals.md 魏区 WEI008。
-- 触发时机是“失去体力后”，因此监听真实的 fk.HpLost；受到伤害不是失去体力
-- 的同义词，不以 fk.Damaged 触发。移动场上一张牌复用公共的两步接口。
local W = require "packages.hanjin.pkg.hanjin_generals.util.wei_phases"

local skill = fk.CreateSkill {
  name = "hanjin__skill_wei008_2",
}

skill:addEffect(fk.HpLost, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and not player.dead
      and W.hasMovableBoardCard(player.room)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei008_2-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    W.moveCardInBoard(player.room, player, skill.name)
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_wei008_2"] = "设变",
  [":hanjin__skill_wei008_2"] = "当你失去体力后，你可以移动场上一张牌。",
  ["#hanjin__skill_wei008_2-invoke"] = "设变：你可以移动场上一张牌",
}

skill.hanjinImplemented = true

return skill
