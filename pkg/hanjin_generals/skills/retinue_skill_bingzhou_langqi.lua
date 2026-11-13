-- WEI/QUN 翼从 · 并州狼骑
--
-- 规则基线：rules/standard-generals.md 翼从并州狼骑。
-- 出牌阶段限一次：令一名其他角色视为对你使用一张【决斗】；本回合你与其
-- 距离视为1。次数用发动历史在 can_use 中强制检查（主动技子技能不继承骨架
-- 的次数限制）。距离关系使用表标记记录所有对手，支持多来源/多持有者，
-- 状态技为随包加载的独立骨架，客户端同样注册；关系不因失去翼从技能消失。
local C = require "packages.hanjin.pkg.hanjin_mode.rules.card_use_targets"

local skill = fk.CreateSkill {
  name = "hanjin__retinue_skill_bingzhou_langqi",
}
skill.hanjinImplemented = true

local DUEL = "hanjin__duel"
local PAIR_MARK = "@[hanjin_bingzhou_pairs]"
local DISTANCE_SKILL = "hanjin__retinue_skill_bingzhou_distance"
local CLEANUP_SKILL = "#hanjin_bingzhou_cleanup"

local cleanup_skill

--- 回合末清理距离关系与状态技；房间级延迟监听，不依赖翼从来源是否仍在。
---@param room Room
local function ensureCleanup(room)
  if cleanup_skill == nil then cleanup_skill = Fk.skills[CLEANUP_SKILL] end
  if cleanup_skill == nil then
    local skel = fk.CreateSkill { name = CLEANUP_SKILL }
    skel:addEffect(fk.TurnEnd, {
      global = true,
      is_delay_effect = true,
      can_refresh = function(self, event, target, player, data)
        return target ~= nil and target.room ~= nil
      end,
      on_refresh = function(self, event, target, player, data)
        local room = target.room
        for _, p in ipairs(room.players) do
          if p:hasSkill(DISTANCE_SKILL) then
            room:setPlayerMark(p, PAIR_MARK, 0)
            room:handleAddLoseSkills(p, "-" .. DISTANCE_SKILL, DISTANCE_SKILL, false, true)
          end
        end
      end,
    })
    cleanup_skill = skel:createSkill()
    Fk.skills[CLEANUP_SKILL] = cleanup_skill
  end
  if not room:hasSkill(CLEANUP_SKILL) then room:addSkill(cleanup_skill) end
end

---@param player ServerPlayer
---@param other ServerPlayer
local function addPair(player, other)
  local room = player.room
  local mine = player:getMark(PAIR_MARK)
  mine = type(mine) == "table" and table.simpleClone(mine) or {}
  local theirs = other:getMark(PAIR_MARK)
  theirs = type(theirs) == "table" and table.simpleClone(theirs) or {}
  table.insertIfNeed(mine, other.id)
  table.insertIfNeed(theirs, player.id)
  room:setPlayerMark(player, PAIR_MARK, mine)
  room:setPlayerMark(other, PAIR_MARK, theirs)
end

--- 其他存活角色。
---@param player ServerPlayer
---@return ServerPlayer[]
local function others(player)
  return table.filter(player.room.alive_players, function(p)
    return p ~= player and not p:isRemoved()
  end)
end

skill:addEffect("active", {
  anim_type = "offensive",
  target_num = 1,
  prompt = "#hanjin__retinue_skill_bingzhou_langqi-prompt",
  target_filter = function(self, player, to_select, selected)
    if #selected > 0 then return false end
    return to_select ~= player and to_select:isAlive() and not to_select:isRemoved()
  end,
  can_use = function(self, player)
    return player.phase == Player.Play
      and player:usedSkillTimes(skill.name, Player.HistoryPhase) == 0
      and #others(player) > 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local to = effect.tos and effect.tos[1]
    if player.dead or to == nil or to.dead or to:isRemoved() or to == player then return end
    if not player:hasSkill(skill.name) then return end

    -- 记录双向关系并确保双方持有随包加载的距离状态技。
    addPair(player, to)
    ensureCleanup(room)
    room:handleAddLoseSkills(player, DISTANCE_SKILL, DISTANCE_SKILL, false, true)
    room:handleAddLoseSkills(to, DISTANCE_SKILL, DISTANCE_SKILL, false, true)

    -- 由目标角色对技能拥有者使用【决斗】；效果明确指定目标。
    local policy = C.explicit({ other_roles = true }, { names = { DUEL } })
    C.useVirtualCard(room, to, DUEL, nil, { player }, skill.name, true, nil, policy)
  end,
})

Fk:loadTranslationTable {
  ["hanjin__retinue_skill_bingzhou_langqi"] = "并州狼骑",
  [":hanjin__retinue_skill_bingzhou_langqi"] = "出牌阶段限一次，你可以令一名其他角色视为对你使用一张【决斗】，本回合你与其距离视为1。",
  ["#hanjin__retinue_skill_bingzhou_langqi-prompt"] = "并州狼骑：选择一名其他角色，其视为对你使用【决斗】",
}

return skill
