-- WEI013 荀彧 · 驱虎
--
-- 规则基线：rules/standard-generals.md WEI013。出牌阶段限一次：与一名体力值大于
-- 你的角色拼点。若你赢，其对其攻击范围内由你选择的另一名角色造成 1 点伤害；
-- 若你没赢（含平局），其视为对你使用一张【杀】。
-- 效果指定的【杀】不计入使用次数，使用公共显式目标策略；伤害来源是拼点对手。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wei013_1",
}

local C = require "packages.hanjin.pkg.hanjin_mode.rules.card_use_targets"

local function eligibleTargets(player)
  return table.filter(player.room.alive_players, function(p)
    return p ~= player and p:isAlive() and not p:isRemoved()
      and p.hp > player.hp and player:canPindian(p)
  end)
end

skill:addEffect("active", {
  prompt = "#hanjin__skill_wei013_1-prompt",
  target_num = 1,
  max_phase_use_time = 1,
  target_filter = function(self, player, to_select, selected)
    return #selected == 0 and to_select ~= player
      and to_select:isAlive() and not to_select:isRemoved()
      and to_select.hp > player.hp and player:canPindian(to_select)
  end,
  can_use = function(self, player)
    return self:withinTimesLimit(player, Player.HistoryPhase)
      and #eligibleTargets(player) > 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos and effect.tos[1]
    if player == nil or target == nil or player.dead or target.dead or target:isRemoved() then return end

    local pindian = player:pindian({ target }, skill.name)
    local result = pindian and pindian.results and pindian.results[target]
    local winner = result and result.winner

    if winner == player then
      -- 由拼点对手对其攻击范围内、由荀彧选择的另一名角色造成伤害。
      local candidates = table.filter(room.alive_players, function(p)
        return p ~= target and p:isAlive() and not p:isRemoved()
          and target:inMyAttackRange(p)
      end)
      if #candidates > 0 then
        local chosen = room:askToChoosePlayers(player, {
          targets = candidates,
          min_num = 1,
          max_num = 1,
          prompt = "#hanjin__skill_wei013_1-damage",
          skill_name = skill.name,
          cancelable = false,
        })
        local victim = chosen and chosen[1]
        if victim ~= nil and target:isAlive() and victim:isAlive() then
          room:damage {
            from = target,
            to = victim,
            damage = 1,
            skillName = skill.name,
          }
        end
      end
    elseif player:isAlive() and target:isAlive() then
      -- 没赢（含平局）：视为对你使用一张【杀】，不计次数。
      C.useVirtualCard(room, target, "hanjin__slash", nil, { player }, skill.name, true, nil,
        C.explicit({ other_roles = true }, { names = { "hanjin__slash" } }))
    end
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_wei013_1"] = "驱虎",
  [":hanjin__skill_wei013_1"] = "出牌阶段限一次，你可以与一名体力值大于你的角色拼点，若你赢，其对其攻击范围内由你选择的另一名角色造成1点伤害；若你没赢，其视为对你使用一张【杀】。",
  ["#hanjin__skill_wei013_1-prompt"] = "驱虎：与一名体力值大于你的角色拼点",
  ["#hanjin__skill_wei013_1-damage"] = "驱虎：选择其攻击范围内的一名角色受到伤害",
}

skill.hanjinImplemented = true
return skill
