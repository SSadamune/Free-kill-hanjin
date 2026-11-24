-- WU009 孙坚 · 英魂
--
-- 规则基线：docs/rules/standard-generals.md 吴区 WU009。
-- 准备阶段：选择一名其他角色并选择一项：
-- 1. 令其摸 X 张牌，然后弃置一张牌；
-- 2. 令其摸一张牌，然后弃置 X 张牌（X 为孙坚已损失的体力值）。
local Selection = require "packages.qiao.pkg.qiao_mode.rules.trigger_selection"

local skill = fk.CreateSkill {
  name = "qiao__skill_wu009_1",
}
skill.qiaoImplemented = true

local DRAW = "#qiao__skill_wu009_1-draw"
local DISCARD = "#qiao__skill_wu009_1-discard"

--- 客户端没有 player.room；与服务端共用 Fk:currentRoom() 的只读房间。
---@param player ServerPlayer | ClientPlayer
---@return Room | Client
local function currentRoom(player)
  return player.room or Fk:currentRoom()
end

---@param player ServerPlayer | ClientPlayer
---@return ServerPlayer[] | ClientPlayer[]
local function otherTargets(player)
  local room = currentRoom(player)
  return table.filter(room:getPresentPlayers(), function(p)
    return p ~= player and p:isAlive() and not p:isRemoved()
  end)
end

skill:addEffect(fk.EventPhaseStart, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and player.phase == Player.Start
      and #otherTargets(player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local to = player.room:askToChoosePlayers(player, {
      min_num = 1,
      max_num = 1,
      targets = otherTargets(player),
      skill_name = skill.name,
      prompt = "#qiao__skill_wu009_1-choose:::" .. player:getLostHp(),
      cancelable = true,
    })
    if #to == 0 then return false end
    local n = player:getLostHp()
    local draw = DRAW .. ":::" .. n
    local discard = DISCARD .. ":::" .. n
    local choice = Selection.askOption(player.room, player, {
      choices = { draw, discard },
      skill_name = skill.name,
      prompt = "#qiao__skill_wu009_1-choice::" .. to[1].id,
    })
    if choice == nil then return false end
    event:setCostData(self, { tos = to, n = n, draw = choice == draw })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self)
    local to, n = cost.tos[1], cost.n
    if cost.draw then
      if to.dead then return end
      to:drawCards(n, skill.name)
      if to:isAlive() then
        room:askToDiscard(to, {
          min_num = 1,
          max_num = 1,
          include_equip = true,
          skill_name = skill.name,
          prompt = "#qiao__skill_wu009_1-throw:::1",
          cancelable = false,
        })
      end
    else
      if to.dead then return end
      to:drawCards(1, skill.name)
      if n > 0 and to:isAlive() then
        room:askToDiscard(to, {
          min_num = n,
          max_num = n,
          include_equip = true,
          skill_name = skill.name,
          prompt = "#qiao__skill_wu009_1-throw:::" .. n,
          cancelable = false,
        })
      end
    end
  end,
})

Fk:loadTranslationTable {
  ["#qiao__skill_wu009_1-choose"] = "英魂：选择一名其他角色，令其摸%arg张牌后弃置一张，或摸一张牌后弃置%arg张",
  ["#qiao__skill_wu009_1-choice"] = "英魂：选择对 %dest 执行的一项",
  ["#qiao__skill_wu009_1-throw"] = "英魂：弃置%arg张牌",
  [DRAW] = "令其摸%arg张牌，然后弃置一张牌",
  [DISCARD] = "令其摸一张牌，然后弃置%arg张牌",
}

return skill
