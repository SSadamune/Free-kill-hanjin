local skill = fk.CreateSkill { name = "qiao__skill_jin076_1" }
local Markers = require "packages.qiao.pkg.qiao_mode.rules.marker_cards"
local pile = "qiao_nu_jinu"
Markers.register(skill.name, pile)
skill:addEffect(fk.EventPhaseStart, {
  can_trigger = function(self, event, target, p, data)
    return p == target and p:hasSkill(skill.name) and data.phase == Player.Finish and #p:getPile(pile) < 5
      and table.find(p:getCardIds("h"), function(id)
        local c = Fk:getCardById(id)
        return c.type == Card.TypeBasic or c:isCommonTrick()
      end)
  end,
  on_cost = function(self, event, target, p)
    local ids = p.room:askToCards(p, { min_num = 1, max_num = 5 - #p:getPile(pile),
      pattern = ".|.|.|hand|.|basic,normal_trick", skill_name = skill.name, cancelable = true, prompt = "#qiao_jinu-store" })
    event:setCostData(self, { cards = ids })
    return #ids > 0
  end,
  on_use = function(self, event, target, p)
    local source = Markers.chooseForSkill(p, self, skill.name)
    if source then Markers.put(p, source, skill.name, event:getCostData(self).cards, false) end
  end,
})
skill:addEffect("filter", {
  handly_cards = function(self, p) if p:hasShownSkill(skill.name) then return p:getPile(pile) end end,
})
for _, timing in ipairs({ fk.PreCardUse, fk.PreCardRespond }) do
  skill:addEffect(timing, {
    can_refresh = function(self, event, target, p, data)
      return p == target and p:hasShownSkill(skill.name) and not data.card:isVirtual()
        and table.contains(p:getPile(pile), data.card.id)
    end,
    on_refresh = function(self, event, target, p, data) data.qiao_jinu = true end,
  })
end
for _, timing in ipairs({ fk.CardUsing, fk.CardResponding }) do
  skill:addEffect(timing, {
    mute = true, is_delay_effect = true,
    can_trigger = function(self, event, target, p, data) return p == target and data.qiao_jinu == true end,
    on_use = function(self, event, target, p, data)
      local judge = { who = p, reason = skill.name, pattern = ".|.|black" }
      p.room:judge(judge)
      if event == fk.CardUsing and judge.card.color == Card.Black then data.unoffsetableList = table.simpleClone(p.room:getPresentPlayers()) end
    end,
  })
end
Fk:loadTranslationTable { [pile] = "积弩", ["#qiao_jinu-store"] = "积弩：你可以扣置基本牌或普通锦囊牌" }
return skill
