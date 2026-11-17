-- WU010 孙策·魂殇的回合结束清理。
--
-- 独立于魂殇本体注册，避免魂殇在回合结束前失去时临时授予的英魂/英姿无法
-- 按来源清理。只移除以魂殇为来源的副本，原有独立技能不受影响。
local SKILL_NAME = "qiao__wu010_hunshang_cleanup"
local SOURCE = "qiao__skill_wu010_3"
local MARK = SOURCE .. "-cleanup-granted"
local YINGHUN = "qiao__skill_wu009_1"
local YINGZI = "qiao__skill_wu005_1"

local skill = fk.CreateSkill {
  name = SKILL_NAME,
}

skill:addEffect(fk.TurnEnd, {
  global = true,
  can_refresh = function(self, event, target, player)
    return player ~= nil and player:getMark(MARK) > 0
  end,
  on_refresh = function(self, event, target, player)
    local room = player.room
    room:handleAddLoseSkills(player, "-" .. YINGHUN, SOURCE, false, true)
    room:handleAddLoseSkills(player, "-" .. YINGZI, SOURCE, false, true)
    room:setPlayerMark(player, MARK, 0)
  end,
})

return skill
