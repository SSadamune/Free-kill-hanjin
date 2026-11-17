-- EM(QUN010) 张角 · 黄巾天兵符
-- 弘法授予的旗入口：准备阶段没有天兵时，将牌堆顶等同群角色数的牌置于旗上。
local P = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_qun"
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
      prompt = "#qiao__em_qun010_banner-invoke",
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
  [P.PILE] = "天兵",
  [":" .. P.BANNER_SKILL] = "准备阶段，若没有“天兵”，你可以将牌堆顶等同群势力角色数的牌置于此牌上，称为“天兵”。"
    .. "有角色因技能或判断大小势力而计算角色数时，群势力角色数视为+X（X为“天兵”数）。",
  ["#qiao__em_qun010_banner-invoke"] = "黄巾天兵符：是否将牌堆顶等同群角色数的牌置于旗上作为天兵",
}

return skill
