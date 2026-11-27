local S = require "packages.qiao.pkg.qiao_bingqing.nu"
local skill = fk.CreateSkill { name = "qiao__retinue_skill_jiefanwei", tags = { Skill.Limited }, max_game_use_time = math.huge }
local R = require "packages.qiao.pkg.qiao_generals.util.retinue_instances"
local PhaseUses = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_retinues"
local Bian = require "packages.qiao.pkg.qiao_generals.util.bian_common"
local Jin = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_jin"
local LimitedUses = require "packages.qiao.pkg.qiao_mode.rules.limited_skill_uses"
local ActiveLimits = require "packages.qiao.pkg.qiao_mode.rules.active_skill_limits"
local Sources = require "packages.qiao.pkg.qiao_mode.rules.skill_sources"
local SameName = require "packages.qiao.pkg.qiao_mode.rules.same_name_skills"
Bian.registerLimitedRetinueSkill(skill.name)

-- 保留手工计次的旧技能及基础为一次、效果可追加次数的【征辟】。
local onceByRule = {
  [Jin.CHEN_SKILL] = true,
  qiao__retinue_skill_bingzhou_langqi = true,
  qiao__retinue_skill_qingzhou_jingrui = true,
  qiao__skill_qun001_2 = true,
  qiao__skill_qun003_1 = true,
  qiao__skill_qun017_1 = true,
  qiao__skill_qun018_2 = true,
  qiao__skill_wei020_1 = true,
  qiao__skill_wei021b_1 = true,
}

local function usedPlayPhase(p, sk)
  local name = SameName.canonicalHistoryKey(sk.name)
  if not onceByRule[name] and not ActiveLimits.declaresOnceInPlayPhase(sk, p) then return false end
  local used = p:usedSkillTimes(sk.name, Player.HistoryPhase) > 0
  if name == Jin.CHEN_SKILL then return used and Jin.sanChenRemaining(p) == 0 end
  return used or PhaseUses.publicUsed(p, sk.name) > 0
end

local function refreshOptions(p, scope)
  local names = {}
  for _, sk in ipairs(p:getAllSkills()) do
    local root = sk:getSkeleton()
    if root and sk.name == root.name and Sources.isGeneralSkill(sk, p) then
      if (scope == Player.HistoryGame and sk:hasTag(Skill.Limited, false) and LimitedUses.hasUsed(p, root.name))
        or (scope == Player.HistoryPhase and usedPlayPhase(p, sk)) then
        table.insertIfNeed(names, root.name)
      end
    end
  end
  return names
end
skill:addEffect("active", {
  card_num = 2, target_num = 1,
  can_use = function(self, p)
    if R.countForSkill(p, skill.name) > 0 then return Bian.canUseLimitedRetinue(p, skill.name) end
    return p:usedSkillTimes(skill.name, Player.HistoryGame) == 0
  end,
  card_filter = function(self, p, id, selected) return #selected < 2 and table.contains(S.discardable(p), id) end,
  target_filter = function(self, p, to, selected) return #selected == 0 and S.present(to) and to:isWounded() end,
  on_use = function(self, room, effect)
    local p, to = effect.from, effect.tos[1]
    local instance = Bian.availableLimitedRetinues(p, skill.name)[1]
    if not instance and R.countForSkill(p, skill.name) > 0 then return end
    if instance then Bian.spendLimitedRetinue(p, instance, skill.name) end
    room:throwCard(effect.cards, skill.name, p, p)
    if not S.present(to) then return end
    room:recover { who = to, num = 1, recoverBy = p, skillName = skill.name }
    if not S.present(to) or not S.present(p) then return end
    local scope = to == p and Player.HistoryPhase or Player.HistoryGame
    local names = refreshOptions(to, scope)
    if #names == 0 then return end
    local selected = room:askToChoice(p, { choices = names, skill_name = skill.name })
    if not table.contains(names, selected) then return end
    if scope == Player.HistoryGame then
      LimitedUses.restore(room, to, selected)
    elseif PhaseUses.restorePhaseUse(to, selected) then
      to:setSkillUseHistory(selected, PhaseUses.publicUsed(to, selected), scope)
    else
      local name = SameName.canonicalHistoryKey(selected)
      to:clearSkillHistory(selected, scope)
      if name == Jin.CHEN_SKILL then Jin.restoreSanChen(to) end
      local mark = Fk.skill_skels[name].qiao_play_phase_use_mark
      if mark then room:setPlayerMark(to, mark, 0) end
    end
  end,
})
return skill
