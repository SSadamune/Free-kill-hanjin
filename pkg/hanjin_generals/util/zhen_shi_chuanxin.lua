-- 穿心使用的固定翼从变更：沿用国战变更事件，但不验明原暗将。
local H=require "packages.hegemony.util"
local E=require "packages.hanjin.pkg.hanjin_mode.rules.general_exchange"
local C=require "packages.hanjin.pkg.hanjin_mode.rules.commander_retinue"
local M={}
function M.replaceDeputy(room,player,retinue,skillName)
  local old=E.actualGeneral(player,true)
  if not Fk.generals[old] or C.isSoldier(old) or not C.isRetinue(retinue)
    or C.limitedRetinueTaken(room,retinue) then return false end
  local data=H.GeneralTransformedData:new{
    who=player,isMain=false,isHidden=false,num=1,origName=old,skillName=skillName,
  }
  if room.logic:trigger(H.GeneralTransforming,player,data) then return false end
  -- 不调用 revealGeneral：旧暗将的明置技能、统领明置都不得发动。
  if player.deputyGeneral=="anjiang" then
    local other=Fk.generals[E.actualGeneral(player,false)]
    local kept=other and other:getSkillNameList(true) or {}
    for _,name in ipairs(Fk.generals[old]:getSkillNameList(true)) do
      if not table.contains(kept,name) then
        player:loseFakeSkill(name)
        player:prelightSkill(name,false)
      end
    end
  end
  C.onGeneralHidden(room,player,old)
  room:changeHero(player,retinue,false,true,false,false,false)
  if player.deputyGeneral~=retinue then return false end
  room:setPlayerMark(player,"__heg_deputy",retinue)
  if C.isLimitedRetinue(retinue) then
    local used=C.usedLimitedRetinues(room)
    used[retinue]={player=player.id,seat=player.seat}
    room:setTag(C.USED_RETINUE_TAG,used)
  end
  room:returnToGeneralPile({old})
  room.logic:trigger(H.GeneralTransformed,player,data)
  return true
end
return M
