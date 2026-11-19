-- 神授思召：进入装备区的当回合仍装备时，使用者用牌无距离限制，且跳过弃牌阶段。
-- 后续回合可由正式合纵入口把该实体装备与合法手牌混选；失去装备即撤销状态。
local skill = fk.CreateSkill {
  name = "qiao__shenshou_sizhao_skill",
  attached_equip = "qiao__shenshou_sizhao",
}

local ACTIVE = "qiao_shenshou_active"

local function active(player)
  return player ~= nil and player:hasSkill(skill.name)
    and player:getMark(ACTIVE) > 0
end

local function hasActiveMark(room)
  for _, player in ipairs(room.players) do
    if player:getMark(ACTIVE) > 0 then return true end
  end
  return false
end

local function clearActiveMarks(room)
  for _, player in ipairs(room.players) do
    if player:getMark(ACTIVE) ~= 0 then
      room:setPlayerMark(player, ACTIVE, 0)
    end
  end
end

skill:addEffect("targetmod", {
  bypass_distances = function(self, player, card_skill, card, to)
    return active(player)
  end,
})

skill:addEffect(fk.EventPhaseChanging, {
  can_trigger = function(self, event, target, player, data)
    return target == player and data.phase == Player.Discard
      and not data.skipped and active(player)
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    data.skipped = true
  end,
})

-- 回合结束清理本回合的“置入装备区”状态。用 refresh 而非 on_use：
-- 清理是规则收尾，不是一次可见的技能发动；全局 refresh 在每个回合结束时只对
-- 当前回合角色判定一次，即使装备已离开装备区也能清掉原持有者的残留状态。
skill:addEffect(fk.TurnEnd, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return target == player and hasActiveMark(Fk:currentRoom())
  end,
  on_refresh = function(self, event, target, player, data)
    clearActiveMarks(Fk:currentRoom())
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "神授思召",
  [":" .. skill.name] = "锁定技，此牌进入装备区的回合中，若你仍装备此牌，你使用牌无距离限制，"
    .. "并跳过你的弃牌阶段。后续回合，你可将此牌作为合纵牌与手牌一同交出。",
}
return skill
