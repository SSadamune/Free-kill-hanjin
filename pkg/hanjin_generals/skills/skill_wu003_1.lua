-- WU003 吕蒙 · 克己
--
-- 锁定技，弃牌阶段开始时，若你未于出牌阶段使用过两种颜色的牌，你本回合
-- 手牌上限+4。
--
-- 只统计真实出牌阶段内、由自己使用的牌；使用纯“打出”的响应牌不算使用。
-- 颜色使用引擎卡牌的有效颜色；无色牌不计入任一颜色。效果通过引擎
-- AddMaxCardsInTurn 标记实现，随回合结束自动清除。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wu003_1",
  tags = { Skill.Compulsory },
}
skill.hanjinImplemented = true

local W = require "packages.hanjin.pkg.hanjin_generals.util.wu_phases"

skill:addEffect(fk.EventPhaseChanging, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    if target ~= player or not player:hasSkill(skill.name) then return false end
    if data.phase ~= Player.Discard or data.skipped then return false end
    local colors = {}
    for _, record in ipairs(W.playPhaseUsed(player)) do
      if record.color == Card.Red or record.color == Card.Black then
        colors[record.color] = true
      end
    end
    return not (colors[Card.Red] and colors[Card.Black])
  end,
  on_use = function(self, event, target, player)
    player.room:addPlayerMark(player, MarkEnum.AddMaxCardsInTurn, 4)
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_wu003_1"] = "克己",
}

return skill
