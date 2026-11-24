-- QUN016 田丰 · 随势
--
-- 规则基线：docs/rules/standard-generals.md 群区 QUN016、docs/rules/generals/qun016-tianfeng.md。
-- 锁定技，两个分支：
--   1. 其他角色进入濒死时，若造成此次濒死的来源与自己势力相同，自己摸一张牌；
--      未造成伤害的体力流失（来源为 nil）不摸牌。来源与濒死角色是两个不同的
--      角色，不能把「与自己同势力的濒死角色」当成来源条件。
--   2. 与自己势力相同的其他角色死亡时，自己选择：失去 1 点体力，或弃置所有
--      手牌。不是强制失去体力；两个选项都必须提供，即使当前没有手牌。
local Selection = require "packages.qiao.pkg.qiao_mode.rules.trigger_selection"
local H = require "packages.hegemony.util"

local skill = fk.CreateSkill {
  name = "qiao__skill_qun016_2",
  tags = { Skill.Compulsory },
}
skill.qiaoImplemented = true

local OPT_LOSE_HP = "#qiao__skill_qun016_2-losehp"
local OPT_DISCARD = "#qiao__skill_qun016_2-discard"

skill:addEffect(fk.EnterDying, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(skill.name) or player.dead then return false end
    if target == player then return false end
    local killer = data and data.killer
    return killer ~= nil and not killer.dead and H.compareKingdomWith(killer, player)
  end,
  -- 锁定技：没有可选消耗，直接结算。
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    if player.dead then return end
    player:drawCards(1, skill.name)
  end,
})

skill:addEffect(fk.Death, {
  anim_type = "negative",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(skill.name) or player.dead then return false end
    if target == player then return false end
    return H.compareKingdomWith(target, player)
  end,
  on_cost = function(self, event, target, player, data)
    local choice = Selection.askOption(player.room, player, {
      choices = { OPT_LOSE_HP, OPT_DISCARD },
      skill_name = skill.name,
      prompt = "#qiao__skill_qun016_2-choice",
      cancelable = false,
    })
    event:setCostData(self, { choice = choice })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local choice = (event:getCostData(self) or {}).choice
    if choice == OPT_LOSE_HP then
      if not player.dead then
        room:loseHp(player, 1, skill.name)
      end
    else
      local ids = player:getCardIds("h")
      if #ids > 0 then
        room:throwCard(ids, skill.name, player, player)
      end
    end
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_qun016_2"] = "随势",
  [":qiao__skill_qun016_2"] = "锁定技，其他角色进入濒死时，若来源与你势力相同，你摸一张牌；与你势力相同的其他角色死亡时，你失去1点体力或弃置所有手牌。",
  ["#qiao__skill_qun016_2-choice"] = "随势：选择失去1点体力，或弃置所有手牌",
  [OPT_LOSE_HP] = "失去1点体力",
  [OPT_DISCARD] = "弃置所有手牌",
}

return skill
