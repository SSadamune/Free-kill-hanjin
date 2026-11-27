-- QUN022A 李傕关联翼从「飞熊军」
-- 限定技，出牌阶段，你可以选择一名体力值与你相同的其他角色，依次视为对其使用一张【顺手牵羊】和一张【杀】。
-- 依定稿规则：同名多份实例各限一次；视为使用的【顺手牵羊】和【杀】均无视距离限制（【杀】亦无视次数）。
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"
local Bian = require "packages.qiao.pkg.qiao_generals.util.bian_common"

local skill = fk.CreateSkill {
  name = Bian.FEIXIONG_SKILL,
  tags = { Skill.Limited },
}
skill.qiaoImplemented = true

skill:addEffect("active", {
  anim_type = "offensive",
  prompt = "#qiao__retinue_skill_feixiongjun-prompt",
  card_num = 0,
  target_num = 1,
  card_filter = Util.FalseFunc,
  can_use = function(self, player)
    if player == nil or player.dead or player.phase ~= Player.Play then return false end
    if not player:hasSkill(skill.name) then return false end
    return Bian.canUseLimitedRetinue(player, skill.name)
  end,
  target_filter = function(self, player, to_select, selected)
    return #selected == 0 and to_select ~= nil and to_select ~= player
      and not to_select.dead and not to_select:isRemoved()
      and to_select.hp == player.hp
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos and effect.tos[1]
    if player == nil or player.dead or target == nil or target == player
      or not RemovedTargets.isPresent(target) or target.hp ~= player.hp then
      return
    end
    local instance = Bian.availableLimitedRetinues(player, skill.name)[1]
    if instance == nil then return end
    Bian.spendLimitedRetinue(player, instance, skill.name)

    -- 1. 视为对其使用【顺手牵羊】（无视距离；区域无牌时跳过）。
    if RemovedTargets.isPresent(player) and RemovedTargets.isPresent(target)
      and #target:getCardIds("hej") > 0 then
      local snatch = Fk:cloneCard("qiao__snatch")
      snatch.skillName = skill.name
      if not player:prohibitUse(snatch) and not player:isProhibited(target, snatch) then
        room:useCard {
          from = player,
          tos = { target },
          card = snatch,
          extra_data = { bypass_distances = true },
        }
      end
    end

    -- 2. 视为对其使用普通【杀】（无视距离与次数）。
    if RemovedTargets.isPresent(player) and RemovedTargets.isPresent(target) then
      local slash = Fk:cloneCard("qiao__slash")
      slash.skillName = skill.name
      if not player:prohibitUse(slash) and not player:isProhibited(target, slash) then
        room:useCard {
          from = player,
          tos = { target },
          card = slash,
          extraUse = true,
          extra_data = { bypass_distances = true, bypass_times = true },
        }
      end
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "飞熊军",
  [":" .. skill.name] = "限定技，出牌阶段，你可以选择一名体力值与你相同的其他角色，依次视为对其使用一张【顺手牵羊】和一张【杀】。",
  ["#qiao__retinue_skill_feixiongjun-prompt"] = "飞熊军：选择一名体力值与你相同的其他角色",
}

return skill
