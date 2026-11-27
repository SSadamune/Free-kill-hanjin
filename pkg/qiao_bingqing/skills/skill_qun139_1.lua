local skill = fk.CreateSkill { name = "qiao__skill_qun139_1" }
local Markers = require "packages.qiao.pkg.qiao_mode.rules.marker_cards"
local pile = "qiao_nu_er"
Markers.register(skill.name, pile)
local function names(p)
  local choices = {}
  for _, name in ipairs({ "slash", "jink" }) do
    local card = Fk:cloneCard("qiao__" .. name)
    if p:getMark("qiao_xiewei_" .. name .. "-round") == 0 and Fk.currentResponsePattern and card:matchVSPattern(Fk.currentResponsePattern) then
      table.insert(choices, name)
    elseif not Fk.currentResponsePattern and name == "slash" and p:getMark("qiao_xiewei_slash-round") == 0 then
      table.insert(choices, name)
    end
  end
  return choices
end
skill:addEffect("viewas", {
  pattern = "slash,jink",
  interaction = function(self, p)
    local list = names(p)
    if #list > 0 then return UI.ComboBox { choices = list, default = list[1] } end
  end,
  card_filter = function(self, p, id, selected) return #selected == 0 and table.contains(p:getCardIds("h"), id) end,
  view_as = function(self, p, ids)
    local name = self.interaction.data
    if #ids ~= 1 or (name ~= "slash" and name ~= "jink") or p:getMark("qiao_xiewei_" .. name .. "-round") ~= 0 then return end
    local card = Fk:cloneCard("qiao__" .. name)
    card.skillName = skill.name
    card:setMark("qiao_xiewei_bait", ids[1])
    return card
  end,
  before_use = function(self, p, use)
    local id = use.card:getMark("qiao_xiewei_bait")
    local name = use.card.trueName
    if not table.contains(p:getCardIds("h"), id) or p:getMark("qiao_xiewei_" .. name .. "-round") > 0 then return skill.name end
    local source = Markers.chooseForSkill(p, self, skill.name)
    if not source then return skill.name end
    p.room:setPlayerMark(p, "qiao_xiewei_" .. name .. "-round", 1)
    Markers.put(p, source, skill.name, { id }, true)
  end,
  enabled_at_play = function(self, p) return not p:isKongcheng() and p:getMark("qiao_xiewei_slash-round") == 0 end,
  enabled_at_response = function(self, p, response) return not response and not p:isKongcheng() and #names(p) > 0 end,
})
Fk:loadTranslationTable { [pile] = "饵" }
return skill
