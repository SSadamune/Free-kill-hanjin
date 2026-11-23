-- WU010 孙策·魂殇的回合结束清理。
--
-- 回合结束时移除以本技能为来源的临时副本，保留其他独立来源。
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
    room:handleAddLoseSkills(player, "-" .. YINGHUN .. "|-" .. YINGZI, SKILL_NAME, false, true)
    room:setPlayerMark(player, MARK, 0)
  end,
})

return skill
