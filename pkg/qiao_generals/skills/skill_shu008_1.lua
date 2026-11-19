-- SHU008 黄忠 · 烈勇
--
-- 规则基线：docs/rules/standard-generals.md 蜀区 SHU008。
-- 锁定技：攻击范围+X（X为已损失体力值，至少为1）；
-- 当使用【杀】指定手牌数不大于你、或体力值不小于你的目标后，你令此【杀】
-- 不能被其响应，或对其伤害+1（由你任选一项，不绑定满足的条件）。
-- 多目标【杀】逐目标分别选择；伤害加成只作用于该目标本次【杀】的伤害。
local skill = fk.CreateSkill {
  name = "qiao__skill_shu008_1",
  tags = { Skill.Compulsory },
}
skill.qiaoImplemented = true

local DMG = "qiao__skill_shu008_1_damage"
local OPT_DISRESPONSIVE = "#qiao__skill_shu008_1-disresponsive"
local OPT_DAMAGE = "#qiao__skill_shu008_1-damage"

skill:addEffect("atkrange", {
  correct_func = function(self, from, to)
    if from ~= nil and from:hasSkill(skill.name) then
      return math.max(from:getLostHp(), 1)
    end
    return 0
  end,
})

skill:addEffect(fk.TargetSpecified, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    if target ~= player or not player:hasSkill(skill.name) then return false end
    if data.card == nil or data.card.trueName ~= "slash" then return false end
    local to = data.to
    if to == nil or to == player or to.dead then return false end
    return to:getHandcardNum() <= player:getHandcardNum() or to.hp >= player.hp
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local to = data.to
    local choice = room:askToChoice(player, {
      choices = { OPT_DISRESPONSIVE, OPT_DAMAGE },
      skill_name = skill.name,
      prompt = "#qiao__skill_shu008_1-choice:" .. to.id,
      cancelable = false,
    })
    event:setCostData(self, { to = to, choice = choice })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local cost = event:getCostData(self) or {}
    local to = cost.to
    if to == nil or to.dead or to:isRemoved() then return end
    if cost.choice == OPT_DISRESPONSIVE then
      data:setDisresponsive(to)
    else
      local use = data.use
      if use ~= nil then
        use[DMG] = use[DMG] or {}
        use[DMG][to.id] = true
      end
    end
  end,
})

-- 普通目标不会继承 AimData.additionalDamage，按本次使用记录的目标结算伤害+1。
-- 具体 +1 由模式级持续技能读取本次使用的目标标记完成，避免失去烈勇后本次
-- 【杀】已建立的加伤消失，也不消费一次性标记。

Fk:loadTranslationTable {
  ["qiao__skill_shu008_1"] = "烈勇",
  [":qiao__skill_shu008_1"] = "锁定技，你的攻击范围+X（X为你已损失体力值，至少为1）；当你使用【杀】指定手牌数小于等于你或体力值大于等于你的目标后，你令此【杀】不能被其响应或对其伤害+1。",
  ["#qiao__skill_shu008_1-choice"] = "烈勇：选择令此【杀】不能被其响应，或对其伤害+1",
  [OPT_DISRESPONSIVE] = "此【杀】不能被其响应",
  [OPT_DAMAGE] = "对其伤害+1",
}

return skill
