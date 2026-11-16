-- JIN013 王濬 · 克清
--
-- 规则基线：rules/generals/jin013-wangjun.md。
-- 出牌阶段限一次，选择一名已横置的其他角色。效果持续至王濬再次发动或死亡：
-- 目标每次真实使用或纯打出牌时，若其横置，由其自己弃置一张牌。使用与打出
-- 分别监听；一次实际使用只落在其中一个事件。目标后来重置只暂停触发，之后
-- 再横置继续生效；王濬失去技能不影响已建立效果，只有来源死亡才终止。
--
-- 因此效果监听器是房间级延迟技能，不依赖王濬之后是否仍有克清。目标身上记录
-- 来源 id 的表标记；来源死亡时由同一房间监听器清理。重复发动只替换目标。
local skill = fk.CreateSkill {
  name = "hanjin__skill_jin013_2",
  max_phase_use_time = 1,
}
skill.hanjinImplemented = true

local J = require "packages.hanjin.pkg.hanjin_generals.util.jin_chain"

local SOURCE_MARK = "hanjin_jin013_2_sources"
local TARGET_MARK = "hanjin_jin013_2_targets"
local LISTENER = "#hanjin__skill_jin013_2_effect"

local listener

--- 服务端查询可成为目标的已横置其他角色。
---@param player ServerPlayer
---@return ServerPlayer[]
local function chainedTargets(player)
  local room = player.room or Fk:currentRoom()
  return table.filter(J.alivePlayers(room), function(p)
    return p ~= player and not p.dead and not p:isRemoved() and p.chained
  end)
end

--- 目标是否有可弃置的牌。
---@param target ServerPlayer
---@return boolean
local function hasDiscardable(target)
  return table.find(target:getCardIds("he"), function(id)
    return not target:prohibitDiscard(id)
  end) ~= nil
end

--- 当前仍存活的效果来源；顺带清理已死亡来源的标记，保证即使 Death 事件被
--- 游戏结束流程截断，后续也不会再按已死来源触发。
---@param target ServerPlayer
---@return integer[]
local function aliveSourceIds(target)
  local sources = target:getTableMark(SOURCE_MARK)
  if type(sources) ~= "table" then return {} end
  local alive, changed = {}, false
  for _, id in ipairs(sources) do
    local source = target.room and target.room:getPlayerById(id)
    if source ~= nil and source:isAlive() then
      table.insert(alive, id)
    else
      changed = true
    end
  end
  if changed then
    target.room:setPlayerMark(target, SOURCE_MARK, #alive > 0 and alive or 0)
  end
  return alive
end

--- 当前是否仍有存活的效果来源。
---@param target ServerPlayer
---@return boolean
local function hasAliveSource(target)
  return #aliveSourceIds(target) > 0
end

--- 目标横置且仍有存活来源时，由其自己为每个仍存活的来源各弃置一张牌。
---@param target ServerPlayer
local function discardOnUse(target)
  if target.dead or target:isRemoved() or not target.chained then return end
  local sources = aliveSourceIds(target)
  if #sources == 0 then return end
  local room = target.room
  for _, id in ipairs(sources) do
    if not hasDiscardable(target) then return end
    local cards = room:askToDiscard(target, {
      min_num = 1,
      max_num = 1,
      include_equip = true,
      skill_name = skill.name,
      prompt = "#hanjin__skill_jin013_2-discard",
      cancelable = false,
    })
    -- askToDiscard 默认已经实际执行弃牌；不能再 throwCard 二次移牌。
    if cards == nil or #cards == 0 then return end
  end
end

--- 安装/复用房间级效果监听器；保留到整局结束。
---@param room Room
local function ensureListener(room)
  if room == nil then return end
  if listener == nil then listener = Fk.skills[LISTENER] end
  if listener == nil then
    local skel = fk.CreateSkill { name = LISTENER }
    local function effectSpec(event)
      return {
        global = true,
        is_delay_effect = true,
        can_trigger = function(self, event, target, player, data)
          return target == player and target ~= nil
            and not target.dead and target.chained
            and hasDiscardable(target)
            and hasAliveSource(target)
        end,
        on_cost = Util.TrueFunc,
        on_use = function(self, event, target, player, data)
          discardOnUse(target)
        end,
      }
    end
    skel:addEffect(fk.CardUsing, effectSpec(fk.CardUsing))
    skel:addEffect(fk.CardResponding, effectSpec(fk.CardResponding))
    -- 来源死亡后终止已建立效果；失技不清理，效果由房间监听器继续维持。
    skel:addEffect(fk.Death, {
      global = true,
      is_delay_effect = true,
      can_refresh = function(self, event, target, player, data)
        -- 房间级监听器的 player 迭代不保证覆盖死亡目标；只要 Death 事件有目标
        -- 就清理一次。重复清理是幂等的，且不进入触发选择。
        return target ~= nil and target.dead
      end,
      on_refresh = function(self, event, target, player, data)
        local room = target.room
        if room == nil then return end
        for _, p in ipairs(room.players) do
          room:removeTableMark(p, SOURCE_MARK, target.id)
        end
        room:setPlayerMark(target, TARGET_MARK, 0)
      end,
    })
    listener = skel:createSkill()
    Fk.skills[LISTENER] = listener
  end
  if not room:hasSkill(LISTENER) then room:addSkill(listener) end
end

skill:addEffect("active", {
  anim_type = "control",
  prompt = "#hanjin__skill_jin013_2-prompt",
  max_phase_use_time = 1,
  card_num = 0,
  target_num = 1,
  card_filter = Util.FalseFunc,
  target_filter = function(self, player, to_select, selected)
    return #selected == 0 and to_select ~= player and not to_select.dead
      and not to_select:isRemoved() and to_select.chained
  end,
  can_use = function(self, player)
    return self:withinTimesLimit(player, Player.HistoryPhase) and #chainedTargets(player) > 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos and effect.tos[1]
    if player == nil or player.dead or target == nil then return end
    if target == player or target.dead or target:isRemoved() or not target.chained then return end
    if not player:hasSkill(skill.name) then return end

    ensureListener(room)
    -- 再次发动即替换旧目标；旧关系移除后不再触发。
    local old = player:getTableMark(TARGET_MARK)
    if type(old) == "table" then
      for _, id in ipairs(old) do
        local previous = room:getPlayerById(id)
        if previous ~= nil then
          room:removeTableMark(previous, SOURCE_MARK, player.id)
        end
      end
    end
    room:setPlayerMark(player, TARGET_MARK, { target.id })
    room:addTableMarkIfNeed(target, SOURCE_MARK, player.id)
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_jin013_2"] = "克清",
  [":hanjin__skill_jin013_2"] = "出牌阶段限一次，你可以选择一名已横置的其他角色，直到你再次发动该技能或死亡：当其使用或打出牌时，若其横置，其弃置一张牌。",
  ["#hanjin__skill_jin013_2-prompt"] = "克清：选择一名已横置的其他角色",
  ["#hanjin__skill_jin013_2-discard"] = "克清：你须弃置一张牌",
}

return skill
