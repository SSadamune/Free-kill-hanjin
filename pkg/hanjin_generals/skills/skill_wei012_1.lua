-- WEI012 典韦 · 强袭
--
-- 规则基线：rules/standard-generals.md WEI012。出牌阶段每名角色限一次：选择一名
-- 攻击范围内的角色，弃置一张武器牌或失去 1 点体力，然后对其造成 1 点伤害。
-- 目标范围在支付费用前确定：目标先按当前攻击范围选出，之后弃武器也不改变已选
-- 目标。每目标限一次按“本出牌阶段”记录，阶段结束自动清除。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wei012_1",
}

local USED = "hanjin__skill_wei012_1-targets-phase"
local OPT_DISCARD = "#hanjin__skill_wei012_1-discard"
local OPT_HP = "#hanjin__skill_wei012_1-hp"

local function weaponIds(player)
  return table.filter(player:getCardIds("he"), function(id)
    local card = Fk:getCardById(id)
    return card ~= nil and card.sub_type == Card.SubtypeWeapon
      and not player:prohibitDiscard(id)
  end)
end

local function eligible(player)
  local used = player:getTableMark(USED)
  return table.find(player.room.alive_players, function(p)
    return p ~= player and p:isAlive() and not p:isRemoved()
      and player:inMyAttackRange(p) and not table.contains(used, p.id)
  end) ~= nil
end

skill:addEffect("active", {
  prompt = "#hanjin__skill_wei012_1-prompt",
  target_num = 1,
  target_filter = function(self, player, to_select, selected)
    return #selected == 0 and to_select ~= player
      and to_select:isAlive() and not to_select:isRemoved()
      and player:inMyAttackRange(to_select)
      and not table.contains(player:getTableMark(USED), to_select.id)
  end,
  can_use = function(self, player)
    -- 费用为弃一张武器牌或失去 1 点体力；两者都不能支付时禁用。
    -- 失去体力不得超过当前体力（hp >= 1 才能支付 1 点）。
    return self:withinTimesLimit(player, Player.HistoryPhase)
      and eligible(player)
      and (player.hp >= 1 or #weaponIds(player) > 0)
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos and effect.tos[1]
    if player == nil or target == nil or player.dead or target.dead or target:isRemoved() then return end

    local weapons = weaponIds(player)
    local choice = OPT_HP
    if #weapons > 0 then
      choice = room:askToChoice(player, {
        choices = { OPT_DISCARD, OPT_HP },
        skill_name = skill.name,
        prompt = "#hanjin__skill_wei012_1-cost",
        cancelable = false,
      })
    end

    if choice == OPT_DISCARD then
      local cards = room:askToDiscard(player, {
        min_num = 1,
        max_num = 1,
        include_equip = true,
        skill_name = skill.name,
        pattern = tostring(Exppattern { id = weapons }),
        prompt = "#hanjin__skill_wei012_1-weapon",
        cancelable = false,
      })
      if cards == nil or #cards == 0 then return end
      room:throwCard(cards, skill.name, player, player)
      if player.dead then return end
    else
      room:loseHp(player, 1, skill.name)
      if player.dead then return end
    end

    room:addTableMarkIfNeed(player, USED, target.id)
    if target:isAlive() and not target:isRemoved() then
      room:damage {
        from = player,
        to = target,
        damage = 1,
        skillName = skill.name,
      }
    end
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_wei012_1"] = "强袭",
  [":hanjin__skill_wei012_1"] = "出牌阶段每名角色限一次，你可以选择一名攻击范围内的角色，弃置一张武器牌或失去1点体力，然后对其造成1点伤害。",
  ["#hanjin__skill_wei012_1-prompt"] = "强袭：选择一名攻击范围内的角色",
  ["#hanjin__skill_wei012_1-cost"] = "强袭：弃置一张武器牌或失去1点体力",
  ["#hanjin__skill_wei012_1-weapon"] = "强袭：弃置一张武器牌",
  [OPT_DISCARD] = "弃置武器牌",
  [OPT_HP] = "失去1点体力",
}

skill.hanjinImplemented = true
return skill
