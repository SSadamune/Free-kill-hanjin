-- SHU012 姜维·天覆的公开攻击范围规则。
-- 当前回合角色实际处于任一已明置天覆来源的队列时，全场攻击范围+2。
local H = require "packages.hegemony.util"

local skill = fk.CreateSkill { name = "qiao__skill_shu012_2_rule" }
local TIANFU = "qiao__skill_shu012_2"

skill:addEffect("atkrange", {
  correct_func = function(self, from)
    local room = Fk:currentRoom()
    if room == nil or room.current == nil then return 0 end
    for _, holder in ipairs(room.alive_players) do
      if not holder.dead and not holder:isRemoved()
        and holder:hasShownSkill(TIANFU)
        and H.inFormationRelation(holder, room.current) then
        return 2
      end
    end
    return 0
  end,
})

return skill
