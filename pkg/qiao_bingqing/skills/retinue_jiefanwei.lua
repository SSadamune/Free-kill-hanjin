local S = require "packages.qiao.pkg.qiao_bingqing.nu"
local skill = fk.CreateSkill { name = "qiao__retinue_skill_jiefanwei", tags = { Skill.Limited }, max_game_use_time = math.huge }
local R = require "packages.qiao.pkg.qiao_generals.util.retinue_instances"
local PhaseUses = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_retinues"
local AVAILABLE = "qiao_jiefanwei_available"
local function unused(p)
  return table.filter(R.instancesForSkill(p, skill.name), function(instance) return (instance.uses or 0) == 0 end)
end
local function spentInstance(p)
  return table.find(R.instancesForSkill(p, skill.name), function(instance) return (instance.uses or 0) > 0 end)
end
local function sync(p)
  local n = #unused(p)
  if p:getMark(AVAILABLE) ~= n then p.room:setPlayerMark(p, AVAILABLE, n) end
end
R.addChangeListener(sync)
local function onceInPlayPhase(root, p)
  if root:getMaxUseTime(p, Player.HistoryPhase) == 1 then return true end
  -- 兼容用历史次数手工限次的旧技能。只识别技能条款，不匹配引号中的引用。
  local desc = Fk:translate(":" .. root.name)
  return desc:startsWith("出牌阶段限一次，") or desc:find("，出牌阶段限一次，", 1, true)
    or desc:find("。出牌阶段限一次，", 1, true) or desc:find("；出牌阶段限一次，", 1, true)
end
local function refreshOptions(p, scope)
  local names = {}
  for _, sk in ipairs(p:getAllSkills()) do
    local root = sk:getSkeleton()
    if root and sk.name == root.name and sk:isPlayerSkill(p) then
      local used = p:usedSkillTimes(root.name, scope) > 0
      if scope == Player.HistoryPhase then
        used = used or PhaseUses.publicUsed(p, root.name) > 0
      end
      local spent = root.qiaoLimitedUseMark and p:getMark(root.qiaoLimitedUseMark) ~= 0
      if scope == Player.HistoryGame and root.name == skill.name and R.countForSkill(p, skill.name) > 0 then
        used = spentInstance(p) ~= nil
      end
      if (scope == Player.HistoryGame and sk:hasTag(Skill.Limited, false) and (used or spent))
        or (scope == Player.HistoryPhase and used and onceInPlayPhase(root, p)) then
        table.insertIfNeed(names, root.name)
      end
    end
  end
  return names
end
skill:addEffect("active", {
  card_num = 2, target_num = 1,
  can_use = function(self, p) return p:getMark(AVAILABLE) > 0 or (R.countForSkill(p, skill.name) == 0 and p:usedSkillTimes(skill.name, Player.HistoryGame) == 0) end,
  card_filter = function(self, p, id, selected) return #selected < 2 and table.contains(S.discardable(p), id) end,
  target_filter = function(self, p, to, selected) return #selected == 0 and S.present(to) and to:isWounded() end,
  on_use = function(self, room, effect)
    local p, to = effect.from, effect.tos[1]
    local instance = unused(p)[1]
    if instance then
      R.recordUse(instance)
      sync(p)
    end
    room:throwCard(effect.cards, skill.name, p, p)
    if not S.present(to) then return end
    room:recover { who = to, num = 1, recoverBy = p, skillName = skill.name }
    if not S.present(to) or not S.present(p) then return end
    local scope = to == p and Player.HistoryPhase or Player.HistoryGame
    local names = refreshOptions(to, scope)
    if #names == 0 then return end
    local selected = room:askToChoice(p, { choices = names, skill_name = skill.name })
    if not table.contains(names, selected) then return end
    if scope == Player.HistoryPhase and PhaseUses.restorePhaseUse(to, selected) then
      to:setSkillUseHistory(selected, PhaseUses.publicUsed(to, selected), scope)
      return
    end
    to:clearSkillHistory(selected, scope)
    local spentMark = Fk.skill_skels[selected].qiaoLimitedUseMark
    if scope == Player.HistoryGame and spentMark then room:setPlayerMark(to, spentMark, 0) end
    if selected == skill.name then
      local spent = spentInstance(to)
      if spent then spent.uses = 0; sync(to) end
    end
  end,
})
return skill
