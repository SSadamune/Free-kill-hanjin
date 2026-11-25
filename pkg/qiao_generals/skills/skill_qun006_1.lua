-- QUN006 董卓 · 横征
--
-- 准备阶段，若体力恰为1或没有手牌，可以获得每名其他角色区域里各一张牌。
-- 不替换正常摸牌；区域含判定区，依次处理实际有牌的角色。
local skill = fk.CreateSkill {
  name = "qiao__skill_qun006_1",
}
skill.qiaoImplemented = true

---@param player ServerPlayer
---@return ServerPlayer[]
local function othersWithCards(player)
  return table.filter(player.room:getPresentPlayers(), function(p)
    return p ~= player and p:isAlive() and not p:isRemoved()
      and #p:getCardIds("hej") > 0
  end)
end

skill:addEffect(fk.EventPhaseStart, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and player:hasSkill(skill.name)
      and data ~= nil and data.phase == Player.Start
      and (player.hp == 1 or #player:getCardIds(Player.Hand) == 0)
      and #othersWithCards(player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_qun006_1-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local others = othersWithCards(player)
    room:sortByAction(others)
    for _, other in ipairs(others) do
      if player.dead then break end
      if other:isAlive() and not other:isRemoved() and #other:getCardIds("hej") > 0 then
        local id = room:askToChooseCard(player, {
          target = other,
          flag = "hej",
          skill_name = skill.name,
          prompt = "#qiao__skill_qun006_1-card::" .. other.id,
        })
        if id ~= nil and id ~= -1 and table.contains(other:getCardIds("hej"), id) then
          room:obtainCard(player, id, false, fk.ReasonPrey, player, skill.name)
        end
      end
    end
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_qun006_1"] = "横征",
  [":qiao__skill_qun006_1"] = "准备阶段，若你的体力值为1或没有手牌，你可以获得每名其他角色区域里各一张牌。",
  ["#qiao__skill_qun006_1-invoke"] = "横征：你可以获得每名其他角色区域里各一张牌",
  ["#qiao__skill_qun006_1-card"] = "横征：选择 %dest 区域里的一张牌",
}

return skill
