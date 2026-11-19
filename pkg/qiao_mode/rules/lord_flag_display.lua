local Wei = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wei"
local Wu = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wu"
local Qun = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_qun"

local M = {}

-- 章武的交互入口授予蜀势力队友，旗的展示仍属于拥有章武的君主。
M.shuFlag = "qiao__skill_em_shu001_flag"
M.flags = {
  [Wei.BANNER] = Wei.BANNER,
  [Wu.FLAG] = Wu.FLAG,
  [Qun.BANNER_SKILL] = Qun.BANNER_SKILL,
  [M.shuFlag] = "qiao__skill_em_shu001_1",
  qiao__skill_em_jin001_banner = "qiao__skill_em_jin001_banner",
}

function M.refresh(holder, flag)
  local mark = "@!!" .. flag
  local shown = holder:isAlive() and holder:hasShownSkill(M.flags[flag], true)
  -- The native picture mark renders its text overlay even without a mark asset.
  local value = shown and "旗" or 0
  if holder:getMark(mark) ~= value then holder.room:setPlayerMark(holder, mark, value) end
end

return M
