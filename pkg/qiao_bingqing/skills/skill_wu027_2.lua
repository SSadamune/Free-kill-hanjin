local C = require "packages.qiao.pkg.qiao_bingqing.chunyi"
local H = require "packages.hegemony.util"
local skill = fk.CreateSkill { name = C.root }
C.addWine(skill)

-- 引擎的通用附加技会发给所有其他角色。醇义的入口随公开势力及明置来源同步。
local function sync(_, player)
  C.sync(player.room)
end

skill:addAcquireEffect(sync)
skill:addLoseEffect(sync)
for _, timing in ipairs({ fk.GeneralShown, fk.GeneralRevealed, fk.GeneralHidden, fk.AfterPropertyChange,
  fk.Death, fk.AfterPlayerRevived, H.GeneralRemoved, H.PlayerRemoved }) do
  skill:addEffect(timing, {
    global = true,
    late_refresh = true,
    can_refresh = function(_, _, target, player) return target == player end,
    on_refresh = function(_, _, _, player) C.sync(player.room) end,
  })
end
return skill
