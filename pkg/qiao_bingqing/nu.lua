local H = require "packages.hegemony.util"
local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"
local R = require "packages.qiao.pkg.qiao_generals.util.retinue_instances"
local Interaction = require "packages.qiao.pkg.qiao_bingqing.interaction"
local M = { present = require("packages.qiao.pkg.qiao_mode.rules.removed_targets").isPresent, allies = H.compareKingdomWith }

function M.choose(p, targets, name, max, optional)
  return Interaction.choosePlayers(p.room, p, targets, name, max, optional)
end

function M.invoke(p, skill, to)
  return p.room:askToSkillInvoke(p, { skill_name = skill, target = to })
end

function M.give(p, to, ids, name)
  return Interaction.give(p.room, p, to, ids, name)
end

function M.damageHistory(p, scope)
  return p.room.logic:getActualDamageEvents(math.huge, Util.TrueFunc, scope or Player.HistoryTurn)
end

function M.slashCost(event, self, p, name, bypass)
  local policy = bypass and C.bypassDistance() or C.default()
  local use = C.selectVirtualCard(p.room, p, { name = "qiao__slash", skill_name = name,
    cancelable = true, policy = policy })
  if use then event:setCostData(self, { use = use }) end
  return use ~= nil
end

function M.each(self, event, target, p, data)
  if #R.instancesForSkill(p, self:getSkeleton().name) > 0 then
    return R.triggerEach(self, event, target, p, data)
  end
  return self:doCost(event, target, p, data)
end

function M.boardCards(p) return #p:getCardIds("ej") end

function M.discardable(p, area)
  return table.filter(p:getCardIds(area or "he"), function(id) return not p:prohibitDiscard(id) end)
end
return M
