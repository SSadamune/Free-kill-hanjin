-- WEI006 郭嘉 · 轻辎
--
-- 规则基线：rules/standard-generals.md 魏区 WEI006。
-- 准备阶段，弃置一名同势力其他角色装备区的一张牌，令其获得“神速”直到其
-- 回合结束。同势力判断复用 hegemony 公共的明置后势力预测，客户端与服务端
-- 使用同一份公开信息。
--
-- 持续时间跨越施加者的回合末：授予状态使用不带 -turn 后缀的独立标记，
-- 只在目标自己的 TurnEnd 由房间级延迟技能回收；不能在郭嘉回合末被自动清除。
-- 授予/移除都带来源（轻辎技能名），是衍生技能来源级增删：目标原有的暗将
-- 神速或之后从其他来源获得的同名技能不会被移除。
local W = require "packages.hanjin.pkg.hanjin_generals.util.wei_phases"

local skill = fk.CreateSkill {
  name = "hanjin__skill_wei006_1",
}

local GRANT_MARK = "hanjin__skill_wei006_1_granted"
local DELAY_SKILL = "#hanjin_wei006_god_speed_delay"

local god_speed_delay

--- 房间级延迟监听：目标回合结束时移除本次以轻辎为来源授予的“神速”。
---@param room Room
local function ensureDelay(room)
  if god_speed_delay == nil then
    god_speed_delay = Fk.skills[DELAY_SKILL]
  end
  if god_speed_delay == nil then
    local skel = fk.CreateSkill { name = DELAY_SKILL }
    skel:addEffect(fk.TurnEnd, {
      global = true,
      is_delay_effect = true,
      can_refresh = function(self, event, target, player, data)
        return target ~= nil and target:getMark(GRANT_MARK) > 0
      end,
      on_refresh = function(self, event, target, player, data)
        local target_room = target.room
        target_room:setPlayerMark(target, GRANT_MARK, 0)
        if not target.dead then
          -- 来源级移除：只删除轻辎这一来源，保留其他来源的同名技能。
          target_room:handleAddLoseSkills(target, "-" .. W.GOD_SPEED, skill.name, false, true)
        end
      end,
    })
    god_speed_delay = skel:createSkill()
    Fk.skills[DELAY_SKILL] = god_speed_delay
  end
  if not room:hasSkill(DELAY_SKILL) then
    room:addSkill(god_speed_delay)
  end
end

--- 可选择的同势力其他角色：装备区至少有一张牌。
---@param room Room
---@param player ServerPlayer
---@return ServerPlayer[]
local function candidates(room, player)
  return table.filter(W.sameKingdomOthers(room, player), function(p)
    return p:isAlive() and not p:isRemoved() and #p:getCardIds("e") > 0
  end)
end

skill:addEffect(fk.EventPhaseStart, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and not player.dead
      and player.phase == Player.Start and #candidates(player.room, player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei006_1-invoke",
    }) then
      return false
    end
    local targets = candidates(room, player)
    if #targets == 0 then return false end
    local chosen = room:askToChoosePlayers(player, {
      min_num = 1,
      max_num = 1,
      targets = targets,
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei006_1-target",
      cancelable = false,
    })
    local to = chosen and chosen[1]
    if to == nil or to.dead or to:isRemoved() then return false end
    local cardId = room:askToChooseCard(player, {
      target = to,
      flag = "e",
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei006_1-card",
    })
    if cardId == nil or not table.contains(to:getCardIds("e"), cardId) then return false end
    event:setCostData(self, { to = to, card = cardId })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self) or {}
    local to, cardId = cost.to, cost.card
    if to == nil or to.dead or to:isRemoved() then return end
    if cardId == nil or not table.contains(to:getCardIds("e"), cardId) then return end

    -- 弃置目标装备区的一张牌（由技能拥有者选择）。
    room:throwCard({ cardId }, skill.name, to, player)

    -- 授予“神速”，来源记为轻辎；目标原有或后获的其他来源不受影响。
    room:handleAddLoseSkills(to, W.GOD_SPEED, skill.name, false, true)
    room:addPlayerMark(to, GRANT_MARK, 1)
    ensureDelay(room)
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_wei006_1"] = "轻辎",
  [":hanjin__skill_wei006_1"] = "准备阶段，你可以弃置一名与你势力相同的其他角色装备区的一张牌，令其获得“神速”直到其回合结束。",
  ["#hanjin__skill_wei006_1-invoke"] = "轻辎：你可以弃置一名同势力其他角色装备区的一张牌，令其获得“神速”直到其回合结束",
  ["#hanjin__skill_wei006_1-target"] = "轻辎：选择一名同势力其他角色",
  ["#hanjin__skill_wei006_1-card"] = "轻辎：选择其装备区的一张牌",
}

skill.hanjinImplemented = true

return skill
