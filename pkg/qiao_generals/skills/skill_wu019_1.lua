-- WU019 陆抗 · 决堰
-- 主将技（☯️-1），准备阶段，你可以选择区域内一张牌，令一名其他角色将此牌当冰【杀】对你使用，
-- 然后你令本回合摸牌阶段摸牌数、使用【杀】次数、攻击范围共计+3。
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"
local Quan = require "packages.qiao.pkg.qiao_generals.util.quan_common"

local skill = fk.CreateSkill {
  name = "qiao__skill_wu019_1",
  tags = { Skill.MainPlace },
}
skill.qiaoImplemented = true

local allocations = {}
for draw = 0, 3 do
  for slash = 0, 3 - draw do
    table.insert(allocations, { draw = draw, slash = slash, range = 3 - draw - slash })
  end
end

local function buildIceSlash(cardId)
  local card = Fk:cloneCard("qiao__ice__slash")
  card:addSubcard(cardId)
  card.skillName = skill.name
  return card
end

local function legalUsersForCard(room, player, cardId)
  local ice = buildIceSlash(cardId)
  return table.filter(room:getPresentPlayers(), function(other)
    return other ~= player
      and not other:prohibitUse(ice)
      and not other:isProhibited(player, ice)
      and other:canUseTo(ice, player, { bypass_distances = true, bypass_times = true })
  end)
end

local function legalAreaGroups(room, player)
  local groups, flat = {}, {}
  local specs = {
    { "$Hand", player:getCardIds("h") },
    { "$Equip", player:getCardIds("e") },
    { "$Judge", player:getCardIds("j") },
  }
  for _, spec in ipairs(specs) do
    local valid = table.filter(spec[2], function(id)
      return #legalUsersForCard(room, player, id) > 0
    end)
    if #valid > 0 then
      table.insert(groups, { spec[1], valid })
      table.insertTable(flat, valid)
    end
  end
  return groups, flat
end

skill:addEffect(fk.EventPhaseStart, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    if target ~= player or player.phase ~= Player.Start or not RemovedTargets.isPresent(player) then
      return false
    end
    if not player:hasSkill(skill.name) then return false end
    local _, flat = legalAreaGroups(player.room, player)
    return #flat > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local groups, flat = legalAreaGroups(room, player)
    if #flat == 0 then return false end
    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_wu019_1-invoke",
    }) then
      return false
    end
    local cardId = #flat == 1 and flat[1] or room:askToChooseCard(player, {
      target = player,
      flag = { card_data = groups },
      skill_name = skill.name,
      prompt = "#qiao__skill_wu019_1-card",
    })
    if cardId == nil or not table.contains(flat, cardId) then
      cardId = flat[1]
    end
    local users = legalUsersForCard(room, player, cardId)
    if #users == 0 then return false end
    local chosen = room:askToChoosePlayers(player, {
      targets = users,
      min_num = 1,
      max_num = 1,
      skill_name = skill.name,
      prompt = "#qiao__skill_wu019_1-user",
      cancelable = false,
    })
    local user = (chosen and chosen[1]) or users[1]
    if user == nil then return false end
    event:setCostData(self, { card = cardId, user = user })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self) or {}
    local cardId, user = cost.card, cost.user
    if not RemovedTargets.isPresent(player) or not RemovedTargets.isPresent(user) then return end
    if cardId == nil or not table.contains(player:getCardIds("hej"), cardId) then return end
    local ice = buildIceSlash(cardId)
    if user:prohibitUse(ice) or user:isProhibited(player, ice) then return end

    -- 先由该其他角色将此区域内牌当冰【杀】对陆抗使用（无视距离与通常次数）。
    room:useCard {
      from = user,
      tos = { player },
      card = ice,
      extraUse = true,
    }

    -- 然后（冰【杀】结算完毕后），若陆抗仍存活，将共计 3 点自由分配至三项。
    if not RemovedTargets.isPresent(player) then return end
    local reply = room:askToCustomDialog(player, {
      skill_name = skill.name,
      component = {
        url = "packages/qiao/pkg/qiao_mode/qml/ZhoujunValueBox.qml",
        prop = {
          prompt = "#qiao__skill_wu019_1-alloc", options = allocations,
          baseValues = { draw = 0, slash = 0, range = 0 },
          thirdStat = "range", thirdLabel = "攻击范围", cancelable = false,
          instruction = "分配本回合的 3 点增益，可调整已分配的点数",
        },
      },
    })
    if not RemovedTargets.isPresent(player) then return end
    local chosen = type(reply) == "table" and table.find(allocations, function(a)
      return a.draw == reply.draw and a.slash == reply.slash and a.range == reply.range
    end) or nil
    chosen = chosen or { draw = 3, slash = 0, range = 0 }
    for key, mark in pairs({ draw = Quan.JUEYAN_DRAW_MARK, slash = Quan.JUEYAN_SLASH_MARK, range = Quan.JUEYAN_RANGE_MARK }) do
      if chosen[key] > 0 then room:addPlayerMark(player, mark, chosen[key]) end
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "决堰",
  [":" .. skill.name] = "主将技（☯️-1），准备阶段，你可以选择区域内一张牌，令一名其他角色将此牌当冰【杀】对你使用，然后你令本回合摸牌阶段摸牌数、使用【杀】次数、攻击范围共计+3。",
  ["#qiao__skill_wu019_1-invoke"] = "决堰：是否选择区域内一张牌令一名其他角色当冰【杀】对你使用？",
  ["#qiao__skill_wu019_1-card"] = "决堰：选择你区域内的一张牌（手牌、装备或判定区）",
  ["#qiao__skill_wu019_1-user"] = "决堰：选择一名其他角色将此牌当冰【杀】对你使用",
  ["#qiao__skill_wu019_1-alloc"] = "决堰：分配 3 点增益",
}

return skill
