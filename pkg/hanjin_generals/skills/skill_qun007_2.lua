-- QUN007 贾诩 · 乱武
--
-- 规则基线：rules/standard-generals.md 群区 QUN007、群包审阅
-- docs/development/implementation/generals/qun-standard.md、
-- rulebook/topics/legal-use-card.md。
-- 限定技，出牌阶段：从当前回合角色起按逆时针逐人处理所有其他角色。每人
-- 先按全体其他角色计算距离最小者，再检查能否合法使用【杀】且目标至少包含
-- 一名最近角色；不能则失去1点体力。不能改选较远但能杀的角色，也不把效果
-- 改成「视为使用」：必须真实使用一张【杀】。
--
-- 真实选人分两步，均复用公共 card_use_targets：
--   1. 用显式策略把可选目标限制为「距离最小且在使用者攻击范围内」，最多
--      一名，因此不选最近角色就无法确认；
--   2. 再用通常【杀】策略选择可附带的较远合法额外目标（受本次牌最大目标数
--      限制）。最终整次使用仍由 C.useCard 按通常【杀】规则复核并只使用一次。
-- 这样未扩公共接口，也没有另造代理技能。
local C = require "packages.hanjin.pkg.hanjin_mode.rules.card_use_targets"

local skill = fk.CreateSkill {
  name = "hanjin__skill_qun007_2",
  tags = { Skill.Limited },
}
skill.hanjinImplemented = true

local SLASH = "hanjin__slash"

local function slashPolicy()
  return C.default({ names = { SLASH } })
end

--- 距离最近的其他存活角色（可能有并列）及最小距离。
local function nearestTargets(player)
  local others = {}
  for _, p in ipairs(player.room.alive_players) do
    if p ~= player and not p:isRemoved() then table.insert(others, p) end
  end
  local min
  for _, p in ipairs(others) do
    local distance = player:distanceTo(p)
    if min == nil or distance < min then min = distance end
  end
  if min == nil then return {}, nil end
  return table.filter(others, function(p) return player:distanceTo(p) == min end), min
end

--- 只允许“最近且在使用者攻击范围内”的一名目标；用于真实选人第一步。
local function nearestPolicy(player, minDistance)
  return C.explicit({
    other_roles = true,
    max_distance = minDistance,
    in_attack_range_of = player.id,
  }, {
    names = { SLASH },
    min_targets = 1,
    max_targets = 1,
  })
end

local function candidates(player, policy)
  return C.candidates(player.room, player, Fk:cloneCard(SLASH), policy,
    { bypass_times = true })
end

local function loseHp(room, player)
  if player:isAlive() and not player:isRemoved() then
    room:loseHp(player, 1, skill.name)
  end
end

--- 处理一名角色的选项：真实使用一张包含最近目标的【杀】，否则失去1点体力。
local function resolveOne(room, to)
  if not to:isAlive() or to:isRemoved() then return end
  local nearest, minDistance = nearestTargets(to)
  if #nearest == 0 or minDistance == nil then
    loseHp(room, to)
    return
  end
  local firstPolicy = nearestPolicy(to, minDistance)
  local legalNearest = candidates(to, firstPolicy)
  if #legalNearest == 0 then
    loseHp(room, to)
    return
  end

  local use = C.askToUseCard(room, to, {
    names = { SLASH },
    pattern = "slash",
    policy = firstPolicy,
    skill_name = skill.name,
    prompt = "#hanjin__skill_qun007_2-use",
    cancelable = true,
    extra_data = { bypass_times = true },
  })
  if use == nil or use.card == nil or #use.tos ~= 1
    or not table.contains(legalNearest, use.tos[1]) then
    if use ~= nil then C.releaseToken(room, use) end
    loseHp(room, to)
    return
  end

  -- 第二步：多目标【杀】可附带其他通常合法目标（不能在第一步替代最近角色）。
  local normalPolicy = slashPolicy()
  local normal = candidates(to, normalPolicy)
  local extras = table.filter(normal, function(p) return not table.contains(use.tos, p) end)
  local maxNum = use.card.skill:getMaxTargetNum(to, use.card)
  local roomForMore = maxNum - #use.tos
  if roomForMore > 0 and #extras > 0 then
    local more = room:askToChoosePlayers(to, {
      min_num = 0,
      max_num = math.min(roomForMore, #extras),
      targets = extras,
      skill_name = skill.name,
      prompt = "#hanjin__skill_qun007_2-extra",
      cancelable = true,
    })
    for _, p in ipairs(more or {}) do
      if not table.contains(use.tos, p) then table.insert(use.tos, p) end
    end
  end

  use.extraUse = true
  use.extra_data = use.extra_data or {}
  use.extra_data.bypass_times = true
  use.extra_data.extraUse = true
  if C.useCard(room, to, use, normalPolicy) == nil then
    loseHp(room, to)
  end
end

skill:addEffect("active", {
  anim_type = "offensive",
  prompt = "#hanjin__skill_qun007_2",
  card_num = 0,
  target_num = 0,
  card_filter = Util.FalseFunc,
  target_filter = Util.FalseFunc,
  can_use = function(self, player)
    if player.phase ~= Player.Play then return false end
    if player:usedSkillTimes(skill.name, Player.HistoryGame) > 0 then return false end
    -- 客户端也会执行 can_use（ReqPlayCard.skillButtonValidity）：ClientPlayer
    -- 没有 room 字段，经公开的 Fk:currentRoom() 取与客户端同源的存活角色。
    local room = Fk:currentRoom()
    if room == nil or room.alive_players == nil then return false end
    for _, p in ipairs(room.alive_players) do
      if p ~= player and not p:isRemoved() then return true end
    end
    return false
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    if player == nil then return end
    -- 快照逆时针顺序；中途死亡者在轮到其时跳过，结算不因贾诩死亡而停止。
    local order = {}
    local p = player:getNextAlive()
    while p ~= player do
      if p:isAlive() and not p:isRemoved() then table.insert(order, p) end
      p = p:getNextAlive()
    end
    for _, to in ipairs(order) do
      resolveOne(room, to)
    end
  end,
})

Fk:loadTranslationTable {
  ["#hanjin__skill_qun007_2"] = "乱武：令所有其他角色各选择使用一张【杀】（须包含距离最近的角色）或失去1点体力",
  ["#hanjin__skill_qun007_2-use"] = "乱武：使用一张【杀】，目标须包含你距离最近且攻击范围内的角色",
  ["#hanjin__skill_qun007_2-extra"] = "乱武：可为此【杀】附带其他合法目标",
}

return skill
