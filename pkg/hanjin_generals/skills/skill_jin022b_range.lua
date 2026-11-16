-- JIN022B 牵弘 · 烈戎的攻击范围持续状态。
-- 独立房间静态技能：烈戎失去后，本回合已获得的攻击范围仍保留到回合结束。
local U = require "packages.hanjin.pkg.hanjin_generals.util.zhen_shi_jin"

local skill = fk.CreateSkill {
  name = U.RANGE_SKILL,
  tags = { Skill.Compulsory },
}

skill:addEffect("atkrange", {
  correct_func = function(self, from, to)
    local value = from:getMark(U.RANGE)
    if type(value) == "number" and value > 0 then return value end
  end,
})

skill:addEffect(fk.TurnEnd, {
  global = true,
  can_refresh = function(self, event, target, player)
    return target == player
  end,
  on_refresh = function(self, event, target, player)
    if player:getMark(U.RANGE) ~= 0 then
      player.room:setPlayerMark(player, U.RANGE, 0)
    end
  end,
})

return skill
