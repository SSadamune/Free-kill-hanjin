local S = require "packages.qiao.pkg.qiao_bingqing.nu"
local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"
local skill = fk.CreateSkill { name = "qiao__skill_qun139_2" }
local pile = "qiao_nu_er"
local function minimum(p, id)
  if not table.contains(p:getPile(pile), id) then return false end
  local n = Fk:getCardById(id).number
  return not table.find(p:getPile(pile), function(other) return Fk:getCardById(other).number < n end)
end
local function lose(p, number)
  if not S.present(p) or p:isKongcheng() then return end
  local cards = p:getCardIds("h")
  p:showCards(cards)
  local discard = table.filter(cards, function(id)
    return table.contains(p:getCardIds("h"), id) and Fk:getCardById(id).number > number and not p:prohibitDiscard(id)
  end)
  if #discard > 0 then p.room:throwCard(discard, skill.name, p, p) end
end
skill:addEffect("active", {
  card_num = 1, target_num = 1, expand_pile = pile,
  can_use = function(self, p) return #p:getPile(pile) > 0 end,
  card_filter = function(self, p, id, selected) return #selected == 0 and minimum(p, id) end,
  target_filter = function(self, p, to, selected) return #selected == 0 and p:canPindian(to, true) end,
  on_use = function(self, room, effect)
    local p, to, id = effect.from, effect.tos[1], effect.cards[1]
    if not minimum(p, id) or not p:canPindian(to, true) then return end
    local pd = p:pindian({ to }, skill.name, Fk:getCardById(id))
    local result = pd.results[to]
    if not result or not pd.fromCard or not result.toCard then return end
    if result.winner ~= p then lose(p, pd.fromCard.number) end
    if result.winner ~= to then lose(to, result.toCard.number) end
    if result.winner then
      local loser = result.winner == p and to or p
      if S.present(loser) and S.present(result.winner) then
        C.useVirtualCard(room, loser, "qiao__thunder__slash", {}, { result.winner }, skill.name, true, { qiao_youque = p.id }, C.bypassDistance())
      end
    end
  end,
})
skill:addEffect(fk.Damage, {
  is_delay_effect = true, mute = true,
  can_trigger = function(self, event, target, p, data)
    if not S.present(p) or not data.card or not table.contains(data.card.skillNames, skill.name) then return false end
    local use = p.room.logic:getCurrentEvent():findParent(GameEvent.UseCard)
    return use and use.data.card == data.card and (use.data.extra_data or {}).qiao_youque == p.id
  end,
  on_use = function(self, event, target, p) p:drawCards(1, skill.name) end,
})
return skill
