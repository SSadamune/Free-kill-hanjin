-- HAN017 刘繇 · 戡难
--
-- 规则基线：rules/generals/han017-liuyao.md 与
-- rulebook/terms/description-terms/and.md。
-- 出牌阶段每名角色限一次：与一名角色拼点；赢的角色“可以获得没赢的拼点牌
-- 并令你本回合使用下张【杀】伤害+1”。按“并”的语义，只有实际取得没赢的
-- 拼点牌时，才同时建立下张【杀】的 +1；不能取得时不得单独加伤。
-- 若刘繇赢，本回合不能再发动。限次与锁定标记在发动者身上并按 Exchange
-- 技能前缀命名；拼点后续与下张【杀】加值都由房间级延迟监听处理，不依赖
-- 当前是否仍有戡难。
local skill = fk.CreateSkill {
  name = "hanjin__skill_han017_1",
}

local USED_TARGETS = "hanjin__skill_han017_1-given_targets-phase"
local LOCK = "hanjin__skill_han017_1-locked-turn"
local NEXT_SLASH = "hanjin_skill_han017_1_next_slash_damage-turn"
local DELAY_SKILL_NAME = "#hanjin_skill_han017_1_delay"
local OPTION_TAKE = "#hanjin__skill_han017_1-take"
local OPTION_DECLINE = "#hanjin__skill_han017_1-decline"

local delay_skill

local function currentRoom(player)
  return player.room or Fk:currentRoom()
end

local function usedTargets(player)
  return player:getTableMark(USED_TARGETS)
end

local function eligibleTargets(player)
  local room = currentRoom(player)
  if room == nil then return {} end
  local used = usedTargets(player)
  local ret = {}
  for _, p in ipairs(room.alive_players) do
    if p ~= player and p:isAlive() and not p:isRemoved()
      and not table.contains(used, p.id) and player:canPindian(p) then
      table.insert(ret, p)
    end
  end
  return ret
end

--- 处理一次已经完成的戡难拼点。只读已建立的拼点数据，不检查技能当前是否
--- 仍在；即使刘繇在拼点途中失技/暗置，赢家取牌与刘繇锁定仍按本次使用结算。
---@param player ServerPlayer
---@param data PindianData
local function resolvePindian(player, data)
  if player == nil or data == nil or data.reason ~= skill.name then return end
  if data.from ~= player or data.tos == nil or #data.tos ~= 1 then return end
  local room = player.room
  local opponent = data.tos[1]
  local result = data.results and data.results[opponent]
  if result == nil then return end
  local winner = result.winner
  if winner == nil then return end

  -- 刘繇赢：本回合不能再发动，与是否取得拼点牌无关。
  if winner == player then
    room:addPlayerMark(player, LOCK, 1)
  end

  local losingCard = (winner == player) and result.toCard or data.fromCard
  local cid = losingCard and losingCard:getEffectiveId()
  if cid == nil or room:getCardArea(cid) ~= Card.Processing then return end
  if winner.dead or winner:isRemoved() then return end

  -- “可以取得并令……”：两个操作按“并”同时执行；拒绝取得或无法取得时，
  -- 不建立下张【杀】的 +1。
  local choice = room:askToChoice(winner, {
    choices = { OPTION_TAKE, OPTION_DECLINE },
    skill_name = skill.name,
    prompt = "#hanjin__skill_han017_1-take",
    cancelable = false,
  })
  if choice ~= OPTION_TAKE then return end
  if room:getCardArea(cid) ~= Card.Processing then return end
  room:obtainCard(winner, cid, true, fk.ReasonPindian, winner, skill.name)
  room:addPlayerMark(player, NEXT_SLASH, 1)
end

--- 房间级延迟监听器：模块缓存保证同名技能对象唯一；不检查刘繇当前是否仍
--- 有技能，已建立的拼点后续与下张【杀】加值不因失技/暗置/交换消失。
---@param room Room
local function ensureDelaySkill(room)
  if room == nil then return end
  if delay_skill == nil then delay_skill = Fk.skills[DELAY_SKILL_NAME] end
  if delay_skill == nil then
    local skel = fk.CreateSkill { name = DELAY_SKILL_NAME }
    skel:addEffect(fk.PindianFinished, {
      global = true,
      is_delay_effect = true,
      can_refresh = function(self, event, target, player, data)
        return type(data) == "table" and data.reason == skill.name
          and not data.__hanjin_han017_1_resolved
      end,
      on_refresh = function(self, event, target, player, data)
        data.__hanjin_han017_1_resolved = true
        resolvePindian(data.from, data)
      end,
    })
    skel:addEffect(fk.AfterCardUseDeclared, {
      global = true,
      is_delay_effect = true,
      can_refresh = function(self, event, target, player, data)
        return target ~= nil and type(data) == "table"
          and not data.__hanjin_han017_1_next_done
          and data.card ~= nil and data.card.trueName == "slash"
          and target:getMark(NEXT_SLASH) > 0
      end,
      on_refresh = function(self, event, target, player, data)
        local bonus = target:getMark(NEXT_SLASH)
        if bonus <= 0 then return end
        data.__hanjin_han017_1_next_done = true
        target.room:setPlayerMark(target, NEXT_SLASH, 0)
        -- 绑定到这一次 UseCardData：同一张杀的多目标/多次伤害共享同一加值，
        -- 不按每个目标或每次伤害分别消费。
        data.additionalDamage = (data.additionalDamage or 0) + bonus
      end,
    })
    delay_skill = skel:createSkill()
    Fk.skills[DELAY_SKILL_NAME] = delay_skill
  end
  if not room:hasSkill(DELAY_SKILL_NAME) then
    room:addSkill(delay_skill)
  end
end

skill:addEffect("active", {
  anim_type = "offensive",
  prompt = "#hanjin__skill_han017_1-prompt",
  card_filter = Util.FalseFunc,
  target_filter = function(self, player, to_select, selected)
    return #selected == 0 and to_select ~= player
      and to_select:isAlive() and not to_select:isRemoved()
      and not table.contains(usedTargets(player), to_select.id)
      and player:canPindian(to_select)
  end,
  can_use = function(self, player)
    return player:getMark(LOCK) == 0
      and #player:getCardIds(Player.Hand) > 0
      and #eligibleTargets(player) > 0
  end,
  target_num = 1,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos and effect.tos[1]
    if player == nil or target == nil or player.dead or target.dead or target:isRemoved() then return end
    if player:getMark(LOCK) > 0 then return end
    if table.contains(usedTargets(player), target.id) then return end
    if not player:canPindian(target) then return end

    ensureDelaySkill(room)
    room:addTableMarkIfNeed(player, USED_TARGETS, target.id)
    player:pindian({ target }, skill.name)
  end,
})

skill:addAcquireEffect(function(self, player)
  ensureDelaySkill(player.room)
end)

Fk:loadTranslationTable {
  ["hanjin__skill_han017_1"] = "戡难",
  [":hanjin__skill_han017_1"] = "出牌阶段每名角色限一次，你可以与一名角色拼点：赢的角色可以获得没赢的拼点牌并令你本回合使用下张【杀】伤害+1，若你赢，你本回合不能再发动此技能。",
  ["#hanjin__skill_han017_1-prompt"] = "戡难：与一名角色拼点",
  ["#hanjin__skill_han017_1-take"] = "戡难：是否取得没赢的拼点牌并令其下张【杀】伤害+1",
  [OPTION_TAKE] = "取得拼点牌",
  [OPTION_DECLINE] = "不取得",
}

skill.hanjinImplemented = true

return skill
