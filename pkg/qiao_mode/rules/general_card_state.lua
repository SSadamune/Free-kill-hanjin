-- 武将牌离牌状态清理的最小公共接口。
--
-- 调用前提：操作已通过调用方校验，旧牌身份仍可取得，且尚未改动该位置的
-- 武将属性/技能；参数是该旧牌的实际程序 ID 和离开位置。
--
-- 本接口只处理旧牌印刷技能对应的暗将 fake/prelight：
--   * 另一武将位仍以暗置状态提供同名技能时，保留该来源的 fake/prelight；
--   * 否则仅撤旧牌的 fake，并撤掉它留下的 prelight；
--   * 实际 player_skills/derivative_skills 不在此模块处理。
-- 旧牌的后天附着技能由 GeneralCardSkills/G.sync 管理；该接口不负责撤回它们。
-- 也不负责 changeHero、标记、体力、回将池、日志、技能次数、牌堆或完成事件；
-- 这些仍由调用方操作入口负责。保护查询统一走 Exchange.cardProvidesSkill，
-- 仍可识别另一暗将的印刷和后天附将来源。
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
local M = {}

--- 撤掉离开指定位置的武将牌贡献的 fake/prelight。
--- @param player ServerPlayer
--- @param leavingGeneral string 离开的武将牌实际程序 ID
--- @param leavingIsDeputy boolean true=离开副将位，false=离开主将位
--- @return boolean changed 是否实际撤销了任一 fake
function M.clearLeavingCardState(player, leavingGeneral, leavingIsDeputy)
  if player == nil or player.room == nil then return false end
  local general = leavingGeneral and Fk.generals[leavingGeneral]
  if general == nil then return false end
  local room = player.room
  local otherIsDeputy = not leavingIsDeputy
  local other = Exchange.actualGeneral(player, otherIsDeputy)
  local protectOther = other ~= nil and other ~= "" and other ~= leavingGeneral
    and not Exchange.isRevealed(player, otherIsDeputy)
  local changed = false
  for _, skillName in ipairs(general:getSkillNameList(true)) do
    local skill = Fk.skills[skillName]
    if skill ~= nil and player:isFakeSkill(skill) then
      -- _fake_skills 按同名技能合并；另一暗将也提供同名技能时不能删其来源。
      local otherFakeSource = protectOther
        and Exchange.cardProvidesSkill(room, other, skillName)
      if not otherFakeSource then
        player:loseFakeSkill(skill)
        -- 旧牌 fake 的预亮一律撤；若技能另有实际来源，技能本身仍保留。
        player:prelightSkill(skill, false)
        changed = true
      end
    end
  end
  return changed
end

return M
