-- 臧霸：每点伤害分别发动，建立的回合效果由独立房间规则处理。
local skill = fk.CreateSkill {name="qiao__skill_wei023_1"}
skill.qiaoImplemented = true
local RULE="qiao__wei023_hengjiang_rule"
local status = require "packages.qiao.pkg.qiao_mode.skill_status"
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
    local room = player.room
    local current = room.current
    local amount = math.max(1, #current:getCardIds("e"))
    return room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__wei023-invoke::" .. current.id .. ":" .. amount,
    })
  end,
  on_use=function(self,event,target,player,data)
    local room=player.room
    if not room:hasSkill(RULE) then room:addSkill(Fk.skills[RULE]) end
    local current=room.current
    local amount = math.max(1, #current:getCardIds("e"))
    room:addPlayerMark(current, MarkEnum.MinusMaxCardsInTurn, amount)
    room:addPlayerMark(current, status.hengjiang, amount)
    room:broadcastProperty(current,"MaxCards")
    local follow=current:getTableMark("qiao_hengjiang_follow-turn")
    table.insert(follow,player.id)
    room:setPlayerMark(current,"qiao_hengjiang_follow-turn",follow)
  end,
})
Fk:loadTranslationTable{
 ["qiao__skill_wei023_1"]="横江",
 [":qiao__skill_wei023_1"]="当你受到1点伤害后，你可以令当前回合角色本回合手牌上限-X（X为其装备区牌数，至少为1）。若如此做，其本回合弃牌阶段结束时，若其此阶段弃置过牌，则你摸一张牌，否则你摸牌至体力上限。",
 ["#qiao__wei023-invoke"]="横江：令 %dest 本回合手牌上限减少 %arg，弃牌阶段结束后你摸牌",
}
return skill
