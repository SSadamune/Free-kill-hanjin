local R = require "packages.qiao.pkg.qiao_generals.util.retinue_instances"

local skill = fk.CreateSkill {
  name = "qiao__retinue_skill_baima_yicong",
}
skill.qiaoImplemented = true

local function triggerEach(self, event, target, player, data)
  if #R.instancesForSkill(player, skill.name) == 0 then
    -- 非翼从来源直接授予技能时，保留“本身一份”语义；真实多实例应同时持有实例。
    return self:doCost(event, target, player, data)
  end
  return R.triggerEach(self, event, target, player, data)
end

Fk:loadTranslationTable {
  ["qiao__retinue_skill_baima_yicong"] = "白马义从",
  [":qiao__retinue_skill_baima_yicong"] = "当你使用或打出【闪】时，你可以获得对方的一张牌。",
  ["#qiao__retinue_skill_baima_yicong-invoke"] = "白马义从：是否获得%src的一张牌？",
  ["#qiao__retinue_skill_baima_yicong-card"] = "白马义从：选择获得%src的一张牌",
}

local takeCard = {
  anim_type = "support",
  on_trigger = triggerEach,
  can_trigger = function(self, event, target, player, data)
    if target ~= player or not player:hasSkill(skill.name) then return false end
    if data.card == nil or data.card.trueName ~= "jink" then return false end
    local from = data.responseToEvent and data.responseToEvent.from
    return from ~= nil and from ~= player and from:isAlive()
  end,
  on_cost = function(self, event, target, player, data)
    local from = data.responseToEvent and data.responseToEvent.from
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__retinue_skill_baima_yicong-invoke:" .. from.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local from = data.responseToEvent and data.responseToEvent.from
    if from == nil or from.dead or #from:getCardIds("he") == 0 then return end
    local chosen = room:askToChooseCards(player, {
      target = from,
      flag = "he",
      min = 1,
      max = 1,
      skill_name = skill.name,
      prompt = "#qiao__retinue_skill_baima_yicong-card:" .. from.id,
      cancelable = false,
    })
    local id = chosen and chosen[1]
    if id ~= nil then
      room:obtainCard(player, id, false, fk.ReasonPrey, player, skill.name)
    end
  end,
}

skill:addEffect(fk.CardUsing, takeCard)
skill:addEffect(fk.CardResponding, takeCard)

return skill
