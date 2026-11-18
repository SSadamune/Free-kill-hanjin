-- 驺虞幡：回合外每回合限一次，在真实的需要使用/打出【杀】或【闪】的请求中，
-- 按请求类型视为使用/打出。动作完成后建立本回合下一次受伤的延时记录；受伤后
-- 即使原防具已失去仍先失去1点体力，原牌仍在装备区且可弃置时才弃置。
local skill = fk.CreateSkill {
  name = "qiao__zouyu_fan_skill",
  attached_equip = "qiao__zouyu_fan",
}

local PENDING = "qiao_zouyu_pending"
local CARD = "qiao_zouyu_card"
local ARMED = "qiao_zouyu_armed"
local USED = "qiao_zouyu_used_turn"
local DELAY_SKILL = "qiao__zouyu_fan_delay"

local delaySkill
local function ensureDelaySkill(room)
  if delaySkill == nil then
    local skel = fk.CreateSkill { name = DELAY_SKILL }
    skel:addEffect(fk.Damaged, {
      global = true,
      can_trigger = function(self, event, target, player, data)
        return target ~= nil and target:getMark(PENDING) > 0
      end,
      on_cost = Util.TrueFunc,
      on_use = function(self, event, target, player, data)
        local room = Fk:currentRoom()
        local cardId = target:getMark(CARD)
        room:setPlayerMark(target, PENDING, 0)
        room:setPlayerMark(target, CARD, 0)
        room:loseHp(target, 1, DELAY_SKILL)
        if target.dead or cardId == 0 then return end
        local card = Fk:getCardById(cardId)
        if card ~= nil and room:getCardOwner(cardId) == target
          and room:getCardArea(cardId) == Card.PlayerEquip
          and not target:prohibitDiscard(card) then
          room:moveCardTo(cardId, Card.DiscardPile, nil,
            fk.ReasonDiscard, DELAY_SKILL, nil, true, target)
        end
      end,
    })
    skel:addEffect(fk.TurnEnd, {
      global = true,
      can_trigger = function(self, event, target, player, data)
        return target ~= nil
      end,
      on_cost = Util.TrueFunc,
      on_use = function(self, event, target, player, data)
        local room = Fk:currentRoom()
        for _, p in ipairs(room.players) do
          room:setPlayerMark(p, PENDING, 0)
          room:setPlayerMark(p, CARD, 0)
          room:setPlayerMark(p, ARMED, 0)
          room:setPlayerMark(p, USED, 0)
        end
      end,
    })
    delaySkill = skel:createSkill()
    local function register(s)
      if s == nil then return end
      Fk.skills[s.name] = Fk.skills[s.name] or s
      for _, related in ipairs(s.related_skills or {}) do register(related) end
    end
    register(delaySkill)
  end
  if not room:getTag("qiao_zouyu_delay_ready") then
    room:addSkill(delaySkill)
    room:setTag("qiao_zouyu_delay_ready", true)
  end
end

local function equipId(player)
  for _, id in ipairs(player:getCardIds(Player.Equip)) do
    local card = Fk:getCardById(id)
    if card ~= nil and card.name == skill.attached_equip then return id end
  end
end

--- 请求的牌名：只接受【杀】或【闪】。
local function requestedName(data)
  if data == nil or data.pattern == nil then return nil end
  local pattern = Exppattern:Parse(data.pattern)
  if pattern:matchExp("slash|0|nosuit|none") then return "slash" end
  if pattern:matchExp("jink|0|nosuit|none") then return "jink" end
end

local function canProvide(self, player, data, response)
  if player == nil or player.dead or not player:hasSkill(skill.name) then return false end
  if player.room.current == player then return false end
  if player:getMark(USED) > 0 then return false end
  if player:usedSkillTimes(skill.name, Player.HistoryTurn) > 0 then return false end
  local name = requestedName(data)
  if name == nil then return false end
  local card = Fk:cloneCard(name)
  if response then
    return not player:prohibitResponse(card)
  end
  return not player:prohibitUse(card)
end

local function promote(player, card)
  if player == nil or card == nil or card.skillName ~= skill.name then return end
  if player:getMark(ARMED) == 0 then return end
  player.room:setPlayerMark(player, ARMED, 0)
  player.room:setPlayerMark(player, PENDING, 1)
  player.room:setPlayerMark(player, USED, 1)
end

local function provide(self, event, target, player, data)
  local name = requestedName(data)
  if name == nil then return end
  local cardId = equipId(player) or 0
  if event:isInstanceOf(fk.AskForCardUse) and name == "slash" then
    local card = Fk:cloneCard("qiao__slash")
    card.skillName = skill.name
    local targets = card:getAvailableTargets(player, data.extraData or {})
    if #targets == 0 then return end
    local picked = player.room:askToChoosePlayers(player, {
      targets = targets,
      min_num = 1,
      max_num = 1,
      skill_name = skill.name,
      prompt = "#qiao__zouyu-target",
      cancelable = true,
    })
    if picked == nil or picked[1] == nil then return end
    data.result = { from = player, card = card, tos = { picked[1] } }
  else
    local card = Fk:cloneCard(name)
    card.skillName = skill.name
    local result = { from = player, card = card }
    if event:isInstanceOf(fk.AskForCardUse) then result.tos = {} end
    data.result = result
  end
  ensureDelaySkill(player.room)
  player.room:setPlayerMark(player, CARD, cardId)
  player.room:setPlayerMark(player, ARMED, 1)
end
-- 只有真实使用/打出完成后才把“待受伤”记录转正；请求结果本身不建立延时。
skill:addEffect(fk.CardUseFinished, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return player ~= nil and data ~= nil and data.from == player
      and data.card ~= nil and data.card.skillName == skill.name
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    promote(player, data.card)
  end,
})

skill:addEffect(fk.CardRespondFinished, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return player ~= nil and data ~= nil and data.from == player
      and data.card ~= nil and data.card.skillName == skill.name
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    promote(player, data.card)
  end,
})
skill:addEffect(fk.AskForCardUse, {
  can_trigger = function(self, event, target, player, data)
    return target == player and canProvide(self, player, data, false)
  end,
  on_use = provide,
})

skill:addEffect(fk.AskForCardResponse, {
  can_trigger = function(self, event, target, player, data)
    return target == player and canProvide(self, player, data, true)
  end,
  on_use = provide,
})

Fk:loadTranslationTable {
  [skill.name] = "驺虞幡",
  ["#qiao__zouyu-target"] = "驺虞幡：选择此【杀】的目标",
  [":" .. skill.name] = "回合外每回合限一次，在需要使用或打出【杀】或【闪】时，"
    .. "你可以视为使用或打出之；随后本回合下一次受到伤害后失去1点体力并弃置此牌。",
}

return skill
