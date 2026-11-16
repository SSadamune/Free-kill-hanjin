-- EM(QUN010) 张角 · 悟心
-- 观察天兵旗实际移入/移出；数量增加或减至0后，通过正常触发成本询问，
-- 由技能效果执行卜算，不直接绕过 SkillEffect 询问暗将。
local P = require "packages.hanjin.pkg.hanjin_generals.util.zhen_shi_lord_qun"

local skill = fk.CreateSkill {
  name = "hanjin__skill_em_qun010_2",
}
skill.hanjinImplemented = true

local function previousCount(player,data)
  local delta=0
  for _,move in ipairs(data or {}) do
    if move.to==player and move.toArea==Card.PlayerSpecial and move.specialName==P.PILE then
      delta=delta+#(move.moveInfo or {})
    end
    if move.from==player then
      for _,info in ipairs(move.moveInfo or {}) do
        if info.fromArea==Card.PlayerSpecial and info.fromSpecialName==P.PILE then delta=delta-1 end
      end
    end
  end
  return P.count(player)-delta
end

skill:addEffect(fk.AfterCardsMove, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if player == nil or player.dead or not player:hasSkill(skill.name) then
      return false
    end
    local old = previousCount(player,data)
    local new = P.count(player)
    local changed = new > old or (new == 0 and old > 0)
    return changed and P.largeCount(player.room) > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_em_qun010_2-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local x = P.largeCount(player.room)
    if x <= 0 or player.dead then return end
    player.room:askToGuanxing(player, {
      cards = player.room:getNCards(x),
      skill_name = skill.name,
    })
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_em_qun010_2"] = "悟心",
  [":hanjin__skill_em_qun010_2"] = "当“天兵”的数量减至0或增加后，你可以卜算X（X为大势力角色数）。",
  ["#hanjin__skill_em_qun010_2-invoke"] = "悟心：是否卜算？",
}

return skill
