-- HAN014 朱儁 · 摧破
--
-- 锁定技：每回合使用第X张牌指定目标后（X为牌名字数），若自己也是此牌目标则
-- 摸1，否则本次牌对当前目标伤害+1。按整个回合真实用牌顺序计数；逐目标事件
-- 分别结算，不以 firstTarget 去重。
local Cuipo = require "packages.qiao.pkg.qiao_generals.util.cuipo"

local skill = fk.CreateSkill {
  name = "qiao__skill_han014_1",
  tags = { Skill.Compulsory },
}
skill.qiaoImplemented = true

local function currentUse(player)
  local current = player.room.logic:getCurrentEvent()
  return current and current:findParent(GameEvent.UseCard, true)
end

skill:addEffect(fk.TargetSpecified, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    if target ~= player or not player:hasSkill(skill.name) or data == nil
      or data.use == nil or data.card == nil then return false end
    local useEvent = currentUse(player)
    return useEvent ~= nil and Cuipo.useIndex(player, useEvent, true) == Cuipo.cardNameLength(data.card)
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    if data.use:hasTarget(player) then
      if not player.dead then player:drawCards(1, skill.name) end
    else
      data.additionalDamage = (data.additionalDamage or 0) + 1
    end
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_han014_1"] = "摧破",
  [":qiao__skill_han014_1"] = "锁定技，当你每回合使用第X张牌指定目标后（X为此牌的牌名字数），若你为此牌目标，则你摸一张牌，否则此牌伤害+1。",
}

return skill
