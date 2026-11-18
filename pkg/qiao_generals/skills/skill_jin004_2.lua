-- JIN004 贾充 · 悖弑
--
-- 规则基线：docs/rules/generals/jin004-jiachong.md。
-- 成为其他角色使用的【杀】或锦囊牌（含延时）唯一实际目标时：弃置一张同类别
-- 自己的牌，取消目标，获得原牌可得材料，然后可使用一张无距离限制的牌。
-- 只有本次后续用牌对原使用者造成的真实伤害才算；未用、取消、未造成伤害均失去
-- 1点体力。后续用牌在“选择时”即接入无距离策略，避免远距离目标选不上。
local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"

local skill = fk.CreateSkill {
  name = "qiao__skill_jin004_2",
}

local TOKEN = "qiao_jin004_2_next_use"
local DELAY = "#qiao_jin004_2_damage_probe"
local delay_skill

local function ensureDamageProbe(room)
  if room == nil then return end
  if delay_skill == nil then delay_skill = Fk.skills[DELAY] end
  if delay_skill == nil then
    local skel = fk.CreateSkill { name = DELAY }
    skel:addEffect(fk.Damage, {
      global = true,
      is_delay_effect = true,
      can_refresh = function(self, event, target, player, data)
        if data == nil or data.from == nil or data.to == nil then return false end
        local useEvent = player.room.logic:getCurrentEvent():findParent(GameEvent.UseCard, true)
        local use = useEvent and useEvent.data
        local record = use and use.extra_data and use.extra_data[TOKEN]
        return type(record) == "table" and data.from == use.from
          and data.from.id == record.actor and data.to.id == record.source
          and data.card == use.card and (data.damage or 0) > 0
      end,
      on_refresh = function(self, event, target, player, data)
        local useEvent = player.room.logic:getCurrentEvent():findParent(GameEvent.UseCard, true)
        local use = useEvent and useEvent.data
        if use ~= nil and use.extra_data and use.extra_data[TOKEN] then
          use.extra_data[TOKEN].damaged = true
        end
      end,
    })
    delay_skill = skel:createSkill()
    Fk.skills[DELAY] = delay_skill
  end
  if not room:hasSkill(DELAY) then room:addSkill(delay_skill) end
end

local function categoryPattern(card)
  if card.type == Card.TypeBasic then return ".|.|.|.|.|basic" end
  if card.type == Card.TypeTrick then return ".|.|.|.|.|trick" end
  if card.type == Card.TypeEquip then return ".|.|.|.|.|equip" end
  return nil
end

local function canDiscardCategory(player, pattern)
  return pattern ~= nil and table.find(player:getCardIds("he"), function(id)
    return Exppattern:Parse(pattern):match(Fk:getCardById(id))
      and not player:prohibitDiscard(id)
  end) ~= nil
end

skill:addEffect(fk.TargetConfirmed, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    if target ~= player or player.dead or not player:hasSkill(skill.name) then return false end
    local use = data and data.use
    if use == nil or use.from == player or use.card == nil then return false end
    local card = use.card
    if card.trueName ~= "slash" and card.type ~= Card.TypeTrick then return false end
    if #use.tos ~= 1 or use.tos[1] ~= player then return false end
    return canDiscardCategory(player, categoryPattern(card))
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_jin004_2-invoke:" .. data.use.from.id,
    }) then
      return false
    end
    local pattern = categoryPattern(data.use.card)
    local discarded = room:askToDiscard(player, {
      min_num = 1,
      max_num = 1,
      include_equip = true,
      pattern = pattern,
      skill_name = skill.name,
      prompt = "#qiao__skill_jin004_2-discard",
      cancelable = true,
    })
    if discarded == nil or #discarded ~= 1 then return false end
    event:setCostData(self, { cards = discarded })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local use = data.use
    local source = use.from
    if source == nil or use.card == nil then return end
    data:cancelTarget(player)

    local ids = room:getSubcardsByRule(use.card, { Card.Processing })
    if #ids > 0 then
      local got = {}
      for _, id in ipairs(ids) do
        if room:getCardArea(id) == Card.Processing then table.insert(got, id) end
      end
      if #got > 0 then
        room:obtainCard(player, got, true, fk.ReasonPrey, source, skill.name)
      end
    end
    if player.dead then return end

    ensureDamageProbe(room)
    local damageRecord = { actor = player.id, source = source.id, damaged = false }
    -- 选择阶段就建立无距离策略；返回的是待执行数据，由本技能执行一次。
    -- 自由用牌：声明 not_passive，客户端不提供无响应时机的【闪】
    -- 【无懈可击】等；服务端 validateUse 的被动分支按同一标记早拒。
    local nextUse = C.askToUseCard(room, player, {
      names = Fk.all_card_names,
      pattern = ".",
      skill_name = skill.name,
      prompt = "#qiao__skill_jin004_2-use",
      cancelable = true,
      extra_data = { not_passive = true },
      policy = C.bypassDistance({ names = Fk.all_card_names }),
    })
    if nextUse ~= nil then
      nextUse.extra_data = nextUse.extra_data or {}
      nextUse.extra_data[TOKEN] = damageRecord
      room:useCard(nextUse)
    end

    local damaged = damageRecord.damaged
    if not player.dead and not damaged then
      room:loseHp(player, 1, skill.name)
    end
  end,
})

skill:addAcquireEffect(function(self, player)
  ensureDamageProbe(player.room)
end)

skill.qiaoImplemented = true

Fk:loadTranslationTable {
  ["#qiao__skill_jin004_2-invoke"] = "悖弑：你可以弃置一张同类别牌，取消 %src 使用的此牌",
  ["#qiao__skill_jin004_2-discard"] = "悖弑：弃置一张同类别牌",
  ["#qiao__skill_jin004_2-use"] = "悖弑：你可以使用一张牌（无距离限制）",
}

return skill
