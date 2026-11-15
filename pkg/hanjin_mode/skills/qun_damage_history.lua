-- 黄巾雷使的房间级事实记录器（模式常驻）。
--
-- 由 mode.lua 在 logic:start 通过 `room:addSkill("hanjin__qun_damage_history")`
-- 安装，先于任何角色取得翼从、明置或换将；不依赖黄巾雷使是否已获得。
-- 本技能只有 refresh，不产生任何额外触发；客户端不读取该房间私有事实。
--
-- 记录内容：本回合第一个“不因使用手牌而造成伤害”的 fk.DamageCaused 时机
-- （TriggerEvent id，数字）。持有者技能只在同一时机开放选择；未发动、没有
-- 手牌或放弃都已消耗本回合机会。每次 TurnStart 清空。
--
-- “不因使用手牌”使用锁定引擎的真实字段与接口：
--   * DamageData 的 card/skillName/chain/parent 字段见 ltk/core/events/hp.lua
--     DamageDataSpec（chain 为铁索传导、parent 为传导来源伤害）；
--     传导伤害在 ltk/server/events/hp.lua 以 chain=true、parent=原伤害创建。
--   * 直接渠道：GameLogic:damageByCardEffect()（ltk/server/gamelogic.lua）要求
--     当前伤害直接对应父 CardEffect；damage.chain 或 damage.card == nil 时为 false。
--   * 手牌判断：真实用牌事件的 UseCardData:isUsingHandcard()（读取使用时的
--     subcardsFromInfo，ltk/core/events/usecard.lua）。
--   * 铁索传导伤害本身不是手牌牌效直接产生；沿用父伤害在同一时机得到的
--     手牌判定，父伤害为手牌伤害时传导伤害也不开放机会。
local skill = fk.CreateSkill {
  name = "hanjin__qun_damage_history",
}

-- 与 retinue_skill_huangjin_leishi.lua 的 FIRST_DAMAGE_TAG 保持一致。
local FIRST_DAMAGE_TAG = "hanjin_qun_damage_history_first"
local HANDCARD_KEY = "__hanjin_qun_damage_history_handcard"

--- 当前伤害是否直接由一次“使用手牌”的牌效造成。
---@param room Room
---@param data DamageData
---@return boolean
local function isHandcardDamage(room, data)
  if data.chain then
    return data.parent ~= nil and data.parent[HANDCARD_KEY] == true
  end
  if room == nil or room.logic == nil or GameEvent == nil then return false end
  if not room.logic:damageByCardEffect() then return false end
  local event = room.logic:getCurrentEvent()
  if event == nil then return false end
  local useEvent = event:findParent(GameEvent.UseCard)
  local use = useEvent and useEvent.data
  return use ~= nil and use.card ~= nil and use:isUsingHandcard() == true
end

skill:addEffect(fk.DamageCaused, {
  can_refresh = function(self, event, target, player, data)
    return target == player and data ~= nil and data.from ~= nil and (data.damage or 0) > 0
  end,
  on_refresh = function(self, event, target, player, data)
    local room = data.from.room
    if room == nil then return end
    if data[HANDCARD_KEY] == nil then
      data[HANDCARD_KEY] = isHandcardDamage(room, data)
    end
    if not data[HANDCARD_KEY] and room:getTag(FIRST_DAMAGE_TAG) == nil then
      room:setTag(FIRST_DAMAGE_TAG, event.id)
    end
  end,
})

skill:addEffect(fk.TurnStart, {
  can_refresh = function(self, event, target, player)
    return target ~= nil and target == player
  end,
  on_refresh = function(self, event, target, player)
    target.room:setTag(FIRST_DAMAGE_TAG, nil)
  end,
})

return skill
