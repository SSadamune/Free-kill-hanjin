-- JIN011 张虎&乐綝 · 果毅
--
-- 规则基线：docs/rules/generals/jin011-zhanghu-yuechen.md。
-- 出牌阶段限一次：实际弃置至少一张基本牌，并选择等量名有牌的其他角色。
-- 每名目标各自选择“弃置其装备区一张牌”或“获得其一张手牌”；两项均有人
-- 选过时，发动者才可对其中一名目标造成1点伤害。选牌操作者始终是发动者，
-- 目标自己的选择只决定分支。牌数必须与目标数相等，不能以弃零牌发动。
local skill = fk.CreateSkill {
  name = "qiao__skill_jin011_1",
}

local OPTION_EQUIP = "qiao__skill_jin011_1-equip"
local OPTION_HAND = "qiao__skill_jin011_1-hand"

--- 候选基本牌：自己手牌区或装备区中、当前可以弃置的基本牌。
---@param player ServerPlayer | ClientPlayer
---@return integer[]
local function basicCardIds(player)
  return table.filter(player:getCardIds("he"), function(id)
    return Fk:getCardById(id).type == Card.TypeBasic and not player:prohibitDiscard(id)
  end)
end

--- “有牌”按技能后续两个分支可执行的范围理解：手牌区或装备区至少有一张。
---@param player Player
---@return boolean
local function hasCards(player)
  return #player:getCardIds(Player.Hand) > 0 or #player:getCardIds(Player.Equip) > 0
end

---@return ServerPlayer[] | ClientPlayer[]
local function alivePlayers()
  local room = Fk:currentRoom()
  if room == nil then return {} end
  return room:getPresentPlayers()
end

--- 有牌的其他角色。
---@param player Player
---@return Player[]
local function candidateTargets(player)
  return table.filter(alivePlayers(), function(p)
    return p ~= player and not p.dead and not p:isRemoved() and hasCards(p)
  end)
end

--- 执行一名目标选择的分支。返回值记录的是“该目标选择了哪一项”，不是该分支
--- 的移牌后来是否成功：选择后插入的移牌/失去牌结算不能抹除已选择事实。
---@param room Room
---@param player ServerPlayer
---@param to ServerPlayer
---@return boolean? choseEquip
---@return boolean? choseHand
local function resolveTarget(room, player, to)
  local equipIds = table.filter(to:getCardIds(Player.Equip), function(id)
    return not to:prohibitDiscard(id)
  end)
  local handIds = to:getCardIds(Player.Hand)

  local choices = {}
  if #equipIds > 0 then table.insert(choices, OPTION_EQUIP) end
  if #handIds > 0 then table.insert(choices, OPTION_HAND) end
  if #choices == 0 then return false, false end

  local option = choices[1]
  if #choices > 1 then
    option = room:askToChoice(to, {
      choices = choices,
      skill_name = skill.name,
      prompt = "#qiao__skill_jin011_1-branch:" .. player.id,
      cancelable = false,
    })
  end
  local choseEquip = option == OPTION_EQUIP
  local choseHand = option == OPTION_HAND

  if choseEquip then
    local id = equipIds[1]
    if #equipIds > 1 then
      id = room:askToChooseCard(player, {
        target = to,
        flag = "e",
        skill_name = skill.name,
        prompt = "#qiao__skill_jin011_1-equip:" .. to.id,
      })
    end
    if id ~= nil and id ~= -1 and table.contains(to:getCardIds(Player.Equip), id) then
      room:throwCard({ id }, skill.name, to, player)
    end
  elseif choseHand then
    local id = handIds[1]
    if #handIds > 1 then
      id = room:askToChooseCard(player, {
        target = to,
        flag = "h",
        skill_name = skill.name,
        prompt = "#qiao__skill_jin011_1-hand:" .. to.id,
      })
    end
    if id ~= nil and id ~= -1 and table.contains(to:getCardIds(Player.Hand), id) then
      room:obtainCard(player, id, false, fk.ReasonPrey, player, skill.name)
    end
  end
  return choseEquip, choseHand
