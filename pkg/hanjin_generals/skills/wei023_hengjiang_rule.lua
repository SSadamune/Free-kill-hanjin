local skill=fk.CreateSkill{name="hanjin__wei023_hengjiang_rule"}
skill:addEffect("maxcards",{
 correct_func=function(self,player) return -(player:getMark("hanjin_hengjiang_penalty-turn") or 0) end,
})
skill:addEffect(fk.EventPhaseEnd,{
 global=true,
 can_trigger=function(self,event,target,player,data)
   return target==player and data.phase==Player.Discard and #player:getTableMark("hanjin_hengjiang_follow-turn")>0
 end,
 on_cost=Util.TrueFunc,
 on_use=function(self,event,target,player,data)
   local room=player.room
   local discarded=#room.logic:getEventsOfScope(GameEvent.MoveCards,1,function(e)
     for _,m in ipairs(e.data) do
       if m.from==player and m.moveReason==fk.ReasonDiscard and #m.moveInfo>0 then return true end
     end
     return false
   end,Player.HistoryPhase)>0
   for _,id in ipairs(player:getTableMark("hanjin_hengjiang_follow-turn")) do
     local owner=room:getPlayerById(id)
     if owner and not owner.dead and not owner:isRemoved() then
       local n=discarded and 1 or math.max(0,owner.maxHp-#owner:getCardIds("h"))
       if n>0 then owner:drawCards(n,"hanjin__skill_wei023_1") end
     end
   end
 end,
})
return skill
