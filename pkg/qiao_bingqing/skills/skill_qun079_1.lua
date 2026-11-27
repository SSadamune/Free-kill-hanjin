local S = require "packages.qiao.pkg.qiao_bingqing.shi"
local skill = fk.CreateSkill { name = "qiao__skill_qun079_1" }
local ban = "@@qiao_xizhen-turn"
local function enemies(p)
  return table.filter(p.room:getPresentPlayers(), function(to) return not S.allies(p, to) end)
end
skill:addEffect(fk.EventPhaseStart, {
  can_trigger = function(self, event, target, p, data)
    return p == target and data.phase == Player.Play and p:hasSkill(skill.name) and #enemies(p) > 0
      and table.find(p:getCardIds("he"), function(id) return not p:prohibitDiscard(id) end)
  end,
  on_cost = function(self, event, target, p)
    local ids = p.room:askToDiscard(p, { min_num = 1, max_num = 1, include_equip = true,
      cancelable = true, skip = true, skill_name = skill.name })
    event:setCostData(self, { cards = ids })
    return #ids == 1
  end,
  on_use = function(self, event, target, p)
    local room = p.room
    room:throwCard(event:getCostData(self).cards, skill.name, p, p)
    local others = enemies(p)
    room:sortByAction(others)
    for _, to in ipairs(others) do
      if S.present(to) then
        if to:isNude() or not S.present(p) or room:askToChoice(to, { choices = { "qiao_xizhen_ban", "discard" }, skill_name = skill.name }) == "qiao_xizhen_ban" then
          room:setPlayerMark(to, ban, 1)
        else
          room:throwCard(room:askToChooseCard(p, { target = to, flag = "he", skill_name = skill.name }), skill.name, to, p)
        end
      end
    end
  end,
})
skill:addEffect("prohibit", {
  prohibit_use = function(self, p) return p:getMark(ban) > 0 end,
  prohibit_response = function(self, p) return p:getMark(ban) > 0 end,
})
Fk:loadTranslationTable { [ban] = "袭阵", qiao_xizhen_ban = "本回合不能使用或打出牌" }
return skill
