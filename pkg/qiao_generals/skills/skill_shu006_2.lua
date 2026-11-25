local Selection = require "packages.qiao.pkg.qiao_mode.rules.trigger_selection"
local Tieqi = require "packages.qiao.pkg.qiao_mode.rules.tieqi"

local skill = fk.CreateSkill {
  name = "qiao__skill_shu006_2",
}
skill.qiaoImplemented = true

local MAIN = "#qiao__skill_shu006_2-main"
local DEPUTY = "#qiao__skill_shu006_2-deputy"

Fk:loadTranslationTable {
  ["qiao__skill_shu006_2"] = "铁骑",
  [":qiao__skill_shu006_2"] = "当你使用【杀】指定一个目标后，你可以令其一张武将牌本回合非锁定技失效，然后你判定，除非其展示手牌并弃置结果花色的所有牌，否则其不能响应此【杀】。",
  ["#qiao__skill_shu006_2-ask"] = "铁骑：选择 %dest 的一张武将牌，令其非锁定技失效并判定",
  [MAIN] = "主将",
  [DEPUTY] = "副将",
  ["#qiao__skill_shu006_2-discard"] = "铁骑：展示并弃置判定花色的所有手牌，否则不能响应此【杀】",
}

skill:addEffect(fk.TargetSpecified, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and data.card ~= nil
      and data.card.trueName == "slash" and data.to ~= nil and data.to ~= player
  end,
  on_cost = function(self, event, target, player, data)
    local to = data.to
    local choices = {}
    if Tieqi.hasGeneral(to, false) then table.insert(choices, MAIN) end
    if Tieqi.hasGeneral(to, true) then table.insert(choices, DEPUTY) end
    if #choices == 0 then return false end
    local choice = Selection.askOption(player.room, player, {
      choices = choices,
      all_choices = { MAIN, DEPUTY },
      buttons = true,
      skill_name = skill.name,
      prompt = "#qiao__skill_shu006_2-ask::" .. to.id,
    })
    if choice == nil then return false end
    event:setCostData(self, choice)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local to = data.to
    local deputy = event:getCostData(self) == DEPUTY
    if Tieqi.hasGeneral(to, deputy) then Tieqi.mark(room, to, deputy) end

    local judge = { who = player, reason = skill.name }
    room:judge(judge)
    if judge.card == nil or judge.card.suit == Card.NoSuit then
      data:setDisresponsive(to)
      return
    end
    local suit = judge.card:getSuitString()
    local matches = {}
    for _, id in ipairs(to:getCardIds("h")) do
      if Fk:getCardById(id).suit == judge.card.suit then table.insert(matches, id) end
    end
    if #matches == 0 then
      data:setDisresponsive(to)
      return
    end
    local cards = room:askToDiscard(to, {
      min_num = #matches,
      max_num = #matches,
      include_equip = false,
      skill_name = skill.name,
      pattern = ".|.|" .. suit,
      prompt = "#qiao__skill_shu006_2-discard:::" .. suit,
      cancelable = true,
      skip = true,
    })
    if not cards or #cards ~= #matches or not table.every(matches, function(id)
      return table.contains(cards, id) and table.contains(to:getCardIds("h"), id)
        and not to:prohibitDiscard(id)
    end) then
      data:setDisresponsive(to)
      return
    end
    to:showCards(to:getCardIds("h"), player)
    room:throwCard(cards, skill.name, to, to)
  end,
})

return skill
