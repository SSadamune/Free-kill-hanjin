-- HAN006 王允 · 定著
--
-- 副将技。出牌阶段结束时，选择一名本回合得到过牌的其他角色，令其视为对
-- 由技能发动者指定的另一名角色使用一张【决斗】。
-- “得到过牌”直接查询本回合的 GameEvent.MoveCards 历史，暗置/晚获得技能也
-- 不会漏记；记录工具只读历史，不安装房间技能。
-- 两个目标都在 on_cost 中选定并保存：发动询问与选目标先于 SkillEffect 的
-- 明置/技能效果结算，避免“先明置再选目标”偏离公共明置顺序。
local skill = fk.CreateSkill {
  name = "hanjin__skill_han006_2",
  tags = { Skill.DeputyPlace },
}

local C = require "packages.hanjin.pkg.hanjin_mode.rules.card_use_targets"
local History = require "packages.hanjin.pkg.hanjin_generals.util.han_history"

local function alive(player)
  return player ~= nil and player:isAlive() and not player:isRemoved()
end

--- 本回合得到过牌的其他角色。
---@param player ServerPlayer
---@return ServerPlayer[]
local function gainedTargets(player)
  local room = player.room
  local ret = {}
  for _, p in ipairs(room.alive_players) do
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
  for _, p in ipairs(room.alive_players) do
    if p ~= gained and alive(p) then table.insert(ret, p) end
  end
  return ret
end

--- 至少存在一组“得到过牌的角色 + 另一名角色”。
---@param player ServerPlayer
---@return boolean
local function hasLegalPair(player)
  for _, gained in ipairs(gainedTargets(player)) do
    if #duelTargets(player.room, gained) > 0 then return true end
  end
  return false
end

skill:addEffect(fk.EventPhaseEnd, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and data.phase == Player.Play and not player.dead
      and hasLegalPair(player)
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_han006_2-invoke",
    }) then
      return false
    end

    local gainedList = gainedTargets(player)
    if #gainedList == 0 then return false end
    local chosen = room:askToChoosePlayers(player, {
      min_num = 1,
      max_num = 1,
      targets = gainedList,
      skill_name = skill.name,
      prompt = "#hanjin__skill_han006_2-gained",
      cancelable = false,
    })
    local gained = chosen and chosen[1]
    if not alive(gained) then return false end

    local others = duelTargets(room, gained)
    if #others == 0 then return false end
    local second = room:askToChoosePlayers(player, {
      min_num = 1,
      max_num = 1,
      targets = others,
      skill_name = skill.name,
      prompt = "#hanjin__skill_han006_2-target",
      cancelable = false,
    })
    local to = second and second[1]
    if not alive(to) or player.dead then return false end

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
    C.useVirtualCard(room, gained, "hanjin__duel", nil, { to }, skill.name, true, nil,
      C.explicit({ other_roles = true }, { names = { "hanjin__duel" } }))
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_han006_2"] = "定著",
  [":hanjin__skill_han006_2"] = "副将技（☯️-1），出牌阶段结束时，你可以选择一名本回合得到过牌的其他角色，其视为对由你指定的另一名角色使用一张【决斗】。",
  ["#hanjin__skill_han006_2-invoke"] = "定著：你可以令一名本回合得到过牌的角色视为使用一张【决斗】",
  ["#hanjin__skill_han006_2-gained"] = "定著：选择一名本回合得到过牌的其他角色",
  ["#hanjin__skill_han006_2-target"] = "定著：选择【决斗】的另一名目标",
}

skill.hanjinImplemented = true

return skill
