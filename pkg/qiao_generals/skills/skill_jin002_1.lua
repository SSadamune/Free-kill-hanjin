-- JIN002 司马师 · 泰然
--
-- 规则基线：docs/rules/generals/jin002-simashi.md。
-- 出牌阶段开始时，可以失去任意点体力，并可以弃置至多当前已损失体力值的牌；
-- 两项都可放弃。实际失去体力数与实际弃牌数分别记录，回合结束时逐条结算：
-- 先回复该次失去的体力，再摸该次弃牌数的牌。
--
-- 后续时机尚未定案，暂按“回合结束时”（fk.TurnEnd）。记录由模式级
-- jin_resources_rule 结算，因此泰然之后失去也不影响已建立的后续效果。
local R = require "packages.qiao.pkg.qiao_generals.util.jin_resources"

local skill = fk.CreateSkill {
  name = "qiao__skill_jin002_1",
}

skill:addEffect(fk.EventPhaseStart, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and player:hasSkill(skill.name)
      and data.phase == Player.Play and player.hp > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_jin002_1-invoke",
    }) then
      return false
    end
    local loss = room:askToNumber(player, {
      min = 0,
      max = player.hp,
      skill_name = skill.name,
      prompt = "#qiao__skill_jin002_1-loss",
    })
    if loss == nil then return false end
    event:setCostData(self, { loss = loss })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local loss = (event:getCostData(self) or {}).loss or 0

    -- 实际失去量由房间规则在 HpChanged 的负 num 记录；插入的濒死救回
    -- 或另一次回复不会改变本次失去值。
    local actualLoss = 0
    if loss > 0 then
      room:loseHp(player, loss, skill.name)
      actualLoss = R.takeTairanLoss(player)
      if player.dead then return end
    end

    -- 弃牌上限读取执行时已损失体力值，包含此前已损失部分和本次失去。
    local maxDiscard = math.max(0, player.maxHp - player.hp)
    local discarded = {}
    if maxDiscard > 0 then
      discarded = room:askToDiscard(player, {
        min_num = 0,
        max_num = maxDiscard,
        include_equip = true,
        skill_name = skill.name,
        prompt = "#qiao__skill_jin002_1-discard:::" .. maxDiscard,
        cancelable = true,
      }) or {}
    end

    local count = #discarded
    if actualLoss > 0 or count > 0 then
      R.addTairanRecord(room, player, { hp = actualLoss, cards = count })
    end
  end,
})

skill.qiaoImplemented = true

Fk:loadTranslationTable {
  ["#qiao__skill_jin002_1-invoke"] = "泰然：你可以失去体力并弃置至多已损失体力值的牌",
  ["#qiao__skill_jin002_1-loss"] = "泰然：选择失去多少点体力",
  ["#qiao__skill_jin002_1-discard"] = "泰然：弃置至多 %arg 张牌",
}

return skill
