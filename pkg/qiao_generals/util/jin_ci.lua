-- 展示面板提交的赐须仍由本人持有，且本人仍可在出牌阶段消耗它。
local M = { SKILL = "qiao__skill_em_jin001_banner" }

function M.canChoose(player, general)
  return type(general) == "string" and player.phase == Player.Play and player:hasSkill(M.SKILL)
    and table.contains(player:getTableMark(M.SKILL), general)
end

return M
