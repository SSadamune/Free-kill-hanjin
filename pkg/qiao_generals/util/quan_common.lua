-- 六势力权包共用辅助：定向叠置、可暗置/可移除武将牌判定、每区弃一、玉玺状态与模式延时记账。
-- 客户端可达查询统一使用 Fk:currentRoom() 与公开状态，不读取服务端私有字段。
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
local Commander = require "packages.qiao.pkg.qiao_mode.rules.commander_retinue"
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"

local M = {}

M.YUJUE_DRAW_MARK = "qiao_han003_yujue_draw-turn"
M.XUANHU_RED_MARK = "qiao_han021_red_discarded-turn"

--- 汉晋定向叠置：仅平置改为叠置，已叠置不反向平置。
function M.directedStack(target)
  if target ~= nil and RemovedTargets.isPresent(target) and target.faceup then
    target:turnOver()
    return true
  end
  return false
end

--- 是否已有暗置武将牌（公开状态判断）。
function M.hasHiddenGeneral(player)
  if player == nil then return false end
  return player.general == "anjiang" or player.deputyGeneral == "anjiang"
end

--- 指定位置是否为可被暗置的明置武将牌（排除暗置、士兵/翼从/偏将、君主及专属野心家）。
function M.canHideGeneralPosition(player, isDeputy)
  if player == nil or player.dead then return false end
  local public = Exchange.publicGeneral(player, isDeputy)
  if type(public) ~= "string" or public == "" or public == "anjiang" then return false end
  if Commander.isSoldier(public) then return false end
  if Exchange.isLordPosition(player, isDeputy) then return false end
  if Exchange.isWildGeneral(public) then return false end
  return true
end

--- 为目标登记一次【鬻爵】本回合下次造成伤害后摸两张牌的延时效果。
function M.addYujueDraw(room, target)
  if room == nil or target == nil or target.dead then return end
  room:addPlayerMark(target, M.YUJUE_DRAW_MARK, 1)
end

return M
