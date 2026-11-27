local H = require "packages.hegemony.util"
local Ci = require "packages.qiao.pkg.qiao_generals.util.jin_ci"
local S = require "packages.qiao.pkg.qiao_bingqing.shi"
local M = { root = "qiao__skill_wu027_2", attached = "qiao__chunyi_other&" }

local function choices(p)
  local list = {}
  for _, name in ipairs({ "yinyangfish", "companion", "vanguard" }) do
    if p:getMark("@!!" .. name) > 0 then table.insert(list, "@!!" .. name) end
  end
  table.insertTable(list, Ci.cards(p))
  return list
end

local function available(p)
  return S.present(p) and #choices(p) > 0 and table.find(Fk:currentRoom():getPresentPlayers(), function(provider)
    return provider:hasShownSkill(M.root) and S.allies(provider, p)
  end) ~= nil
end

function M.addWine(skill)
  skill:addEffect("viewas", {
    pattern = "analeptic",
    interaction = function(self, p)
      local list = choices(p)
      if #list > 0 then return UI.ComboBox { choices = list, default = list[1] } end
    end,
    card_filter = Util.FalseFunc,
    view_as = function(self, p, cards)
      if #cards ~= 0 or not available(p) then return end
      local card = Fk:cloneCard("qiao__analeptic")
      card.skillName = skill.name
      return card
    end,
    before_use = function(self, p, use)
      local chosen = self.interaction.data
      if not available(p) or not table.contains(choices(p), chosen) then return skill.name end
      if chosen:startsWith("@!!") then
        H.removeHegMark(p.room, p, chosen:sub(4), 1)
      elseif not Ci.consume(p.room, p, chosen) then
        return skill.name
      end
    end,
    enabled_at_play = function(self, p) return available(p) end,
    enabled_at_response = function(self, p, response) return not response and available(p) end,
  })
end
return M
