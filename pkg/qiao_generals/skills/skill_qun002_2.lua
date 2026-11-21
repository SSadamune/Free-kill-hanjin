-- QUN002 吕布 · 虓猛
--
-- 规则基线：docs/rules/standard-generals.md 群区 QUN002、
-- docs/rules/generals/qun002-lvbu.md、docs/rules/extra-targets.md。
-- 每回合限一次：吕布使用【决斗】时，由当前回合角色（不一定是吕布）为该牌
-- 追加至多两个「与吕布势力不同」的目标。转化【决斗】同样适用；额外目标在
-- 目标声明后加入，不重新使用此牌。候选条件走公共 extra_targets 结构化入口。
local ExtraTargets = require "packages.qiao.pkg.qiao_mode.rules.extra_targets"

local skill = fk.CreateSkill {
  name = "qiao__skill_qun002_2",
}
skill.qiaoImplemented = true

local TARGETS = { target_condition = { different_kingdom = true, other_roles = true } }

local function canChoose(player)
  return player ~= nil and player:isAlive() and not player:isRemoved()
end

skill:addEffect(fk.AfterCardTargetDeclared, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return data.from == player and data.card.trueName == "duel" and player:hasSkill(skill.name)
      and player:usedSkillTimes(skill.name, Player.HistoryTurn) == 0
      and canChoose(player.room.current)
      and #ExtraTargets.candidates(player.room, data, TARGETS) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    -- 「当前回合角色可以」：选择权属于当前回合角色，不归吕布代选；
    -- 当前回合角色不存在时本次不发动，找不到合法选择者就不擅自转移。
    local chooser = room.current
    if not canChoose(chooser) then return false end
    local tos = ExtraTargets.candidates(room, data, TARGETS)
    if #tos == 0 then return false end
    local chosen = room:askToChoosePlayers(chooser, {
      min_num = 1,
      max_num = math.min(2, #tos),
      targets = tos,
      skill_name = skill.name,
      prompt = "#qiao__skill_qun002_2-extra",
      cancelable = true,
    })
    if chosen == nil or #chosen == 0 then return false end
    event:setCostData(self, { tos = chosen })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local cost = event:getCostData(self) or {}
    local legal = ExtraTargets.candidates(player.room, data, TARGETS)
    for _, p in ipairs(cost.tos or {}) do
      -- 复核回复期间目标状态与候选条件，避免追加过时目标。
      if table.removeOne(legal, p) then
        data:addTarget(p)
      end
    end
  end,
})

Fk:loadTranslationTable {
  ["#qiao__skill_qun002_2-extra"] = "虓猛：为此【决斗】额外指定至多两个与吕布势力不同的目标",
}

return skill
