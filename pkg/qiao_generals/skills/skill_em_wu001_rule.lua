-- EM(WU001) 缘江烽火图：已建立后续效果的独立房间技能。
-- 两件事都由本静态技能承担，不依赖当前是否仍持有缘江烽火图：
--   1. 受牌伤害后建立的“本回合下次受到的伤害-1”，只对该次伤害生效、用后消耗；
--   2. 准备阶段临时授技与本回合减伤待生效次数在回合结束（或受益者死亡）时清理。
-- “本回合”按当前回合计算：任一回合结束时，所有尚未消耗的减伤都失效。
local P = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wu"

local skill = fk.CreateSkill { name = P.RULE }

-- 已建立的减伤：不限定伤害渠道（技能伤害也适用），每次消耗一项。
skill:addEffect(fk.DetermineDamageInflicted, {
  global = true,
  is_delay_effect = true,
  can_trigger = function(self, event, target, player, data)
    if target ~= player or data == nil then return false end
    if data.prevented or (data.damage or 0) < 1 then return false end
    return P.pending(player) > 0
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    if not P.consumePending(room, player) then return end
    data:changeDamage(-1)
  end,
})

--- 清除所有角色尚未消耗的本回合减伤。
local function clearAllPending(room)
  for _, p in ipairs(room.players) do
    P.clearPending(room, p)
  end
end

--- 场上是否还有任何待清理的减伤。
local function anyPending(room)
  for _, p in ipairs(room.players) do
    if P.pending(p) > 0 then return true end
  end
  return false
end

-- 回合结束：本回合建立的减伤全部失效，临时授技只撤本次来源。
skill:addEffect(fk.TurnEnd, {
  global = true,
  is_delay_effect = true,
  can_refresh = function(self, event, target, player, data)
    if target == nil or target ~= player then return false end
    return P.hasTemp(player.room, target) or anyPending(player.room)
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    P.expireTemp(room, target)
    clearAllPending(room)
  end,
})

-- 死亡：撤销该角色本次授予与尚未消耗的减伤。
skill:addEffect(fk.Death, {
  global = true,
  is_delay_effect = true,
  can_refresh = function(self, event, target, player, data)
    return target ~= nil and target == player
      and (P.hasTemp(player.room, target) or P.pending(target) > 0)
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    P.expireTemp(room, target)
    P.clearPending(room, target)
  end,
})

return skill
