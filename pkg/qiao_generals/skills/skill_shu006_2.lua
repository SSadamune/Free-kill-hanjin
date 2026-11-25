local Selection = require "packages.qiao.pkg.qiao_mode.rules.trigger_selection"
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"

local skill = fk.CreateSkill {
  name = "qiao__skill_shu006_2",
}
skill.qiaoImplemented = true

local POS = "qiao__skill_shu006_2_positions-turn"
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

local function hasGeneralCard(to, pos)
  local name = Exchange.actualGeneral(to, pos == "deputy")
  return name ~= "" and name ~= "anjiang" and Fk.generals[name] ~= nil and not Exchange.isSoldier(name)
end

skill:addEffect(fk.TargetSpecified, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and data.card ~= nil
      and data.card.trueName == "slash" and data.to ~= nil and data.to ~= player
  end,
  on_cost = function(self, event, target, player, data)
    local to = data.to
    local choices = {}
    if hasGeneralCard(to, "main") then table.insert(choices, MAIN) end
    if hasGeneralCard(to, "deputy") then table.insert(choices, DEPUTY) end
    if #choices == 0 then return false end
    local choice = Selection.askOption(player.room, player, {
      choices = choices,
      all_choices = { MAIN, DEPUTY },
      buttons = true,
      skill_name = skill.name,
      prompt = "#qiao__skill_shu006_2-ask::" .. to.id,
    })
    if choice == nil then return false end
    event:setCostData(self, choice == MAIN and "main" or "deputy")
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local to = data.to
    local selected = event:getCostData(self)
    if hasGeneralCard(to, selected) then
      local old = to:getTableMark(POS)
      if type(old) ~= "table" then old = {} end
      if not table.contains(old, selected) then table.insert(old, selected) end
      room:setPlayerMark(to, POS, old)
    end

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
