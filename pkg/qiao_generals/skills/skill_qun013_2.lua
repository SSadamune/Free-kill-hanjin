-- QUN013 马腾 · 雄异
--
-- 规则基线：docs/rules/standard-generals.md 群区 QUN013、群包审阅
-- docs/development/implementation/generals/qun-standard.md。
-- 限定技，出牌阶段：先令所有与自己势力相同的角色（含自己）各摸三张，
-- 然后检查「与自己势力相同的角色数是否全场最少（含并列）」，符合才回复 1 点。
-- 势力比较与统计复用锁定上游 hegemony 的公共入口（compareKingdomWith /
-- getKingdomPlayersNum），不自行聚合势力字符串，也不额外处理野心家。
local H = require "packages.hegemony.util"

local skill = fk.CreateSkill {
  name = "qiao__skill_qun013_2",
  tags = { Skill.Limited },
}
skill.qiaoImplemented = true

skill:addEffect("active", {
  anim_type = "drawcard",
  prompt = "#qiao__skill_qun013_2",
  card_num = 0,
  target_num = 0,
  card_filter = Util.FalseFunc,
  can_use = function(self, player)
    return player:usedSkillTimes(skill.name, Player.HistoryGame) == 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local targets = table.filter(room:getPresentPlayers(), function(p)
      return not p.dead and H.compareKingdomWith(p, player)
    end)
    for _, p in ipairs(targets) do
      if not p.dead then
        p:drawCards(3, skill.name)
      end
    end

    if player.dead then return end
    local kingdom = H.getKingdom(player)
    if kingdom == nil or kingdom == "" or kingdom == "unknown" then return end
    local mapper = H.getKingdomPlayersNum(room)
    local num = mapper[kingdom]
    if num == nil then return end
    for _, other in pairs(mapper) do
      if other < num then return end
    end
    if player:isWounded() then
      room:recover {
        who = player,
        num = 1,
        recoverBy = player,
        skillName = skill.name,
      }
    end
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_qun013_2"] = "雄异",
  [":qiao__skill_qun013_2"] = "限定技，出牌阶段，你可以令所有与你势力相同的角色各摸三张牌，然后若与你势力相同的角色数最小，你回复1点体力。",
  ["#qiao__skill_qun013_2"] = "雄异：令所有与你势力相同的角色各摸三张牌",
}

return skill
