-- WU014 鲁肃 · 缔盟
--
-- 出牌阶段限一次：选择两名其他角色，弃置等同于其手牌数差的牌，令其交换
-- 手牌；然后可以对其中手牌未增加的角色纵横“好施”，直到其下一个回合结束。
-- 弃置是发动消耗，按项目通则须实际弃置至少一张，手牌数相等（差为 0）不能
-- 作为消耗支付；因此不能选择手牌数相等的两名角色。
-- “纵横好施”由预注册静态技能 `hanjin__wu_dimeng_expiry` 在目标自己的下一个
-- 回合结束时按来源移除，不会因授予时所在回合（含额外回合）提前清理。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wu014_2",
}
skill.hanjinImplemented = true

local HAOSHI = "hanjin__skill_wu014_1"
local EXPIRY = "hanjin__wu_dimeng_expiry"
local GRANT_MARK = "hanjin_wu_dimeng_granted"

--- 客户端可用性计算时没有 ServerPlayer.room；回退到当前房间。
---@param player ServerPlayer | ClientPlayer
---@return Room?
local function currentRoom(player)
  return player.room or Fk:currentRoom()
end

local function ensureExpiry(room)
  if room == nil then return end
  if not room:hasSkill(EXPIRY) then
    room:addSkill(EXPIRY)
  end
end

local function others(player)
  local room = currentRoom(player)
  if room == nil then return {} end
  return table.filter(room.alive_players, function(p)
    return p ~= player and p:isAlive() and not p:isRemoved()
  end)
end

--- 当前可被该角色弃置的牌数（含手牌/装备，排除禁弃）。
---@param player ServerPlayer | ClientPlayer
---@return integer
local function discardableCount(player)
  return #table.filter(player:getCardIds("he"), function(id)
    local card = Fk:getCardById(id)
    return card ~= nil and not player:prohibitDiscard(card)
  end)
end

local function canPayAnyPair(player)
  local list = others(player)
  local owned = discardableCount(player)
  for i = 1, #list do
    for j = i + 1, #list do
      local diff = math.abs(#list[i]:getCardIds(Player.Hand) - #list[j]:getCardIds(Player.Hand))
      -- 差为 0 时无法实际弃置牌，不能作为发动消耗。
      if diff > 0 and diff <= owned then return true end
    end
  end
  return false
end

skill:addEffect("active", {
  anim_type = "control",
  prompt = "#hanjin__skill_wu014_2-prompt",
  target_num = 2,
  max_phase_use_time = 1,
  target_filter = function(self, player, to_select, selected)
    if to_select == player or not to_select:isAlive() or to_select:isRemoved() then return false end
    if table.contains(selected, to_select) then return false end
    if #selected == 0 then return true end
    local first = selected[1]
    local diff = math.abs(#first:getCardIds(Player.Hand) - #to_select:getCardIds(Player.Hand))
    return diff > 0 and diff <= discardableCount(player)
  end,
  can_use = function(self, player)
    return self:withinTimesLimit(player, Player.HistoryPhase) and canPayAnyPair(player)
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local tos = effect.tos or {}
    local a, b = tos[1], tos[2]
    if player == nil or player.dead or a == nil or b == nil or a == b then return end
    if not a:isAlive() or not b:isAlive() or a:isRemoved() or b:isRemoved() then return end

    local beforeA = #a:getCardIds(Player.Hand)
    local beforeB = #b:getCardIds(Player.Hand)
    local diff = math.abs(beforeA - beforeB)
    if diff <= 0 or diff > discardableCount(player) then return end

    local costCards = room:askToDiscard(player, {
      min_num = diff,
      max_num = diff,
      include_equip = true,
      skill_name = skill.name,
      prompt = "#hanjin__skill_wu014_2-discard:::" .. diff,
      cancelable = false,
    })
    if costCards == nil or #costCards ~= diff then return end
    if player.dead then return end

    room:swapAllCards(player, { a, b }, skill.name)
    if a.dead or b.dead then return end

    local eligible = {}
    if #a:getCardIds(Player.Hand) <= beforeA then table.insert(eligible, a) end
    if #b:getCardIds(Player.Hand) <= beforeB then table.insert(eligible, b) end
    if #eligible == 0 then return end

    local grantTo = eligible[1]
    if #eligible > 1 then
      local chosen = room:askToChoosePlayers(player, {
        targets = eligible,
        min_num = 1,
        max_num = 1,
        skill_name = skill.name,
        prompt = "#hanjin__skill_wu014_2-target",
        cancelable = false,
      })
      grantTo = chosen and chosen[1]
    end
    if grantTo == nil or grantTo.dead or grantTo:isRemoved() then return end
    if grantTo:hasSkill(HAOSHI) then return end

    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_wu014_2-grant::" .. grantTo.id,
    }) then
      return
    end

    ensureExpiry(room)
    room:handleAddLoseSkills(grantTo, HAOSHI, skill.name, false, true)
    room:addPlayerMark(grantTo, GRANT_MARK, 1)
  end,
})

skill:addAcquireEffect(function(self, player)
  ensureExpiry(player.room or Fk:currentRoom())
end)

Fk:loadTranslationTable {
  ["hanjin__skill_wu014_2"] = "缔盟",
  [":hanjin__skill_wu014_2"] = "出牌阶段限一次，你可以选择两名其他角色并弃置等同其手牌数差的牌，令其交换手牌，你可以对其中手牌未增加的角色纵横“好施”。",
  ["#hanjin__skill_wu014_2-prompt"] = "缔盟：选择两名其他角色",
  ["#hanjin__skill_wu014_2-discard"] = "缔盟：弃置 %arg 张牌",
  ["#hanjin__skill_wu014_2-target"] = "缔盟：选择一名手牌未增加的角色",
  ["#hanjin__skill_wu014_2-grant"] = "缔盟：你可以令 %dest 纵横“好施”直到其下个回合结束",
}

return skill
