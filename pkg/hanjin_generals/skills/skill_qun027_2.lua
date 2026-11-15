-- QUN027 韩遂 · 骁逆
--
-- 规则基线：rules/standard-generals.md 群区 QUN027、群包审阅
-- docs/development/implementation/generals/qun-standard.md。
-- 限定技，出牌阶段：视为对任意名其他势力角色使用一张【杀】。目标采用显式
-- 策略（不套通常攻击距离，数量由所选目标决定），并走公共 card_use_targets。
-- 本次视为【杀】结束后，由模式级 qun_cards_rule 按实际 damageDealt 选一名
-- 未因此受到伤害的原目标弃置其两张牌；不把“伤害总量为 0”当作唯一分支。
local C = require "packages.hanjin.pkg.hanjin_mode.rules.card_use_targets"

local skill = fk.CreateSkill {
  name = "hanjin__skill_qun027_2",
  tags = { Skill.Limited },
}
skill.hanjinImplemented = true

local SLASH = "hanjin__slash"
local MARK = "hanjin_qun027"
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

skill:addEffect("active", {
  anim_type = "offensive",
  prompt = "#hanjin__skill_qun027_2",
  card_num = 0,
  target_num = 0,
  card_filter = Util.FalseFunc,
  target_filter = Util.FalseFunc,
  can_use = function(self, player)
    return player.phase == Player.Play
      and player:usedSkillTimes(skill.name, Player.HistoryGame) == 0
      and #candidates(player.room, player) > 0
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
      prompt = "#hanjin__skill_qun027_2-target",
      cancelable = true,
    })
    if tos == nil or #tos == 0 then return end
    C.useVirtualCard(room, player, SLASH, nil, tos, skill.name, true,
      { bypass_times = true, [MARK] = { user = player.id } }, policy(#all))
  end,
})

Fk:loadTranslationTable {
  ["#hanjin__skill_qun027_2"] = "骁逆：视为对任意名其他势力角色使用一张【杀】",
  ["#hanjin__skill_qun027_2-target"] = "骁逆：选择任意名其他势力角色",
  ["#hanjin__skill_qun027_2-discard-target"] = "骁逆：选择一名未因此受到伤害的原目标",
  ["#hanjin__skill_qun027_2-discard"] = "骁逆：弃置其 %arg 张牌",
}

return skill
