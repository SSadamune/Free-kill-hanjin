-- WEI/QUN 翼从 · 并州狼骑
--
-- 规则基线：docs/rules/standard-generals.md 翼从并州狼骑。
-- 出牌阶段限一次：令一名其他角色视为对你使用一张【决斗】；本回合你与其
-- 距离视为1。次数用发动历史在 can_use 中强制检查（主动技子技能不继承骨架
-- 的次数限制）。距离关系使用表标记记录所有对手，支持多来源/多持有者，
-- 状态技为随包加载的独立骨架，客户端同样注册；关系不因失去翼从技能消失。
local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"
local R = require "packages.qiao.pkg.qiao_generals.util.retinue_instances"
local Z = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_retinues"

local skill = fk.CreateSkill {
  name = "qiao__retinue_skill_bingzhou_langqi",
}
skill.qiaoImplemented = true

local DUEL = "qiao__duel"
local PAIR_MARK = "@[qiao_bingzhou_pairs]"
local DISTANCE_SKILL = "qiao__retinue_skill_bingzhou_distance"
local CLEANUP_SKILL = "#qiao_bingzhou_cleanup"

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
---@param instanceId integer
local function addPair(player, other, instanceId)
  local room = player.room
  local mine = player:getMark(PAIR_MARK)
  mine = type(mine) == "table" and table.simpleClone(mine) or {}
  local theirs = other:getMark(PAIR_MARK)
  theirs = type(theirs) == "table" and table.simpleClone(theirs) or {}
  local function add(list, otherId)
    for _, entry in ipairs(list) do
      if type(entry) == "table" and entry.instance == instanceId
        and entry.other == otherId then return end
    end
    table.insert(list, { instance = instanceId, other = otherId })
  end
  add(mine, other.id)
  add(theirs, player.id)
  room:setPlayerMark(player, PAIR_MARK, mine)
  room:setPlayerMark(other, PAIR_MARK, theirs)
end

--- 其他存活角色。客户端没有 player.room 时读当前房间的公开角色列表。
---@param player Player
---@return Player[]
local function others(player)
  local room = Fk:currentRoom()
  if room == nil then return {} end
  return table.filter(room:getPresentPlayers(), function(p)
    return p ~= player and not p:isRemoved()
  end)
end

skill:addEffect("active", {
  anim_type = "offensive",
  card_num = 0,
  target_num = 1,
  prompt = "#qiao__retinue_skill_bingzhou_langqi-prompt",
  target_filter = function(self, player, to_select, selected)
    if #selected > 0 then return false end
    return to_select ~= player and to_select:isAlive() and not to_select:isRemoved()
  end,
  can_use = function(self, player)
    if player.phase ~= Player.Play or #others(player) == 0 then return false end
    if R.countForSkill(player, skill.name) == 0 then
      return player:getMark("qiao_bingzhou_direct-phase") == 0
    end
    return Z.canUse(player, skill.name, 1)
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local to = effect.tos and effect.tos[1]
    if player.dead or to == nil or to.dead or to:isRemoved() or to == player then return end
    if not player:hasSkill(skill.name) then return end

    local instances = R.instancesForSkill(player, skill.name)
    local instance = nil
    if #instances > 0 then
      instance = Z.availableInstances(player, skill.name, 1)[1]
      -- 有实例但本阶段全部用尽：不得落入 direct fallback 再多发动一次。
      if instance == nil then return end
      Z.spend(player, instance, skill.name)
      addPair(player, to, instance.id)
    else
      if player:getMark("qiao_bingzhou_direct-phase") ~= 0 then return end
      room:addPlayerMark(player, "qiao_bingzhou_direct-phase", 1)
      addPair(player, to, 0)
    end
    ensureCleanup(room)
    room:handleAddLoseSkills(player, DISTANCE_SKILL, DISTANCE_SKILL, false, true)
    room:handleAddLoseSkills(to, DISTANCE_SKILL, DISTANCE_SKILL, false, true)

    local policy = C.explicit({ other_roles = true }, { names = { DUEL } })
    C.useVirtualCard(room, to, DUEL, nil, { player }, skill.name, true, nil, policy)
  end,
})

Fk:loadTranslationTable {
  ["qiao__retinue_skill_bingzhou_langqi"] = "并州狼骑",
  [":qiao__retinue_skill_bingzhou_langqi"] = "出牌阶段限一次，你可以令一名其他角色视为对你使用一张【决斗】，本回合你与其距离视为1。",
  ["#qiao__retinue_skill_bingzhou_langqi-prompt"] = "并州狼骑：选择一名其他角色，其视为对你使用【决斗】",
}

return skill
