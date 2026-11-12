local C = require "packages.hanjin.pkg.hanjin_mode.rules.commander_retinue"
local H = require "packages.hegemony.util"

-- 模式级公共规则。相关规则必须在所有包加载完成后挂到本技能的实际
-- Skill 对象上；SkillSkeleton 的 related_skills 只是展示用的技能名表，
-- createSkill 不会把它复制给主技能，房间因此不会加载上游国战规则。
local skill = fk.CreateSkill {
  name = C.RULE_SKILL,
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

-- 模式规则的实际依赖。只挂既有国战公共规则和汉晋自己的模式技：
-- * heg_rule 恢复国战回合开始亮将、鏖战等公共流程；
-- * #hanjin_exchange_history 记录交换武将所需的逐牌技能使用；
-- * #hanjin_ascension_rule 提供汉晋君主升变/胜负规则；
-- * #hanjin_adaptation_display 提供应变牌手牌提示（仅在汉晋房间加入）。
-- 汉晋君主版不使用 lord 命名，也不登记 HegUtil.lordGenerals，因此 heg_rule
-- 的 lord_convert 分支不会为汉晋普通将提供原生君主转换；升变仍由汉晋升变规则负责。
-- 房间添加技能时会按名字去重，因此这些技能即使另有全局入口也不会重复注册。
Fk:addPostLoadFunc(function()
  local base = Fk.skills[C.RULE_SKILL]
  if base == nil then return end
  for _, name in ipairs({
    "heg_rule",
    "#hanjin_exchange_history",
    "#hanjin_ascension_rule",
    "#hanjin_adaptation_display",
    "#hanjin_only_as_rule",
    "#hanjin_only_as_prohibit",
    "#hanjin_battle_royal_rule",
    "#hanjin_use_targets_rule",
  }) do
    local dependency = Fk.skills[name]
    if dependency ~= nil then table.insertIfNeed(base.related_skills, dependency) end
  end
end)

return skill
