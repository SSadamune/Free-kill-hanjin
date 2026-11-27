local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
local tracker = require "packages.qiao.pkg.qiao_generals.util.reveal_ticket"
local M = { general = "qiao_heg__jin066", exchanged = TriggerEvent:subclass("QiaoHuFenExchanged") }
M.reveal = tracker(M.general, function(deputy) return deputy and "qiao__skill_jin066_2" or "qiao__skill_jin066_1" end)

local function flow(e)
  return not e or e.event == GameEvent.Game or e.event == GameEvent.Round or e.event == GameEvent.Turn or e.event == GameEvent.Phase
end
Exchange.addCompletionListener(function(room, context)
  for _, move in ipairs(context.moved) do
    if move.general == M.general then
      local p, deputy = move.to.player, move.to.isDeputy
      local function finish()
        if not p.dead and Exchange.publicGeneral(p, deputy) == M.general then
          room.logic:trigger(M.exchanged, p, { deputy = deputy })
        end
      end
      local e = room.logic:getCurrentEvent()
      if flow(e) then finish() else
        while e.parent and not flow(e.parent) do e = e.parent end
        e:addExitFunc(finish)
      end
    end
  end
end)

function M.after(skill, deputy, action, cost)
  for _, timing in ipairs({ fk.GeneralRevealed, M.exchanged }) do
    skill:addEffect(timing, {
      can_trigger = function(self, event, target, p, data)
        if p ~= target or p.dead then return false end
        if event == M.exchanged then return data.deputy == deputy and p:hasShownSkill(skill.name) end
        return M.reveal.available(p, skill.name)
      end,
      on_cost = function(self, event, target, p, data)
        if event == fk.GeneralRevealed and not M.reveal.take(p, skill.name) then return false end
        if cost then return cost(self, event, target, p, data) end
        return p.room:askToSkillInvoke(p, { skill_name = skill.name })
      end,
      on_use = action,
    })
  end
end
return M
