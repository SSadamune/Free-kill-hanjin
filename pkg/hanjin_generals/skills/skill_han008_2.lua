-- HAN008 伏皇后 · 求援
--
-- 当你成为其他角色使用【杀】的目标时，可以令另一名其他角色也成为目标；
-- 新增目标只优先结算其牌效果，目标时机仍按正常使用事件生成。此【杀】被
-- 抵消后对其余目标无效（复用方天画戟登记 nullifiedTargets 的方式）。
--
-- 额外目标条件使用公共 ExtraTargets 的显式条件“另一名其他角色”，因此不
-- 再用普通攻击距离阻挡；已禁止、已在目标列表中的角色仍排除。
-- 新增目标 id 只记录在本次 UseCardData 上；效果结算顺序在
-- BeforeCardUseEffect 调整，不在 onAim 中排序，不提前目标事件。
local skill = fk.CreateSkill {
  name = "hanjin__skill_han008_2",
}

local E = require "packages.hanjin.pkg.hanjin_mode.rules.extra_targets"

local PRIORITY = "hanjin_skill_han008_2_priority"
local USERS = "hanjin_skill_han008_2_users"
local DELAY_NAME = "#hanjin_skill_han008_2_delay"

local delay_skill

local function ensureDelay(room)
  if room == nil then return end
  if delay_skill == nil then delay_skill = Fk.skills[DELAY_NAME] end
  if delay_skill == nil then
    local skel = fk.CreateSkill { name = DELAY_NAME }

    -- 目标事件全部结束后，只移动实际效果循环的先后；use.tos 的排列不参与
    -- 目标时机生成。
    skel:addEffect(fk.BeforeCardUseEffect, {
      global = true,
      is_delay_effect = true,
      can_refresh = function(self, event, target, player, data)
        local priority = data and data[PRIORITY]
        return type(priority) == "table" and #priority > 0
          and not data.__hanjin_han008_2_reordered
      end,
      on_refresh = function(self, event, target, player, data)
        local priority = data[PRIORITY]
        data.__hanjin_han008_2_reordered = true
        local room = data.from.room
        local ordered, seen = {}, {}
        for _, id in ipairs(priority) do
          local p = room:getPlayerById(id)
          if p ~= nil and table.contains(data.tos, p) and not seen[p] then
            seen[p] = true
            table.insert(ordered, p)
          end
        end
        for _, p in ipairs(data.tos) do
          if not seen[p] then
            seen[p] = true
            table.insert(ordered, p)
          end
        end
        local subTos = {}
        for i, p in ipairs(ordered) do
          local oldIndex = table.indexOf(data.tos, p)
          subTos[i] = data.subTos and oldIndex and data.subTos[oldIndex] or {}
        end
        data.tos = ordered
        data.subTos = subTos
      end,
    })

    -- 任意目标被抵消后，其余目标不再响应/生效；与方天画戟相同的 use 级登记。
    skel:addEffect(fk.CardEffectCancelledOut, {
      global = true,
      is_delay_effect = true,
      can_refresh = function(self, event, target, player, data)
        local use = data and data.use
        local priority = use and use[PRIORITY]
        return type(priority) == "table" and #priority > 0
          and data.card ~= nil and data.card.trueName == "slash"
          and not data.__hanjin_han008_2_cancelled
      end,
      on_refresh = function(self, event, target, player, data)
        data.__hanjin_han008_2_cancelled = true
        local targets = data.tos or data.use.tos
        if targets and #targets > 0 then
          data:setNullified(targets)
        end
      end,
    })

    delay_skill = skel:createSkill()
    Fk.skills[DELAY_NAME] = delay_skill
  end
  if not room:hasSkill(DELAY_NAME) then
    room:addSkill(delay_skill)
  end
end

skill:addEffect(fk.TargetConfirming, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    if target ~= player or not player:hasSkill(skill.name) then return false end
    if data.card == nil or data.card.trueName ~= "slash" then return false end
    local use = data.use
    if use == nil or use.from == player then return false end
    local users = use[USERS]
    if type(users) == "table" and users[player.id] then return false end
    return #E.candidates(player.room, use, {
      target_condition = { other_roles = true },
    }) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_han008_2-invoke",
    }) then
      return false
    end

    local use = data.use
    local candidates = E.candidates(room, use, {
      target_condition = { other_roles = true },
    })
    if #candidates == 0 then return false end
    local chosen = room:askToChoosePlayers(player, {
      min_num = 1,
      max_num = 1,
      targets = candidates,
      skill_name = skill.name,
      prompt = "#hanjin__skill_han008_2-target",
      cancelable = false,
    })
    local to = chosen and chosen[1]
    if to == nil or to.dead or to:isRemoved() then return false end
    if not E.isCandidate(room, use, to, {
      target_condition = { other_roles = true },
    }) then return false end

    -- 发动消耗只做“选另一名其他角色”；加入目标、优先记录和本次使用记录
    -- 留到正常 on_use，保证先明置/进入技能生效再改使用数据。
    event:setCostData(self, { to = to })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self) or {}
    local to = cost.to
    local use = data.use
    if use == nil or to == nil or to.dead or to:isRemoved() then return end
    if not E.isCandidate(room, use, to, {
      target_condition = { other_roles = true },
    }) then return end

    ensureDelay(room)
    -- 在目标确认阶段加入 AimData/使用数据，后续仍会生成新增目标的
    -- TargetSpecified/TargetConfirmed 等事件。
    data:addTarget(to)
    -- extra_data 会在目标事件结束时被 AimData 的旧值覆盖，故把优先目标
    -- 与本次发动记录挂在 UseCardData 自身字段上。
    local priority = use[PRIORITY] or {}
    table.insert(priority, to.id)
    use[PRIORITY] = priority
    local users = use[USERS] or {}
    users[player.id] = true
    use[USERS] = users
  end,
})

skill:addAcquireEffect(function(self, player)
  ensureDelay(player.room)
end)

Fk:loadTranslationTable {
  ["hanjin__skill_han008_2"] = "求援",
  [":hanjin__skill_han008_2"] = "当你成为其他角色使用【杀】的目标时，你可以令另一名其他角色也成为目标且优先结算，此【杀】被抵消后对其余目标无效。",
  ["#hanjin__skill_han008_2-invoke"] = "求援：你可以令另一名其他角色也成为此【杀】的目标",
  ["#hanjin__skill_han008_2-target"] = "求援：选择另一名其他角色",
}

skill.hanjinImplemented = true

return skill
