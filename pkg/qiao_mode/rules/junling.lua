-- 汉晋军令公共规则适配（rulebook/terms/description-terms/junling.md）。
--
-- 只在汉晋房间（Modes.inRoom）生效，保留上游 H.askToCommand 的事件与询问入口，
-- 使既有测试与军令触发器无缝兼容，同时统一修复锁定国战军令与汉晋规则的差异：
--   * 军令一：伤害目标为任意在场角色，包括执行者本人；
--   * 军令二：先摸 1 牌，再交给发起者 2 张牌（不足全交，不能交给自己），
--     以执行者为 proposer 触发【恩怨】等“交给”时机；
--   * 军令五：按汉晋定向叠置（已叠置不反向平置），并禁止本回合回复体力；
--   * 军令六：弃置除所保留的至多一张手牌和一张装备外的全部可弃牌。
local H = require "packages.hegemony.util"
local Modes = require "packages.qiao.pkg.qiao_mode.modes"
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"

local M = {}
local installed = false
local contexts = setmetatable({}, { __mode = "k" })

function M.pending(room)
  return contexts[room]
end

function M.context(room, data)
  local context = contexts[room]
  if context and context.from == data.from and context.to == (data.tos or {})[1]
    and context.skillName == data.skillName then return context.effect end
end

local function inQiao(room)
  return room ~= nil and type(room.getSettings) == "function" and Modes.inRoom(room)
end

local hanjinCommands = {
  command1 = {
    on_prepare = function(from, data)
      local room = from.room
      local targets = room:getPresentPlayers()
      if #targets == 0 then
        data.command_data = { tos = {} }
        return
      end
      local chosen = room:askToChoosePlayers(from, {
        targets = targets,
        min_num = 1,
        max_num = 1,
        prompt = "#command1-damage:::" .. table.concat(
          table.map(data.tos or {}, Player.__touistring), "、"),
        skill_name = data.skillName,
        cancelable = false,
      })
      local dest = chosen and chosen[1] or targets[1]
      room:sendLog {
        type = "#Command1Damage",
        from = from.id,
        to = { dest.id },
      }
      room:doIndicate(from, { dest })
      data.command_data = { tos = { dest } }
    end,
    on_use = function(to, from, data)
      local room = to.room
      local target = data.command_data and data.command_data.tos and data.command_data.tos[1]
      if target == nil or not RemovedTargets.isPresent(target) then return end
      room:damage {
        from = to,
        to = target,
        damage = 1,
        damageType = fk.NormalDamage,
        skillName = "command",
      }
    end,
  },
  command2 = {
    on_use = function(to, from)
      local room = to.room
      if not to.dead then
        to:drawCards(1, "command")
      end
      if to.dead or from == nil or to == from or not RemovedTargets.isPresent(from) then return end
      local he = to:getCardIds("he")
      if #he == 0 then return end
      local cards
      if #he <= 2 then
        cards = table.simpleClone(he)
      else
        cards = room:askToCards(to, {
          min_num = 2,
          max_num = 2,
          include_equip = true,
          skill_name = "command",
          prompt = "#command2-give::" .. from.id,
          cancelable = false,
        })
        if type(cards) ~= "table" or #cards ~= 2 then
          cards = { he[1], he[2] }
        end
      end
      -- proposer 为交牌方 to，确保【恩怨】等按交给动作触发的技能正确识别。
      room:obtainCard(from, cards, false, fk.ReasonGive, to, "command")
    end,
  },
  command3 = {
    on_use = function(to)
      if not to.dead then
        to.room:loseHp(to, 1, "command")
      end
    end,
  },
  command4 = {
    on_use = function(to)
      local room = to.room
      room:setPlayerMark(to, "@@command4_effect-turn", 1)
      room:addPlayerMark(to, MarkEnum.UncompulsoryInvalidity .. "-turn")
      room:addSkill("#command_skill")
    end,
  },
  command5 = {
    on_use = function(to)
      local room = to.room
      -- 汉晋定向叠置：仅平置角色改为叠置，已叠置角色不再翻回平置。
      if not to.dead and to.faceup then
        to:turnOver()
      end
      room:setPlayerMark(to, "@@command5_effect-turn", 1)
      room:addSkill("#command_skill")
    end,
  },
  command6 = {
    on_use = function(to)
      local room = to.room
      local hands = to:getCardIds("h")
      local equips = to:getCardIds("e")
      if #hands < 2 and #equips < 2 then return end
      local to_remain = {}
      if #hands > 0 then table.insert(to_remain, hands[1]) end
      if #equips > 0 then table.insert(to_remain, equips[1]) end
      room:addSkill("#command_skill")
      local _, ret = room:askToUseActiveSkill(to, {
        skill_name = "#command_skill",
        prompt = "#command6-select",
        extra_data = { skillName = "command" },
        cancelable = false,
      })
      if ret and type(ret.cards) == "table" and #ret.cards > 0 then
        to_remain = ret.cards
      end
      local toDiscard = table.filter(to:getCardIds("he"), function(id)
        return not table.contains(to_remain, id) and not to:prohibitDiscard(Fk:getCardById(id))
      end)
      if #toDiscard > 0 then
        room:throwCard(toDiscard, "command", to, to)
      end
    end,
  },
}

--- 统一发起汉晋军令（允许对任意在场角色，包含发起者本人）。
---@param from ServerPlayer
---@param to ServerPlayer
---@param skillName string
---@param effect? table @ 当前技能结算事实，仅供服务端决策
---@return boolean, table?
function M.ask(from, to, skillName, effect)
  if from == nil or to == nil or from.dead or not RemovedTargets.isPresent(to) then
    return false, nil
  end
  local params = {
    tos = { to },
    skill_name = skillName,
  }
  local room = from.room
  local previous = contexts[room]
  contexts[room] = { from = from, to = to, skillName = skillName, effect = effect }
  local ok, executed, data = pcall(H.askToCommand, from, params)
  contexts[room] = previous
  if not ok then error(executed, 0) end
  return executed == true, data
end

function M.install()
  if installed then return end
  installed = true

  local originalPrepare = H.CommandPrepare
  H.CommandPrepare = function(name, data)
    local room = data and data.from and data.from.room
    local handler = inQiao(room) and hanjinCommands[name]
    if handler then
      if handler.on_prepare then handler.on_prepare(data.from, data) end
      return
    end
    return originalPrepare(name, data)
  end

  local originalCB = H.CommandCB
  H.CommandCB = function(name, target, from, data)
    local room = (target and target.room) or (from and from.room)
    local handler = inQiao(room) and hanjinCommands[name]
    if handler then
      handler.on_use(target, from or (data and data.from), data)
      return
    end
    return originalCB(name, target, from, data)
  end
end

return M
