-- Independent HanJin Thunder Slash. It uses the engine's ordinary Slash
-- timing/distance rules, but may exceed the per-phase limit when its explicit
-- 孤军 → ignore_times adaptation entry is satisfied. The actual "does not
-- count" flag is fixed later in fk.PreCardUse, before UseCard records history.
local A = require "packages.hanjin.pkg.hanjin_mode.rules.adaptation"
local skill = fk.CreateSkill { name = "hanjin__thunder_slash_skill" }

local function ignoreTimes(player, card, extra_data)
  if extra_data and extra_data.bypass_times then return true end
  return A.ignoreTimesCandidate(player.room or Fk:currentRoom(), player, card)
end

skill:addEffect("cardskill", {
  prompt = function(self, player, selected_cards)
    local card = Fk:cloneCard("hanjin__thunder__slash")
    card:addSubcards(selected_cards)
    local max_num = self:getMaxTargetNum(player, card)
    if max_num > 1 then
      local num = #table.filter(Fk:currentRoom().alive_players, function(p)
        return p ~= player and not player:isProhibited(p, card)
      end)
      max_num = math.min(num, max_num)
    end
    return max_num > 1 and "#hanjin__thunder_slash_skill_multi:::" .. max_num
      or "#hanjin__thunder_slash_skill"
  end,
  max_phase_use_time = 1,
  target_num = 1,
  can_use = function(self, player, card, extra_data)
    if player:prohibitUse(card) then return false end
    return (extra_data and extra_data.bypass_times) or player.phase ~= Player.Play
      or self:withinTimesLimit(player, Player.HistoryPhase, card, "slash")
      or ignoreTimes(player, card, extra_data)
  end,
  mod_target_filter = function(self, player, to_select, selected, card, extra_data)
    return to_select ~= player and
      not (not (extra_data and extra_data.bypass_distances)
        and not self:withinDistanceLimit(player, true, card, to_select))
  end,
  target_filter = function(self, player, to_select, selected, _, card, extra_data)
    if not Util.CardTargetFilter(self, player, to_select, selected, _, card, extra_data) then return false end
    return self:modTargetFilter(player, to_select, selected, card, extra_data) and
      (
        #selected > 0 or
        player.phase ~= Player.Play or
        (extra_data and extra_data.bypass_times) or
        self:withinTimesLimit(player, Player.HistoryPhase, card, "slash", to_select) or
        ignoreTimes(player, card, extra_data)
      )
  end,
  on_effect = function(self, room, effect)
    if not effect.to.dead then
      room:damage({
        from = effect.from,
        to = effect.to,
        card = effect.card,
        damage = 1,
        damageType = fk.ThunderDamage,
        skillName = skill.name,
      })
    end
  end,
})

skill:addAI(Fk.Ltk.AI.newCardSkillStrategy {
  keep_value = 3.66,
  use_value = 4.55,
  use_priority = 2.5,
  on_effect = function(self, logic, effect)
    logic:damage({
      from = effect.from,
      to = effect.to,
      card = effect.card,
      damage = 1,
      damageType = fk.ThunderDamage,
      skillName = skill.name,
    })
  end,
})

return skill
