-- WU010 孙策 · 鹰扬
--
-- 拼点牌亮出后、结果确定前，改动自己对应的拼点牌点数；只改本次拼点计算，
-- 不改实体牌的持久点数。发起者或参与者均可发动。
local Selection = require "packages.qiao.pkg.qiao_mode.rules.trigger_selection"
local skill = fk.CreateSkill {
  name = "qiao__skill_wu010_2",
}
skill.qiaoImplemented = true

local PLUS = "qiao__skill_wu010_2-plus3"
local MINUS = "qiao__skill_wu010_2-sub3"

skill:addEffect(fk.PindianCardsDisplayed, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(skill.name) and data ~= nil
      and (player == data.from or (data.results and data.results[player]))
  end,
  on_cost = function(self, event, target, player, data)
    local choice = Selection.askOption(player.room, player, {
      choices = { PLUS, MINUS },
      skill_name = skill.name,
      prompt = "#qiao__skill_wu010_2-choice",
    })
    if choice == PLUS or choice == MINUS then
      event:setCostData(self, { choice = choice })
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local choice = (event:getCostData(self) or {}).choice
    player.room:changePindianNumber(data, player, choice == PLUS and 3 or -3, skill.name)
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_wu010_2"] = "鹰扬",
  [":qiao__skill_wu010_2"] = "你的拼点牌亮出后，你可以令点数+3或-3。",
  ["#qiao__skill_wu010_2-choice"] = "鹰扬：选择令你的拼点牌点数+3或-3",
  [PLUS] = "令你的拼点牌点数+3",
  [MINUS] = "令你的拼点牌点数-3",
}

return skill
