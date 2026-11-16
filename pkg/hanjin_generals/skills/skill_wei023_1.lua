-- 臧霸：每点伤害分别发动，建立的回合效果由独立房间规则处理。
local skill = fk.CreateSkill {name="hanjin__skill_wei023_1"}
skill.hanjinImplemented = true
local RULE="hanjin__wei023_hengjiang_rule"
skill:addEffect(fk.Damaged,{
  can_trigger=function(self,event,target,player,data)
    return target==player and player:hasSkill(skill.name) and not player.dead
      and player.room.current~=nil and not player.room.current.dead
  end,
  on_trigger=function(self,event,target,player,data)
    for _=1,data.damage do
      if player.dead or player.room.current.dead then break end
      self:doCost(event,target,player,data)
    end
  end,
  on_cost=function(self,event,target,player,data)
    return player.room:askToSkillInvoke(player,{skill_name=skill.name,prompt="#hanjin__wei023-invoke"})
  end,
  on_use=function(self,event,target,player,data)
    local room=player.room
    if not room:hasSkill(RULE) then room:addSkill(Fk.skills[RULE]) end
    local current=room.current
    room:addPlayerMark(current,"hanjin_hengjiang_penalty-turn",math.max(1,#current:getCardIds("e")))
    local follow=current:getTableMark("hanjin_hengjiang_follow-turn")
    table.insert(follow,player.id)
    room:setPlayerMark(current,"hanjin_hengjiang_follow-turn",follow)
  end,
})
Fk:loadTranslationTable{
 ["hanjin__skill_wei023_1"]="横江",
 [":hanjin__skill_wei023_1"]="当你受到1点伤害后，你可以令当前回合角色本回合手牌上限-X（X为其装备区牌数，至少为1）。若如此做，其本回合弃牌阶段结束时，若其此阶段弃置过牌，则你摸一张牌，否则你摸牌至体力上限。",
 ["#hanjin__wei023-invoke"]="横江：降低当前角色手牌上限，并建立弃牌阶段结束后的摸牌效果",
}
return skill
