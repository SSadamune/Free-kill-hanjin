-- HAN006 王允 · 定著
--
-- 副将技。出牌阶段结束时，选择一名本回合得到过牌的其他角色，令其视为对
-- 由技能发动者指定的另一名角色使用一张【决斗】。
-- “得到过牌”直接查询本回合的 GameEvent.MoveCards 历史，暗置/晚获得技能也
-- 不会漏记；记录工具只读历史，不安装房间技能。
-- 两个目标都在 on_cost 中选定并保存：发动询问与选目标先于 SkillEffect 的
-- 明置/技能效果结算，避免“先明置再选目标”偏离公共明置顺序。
local skill = fk.CreateSkill {
  name = "qiao__skill_han006_2",
  tags = { Skill.DeputyPlace },
}

local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"
local History = require "packages.qiao.pkg.qiao_generals.util.han_history"

local function alive(player)
  return player ~= nil and player:isAlive() and not player:isRemoved()
end

--- 本回合得到过牌的其他角色。
---@param player ServerPlayer
---@return ServerPlayer[]
local function gainedTargets(player)
  local room = player.room
  local ret = {}
  for _, p in ipairs(room:getPresentPlayers()) do
    if p ~= player and alive(p) and History.count(room, p) > 0 then
      table.insert(ret, p)
    end
  end
  return ret
end

--- 除 gained 以外的合法【决斗】目标；可以包括定著发动者本人。
---@param room Room
---@param gained ServerPlayer
---@return ServerPlayer[]
local function duelTargets(room, gained)
  local ret = {}
  for _, p in ipairs(room:getPresentPlayers()) do
    if p ~= gained and alive(p) then table.insert(ret, p) end
  end
  return ret
end

local SELECT = "#qiao__skill_han006_2_select"

skill:addAuxActiveSkill(SELECT, {
  card_num = 0,
  target_num = 2,
  target_filter = function(self, player, to_select, selected)
    if to_select.dead or to_select:isRemoved() then return false end
    if #selected == 0 then return table.contains(self._extra_data.gained, to_select.id) end
    return #selected == 1 and to_select ~= selected[1]
  end,
})

skill:addEffect(fk.EventPhaseEnd, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and data.phase == Player.Play and not player.dead
      and #gainedTargets(player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local gainedList = gainedTargets(player)
    if #gainedList == 0 then return false end
    local ok, ret = room:askToUseActiveSkill(player, {
      skill_name = SELECT,
      prompt = "#qiao__skill_han006_2-target",
      cancelable = true,
      extra_data = { skillName = skill.name, gained = table.map(gainedList, Util.IdMapper) },
    })
    local targets = ok and ret and ret.targets or {}
    local gained, to = targets[1], targets[2]
    if #targets ~= 2 or not table.contains(gainedList, gained)
      or not table.contains(duelTargets(room, gained), to) or player.dead then return false end

    event:setCostData(self, { gained = gained, to = to })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self) or {}
    local gained, to = cost.gained, cost.to
    if player.dead or not alive(gained) or not alive(to) then return end

    -- 效果明确指定“由你指定的另一名角色”，使用显式目标策略；【决斗】本身
    -- 不涉及距离，仍由公共策略复核禁止使用/禁止指定。
    C.useVirtualCard(room, gained, "qiao__duel", nil, { to }, skill.name, true, nil,
      C.explicit({ other_roles = true }, { names = { "qiao__duel" } }))
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_han006_2"] = "定著",
  [":qiao__skill_han006_2"] = "副将技（☯️-1），出牌阶段结束时，你可以选择一名本回合得到过牌的其他角色，其视为对由你指定的另一名角色使用一张【决斗】。",
  ["#qiao__skill_han006_2-target"] = "定著：依次选择【决斗】的使用者和目标",
}

skill.qiaoImplemented = true

return skill
