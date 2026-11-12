local C = require "packages.hanjin.pkg.hanjin_mode.rules.card_use_targets"

-- HanJin room rule for the public use-target strategy:
--   * a FilterSkill supplies a policy-aware CardSkill proxy to UI/server target
--     selection;
--   * a TargetModSkill implements "no distance limit" without touching other
--     printed conditions;
--   * PreCardUse revalidates only uses carrying a server-issued strategy token,
--     so forged extra_data cannot bypass the target rule.
local skill = fk.CreateSkill {
  name = C.RULE_SKILL,
  tags = { Skill.Compulsory },
}

local function inHanjin(player)
  return player ~= nil and player.room ~= nil
    and player.room:getSettings("gameMode") == "hanjin_heg_mode"
end

skill:addEffect("filter", {
  card_skill_filter = function(self, card, player)
    if card == nil or card.skill == nil or player == nil then return nil end
    if C.activePolicy(player.room, player, card) == nil then return nil end
    return C.proxyNameFor(card.skill)
  end,
})

skill:addEffect("targetmod", {
  bypass_distances = function(self, player, card_skill, card, to)
    if card == nil then return false end
    local rec = C.activePolicy(player and player.room, player, card)
    return rec ~= nil and rec.kind == C.KIND_BYPASS_DISTANCE
  end,
})

skill:addEffect(fk.PreCardUse, {
  global = true,
  mute = true,
  is_delay_effect = true,
  priority = 30,
  can_trigger = function(self, event, target, player, data)
    return target == player and inHanjin(player) and data ~= nil and data.card ~= nil
      and data.extra_data ~= nil
      and (data.extra_data.hanjin_use_targets ~= nil
        or data.extra_data.hanjin_use_targets_token ~= nil)
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local rec = C.trustedPolicy(room, data)
    if rec == nil then
      C.releaseToken(room, data)
      return true
    end
    if not C.validateUse(room, player, data, rec, nil, { require_trusted = true }) then
      C.releaseToken(room, data)
      return true
    end
  end,
})

skill:addEffect(fk.CardUseFinished, {
  global = true,
  mute = true,
  priority = -100,
  can_refresh = function(self, event, target, player, data)
    return target == player and data ~= nil
  end,
  on_refresh = function(self, event, target, player, data)
    C.releaseToken(player.room, data)
  end,
})

skill:addEffect(fk.GameStart, {
  global = true,
  mute = true,
  can_refresh = function(self, event, target, player)
    return player.seat == 1 and inHanjin(player)
  end,
  on_refresh = function(self, event, target, player)
    local room = player.room
    room:setTag(C.POLICY_TAG, nil)
    for _, p in ipairs(room.players) do
      room:setPlayerMark(p, C.POLICY_MARK, 0)
    end
  end,
})

Fk:loadTranslationTable {
  [C.RULE_SKILL] = "汉晋用牌目标规则",
}

return skill
