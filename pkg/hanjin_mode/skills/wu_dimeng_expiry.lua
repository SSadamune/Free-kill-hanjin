-- 吴包：缔盟“纵横好施”到期清理的静态模式辅助技能。
--
-- 由 mode.lua 在 logic:start 时安装（整合接线）；也可由缔盟取得/授予时确保
-- 存在。授予状态不带 `-turn` 后缀，因此不会被授予时所在回合的结束清理，
-- 只在目标自己的下一个回合结束时移除；来源级移除仅删除缔盟这一来源，
-- 保留目标原有或之后从其他来源获得的同名技能。
local skill = fk.CreateSkill {
  name = "hanjin__wu_dimeng_expiry",
}

local HAOSHI = "hanjin__skill_wu014_1"
local DIMENG_SOURCE = "hanjin__skill_wu014_2"
local GRANT_MARK = "hanjin_wu_dimeng_granted"

skill:addEffect(fk.TurnEnd, {
  global = true,
  is_delay_effect = true,
  can_refresh = function(self, event, target, player, data)
    return target ~= nil and target:getMark(GRANT_MARK) > 0
  end,
  on_refresh = function(self, event, target, player, data)
    local room = target.room
    room:setPlayerMark(target, GRANT_MARK, 0)
    if not target.dead then
      -- 来源级移除：只删除缔盟授予的那一份，保留其他来源的同名技能。
      room:handleAddLoseSkills(target, "-" .. HAOSHI, DIMENG_SOURCE, false, true)
    end
  end,
})

return skill
