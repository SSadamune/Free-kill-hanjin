-- 并州狼骑 · 距离状态辅助骨架（随包加载，服务端/客户端同一份）
--
-- 由并州狼骑在建立“本回合与其距离视为1”的关系时，挂到关系双方身上。
-- 关系不是标量覆盖：每名角色用表标记记录本回合所有对手 id，支持多个来源与
-- 多个持有者同时存在。距离状态技只读这些公开同步的标记。
local PAIR_MARK = "@[hanjin_bingzhou_pairs]"

local function pairsOf(player)
  local mark = player:getMark(PAIR_MARK)
  return type(mark) == "table" and mark or {}
end

local skill = fk.CreateSkill {
  name = "hanjin__retinue_skill_bingzhou_distance",
}

skill:addEffect("distance", {
  fixed_func = function(self, from, to)
    if table.contains(pairsOf(from), to.id) or table.contains(pairsOf(to), from.id) then
      return 1
    end
    return nil
  end,
})

Fk:loadTranslationTable {
  ["hanjin__retinue_skill_bingzhou_distance"] = "并州狼骑·距离",
}

return skill
