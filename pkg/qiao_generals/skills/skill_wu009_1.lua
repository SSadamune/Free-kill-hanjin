-- WU009 孙坚 · 英魂
--
-- 规则基线：docs/rules/standard-generals.md 吴区 WU009。
-- 准备阶段：选择一名其他角色并选择一项：
-- 1. 令其摸 X 张牌，然后弃置一张牌；
-- 2. 令其摸一张牌，然后弃置 X 张牌（X 为孙坚已损失的体力值）。
local skill = fk.CreateSkill {
  name = "qiao__skill_wu009_1",
}
skill.qiaoImplemented = true

local DRAW = "#qiao__skill_wu009_1-draw"
local DISCARD = "#qiao__skill_wu009_1-discard"
local CHOOSE = "#qiao__skill_wu009_1_choose"

local function options(player)
  local count = ":::" .. player:getLostHp()
  return { DRAW .. count, DISCARD .. count }
end

local function canChoose(player, target)
  return target and target ~= player and target:isAlive() and not target:isRemoved()
end

skill:addAuxActiveSkill(CHOOSE, {
  card_num = 0,
  target_num = 1,
  target_filter = function(self, player, target, selected)
    return #selected == 0 and canChoose(player, target)
  end,
  interaction = function(self, player)
    return UI.OptionBox { options = options(player), direct_send = true }
  end,
})

skill:addEffect(fk.EventPhaseStart, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and player.phase == Player.Start
      and table.find(player.room:getPresentPlayers(), function(p) return canChoose(player, p) end) ~= nil
  end,
  on_cost = function(self, event, target, player, data)
    local ok, result = player.room:askToUseActiveSkill(player, {
      skill_name = CHOOSE,
      extra_data = { skillName = skill.name },
      prompt = "#qiao__skill_wu009_1-choose",
      cancelable = true,
      skip = true,
    })
    local choices = options(player)
    if not ok or #result.targets ~= 1 or not canChoose(player, result.targets[1])
      or #(result.cards or {}) > 0 or not table.contains(choices, result.interaction) then return false end
    event:setCostData(self, { tos = result.targets, n = player:getLostHp(), draw = result.interaction == choices[1] })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self)
    local to, n = cost.tos[1], cost.n
    if cost.draw then
      if to.dead then return end
      to:drawCards(n, skill.name)
      if to:isAlive() then
        room:askToDiscard(to, {
          min_num = 1,
          max_num = 1,
          include_equip = true,
          skill_name = skill.name,
          prompt = "#qiao__skill_wu009_1-throw:::1",
          cancelable = false,
        })
      end
    else
      if to.dead then return end
      to:drawCards(1, skill.name)
      if n > 0 and to:isAlive() then
        room:askToDiscard(to, {
          min_num = n,
          max_num = n,
          include_equip = true,
          skill_name = skill.name,
          prompt = "#qiao__skill_wu009_1-throw:::" .. n,
          cancelable = false,
        })
      end
    end
  end,
})

Fk:loadTranslationTable {
  [CHOOSE] = "英魂",
  ["#qiao__skill_wu009_1-choose"] = "英魂：选择一名其他角色，然后点击要执行的选项",
  ["#qiao__skill_wu009_1-throw"] = "英魂：弃置%arg张牌",
  [DRAW] = "令其摸%arg张牌，然后弃置一张牌",
  [DISCARD] = "令其摸一张牌，然后弃置%arg张牌",
}

return skill
