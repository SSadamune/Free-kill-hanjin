-- WEI017 李典 · 忘隙
--
-- 一次伤害事件只触发一次，不按伤害点数拆分：李典对他人造成伤害后，或受到
-- 他人伤害后，两方都能摸牌时才可发动。
local skill = fk.CreateSkill {
  name = "qiao__skill_wei017_2",
}
skill.qiaoImplemented = true

--- 本次伤害事件中与李典相对的另一名角色；自伤或无来源伤害不触发。
---@param player ServerPlayer
---@param data DamageData
---@return ServerPlayer|nil
local function otherPlayer(player, data)
  if data == nil then return nil end
  if data.from == player and data.to ~= player then return data.to end
  if data.to == player and data.from ~= player then return data.from end
  return nil
end

local function canDraw(player)
  return player ~= nil and player:isAlive() and not player:isRemoved()
end

local function drawTogether(room, first, second)
  local draws, total = {}, 0
  for _, player in ipairs({ first, second }) do
    local draw = DrawData:new{ who = player, num = 1, fromPlace = "top", skillName = skill.name }
    room.logic:trigger(fk.BeforeDrawCard, player, draw)
    if draw.num < 1 then return end
    table.insert(draws, draw)
    total = total + draw.num
  end
  if not canDraw(draws[1].who) or not canDraw(draws[2].who) then return end
  if #room:getNCards(total) < total then return end

  local left, right = 1, #room.draw_pile
  local moves = {}
  for _, draw in ipairs(draws) do
    local ids
    if draw.fromPlace == "bottom" then
      ids = table.slice(room.draw_pile, right - draw.num + 1, right + 1)
      right = right - draw.num
    else
      ids = table.slice(room.draw_pile, left, left + draw.num)
      left = left + draw.num
    end
    table.insert(moves, {
      ids = ids,
      to = draw.who,
      toArea = Card.PlayerHand,
      moveReason = fk.ReasonDraw,
      proposer = draw.who,
      skillName = skill.name,
    })
  end
  room:moveCards(table.unpack(moves))
end

local spec = {
  anim_type = "drawcard",
  -- 默认 trigger_times 为 1；不按 data.damage 增加次数。
  can_trigger = function(self, event, target, player, data)
    return target == player and canDraw(player) and player:hasSkill(skill.name)
      and data ~= nil and (data.damage or 0) > 0
      and canDraw(otherPlayer(player, data))
  end,
  on_cost = function(self, event, target, player, data)
    local other = otherPlayer(player, data)
    if not canDraw(player) or not canDraw(other) then return false end
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_wei017_2-invoke::" .. other.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    local other = otherPlayer(player, data)
    if not canDraw(player) or not canDraw(other) then return end
    drawTogether(player.room, player, other)
  end,
}

skill:addEffect(fk.Damage, spec)
skill:addEffect(fk.Damaged, spec)

Fk:loadTranslationTable {
  ["qiao__skill_wei017_2"] = "忘隙",
  [":qiao__skill_wei017_2"] = "当你对其他角色造成伤害后，或受到其他角色的伤害后，你可以摸一张牌并令其摸一张牌。",
  ["#qiao__skill_wei017_2-invoke"] = "忘隙：你可以摸一张牌，并令 %dest 摸一张牌",
}

return skill
