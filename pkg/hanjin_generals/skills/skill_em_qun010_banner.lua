-- EM(QUN010) 张角 · 黄巾天兵符
-- 弘法授予的旗入口：准备阶段没有天兵时，将牌堆顶等同群角色数的牌置于旗上。
local P = require "packages.hanjin.pkg.hanjin_generals.util.zhen_shi_lord_qun"
local H = require "packages.hegemony.util"

local skill = fk.CreateSkill {
  name = P.BANNER_SKILL,
  derived_piles = P.PILE,
}

skill:addEffect(fk.EventPhaseStart, {
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and player.phase == Player.Start
      and player:hasSkill(skill.name) and P.count(player) == 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__em_qun010_banner-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local count = H.getKingdomPlayersNum(room, false)["qun"] or 0
    if count <= 0 then return end
    local ids = room:getNCards(count)
    P.add(player, ids, skill.name)
  end,
})

Fk:loadTranslationTable {
  [P.BANNER_SKILL] = "黄巾天兵符",
  ["#hanjin__em_qun010_banner-invoke"] = "黄巾天兵符：是否将牌堆顶等同群角色数的牌置于旗上作为天兵",
}

return skill
