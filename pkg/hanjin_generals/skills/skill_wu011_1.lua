-- WU011 小乔 · 天香
--
-- 每回合每项限一次：受到伤害时，弃置一张红桃牌并防止此伤害，然后选择一名
-- 其他角色和一项：
--   1. 伤害来源对其造成 1 点伤害，其摸等同于已损失体力值的牌（至多五张）；
--   2. 其失去 1 点体力，然后获得弃置的牌。
-- 这是“防止原伤害后另造成伤害/失去体力”，不是旧式伤害转移。弃置的红桃牌
-- 在费用阶段支付；红颜的黑桃视为红桃通过锁视过滤在选牌时生效。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wu011_1",
}
skill.hanjinImplemented = true

local OPT_DAMAGE = "#hanjin__skill_wu011_1-damage"
local OPT_LOSEHP = "#hanjin__skill_wu011_1-losehp"
local USED_DAMAGE = "hanjin__skill_wu011_1_damage-turn"
local USED_LOSEHP = "hanjin__skill_wu011_1_losehp-turn"

local function otherPlayers(player)
  return table.filter(player.room.alive_players, function(p)
    return p ~= player and p:isAlive() and not p:isRemoved()
  end)
end

--- 合法红桃花色可弃牌：红颜锁视后的花色 + 禁弃过滤。
---@param player ServerPlayer
---@return integer[]
local function legalHeartCards(player)
  local ids = {}
  for _, id in ipairs(player:getCardIds("he")) do
    local card = Fk:getCardById(id)
    if card ~= nil and card.suit == Card.Heart and not player:prohibitDiscard(card) then
      table.insert(ids, id)
    end
  end
  return ids
end

local function availableOptions(player, data)
  local options = {}
  if player:getMark(USED_DAMAGE) == 0 and data.from ~= nil and not data.from.dead then
    table.insert(options, OPT_DAMAGE)
  end
  if player:getMark(USED_LOSEHP) == 0 then
    table.insert(options, OPT_LOSEHP)
  end
  return options
end

skill:addEffect(fk.DamageInflicted, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and not player.dead
      and data ~= nil and data.damage > 0 and not data.prevented
      and #otherPlayers(player) > 0 and #legalHeartCards(player) > 0
      and #availableOptions(player, data) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_wu011_1-invoke",
    }) then
      return false
    end
    local candidates = legalHeartCards(player)
    if #candidates == 0 then return false end
    local chosen = room:askToCards(player, {
      min_num = 1,
      max_num = 1,
      include_equip = true,
      pattern = tostring(Exppattern { id = candidates }),
      skill_name = skill.name,
      prompt = "#hanjin__skill_wu011_1-discard",
      cancelable = false,
    })
    local card = chosen and chosen[1]
    -- 选牌界面只展示合法候选；支付前再次按当前状态核对花色与禁弃。
    local legal = legalHeartCards(player)
    if card == nil or not table.contains(legal, card) then return false end
    room:throwCard({ card }, skill.name, player, player)
    event:setCostData(self, { card = card })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self) or {}
    local card = cost.card

    -- 先防止原伤害，再执行另行选择的分支。
    data:preventDamage()
    if player.dead then return end

    local tos = otherPlayers(player)
    if #tos == 0 then return end
    local chosen = room:askToChoosePlayers(player, {
      targets = tos,
      min_num = 1,
      max_num = 1,
      skill_name = skill.name,
      prompt = "#hanjin__skill_wu011_1-target",
      cancelable = false,
    })
    local to = chosen and chosen[1]
    if to == nil or to.dead or to:isRemoved() then return end

    local options = availableOptions(player, data)
    local option
    if #options == 0 then
      return
    elseif #options == 1 then
      option = options[1]
    else
      option = room:askToChoice(player, {
        choices = options,
        skill_name = skill.name,
        prompt = "#hanjin__skill_wu011_1-option",
        cancelable = false,
      })
    end

    if option == OPT_DAMAGE then
      room:addPlayerMark(player, USED_DAMAGE, 1)
      local from = data.from
      if from ~= nil and not from.dead then
        room:damage {
          from = from,
          to = to,
          damage = 1,
          skillName = skill.name,
        }
      end
      if to:isAlive() and not to.dead then
        local lost = to:getLostHp()
        if lost > 0 then
          to:drawCards(math.min(5, lost), skill.name)
        end
      end
    else
      room:addPlayerMark(player, USED_LOSEHP, 1)
      if to:isAlive() and not to.dead then
        room:loseHp(to, 1, skill.name)
        if not to.dead and card ~= nil and room:getCardArea(card) == Card.DiscardPile then
          room:obtainCard(to, card, true, fk.ReasonPrey, player, skill.name)
        end
      end
    end
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_wu011_1"] = "天香",
  [":hanjin__skill_wu011_1"] = "每回合每项限一次，当你受到伤害时，你可以弃置一张红桃牌并防止此伤害，然后选择一名其他角色和以下一项：1.来源对其造成1点伤害，其摸等同已损失体力值的牌（至多摸五张）；2.其失去1点体力，然后获得你弃置的牌。",
  ["#hanjin__skill_wu011_1-invoke"] = "天香：你可以弃置一张红桃牌并防止此伤害",
  ["#hanjin__skill_wu011_1-discard"] = "天香：弃置一张红桃牌",
  ["#hanjin__skill_wu011_1-target"] = "天香：选择一名其他角色",
  ["#hanjin__skill_wu011_1-option"] = "天香：选择一项",
  [OPT_DAMAGE] = "来源对其造成1点伤害，其摸已损失体力值张牌",
  [OPT_LOSEHP] = "其失去1点体力，然后获得弃置的牌",
}

return skill
