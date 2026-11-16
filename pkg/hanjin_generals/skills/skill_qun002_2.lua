-- QUN002 吕布 · 虓猛
--
-- 规则基线：rules/standard-generals.md 群区 QUN002、
-- rules/generals/qun002-lvbu.md、rules/extra-targets.md。
-- 每回合限一次：吕布使用【决斗】时，由当前回合角色（不一定是吕布）为该牌
-- 追加至多两个「与吕布势力不同」的目标。转化【决斗】同样适用；额外目标在
-- 目标声明后加入，不重新使用此牌。候选条件走公共 extra_targets 结构化入口。
local C = require "packages.hanjin.pkg.hanjin_mode.rules.card_use_targets"

local skill = fk.CreateSkill {
  name = "hanjin__skill_qun002_2",
}
skill.hanjinImplemented = true

local CONDITION = { different_kingdom = true, other_roles = true }

local function candidates(player, data)
  if data == nil or data.card == nil or data.card.trueName ~= "duel" then return {} end
  local ret = {}
  for _, p in ipairs(data:getExtraTargets()) do
    if p ~= player and p:isAlive() and not p:isRemoved()
      and C.matchesCondition(player.room, player, data.card, p, CONDITION) then
      table.insert(ret, p)
    end
  end
  return ret
end

skill:addEffect(fk.AfterCardTargetDeclared, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return data ~= nil and data.from == player and player:hasSkill(skill.name)
      and player:usedSkillTimes(skill.name, Player.HistoryTurn) == 0
      and #candidates(player, data) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local tos = candidates(player, data)
    if #tos == 0 then return false end
    -- 「当前回合角色可以」：选择权属于当前回合角色，不归吕布代选；
    -- 当前回合角色不存在时本次不发动，找不到合法选择者就不擅自转移。
    local chooser = room.current
    if chooser == nil or chooser.dead or chooser:isRemoved() then return false end
    local chosen = room:askToChoosePlayers(chooser, {
      min_num = 1,
      max_num = math.min(2, #tos),
      targets = tos,
      skill_name = skill.name,
      prompt = "#hanjin__skill_qun002_2-extra",
      cancelable = true,
    })
    if chosen == nil or #chosen == 0 then return false end
    event:setCostData(self, { tos = chosen })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local cost = event:getCostData(self) or {}
    local legal = candidates(player, data)
    for _, p in ipairs(cost.tos or {}) do
      -- 复核回复期间目标状态与候选条件，避免追加过时目标。
      if table.contains(legal, p) and not p.dead and not p:isRemoved() then
        data:addTarget(p)
      end
    end
  end,
})

Fk:loadTranslationTable {
  ["#hanjin__skill_qun002_2-extra"] = "虓猛：为此【决斗】额外指定至多两个与吕布势力不同的目标",
}

return skill
