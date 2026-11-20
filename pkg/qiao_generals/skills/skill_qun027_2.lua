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
local CONDITION = { same_kingdom = false, other_roles = true }

local function policy(maxTargets)
  return C.explicit(CONDITION, {
    names = { SLASH },
    min_targets = 1,
    max_targets = maxTargets,
  })
end

local function canTarget(room, player, target)
  local slash = Fk:cloneCard(SLASH)
  slash.skillName = skill.name
  return not target.dead and not target:isRemoved()
    and C.matchesCondition(room, player, slash, target, CONDITION)
    and player:canUseTo(slash, target, { bypass_times = true, bypass_distances = true })
end

skill:addEffect("active", {
  anim_type = "offensive",
  prompt = "#qiao__skill_qun027_2",
  card_num = 0,
  min_target_num = 1,
  max_target_num = function() return #Fk:currentRoom():getPresentPlayers() - 1 end,
  card_filter = Util.FalseFunc,
  target_filter = function(self, player, target, selected)
    return not table.contains(selected, target) and canTarget(Fk:currentRoom(), player, target)
  end,
  can_use = function(self, player)
    local room = Fk:currentRoom()
    return player.phase == Player.Play
      and player:usedSkillTimes(self.name, Player.HistoryGame) == 0
      and table.find(room:getPresentPlayers(), function(target) return canTarget(room, player, target) end) ~= nil
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    if player == nil or player.dead then return end
    local tos = effect.tos or {}
    if #tos == 0 or not table.every(tos, function(target) return canTarget(room, player, target) end) then return end
    C.useVirtualCard(room, player, SLASH, nil, tos, skill.name, true,
      { bypass_times = true, [MARK] = { user = player.id } }, policy(#tos))
  end,
})

Fk:loadTranslationTable {
  ["#qiao__skill_qun027_2"] = "骁逆：视为对任意名其他势力角色使用一张【杀】",
  ["#qiao__skill_qun027_2-discard-target"] = "骁逆：选择一名未因此受到伤害的原目标",
  ["#qiao__skill_qun027_2-discard"] = "骁逆：弃置其 %arg 张牌",
}

return skill
