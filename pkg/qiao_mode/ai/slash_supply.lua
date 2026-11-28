local Adaptation = require "packages.qiao.pkg.qiao_mode.rules.adaptation"
local Health = require "packages.qiao.pkg.qiao_mode.ai.health_value"

local M = {}

local function capacity(ai, card, target, future)
  local player = ai.player
  local skill = card:getSkill(player)
  local limit = skill:getMaxUseTime(player, Player.HistoryPhase, card, target)
  if not limit or player:hasMark(MarkEnum.BypassTimesLimit) or target:hasMark(MarkEnum.BypassTimesLimitTo)
    or card:hasMark(MarkEnum.BypassTimesLimit) then return math.huge end
  for _, mod in ipairs(ai.room.status_skills[TargetModSkill] or Util.DummyTable) do
    if mod:bypassTimesCheck(player, skill, Player.HistoryPhase, card, target) then return math.huge end
  end
  local used = not future and ai.room.current == player and player.phase == Player.Play
    and player:usedCardTimes("slash", Player.HistoryPhase) or 0
  return math.max(0, limit - used)
end

function M.cardCapacity(ai, card, options)
  options = options or Util.DummyTable
  local extra = { bypass_times = true, bypass_distances = options.far }
  local best
  for _, target in ipairs(ai.room:getPresentPlayers()) do
    if ai:isEnemy(target) and ai.player:canUseTo(card, target, extra)
      and (not options.safe or options.safe(ai, card, target)) then
      best = math.max(best or 0, capacity(ai, card, target, options.future))
    end
  end
  return best
end

function M.plan(ai, options)
  local normal, free, limit = 0, 0, 0
  for _, id in ipairs(ai.player:getCardIds("h")) do
    local card = Fk:getCardById(id)
    if card.trueName == "slash" then
      local available = M.cardCapacity(ai, card, options)
      if available then
        if Adaptation.ignoreTimesCandidate(ai.room, ai.player, card) then
          free = free + 1
        else
          normal = normal + 1
          limit = math.max(limit, available)
        end
      end
    end
  end
  return { normal = normal, free = free, limit = limit }
end

function M.sealOption(ai, prop, safe)
  local player = ai.player
  local current = ai.room.logic:getCurrentEvent()
  local turn = current and current:findParent(GameEvent.Turn, true)
  local hasPlay = not turn or player:canSkip(Player.Play)
  local plan = hasPlay and M.plan(ai, { future = true, safe = safe }) or { normal = 0, free = 0, limit = 0 }
  local base = prop.baseValues
  local before = math.min(plan.normal, plan.limit)
  local drawn = (not turn or player:canSkip(Player.Draw)) and 1 or 0
  local baseOverflow = math.max(0, player:getHandcardNum() + drawn * base.draw - before - plan.free - base.hand)
  local chosen, best = nil, 0
  for _, option in ipairs(prop.options) do
    local limit = math.max(0, plan.limit + option.slash)
    local useful = math.min(plan.normal, limit)
    local overflow = math.max(0,
      player:getHandcardNum() + drawn * (base.draw + option.draw) - useful - plan.free - base.hand - option.hand)
    local score = 3 * drawn * option.draw + Health.damage(ai, 0.75) * (useful - before) + baseOverflow - overflow
    if base.slash > 0 and base.slash + option.slash == 0 and limit ~= math.huge then score = score - 1.5 end
    if score > best then chosen, best = option, score end
  end
  return chosen
end

return M