end

skill:addEffect("active", {
  anim_type = "offensive",
  prompt = "#qiao__skill_jin011_1-prompt",
  max_phase_use_time = 1,
  include_equip = true,
  min_card_num = 1,
  max_card_num = function(self, player) return #basicCardIds(player) end,
  min_target_num = 1,
  max_target_num = function(self, player) return #candidateTargets(player) end,
  card_filter = function(self, player, to_select, selected)
    if #selected >= #basicCardIds(player) then return false end
    return table.contains(basicCardIds(player), to_select)
  end,
  target_filter = function(self, player, to_select, selected)
    if to_select == player or to_select.dead or to_select:isRemoved() then return false end
    if #selected >= #candidateTargets(player) then return false end
    return hasCards(to_select)
  end,
  -- 客户端确认键的正式过滤：已选目标数必须与已选基本牌数相等。
  feasible = function(self, player, selected, selected_cards)
    return #selected_cards >= 1 and #selected >= 1 and #selected == #selected_cards
  end,
  can_use = function(self, player)
    return self:withinTimesLimit(player, Player.HistoryPhase)
      and #basicCardIds(player) > 0
      and #candidateTargets(player) > 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    if player == nil or player.dead then return end
    local cards = table.simpleClone(effect.cards or {})
    local targets = table.simpleClone(effect.tos or {})

    -- 服务端复核：至少一张基本牌且与目标数完全相等；所有素材仍属本人。
    if #cards < 1 or #cards ~= #targets then return end
    local legalCards = basicCardIds(player)
    for _, id in ipairs(cards) do
      if not table.contains(legalCards, id) then return end
    end
    local legalTargets = candidateTargets(player)
    local seen = {}
    for _, to in ipairs(targets) do
      if not table.contains(legalTargets, to) or seen[to] then return end
      seen[to] = true
    end

    -- 实际弃置作为发动消耗；不足一张则整次不生效。
    room:throwCard(cards, skill.name, player, player)
    if player.dead then return end

    room:sortByAction(targets)
    -- 只统计各目标实际选择过的分支；之后插入的移牌不影响“已选择”事实。
    local choseEquip, choseHand = false, false
    for _, to in ipairs(targets) do
      if player.dead then break end
      if not to.dead and not to:isRemoved() then
        local equip, hand = resolveTarget(room, player, to)
        choseEquip = choseEquip or equip
        choseHand = choseHand or hand
      end
    end

    if player.dead or not (choseEquip and choseHand) then return end
    local aliveTargets = table.filter(targets, function(p)
      return p:isAlive() and not p:isRemoved()
    end)
    if #aliveTargets == 0 then return end
    local chosen = room:askToChoosePlayers(player, {
      min_num = 1,
      max_num = 1,
      targets = aliveTargets,
      skill_name = skill.name,
      prompt = "#qiao__skill_jin011_1-damage",
      cancelable = true,
    })
    local to = chosen and chosen[1]
    if to == nil then return end
    room:damage {
      from = player,
      to = to,
      damage = 1,
      skillName = skill.name,
    }
  end,
})

skill.qiaoImplemented = true

Fk:loadTranslationTable {
  [OPTION_EQUIP] = "你弃置其装备区一张牌",
  [OPTION_HAND] = "你获得其一张手牌",
  ["#qiao__skill_jin011_1-prompt"] = "果毅：弃置至少一张基本牌并选择等量名有牌的其他角色",
  ["#qiao__skill_jin011_1-branch"] = "果毅：%src 令你选择一项",
  ["#qiao__skill_jin011_1-equip"] = "果毅：选择 %dest 装备区一张牌弃置",
  ["#qiao__skill_jin011_1-hand"] = "果毅：获得 %dest 的一张手牌",
  ["#qiao__skill_jin011_1-damage"] = "果毅：两项均有人选过，你可以对其中一名角色造成1点伤害",
}

return skill
