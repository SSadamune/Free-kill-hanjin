local skill = fk.CreateSkill {
  name = "qiao__retinue_skill_zhoucang",
}
skill.qiaoImplemented = true

local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"
local R = require "packages.qiao.pkg.qiao_generals.util.retinue_instances"

local function triggerEach(self, event, target, player, data)
  if #R.instancesForSkill(player, skill.name) == 0 then
    return self:doCost(event, target, player, data)
  end
  return R.triggerEach(self, event, target, player, data)
end

Fk:loadTranslationTable {
  ["qiao__retinue_skill_zhoucang"] = "周仓",
  [":qiao__retinue_skill_zhoucang"] = "当你使用【杀】后，你可以将此【杀】或目标角色使用的【闪】交给另一名其他角色，若其以此法获得红色牌，其可以对你攻击范围内的一名角色使用一张【杀】。",
  ["#qiao__retinue_skill_zhoucang-give"] = "周仓：选择本次的【杀】或【闪】及收牌角色",
  ["#qiao__retinue_skill_zhoucang-use"] = "周仓：是否对你攻击范围内的一名角色使用【杀】？",
}

local function availableId(room, id)
  if id == nil then return false end
  local area = room:getCardArea(id)
  return area == Card.DiscardPile or area == Card.Processing
end

skill:addEffect(fk.CardUseFinished, {
  anim_type = "support",
  on_trigger = triggerEach,
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and data.card ~= nil and data.card.trueName == "slash"
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local ids, groups = {}, {}
    local function addCard(card)
      local components = Card:getIdList(card)
      if #components == 0 then return end
      if not table.every(components, function(id) return availableId(room, id) end) then return end
      for _, id in ipairs(components) do
        if groups[id] == nil then
          table.insert(ids, id)
          groups[id] = components
        end
      end
    end
    addCard(data.card)
    for _, card in ipairs(data.cardsResponded or {}) do
      if card.trueName == "jink" then addCard(card) end
    end
    if #ids == 0 then return false end
    local targets = {}
    for _, p in ipairs(room:getPresentPlayers()) do
      if p ~= player and not table.contains(data.tos, p) and not p:isRemoved() then
        table.insert(targets, p)
      end
    end
    if #targets == 0 then return false end
    local tos, cards = room:askToChooseCardsAndPlayers(player, {
      min_num = 1,
      max_num = 1,
      min_card_num = 1,
      max_card_num = 1,
      targets = targets,
      expand_pile = ids,
      pattern = tostring(Exppattern { id = ids }),
      skill_name = skill.name,
      prompt = "#qiao__retinue_skill_zhoucang-give",
      cancelable = true,
    })
    if #tos ~= 1 or #cards ~= 1 or not table.contains(targets, tos[1]) or groups[cards[1]] == nil then
      return false
    end
    event:setCostData(self, { cards = groups[cards[1]], to = tos[1] })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self)
    local to = cost.to
    local cards = cost.cards or {}
    if to == nil or to.dead or #cards == 0 then return end
    if not table.every(cards, function(id) return availableId(room, id) end) then return end
    local red = table.find(cards, function(id) return Fk:getCardById(id).color == Card.Red end)
    room:obtainCard(to, cards, true, fk.ReasonGive, player)
    if red == nil or to.dead then return end
    local policy = C.explicit({ other_roles = true, in_attack_range_of = player.id },
      { names = { "qiao__slash", "qiao__fire__slash", "qiao__thunder__slash", "qiao__ice__slash" }, min_targets = 1, max_targets = 1 })
    local use = C.askToUseCard(room, to, {
      names = { "qiao__slash", "qiao__fire__slash", "qiao__thunder__slash", "qiao__ice__slash" },
      pattern = "slash",
      skill_name = skill.name,
      prompt = "#qiao__retinue_skill_zhoucang-use",
      cancelable = true,
      policy = policy,
      extra_data = { qiao_trigger_use = true },
    })
    if use == nil or use.card == nil then return end
    C.useCard(room, to, use, policy)
  end,
})

return skill
