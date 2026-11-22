-- “赐”的公开持有记录。出牌阶段的消耗权限只取决于自己的标记。
local Discard = require "packages.qiao.pkg.qiao_mode.rules.general_discard"
local M = {
  SKILL = "qiao__skill_em_jin001_banner",
  CONSUME = "qiao__skill_em_jin001_consume",
  MARK = "@[qiao_ci]",
  SPENT = "qiao_jin001_ci_spent-phase",
}

function M.canSpend(player)
  return player ~= nil and not player.dead and not player:isRemoved() and player.phase == Player.Play
    and player:getMark(M.SPENT) == 0 and #player:getTableMark(M.SKILL) > 0
end

function M.canChoose(player, general)
  return type(general) == "string" and M.canSpend(player)
    and table.contains(player:getTableMark(M.SKILL), general)
end

function M.refreshMark(room, holder)
  local count = #holder:getTableMark(M.SKILL)
  -- 0 会移除标记，持旗者的空列表也需要能打开。
  local value = (count > 0 or (holder:isAlive() and holder:hasShownSkill(M.SKILL, true))) and count + 1 or 0
  if holder:getMark(M.MARK) ~= value then room:setPlayerMark(holder, M.MARK, value) end
end

function M.save(room, holder, list)
  room:setPlayerMark(holder, M.SKILL, #list > 0 and list or 0)
  M.refreshMark(room, holder)
end

function M.consume(room, holder, chosen)
  local remaining = holder:getTableMark(M.SKILL)
  if not table.removeOne(remaining, chosen) then return false end
  Discard.add(room, { chosen })
  M.save(room, holder, remaining)
  return true
end

return M
