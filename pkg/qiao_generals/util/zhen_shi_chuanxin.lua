-- 穿心使用的固定翼从变更：沿用国战变更事件，但不验明原暗将。
local H=require "packages.hegemony.util"
local E=require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
local CardState=require "packages.qiao.pkg.qiao_mode.rules.general_card_state"
local C=require "packages.qiao.pkg.qiao_mode.rules.commander_retinue"
local Discard = require "packages.qiao.pkg.qiao_mode.rules.general_discard"
local Wei = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wei"
local M={}
function M.replaceDeputy(room,player,retinue,skillName)
  local old=E.actualGeneral(player,true)
  -- 君主武将牌不能被实际变更，包括暗置的牌；拒绝后由调用方执行“否则”。
  -- 在任何事件、离牌状态清理或将池移动之前返回。
  if E.isLordPosition(player,true) or Wei.isPositionRestricted(room, player, true) then return false end
  if not Fk.generals[old] or C.isSoldier(old) or not C.retinueAllowed(room,retinue)
    or C.limitedRetinueTaken(room,retinue) then return false end
  local data=H.GeneralTransformedData:new{
    who=player,isMain=false,isHidden=false,num=1,origName=old,skillName=skillName,
  }
  if room.logic:trigger(H.GeneralTransforming,player,data) then return false end
  -- 不调用 revealGeneral：旧暗将的明置技能、统领明置都不得发动。
  if player.deputyGeneral=="anjiang" then
    CardState.clearLeavingCardState(player,old,true)
  end
  C.onGeneralHidden(room,player,old)
  room:changeHero(player,retinue,false,true,false,false,false)
  if player.deputyGeneral~=retinue then return false end
  room:setPlayerMark(player,"__heg_deputy",retinue)
  C.noteRetinueAdmission(room,retinue)
  if C.isLimitedRetinue(retinue) then
    local used=C.usedLimitedRetinues(room)
    used[retinue]={player=player.id,seat=player.seat}
    room:setTag(C.USED_RETINUE_TAG,used)
  end
  Discard.add(room, { old })
  room.logic:trigger(H.GeneralTransformed,player,data)
  return true
end
return M
