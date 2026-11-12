-- HANJIN 方天画戟（国战势备版本，沿用用户已选的 `sa__halberd` 效果）
--
-- 规则依据：rules/card-deck.md 第 6 节指定方天画戟使用国战势备版本；
-- rulebook/events/use-card.md 规定“对当前目标生效前”若被【闪】抵消，
-- 后续目标先判断“此牌对当前目标无效”，无效则不生成响应与效果时机。
--
-- 扩目标规则直接沿用上游 sa__halberd；0.5.25 的 UseCardData 没有
-- setNullified，仅 AimData/CardEffectData 提供该接口，因此在
-- CardEffectData 上把整张【杀】的目标登记为无效，而不是全局改引擎。
local skill = fk.CreateSkill {
  name = "hanjin__halberd_skill",
  attached_equip = "hanjin__halberd",
}

local H = require "packages.hegemony.util"

skill:addAuxActiveSkill("#hanjin__halberd_active", {
  can_use = Util.FalseFunc,
  min_target_num = 1,
  card_num = 0,
  card_filter = Util.FalseFunc,
  -- 0.5.25 通过第 6 个参数传入 askToUseActiveSkill 的 extra_data；
  -- 上游的 self.orig_tos/self.targets 在本版本技能对象上并不存在。
  target_filter = function(self, player, to_select, selected, selected_cards, card, extra_data)
    local orig_tos = (extra_data or {}).orig_tos or {}
    local candidates = (extra_data or {}).targets or {}
    local room = Fk:currentRoom()
    return table.contains(candidates, to_select.id) and
      (to_select.kingdom == "unknown" or
      (table.every(orig_tos, function(id)
        local original = room:getPlayerById(id)
        return original == nil or not H.compareKingdomWith(to_select, original)
      end) and table.every(selected, function(p)
        return not H.compareKingdomWith(to_select, p)
      end)))
  end,
})

skill:addEffect(fk.AfterCardTargetDeclared, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and data.card ~= nil and data.card.trueName == "slash"
      and #data:getExtraTargets() > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local _, ret = room:askToUseActiveSkill(player, {
      skill_name = "#hanjin__halberd_active",
      prompt = "#hanjin__halberd-ask",
      extra_data = {
        orig_tos = table.map(data.tos, Util.IdMapper),
        targets = table.map(data:getExtraTargets(), Util.IdMapper),
      },
    })
    if ret then
      event:setCostData(self, { tos = ret.targets })
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:broadcastPlaySound("./packages/standard_cards/audio/card/halberd")
    room:setEmotion(player, "./packages/standard_cards/image/anim/halberd")
    data:addTarget(event:getCostData(self).tos)
    data.extra_data = data.extra_data or {}
    data.extra_data.hanjinHalberd = true
  end,
})

skill:addEffect(fk.CardEffectCancelledOut, {
  mute = true,
  is_delay_effect = true,
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if data.card == nil or data.card.trueName ~= "slash" then return false end
    local use_event = player.room.logic:getCurrentEvent():findParent(GameEvent.UseCard)
    return use_event ~= nil and use_event.data ~= nil
      and ((use_event.data.extra_data or {}).hanjinHalberd == true)
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local use_event = room.logic:getCurrentEvent():findParent(GameEvent.UseCard)
    local use = use_event and use_event.data
    if use == nil then return end
    -- “此【杀】对所有目标均无效”：登记到 use.nullifiedTargets 后，后续目标的
    -- “对当前目标生效前”前置判断直接跳过响应与效果。
    local targets = data.tos or use.tos
    if #targets > 0 then
      data:setNullified(targets)
    end
  end,
})

Fk:loadTranslationTable {
  ["hanjin__halberd_skill"] = "方天画戟",
  ["#hanjin__halberd-ask"] = "方天画戟：令任意名势力各不相同且与已选择的目标势力均不相同的角色和任意名没有势力的角色也成为目标",
}

return skill
