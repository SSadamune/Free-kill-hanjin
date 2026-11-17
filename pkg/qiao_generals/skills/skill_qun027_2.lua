-- QUN027 韩遂 · 骁逆
--
-- 规则基线：docs/rules/standard-generals.md 群区 QUN027、群包审阅
-- docs/development/implementation/generals/qun-standard.md。
-- 限定技，出牌阶段：视为对任意名其他势力角色使用一张【杀】。目标采用显式
-- 策略（不套通常攻击距离，数量由所选目标决定），并走公共 card_use_targets。
-- 本次视为【杀】结束后，由模式级 qun_cards_rule 按实际 damageDealt 选一名
-- 未因此受到伤害的原目标弃置其两张牌；不把“伤害总量为 0”当作唯一分支。
local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"

local skill = fk.CreateSkill {
  name = "qiao__skill_qun027_2",
  tags = { Skill.Limited },
}
skill.qiaoImplemented = true

local SLASH = "qiao__slash"
local MARK = "qiao_qun027"
local CONDITION = { different_kingdom = true, other_roles = true }

local function policy(maxTargets)
  return C.explicit(CONDITION, {
    names = { SLASH },
    min_targets = 1,
    max_targets = maxTargets,
  })
end

local function candidates(room, player)
  -- 先用可容纳全场的上限查询候选；explicit 条件会替换【杀】的通常距离条件。
  return C.candidates(room, player, Fk:cloneCard(SLASH), policy(#room.alive_players),
    { bypass_times = true })
end

--- 客户端与服务端共用「存在合法目标」判断。card_use_targets 的策略栈只在服务端
--- 可用（该模块的 isServer 断言），客户端复用 public 的条件判断与 canUseTo：
---   * C.matchesCondition(room, player, slash, target, CONDITION) 只委托
---     extra_targets.lua 的条件匹配（其他角色 + 不同势力，经 hegemony 公共判断，
---     野心家按 role 计算），不需要服务端策略栈；
---   * player:canUseTo(slash, target, {bypass_times, bypass_distances})
---     （锁定 ltk/core/player.lua:1219）含禁止使用/禁止指定目标与杀的目标条件，
---     与服务端显式策略的禁止语义一致。不再直接比较 kingdom 字符串。
local function hasCandidate(room, player)
  if room == nil then return false end
  if player.class ~= nil and player.class.name == "ServerPlayer" then
    return #candidates(room, player) > 0
  end
  local slash = Fk:cloneCard(SLASH)
  slash.skillName = skill.name
  return table.find(room.alive_players or {}, function(p)
    return p ~= player and not p.dead and not p:isRemoved()
      and C.matchesCondition(room, player, slash, p, CONDITION)
      and player:canUseTo(slash, p, { bypass_times = true, bypass_distances = true })
  end) ~= nil
end

skill:addEffect("active", {
  anim_type = "offensive",
  prompt = "#qiao__skill_qun027_2",
  card_num = 0,
  target_num = 0,
  card_filter = Util.FalseFunc,
  target_filter = Util.FalseFunc,
  can_use = function(self, player)
    return player.phase == Player.Play
      and player:usedSkillTimes(skill.name, Player.HistoryGame) == 0
      and hasCandidate(Fk:currentRoom(), player)
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    if player == nil or player.dead then return end
    local all = candidates(room, player)
    if #all == 0 then return end
    local tos = room:askToChoosePlayers(player, {
      min_num = 1,
      max_num = #all,
      targets = all,
      skill_name = skill.name,
      prompt = "#qiao__skill_qun027_2-target",
      cancelable = true,
    })
    if tos == nil or #tos == 0 then return end
    C.useVirtualCard(room, player, SLASH, nil, tos, skill.name, true,
      { bypass_times = true, [MARK] = { user = player.id } }, policy(#all))
  end,
})

Fk:loadTranslationTable {
  ["#qiao__skill_qun027_2"] = "骁逆：视为对任意名其他势力角色使用一张【杀】",
  ["#qiao__skill_qun027_2-target"] = "骁逆：选择任意名其他势力角色",
  ["#qiao__skill_qun027_2-discard-target"] = "骁逆：选择一名未因此受到伤害的原目标",
  ["#qiao__skill_qun027_2-discard"] = "骁逆：弃置其 %arg 张牌",
}

return skill
