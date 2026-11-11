local C = require "packages.hanjin.pkg.hanjin_mode.rules.commander_retinue"
local H = require "packages.hegemony.util"

-- 模式级公共规则。related_skills 保证上游国战规则仍然加载。
local skill = fk.CreateSkill {
  name = C.RULE_SKILL,
  related_skills = { "heg_rule", "#hanjin_exchange_history" },
}

skill:addEffect(fk.GameStart, {
  can_refresh = function(self, event, target, player)
    return player.seat == 1
  end,
  on_refresh = function(self, event, target, player)
    local room = player.room
    C.reset(room)
    for _, p in ipairs(room.players) do C.grantAbility(p) end
    C.refreshAvailability(room)
  end,
})

skill:addEffect(fk.GeneralShown, {
  global = true,
  priority = 0,
  can_trigger = function(self, event, target, player, data)
    return target == player
  end,
  on_trigger = function(self, event, target, player, data)
    C.onGeneralShown(player.room, player, data)
  end,
})

--- 找到一张仍处于临时占用中的统领视为牌。只认服务端来源记录和牌面一致，
--- 客户端伪造的来源标记不会在这里转为永久记录。
local function pendingAbilitySource(room, use)
  if use == nil or use.card == nil then return nil end
  local key = use.card:getMark(C.CARD_SOURCE_MARK)
  if type(key) ~= "string" or key == "" then return nil end
  local source = C.source(room, key)
  if source == nil or use.card.name ~= source.card then return nil end
  if not C.abilityReserved(room, key) then return nil end
  return source, key
end

-- 引擎时序（ltk/server/events/usecard.lua）：after_use/before_use 支付 →
-- fk.PreCardUse（可 breakEvent 中止）→ 牌移入处理区 →
-- fk.AfterCardUseDeclared → fk.CardUsing（无懈可击在此之后才抵消效果）→
-- fk.CardUseFinished（中止时 event.interrupted = true）。
-- 因此：宣告使用时永久扣一次；中止时只释放临时占用；被抵消不返还。
skill:addEffect(fk.AfterCardUseDeclared, {
  global = true,
  priority = 100,
  can_trigger = function(self, event, target, player, data)
    return target == player and pendingAbilitySource(player.room, data) ~= nil
  end,
  on_trigger = function(self, event, target, player, data)
    local _, key = pendingAbilitySource(player.room, data)
    if key ~= nil then C.commitAbilityUse(player.room, key, player) end
  end,
})

-- 兜底：询问返回的 use 若最终没有进入 room:useCard，临时占用不应跨回合。
skill:addEffect(fk.TurnStart, {
  global = true,
  can_trigger = function(self, event, target, player)
    return target == player
  end,
  on_trigger = function(self, event, target, player)
    C.clearReservations(player.room)
  end,
})

skill:addEffect(fk.CardUseFinished, {
  global = true,
  priority = 100,
  can_trigger = function(self, event, target, player, data)
    return target == player and pendingAbilitySource(player.room, data) ~= nil
  end,
  on_trigger = function(self, event, target, player, data)
    local _, key = pendingAbilitySource(player.room, data)
    if key == nil then return end
    local current = player.room.logic:getCurrentEvent()
    if current ~= nil and current.interrupted then
      C.releaseAbilityReservation(player.room, key)
    else
      -- 兜底：未触发 AfterCardUseDeclared 的牌仍按已宣告使用处理。
      C.commitAbilityUse(player.room, key, player)
    end
  end,
})

skill:addEffect(fk.GeneralHidden, {
  global = true,
  priority = 0,
  can_trigger = function(self, event, target, player, data)
    return target == player
  end,
  on_trigger = function(self, event, target, player, data)
    C.onGeneralHidden(player.room, player, data)
  end,
})

skill:addEffect(fk.AfterPropertyChange, {
  global = true,
  priority = -10,
  can_trigger = function(self, event, target, player, data)
    return target == player
  end,
  on_trigger = function(self, event, target, player, data)
    C.onAfterPropertyChange(player.room, player, data)
  end,
})

skill:addEffect(H.GeneralRemoved, {
  global = true,
  priority = -10,
  can_trigger = function(self, event, target, player, data)
    return target == player
  end,
  on_trigger = function(self, event, target, player, data)
    C.onGeneralRemoved(player.room, player, data)
  end,
})

skill:addEffect(fk.Death, {
  global = true,
  priority = -10,
  can_trigger = function(self, event, target, player, data)
    return target == player
  end,
  on_trigger = function(self, event, target, player, data)
    C.onDeath(player.room, player)
  end,
})

Fk:loadTranslationTable {
  [C.RULE_SKILL] = "汉晋统领规则",
}

return skill
