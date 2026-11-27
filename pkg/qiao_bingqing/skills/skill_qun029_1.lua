local S = require "packages.qiao.pkg.qiao_bingqing.nu"
local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"
local skill = fk.CreateSkill { name = "qiao__skill_qun029_1" }
for _, timing in ipairs({ fk.CardUsing, fk.GeneralShown }) do
  skill:addEffect(timing, {
    global = true,
    can_refresh = function(self, event, target, p, data)
      return target == p and ((event == fk.CardUsing and data.card.trueName == "analeptic") or (event == fk.GeneralShown and p ~= p.room.current))
    end,
    on_refresh = function(self, event, target, p) p.room:setPlayerMark(p, "qiao_xunji-turn", 1) end,
  })
end
local function victims(p)
  return table.filter(C.effectCandidates(p.room, p, Fk:cloneCard("qiao__slash"), C.bypassDistance()), function(to)
    return to:getMark("qiao_xunji-turn") > 0
  end)
end
skill:addEffect(fk.TurnEnd, {
  can_trigger = function(self, event, target, p) return p:hasSkill(skill.name) and #victims(p) > 0 end,
  on_cost = function(self, event, target, p)
    local tos = S.choose(p, victims(p), skill.name, math.huge, true)
    event:setCostData(self, { tos = tos })
    return #tos > 0
  end,
  on_use = function(self, event, target, p)
    for _, to in ipairs(event:getCostData(self).tos) do
      if S.present(p) and S.present(to) then C.useVirtualCard(p.room, p, "qiao__slash", {}, { to }, skill.name, true, nil, C.bypassDistance()) end
    end
  end,
})
return skill
