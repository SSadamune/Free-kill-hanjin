-- WEI032 郭淮 · 精策
-- 每回合结束时，比较本回合自己使用或打出的牌数（事件数，不是材料张数）
-- 与当前体力：大于摸1，等于摸2。使用和打出分别记一次，不按材料累计。
-- 历史由模式级公开事件账本记录，包含郭淮取得/明置精策之前的用牌。
local H = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_history"

local skill = fk.CreateSkill {
  name = "qiao__skill_wei032_1",
}
skill.qiaoImplemented = true

local function drawCount(player)
  local count = H.cardCount(player.room, player)
  if count == player.hp then return 2 end
  return count > player.hp and 1 or 0
end

skill:addEffect(fk.TurnEnd, {
  can_trigger = function(self, event, target, player)
    return not player.dead and player:hasSkill(skill.name)
      and drawCount(player) > 0
  end,
  on_cost = function(self, event, target, player)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_wei032_1-invoke:::" .. drawCount(player),
    })
  end,
  on_use = function(self, event, target, player)
    local n = drawCount(player)
    if n > 0 then player:drawCards(n, skill.name) end
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_wei032_1"] = "精策",
  ["#qiao__skill_wei032_1-invoke"] = "精策：你可以摸 %arg 张牌",
}

return skill
