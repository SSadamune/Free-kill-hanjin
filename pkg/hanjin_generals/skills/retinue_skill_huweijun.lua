-- WEI 翼从 · 虎卫军
--
-- 规则基线：rules/standard-generals.md 翼从虎卫军。
-- 每个回合结束时（不限于自己的回合），若虎卫军持有者在该回合共计造成和
-- 受到过的伤害点数大于1，可以移动场上一张牌。使用 getActualDamageEvents
-- 读取实际伤害（排除被防止的伤害）；一次自己对自己的伤害同时计为造成与
-- 受到两份。移牌复用 B 组公共接口。
local W = require "packages.hanjin.pkg.hanjin_generals.util.wei_phases"

local skill = fk.CreateSkill {
  name = "hanjin__retinue_skill_huweijun",
}
skill.hanjinImplemented = true

--- 本回合与 player 相关的实际伤害点数之和。
---@param room Room
---@param player ServerPlayer
---@return integer
local function damageTotal(room, player)
  local total = 0
  local events = room.logic:getActualDamageEvents(math.huge, function(event)
    local data = event.data
    return data ~= nil and (data.from == player or data.to == player)
  end, Player.HistoryTurn)
  for _, event in ipairs(events) do
    local data = event.data
    local num = data.damage or 0
    -- 自己对自己造成的伤害同时计“造成”和“受到”两份。
    if data.from == player then total = total + num end
    if data.to == player then total = total + num end
  end
  return total
end

skill:addEffect(fk.TurnEnd, {
  global = true,
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return target ~= nil and player ~= nil and player:hasSkill(skill.name)
      and not player.dead and damageTotal(player.room, player) > 1
      and W.hasMovableBoardCard(player.room)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__retinue_skill_huweijun-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    W.moveCardInBoard(player.room, player, skill.name)
  end,
})

Fk:loadTranslationTable {
  ["hanjin__retinue_skill_huweijun"] = "虎卫军",
  [":hanjin__retinue_skill_huweijun"] = "每回合结束时，若你本回合共计造成和受到过的伤害数大于1，你可以移动场上一张牌。",
  ["#hanjin__retinue_skill_huweijun-invoke"] = "虎卫军：你可以移动场上一张牌",
}

return skill
