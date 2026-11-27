local S = require "packages.qiao.pkg.qiao_bingqing.shi"
local OnlyAs = require "packages.qiao.pkg.qiao_mode.rules.only_as"
local skill = fk.CreateSkill { name = "qiao__skill_shu091_2", tags = { Skill.Compulsory } }
OnlyAs.define("gufen", {
  match = { suits = { Card.Diamond }, types = { Card.TypeTrick } },
  conversions = { { name = "qiao__analeptic", modes = { "use" } } },
  direct_zones = { "hand" }, view_zones = { "hand" }, skill = skill.name,
})
OnlyAs.addViewAsEffect(skill, "gufen")
local function sync(p)
  if p:hasShownSkill(skill.name) and not OnlyAs.getSource(p.room, "gufen:" .. p.id) then
    OnlyAs.addSource(p.room, { id = "gufen:" .. p.id, def = "gufen", holder = p })
  end
end
skill:addAcquireEffect(function(self, p) sync(p) end)
for _, timing in ipairs({ fk.GeneralShown, fk.GeneralRevealed, fk.AfterPropertyChange, fk.GameStart }) do
  skill:addEffect(timing, {
    can_refresh = function(self, event, target, p)
      return p:hasShownSkill(skill.name) and not OnlyAs.getSource(p.room, "gufen:" .. p.id)
    end,
    on_refresh = function(self, event, target, p) sync(p) end,
  })
end
local function partners(p)
  return table.filter(p.room:getPresentPlayers(), function(to) return to ~= p and #S.pairs(p.room, p, to) > 0 end)
end
skill:addEffect(fk.HpRecover, {
  can_trigger = function(self, event, target, p, data)
    return target == p and p:hasSkill(skill.name) and (not data.card or data.card.trueName ~= "peach") and #partners(p) > 0
  end,
  on_use = function(self, event, target, p)
    local to = S.pick(p.room, p, partners(p), skill.name)[1]
    S.exchange(p.room, p, S.pairs(p.room, p, to), skill.name)
  end,
})
return skill
