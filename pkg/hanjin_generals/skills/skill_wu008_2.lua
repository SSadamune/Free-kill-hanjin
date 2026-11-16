-- WU008 孙尚香 · 枭姬
--
-- 规则基线：rules/standard-generals.md 吴区 WU008。
-- 每失去一张装备区里的牌后可以摸一张；若失去时不在自己的回合内，改为
-- 摸两张。按实际离开装备区的牌逐张触发，与引擎 AfterCardsMove 的 moveInfo
-- 一致；“回合外”按当前回合角色判断。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wu008_2",
}
skill.hanjinImplemented = true

--- 本次移动中从该角色装备区离开的牌数。
---@param player ServerPlayer
---@param data MoveCardsData[]
---@return integer
local function lostEquipCount(player, data)
  local count = 0
  for _, move in ipairs(data or {}) do
    if move.from == player then
      for _, info in ipairs(move.moveInfo or {}) do
        if info.fromArea == Card.PlayerEquip then
          count = count + 1
        end
      end
    end
  end
  return count
end

skill:addEffect(fk.AfterCardsMove, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(skill.name) or player.dead then return false end
    return lostEquipCount(player, data) > 0
  end,
  trigger_times = function(self, event, target, player, data)
    return lostEquipCount(player, data)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_wu008_2-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local n = player.room.current == player and 1 or 2
    player:drawCards(n, skill.name)
  end,
})

Fk:loadTranslationTable {
  ["#hanjin__skill_wu008_2-invoke"] = "枭姬：你可以摸牌（回合外改为摸两张）",
}

return skill
