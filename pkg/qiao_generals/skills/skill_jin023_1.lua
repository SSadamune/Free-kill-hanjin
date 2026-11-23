-- JIN023 马隆 · 锋械
-- 出牌阶段限一次：两名角色各一张装备先进入处理区，再进入对方装备区；
-- 若其中一名为自己，随后对另一名或其队列视为使用【杀】。
local H = require "packages.hegemony.util"
local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"

local Wu = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wu"

local skill = fk.CreateSkill {
  name = "qiao__skill_jin023_1",
}
skill.qiaoImplemented = true

local SLASH = "qiao__slash"

local function equipIds(player)
  return player:getCardIds("e")
end

local function canReceive(player, card, outgoing)
  local function hasRoom(subtype)
    local equips = player:getEquipments(subtype)
    local remaining = #equips - (table.contains(equips, outgoing) and 1 or 0)
    return #player:getAvailableEquipSlots(subtype) > remaining
  end
  if Fk.packages.qiao_cards.qiao_cards.isDualMount(card) then
    return hasRoom(Card.SubtypeOffensiveRide) and hasRoom(Card.SubtypeDefensiveRide)
  end
  return hasRoom(card.sub_type)
end

local function protected(owner, chooser, id)
  return owner:hasShownSkill(Wu.JUBAO) and Wu.isProtectedTreasure(owner, chooser, id)
end

local function secondCandidates(chooser, a, b, idA)
  if protected(a, chooser, idA) then return {} end
  local cardA = a:getVirtualEquip(idA) or Fk:getCardById(idA)
  return table.filter(equipIds(b), function(idB)
    local cardB = b:getVirtualEquip(idB) or Fk:getCardById(idB)
    return not protected(b, chooser, idB) and canReceive(b, cardA, idB) and canReceive(a, cardB, idA)
  end)
end

local function firstCandidates(chooser, a, b)
  return table.filter(equipIds(a), function(id)
    return #secondCandidates(chooser, a, b, id) > 0
  end)
end

local function canExchangeWithSomeone(room, chooser, target)
  return table.find(room:getPresentPlayers(), function(other)
    return other ~= target and #firstCandidates(chooser, target, other) > 0
  end) ~= nil
end

local function chooseEquip(room, chooser, target, ids)
  if #ids == 0 then return end
  if #ids == 1 then return ids[1] end
  local id = room:askToChooseCard(chooser, {
    target = target,
    flag = { card_data = { { "$Equip", ids } } },
    skill_name = skill.name,
    prompt = "#qiao__skill_jin023_1-equip::" .. target.id .. ":" .. skill.name,
  })
  if table.contains(ids, id) then return id end
end

local function swapEquips(room, player, a, b, idA, idB)
  local transfers = {
    { from = a, to = b, id = idA, virtual = a:getVirtualEquip(idA) },
    { from = b, to = a, id = idB, virtual = b:getVirtualEquip(idB) },
  }
  local outgoing, incoming = {}, {}
  for _, t in ipairs(transfers) do
    table.insert(outgoing, {
      from = t.from, ids = { t.id }, toArea = Card.Processing,
      moveReason = fk.ReasonExchange, proposer = player, skillName = skill.name, moveVisible = true,
    })
  end
  room:moveCards(table.unpack(outgoing))
  -- 两张牌一起离开后，防移动与嵌套结算可能改变实际空槽。
  for _, t in ipairs(transfers) do
    if room:getCardArea(t.id) == Card.Processing and not t.to.dead and not t.to:isRemoved()
      and canReceive(t.to, t.virtual or Fk:getCardById(t.id)) then
      table.insert(incoming, {
        ids = { t.id }, fromArea = Card.Processing, to = t.to, toArea = Card.PlayerEquip,
        virtualEquip = t.virtual, moveReason = fk.ReasonExchange, proposer = player,
        skillName = skill.name, moveVisible = true,
      })
    end
  end
  if #incoming > 0 then room:moveCards(table.unpack(incoming)) end
  room:cleanProcessingArea({ idA, idB }, skill.name)
end

local function queueTargets(room, other, user, condition)
  local slash = Fk:cloneCard(SLASH)
  local result = { other }
  for _, p in ipairs(H.getFormationRelation(other) or {}) do
    if not p.dead and not p:isRemoved() and C.matchesCondition(room, user, slash, p, condition) then
      table.insertIfNeed(result, p)
    end
  end
  return result
end

skill:addEffect("active", {
  prompt = "#qiao__skill_jin023_1-prompt",
  target_num = 2,
  card_num = 0,
  max_phase_use_time = 1,
  can_use = function(self, player)
    if player.phase ~= Player.Play or player.dead then return false end
    local room = Fk:currentRoom()
    return table.find(room:getPresentPlayers(), function(target)
      return #equipIds(target) > 0 and canExchangeWithSomeone(room, player, target)
    end) ~= nil
  end,
  target_filter = function(self, player, to_select, selected)
    if #selected >= 2 or to_select == nil or to_select.dead or to_select:isRemoved()
      or #equipIds(to_select) == 0 or table.contains(selected, to_select) then return false end
    if #selected == 1 then return #firstCandidates(player, selected[1], to_select) > 0 end
    return canExchangeWithSomeone(Fk:currentRoom(), player, to_select)
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local targets = effect.tos or {}
    if player == nil or player.dead or #targets ~= 2 then return end
    local a, b = targets[1], targets[2]
    if a == nil or b == nil or a == b or a.dead or b.dead or a:isRemoved() or b:isRemoved() then return end

    local idA = chooseEquip(room, player, a, firstCandidates(player, a, b))
    if idA == nil or not table.contains(equipIds(a), idA) then return end
    local idB = chooseEquip(room, player, b, secondCandidates(player, a, b, idA))
    if idB == nil or a.dead or b.dead or a:isRemoved() or b:isRemoved()
      or not table.contains(equipIds(a), idA)
      or not table.contains(secondCandidates(player, a, b, idA), idB) then return end
    swapEquips(room, player, a, b, idA, idB)

    local other
    if a == player then other = b elseif b == player then other = a end
    if other == nil or other.dead or other:isRemoved() then return end

    local condition = {}
    local targetsForSlash = { other }
    local queue = queueTargets(room, other, player, condition)
    if #queue > 1 then
      local choice = room:askToChoice(player, {
        choices = { "single", "queue" },
        skill_name = skill.name,
        prompt = "#qiao__skill_jin023_1-target-group",
        cancelable = false,
      })
      if choice == "queue" then targetsForSlash = queue end
    end

    local policy = C.explicit(condition, {
      names = { SLASH },
      min_targets = 1,
      max_targets = #targetsForSlash,
    })
    C.useVirtualCard(room, player, SLASH, nil, targetsForSlash, skill.name, true, { bypass_times = true }, policy)
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_jin023_1"] = "锋械",
  ["#qiao__skill_jin023_1-prompt"] = "锋械：交换两名角色各一张装备牌，然后可对另一名或其队列使用【杀】",
  ["#qiao__skill_jin023_1-equip"] = "锋械：选择 %dest 一张装备牌",
  ["#qiao__skill_jin023_1-target-group"] = "锋械：选择【杀】的目标组",
  ["single"] = "另一名角色",
  ["queue"] = "其队列",
}

return skill
