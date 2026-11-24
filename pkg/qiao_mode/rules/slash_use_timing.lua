local M = {}

local idleUses = setmetatable({}, { __mode = "k" })
local idleReplies = setmetatable({}, { __mode = "k" })
local wrappedViewAs = setmetatable({}, { __mode = "k" })
local wrappedCardSkills = setmetatable({}, { __mode = "k" })
local EFFECT_REQUEST = "qiao_slash_effect_request"

--- 【杀】在效果中的候选查询与执行使用同一份次数参数。
function M.effectTargetData(extra)
  local data = table.simpleClone(extra or {})
  data.bypass_times = true
  return data
end

function M.applyEffectUse(use)
  if type(use) == "table" and use.card and use.card.trueName == "slash" and not idleUses[use] then
    if not (use.extra_data or {}).bypass_times then
      use.extra_data = M.effectTargetData(use.extra_data)
    end
    use.extraUse = true
  end
  return use
end

local function slashRequestData(extra)
  if extra and extra[EFFECT_REQUEST] and not extra.bypass_times then
    return M.effectTargetData(extra)
  end
  return extra
end

--- 两端按请求上下文检查【杀】，混合用牌请求中的其他牌仍遵循原参数。
function M.installCardChecks()
  for _, card in pairs(Fk.all_card_types) do
    local skill = card.trueName == "slash" and card.skill
    if skill and not wrappedCardSkills[skill] then
      wrappedCardSkills[skill] = true
      local canUse, targetFilter = skill.canUse, skill.targetFilter
      function skill:canUse(player, card, extra)
        return canUse(self, player, card, slashRequestData(extra))
      end
      function skill:targetFilter(player, target, selected, cards, card, extra)
        return targetFilter(self, player, target, selected, cards, card, slashRequestData(extra))
      end
    end
  end
end

local function markIdleUse(use)
  if type(use) == "table" and use.card then idleUses[use] = true end
  return use
end

local function wrapViewAs(skill)
  if wrappedViewAs[skill] then return end
  wrappedViewAs[skill] = true
  local onUse = skill.onUse
  function skill:onUse(room, effect, card, params)
    if params ~= nil or idleReplies[room] ~= self then return onUse(self, room, effect, card, params) end
    -- 引擎会在回包函数内部执行视为使用。只标记视为技交回的牌，
    -- 其支付代价或执行其他效果途中产生的用牌仍属于结算。
    idleReplies[room] = nil
    return markIdleUse(onUse(self, room, effect, card, params))
  end
end

local function viewAsForReply(data)
  local id = type(data.card) == "table" and data.card.skill or data.special_skill
  local skill = id and Fk.skills[id]
  if skill and skill:isInstanceOf(ViewAsSkill) then return skill end
end

function M.installServer(room)
  local useReply = room.handleUseCardReply
  function room:handleUseCardReply(player, data, params)
    if params ~= nil or type(data) ~= "table" then return useReply(self, player, data, params) end
    -- 锁定引擎的 PlayCard 是唯一不传询问参数的正常回包入口。
    local skill = viewAsForReply(data)
    if skill then wrapViewAs(skill) end
    local previous = idleReplies[self]
    idleReplies[self] = skill
    local ok, result = pcall(useReply, self, player, data, params)
    idleReplies[self] = previous
    if not ok then error(result, 0) end
    return markIdleUse(result)
  end

  -- 引擎的效果用牌请求已经在选择时放宽次数。把同一语义保存到返回的
  -- 实际用牌，供转化、服务端复核及最终计次使用。
  for _, method in ipairs({ "askToUseCard", "askToUseRealCard", "askToUseVirtualCard" }) do
    local ask = room[method]
    room[method] = function(self, player, params)
      local request = table.simpleClone(params)
      request.extra_data = table.simpleClone(params.extra_data or {})
      request.extra_data[EFFECT_REQUEST] = true
      return M.applyEffectUse(ask(self, player, request))
    end
  end

  local useCard = room.useCard
  function room:useCard(use)
    -- 只有普通回包直接产生的使用已登记。其余用牌默认属于效果结算，
    -- 即使在出牌阶段，或由普通回包选中的主动技间接产生。
    M.applyEffectUse(use)
    return useCard(self, use)
  end
end

return M
