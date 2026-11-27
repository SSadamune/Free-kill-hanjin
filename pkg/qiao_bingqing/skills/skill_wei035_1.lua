local S = require "packages.qiao.pkg.qiao_bingqing.shi"
local skill = fk.CreateSkill { name = "qiao__skill_wei035_1" }
local types, targets = "qiao_pindi_types-turn", "qiao_pindi_targets-turn"
local function cardOK(p, id)
  return table.contains(p:getCardIds("he"), id) and not p:prohibitDiscard(id)
    and not table.contains(p:getTableMark(types), Fk:getCardById(id).type)
end
local function targetOK(p, to)
  return S.present(to) and p ~= to and not table.contains(p:getTableMark(targets), to.id)
end
local function resolve(room, p, id, to)
  if not cardOK(p, id) or not targetOK(p, to) then return end
  room:addTableMarkIfNeed(p, types, Fk:getCardById(id).type)
  room:addTableMarkIfNeed(p, targets, to.id)
  local count = #p:getTableMark(types)
  room:throwCard(id, skill.name, p, p)
  if not S.present(to) then return end
  local canDiscard = table.find(to:getCardIds("he"), function(i) return not to:prohibitDiscard(i) end)
  local choice = canDiscard and room:askToChoice(p, { choices = { "qiao_pindi_draw:::" .. count, "qiao_pindi_discard:::" .. count }, skill_name = skill.name })
  if choice == "qiao_pindi_discard:::" .. count then
    room:askToDiscard(to, { min_num = count, max_num = count, include_equip = true, skill_name = skill.name, cancelable = false })
  else
    to:drawCards(count, skill.name)
  end
  if S.present(p) and S.present(to) and to:isWounded() and not p.chained then p:setChainState(true) end
end
local selector = {
  card_num = 1, target_num = 1,
  card_filter = function(self, p, id, selected) return #selected == 0 and cardOK(p, id) end,
  target_filter = function(self, p, to, selected) return #selected == 0 and targetOK(p, to) end,
}
local active = table.simpleClone(selector)
active.on_use = function(self, room, effect) resolve(room, effect.from, effect.cards[1], effect.tos[1]) end
skill:addEffect("active", active)
skill:addAuxActiveSkill("#qiao_shi_pindi_select", selector)
skill:addEffect(fk.Damaged, {
  can_trigger = function(self, event, target, p)
    return target == p and p:hasSkill(skill.name) and table.find(p:getCardIds("he"), function(id) return cardOK(p, id) end)
      and table.find(p.room:getPresentPlayers(), function(to) return targetOK(p, to) end)
  end,
  on_cost = function(self, event, target, p)
    local ok, ret = p.room:askToUseActiveSkill(p, { skill_name = "#qiao_shi_pindi_select", cancelable = true,
      extra_data = { skillName = skill.name }, prompt = "#qiao_shi_pindi" })
    if ok then event:setCostData(self, ret) end
    return ok
  end,
  on_use = function(self, event, target, p)
    local ret = event:getCostData(self)
    resolve(p.room, p, ret.cards[1], ret.targets[1])
  end,
})
Fk:loadTranslationTable { qiao_pindi_draw = "令其摸%arg张牌", qiao_pindi_discard = "令其弃置%arg张牌", ["#qiao_shi_pindi"] = "品第：弃置一张本回合未选过类别的牌，选择一名未选过的其他角色" }
return skill
