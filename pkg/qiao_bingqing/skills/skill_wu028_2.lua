local S = require "packages.qiao.pkg.qiao_bingqing.nu"
local skill = fk.CreateSkill { name = "qiao__skill_wu028_2", tags = { Skill.Limited } }
skill:addEffect("active", {
  card_num = 0, target_num = 1,
  can_use = function(self, p) return p:usedSkillTimes(skill.name, Player.HistoryGame) == 0 end,
  target_filter = function(self, p, to, selected) return #selected == 0 and S.present(to) end,
  on_use = function(self, room, effect)
    local to = effect.tos[1]
    local actors = table.filter(room:getPresentPlayers(), function(p) return p:inMyAttackRange(to) end)
    room:sortByAction(actors)
    for _, p in ipairs(actors) do
      if S.present(to) and S.present(p) then
        local paid = room:askToDiscard(p, { min_num = 1, max_num = 1, pattern = ".|.|.|.|.|weapon",
          include_equip = true, cancelable = true, skill_name = skill.name, prompt = "#qiao_chiyuan-discard::" .. to.id })
        if #paid == 0 and S.present(to) then to:drawCards(1, skill.name) end
      end
    end
  end,
})
Fk:loadTranslationTable { ["#qiao_chiyuan-discard"] = "驰援：你可以弃置一张武器牌，否则令 %dest 摸一张牌" }
return skill
