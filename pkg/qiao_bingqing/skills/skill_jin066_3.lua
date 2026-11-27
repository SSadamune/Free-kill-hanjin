local S = require "packages.qiao.pkg.qiao_bingqing.shi"
local skill = fk.CreateSkill { name = "qiao__skill_jin066_3" }
local function options(p)
  local room = p.room
  return table.filter(room:getPresentPlayers(), function(to)
    if not p.deputyGeneral or not to.deputyGeneral then return false end
    return #S.pairs(room, p, to, to == p and p.general or p.deputyGeneral, to.deputyGeneral) > 0
  end)
end
skill:addEffect(fk.EventPhaseStart, {
  can_trigger = function(self, event, target, p, data)
    return p == target and data.phase == Player.Finish and p:hasSkill(skill.name) and #options(p) > 0
  end,
  on_cost = function(self, event, target, p)
    local to = p.room:askToChoosePlayers(p, { targets = options(p), min_num = 1, max_num = 1,
      skill_name = skill.name, prompt = "#qiao_zhuanzheng", cancelable = true })[1]
    event:setCostData(self, { to = to })
    return to ~= nil
  end,
  on_use = function(self, event, target, p)
    local to = event:getCostData(self).to
    local pairs = S.pairs(p.room, p, to, to == p and p.general or p.deputyGeneral, to.deputyGeneral)
    S.exchange(p.room, to, pairs, skill.name, to ~= p)
  end,
})
Fk:loadTranslationTable { ["#qiao_zhuanzheng"] = "转征：选择自己交换主副将，或选择队友询问是否交换副将" }
return skill
