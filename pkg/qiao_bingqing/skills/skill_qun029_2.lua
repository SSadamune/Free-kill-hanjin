local Placement = require "packages.qiao.pkg.qiao_mode.rules.mount_placement"
local S = require "packages.qiao.pkg.qiao_bingqing.nu"
local skill = fk.CreateSkill { name = "qiao__skill_qun029_2" }
local function subtypes(card)
  if Fk.packages.qiao_cards.qiao_cards.isDualMount(card) then
    return { Card.SubtypeOffensiveRide, Card.SubtypeDefensiveRide }
  end
  return { card.sub_type }
end
local function eligible(p, other)
  return table.filter(other:getCardIds("e"), function(id) return Placement.canPut(p, id) end)
end
for _, timing in ipairs({ fk.TargetSpecified, fk.TargetConfirmed }) do
  skill:addEffect(timing, {
    can_trigger = function(self, event, target, p, data)
      local other = event == fk.TargetSpecified and data.to or data.from
      return target == p and p:hasSkill(skill.name) and data.card.trueName == "slash" and other ~= p and S.present(other) and #eligible(p, other) > 0
    end,
    on_cost = function(self, event, target, p, data) return S.invoke(p, skill.name, event == fk.TargetSpecified and data.to or data.from) end,
    on_use = function(self, event, target, p, data)
      local other = event == fk.TargetSpecified and data.to or data.from
      local list = eligible(p, other)
      if #list == 0 then return end
      local id = p.room:askToChooseCard(p, { target = other, flag = { card_data = {{ "$Equip", list }} }, skill_name = skill.name })
      if not table.contains(list, id) then return end
      local types = subtypes(other:getVirtualEquip(id) or Fk:getCardById(id))
      Placement.put(p.room, p, id, skill.name)
      if p.room:getCardOwner(id) ~= p or p.room:getCardArea(id) ~= Card.PlayerEquip then return end
      local use = p.room.logic:getCurrentEvent():findParent(GameEvent.UseCard)
      use:addExitFunc(function()
        if not S.present(p) or not S.present(other) then return end
        local ids = {}
        for _, subtype in ipairs(types) do
          for _, equip in ipairs(p:getEquipments(subtype)) do table.insertIfNeed(ids, equip) end
        end
        for _, equip in ipairs(ids) do
          if p:canMoveCardInBoardTo(other, equip) then p.room:moveCardIntoEquip(other, equip, skill.name, false, p) end
        end
      end)
    end,
  })
end
return skill
