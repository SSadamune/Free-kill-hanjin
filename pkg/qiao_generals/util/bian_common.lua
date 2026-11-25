-- 六势力变包共用辅助。
-- 客户端可达查询统一使用 Fk:currentRoom() 与公开标记，不访问服务端 room tag 或私有字段。
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"

local M = {}

-- 武将交换完成监听：同步伍琼&种辑个人鏖战状态。
Exchange.addCompletionListener(function(room, context)
  if room == nil or context == nil then return end
  local BattleRoyal = require "packages.qiao.pkg.qiao_mode.rules.battle_royal"
  for _, side in ipairs(context.sides or {}) do
    local p = side.player
    if p ~= nil then
      BattleRoyal.syncPersonal(room, p, "qiao__skill_han023_2",
        not p.dead and p:hasShownSkill("qiao__skill_han023_2", true))
    end
  end
end)

return M
