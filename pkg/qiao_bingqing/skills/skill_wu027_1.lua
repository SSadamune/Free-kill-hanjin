local S = require "packages.qiao.pkg.qiao_bingqing.shi"
local H = require "packages.hegemony.util"
local skill = fk.CreateSkill { name = "qiao__skill_wu027_1" }
skill:addEffect("viewas", {
  pattern = "slash",
  card_filter = function(self, p, id, selected)
    return #selected < 2 and table.contains(p:getCardIds("he"), id)
  end,
  view_as = function(self, p, ids)
    if #ids ~= 2 then return end
    local card = Fk:cloneCard("qiao__fire__slash")
    card:addSubcards(ids)
    card.skillName = skill.name
    return card
  end,
  enabled_at_response = function(self, p, response) return not response end,
})
skill:addEffect("targetmod", {
  extra_target_func = function(self, p, cardSkill, card)
    if card and table.contains(card.skillNames, skill.name) then return 1 end
  end,
})
skill:addEffect(fk.CardUseFinished, {
  is_delay_effect = true, mute = true,
  can_trigger = function(self, event, target, p, data)
    return target == p and S.present(p) and table.contains(data.card.skillNames, skill.name)
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, p, data)
    local room = p.room
    local allies = table.filter(room:getPresentPlayers(), function(to) return p ~= to and S.allies(p, to) end)
    local to = S.pick(room, p, allies, skill.name)[1]
    if not to then return end
    local damage = 0
    local use = room.logic:getCurrentEvent():findParent(GameEvent.UseCard, true)
    if use then
      for _, hit in ipairs(use:searchEvents(GameEvent.Damage, math.huge, function(e)
        return e.data.dealtRecorderId ~= nil and e.data.card == data.card
          and e:findParent(GameEvent.UseCard) == use
      end)) do
        damage = damage + hit.data.damage
      end
    end
    if damage > 1 then
      for _, ally in ipairs({ p, to }) do
        if ally:getMark("@!!yinyangfish") == 0 then H.addHegMark(ally, "yinyangfish") end
      end
    else
      S.exchange(room, to, S.pairs(room, to, p, nil, "qiao_heg__wu027"), skill.name, true)
    end
  end,
})
return skill
