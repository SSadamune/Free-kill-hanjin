-- WEI032 郭淮 · 屏御
-- 副将技：同势力其他角色需要使用【闪】时，可先请求郭淮；郭淮选择是否
-- 实际打出一张【闪】，该牌视为请求者使用。使用与打出的请求分别走
-- AskForCardUse / AskForCardResponse，不把郭淮变成原杀的直接目标。
local H = require "packages.hegemony.util"

local skill = fk.CreateSkill {
  name = "qiao__skill_wei032_3",
  tags = { Skill.DeputyPlace },
}
skill.qiaoImplemented = true

local function isJink(pattern)
  return pattern ~= nil and Exppattern:Parse(pattern):matchExp("jink|0|nosuit|none")
end

local function canOffer(target, player)
  return target ~= nil and player ~= nil and target ~= player
    and not target.dead and not player.dead
    and player:hasShownSkill(skill.name)
    and H.compareKingdomWith(target, player)
end

--- 郭淮先实际打出闪，再把处理区中的实体材料组成一张由请求者使用的闪。
--- 与虎驾同一材料生命周期：先 responseCard，再 clone + addSubcards(Processing)。
---@param room Room
---@param target ServerPlayer
---@param player ServerPlayer
---@param prompt string
---@param for_use boolean
---@return table?
local function playJinkFor(room, target, player, prompt, for_use)
  local response = room:askToResponse(player, {
    pattern = "jink",
    skill_name = skill.name,
    prompt = prompt,
    cancelable = true,
  })
  if response == nil or response.card == nil or #Card:getIdList(response.card) == 0 then
    return nil
  end
  -- 先由郭淮真实打出；原始材料不直接弃置，转为请求者的使用材料。
  response.skipDrop = true
  room:responseCard(response)
  local ids = room:getSubcardsByRule(response.card, { Card.Processing })
  if #ids == 0 then return nil end
  local card = Fk:cloneCard("jink")
  card.skillName = skill.name
  card:addSubcards(ids)
  local result = { from = target, card = card, extra_data = {} }
  result.extra_data.qiao_pingyu_user = target.id
  result.extra_data.qiao_pingyu_responder = player.id
  if for_use then result.tos = {} end
  return result
end

local function askRequest(target, player, prompt)
  local room = target.room
  local choice = room:askToChoice(target, {
    choices = { "request", "cancel" },
    skill_name = skill.name,
    prompt = prompt,
    cancelable = false,
  })
  if choice ~= "request" then return false end
  return room:askToSkillInvoke(player, {
    skill_name = skill.name,
    prompt = "#qiao__skill_wei032_3-invoke",
  })
end

skill:addEffect(fk.AskForCardUse, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return canOffer(target, player) and isJink(data.pattern)
  end,
  on_cost = function(self, event, target, player, data)
    return askRequest(target, player, "#qiao__skill_wei032_3-request_use")
  end,
  on_use = function(self, event, target, player, data)
    data.result = playJinkFor(player.room, target, player,
      "#qiao__skill_wei032_3-play", true)
  end,
})

skill:addEffect(fk.AskForCardResponse, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return canOffer(target, player) and isJink(data.pattern)
  end,
  on_cost = function(self, event, target, player, data)
    return askRequest(target, player, "#qiao__skill_wei032_3-request_response")
  end,
  on_use = function(self, event, target, player, data)
    data.result = playJinkFor(player.room, target, player,
      "#qiao__skill_wei032_3-play", false)
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_wei032_3"] = "屏御",
  ["#qiao__skill_wei032_3-request_use"] = "屏御：是否请求郭淮替你使用【闪】",
  ["#qiao__skill_wei032_3-request_response"] = "屏御：是否请求郭淮替你打出【闪】",
  ["#qiao__skill_wei032_3-invoke"] = "屏御：是否替其打出【闪】",
  ["#qiao__skill_wei032_3-play"] = "屏御：选择一张【闪】",
  ["request"] = "请求",
  ["cancel"] = "取消",
}

return skill
