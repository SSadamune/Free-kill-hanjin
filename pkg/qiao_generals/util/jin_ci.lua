-- “赐”的公开持有记录。出牌阶段的消耗权限只取决于自己的标记。
local Discard = require "packages.qiao.pkg.qiao_mode.rules.general_discard"
local M = {
  SKILL = "qiao__skill_em_jin001_banner",
  CONSUME = "qiao__skill_em_jin001_consume",
  MARK = "@[qiao_ci]",
  SPENT = "qiao_jin001_ci_spent-phase",
}

function M.cards(holder)
  local mark = holder:getMark(M.MARK)
  if type(mark) == "table" then return mark end
  -- 旧房间的公开标记只保存数量，实体将牌名单存在持有人身上的旗名标记里。
  return holder:getTableMark(M.SKILL)
end

function M.canSpend(player)
  return player ~= nil and not player.dead and not player:isRemoved() and player.phase == Player.Play
    and player:getMark(M.SPENT) == 0 and #M.cards(player) > 0
end

function M.canChoose(player, general)
  return type(general) == "string" and M.canSpend(player)
    and table.contains(M.cards(player), general)
end

function M.save(room, holder, list)
  -- 1 仅表示持旗者可查看空册。所有实体牌直接保存在各持有者的“赐”标记上。
  local value = #list > 0 and list or (holder:isAlive() and holder:hasShownSkill(M.SKILL, true) and 1 or 0)
  if holder:getMark(M.SKILL) ~= 0 then room:setPlayerMark(holder, M.SKILL, 0) end
  if holder:getMark(M.MARK) ~= value then room:setPlayerMark(holder, M.MARK, value) end
end

function M.refreshMark(room, holder)
  if type(holder:getMark(M.MARK)) ~= "table" then M.save(room, holder, M.cards(holder)) end
end

function M.consume(room, holder, chosen)
  local remaining = M.cards(holder)
  if not table.removeOne(remaining, chosen) then return false end
  Discard.add(room, { chosen })
  M.save(room, holder, remaining)
  return true
end

return M
