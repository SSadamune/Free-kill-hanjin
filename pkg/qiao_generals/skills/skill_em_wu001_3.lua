-- EM(WU001) 孙权 · 聚宝
-- 锁定技：防止其他角色不因弃置而移动你装备着的宝物牌；结束阶段若
-- 【定澜夜明珠】在场上或弃牌堆，摸一张牌，并获得装备着该牌的角色一张牌。
local P = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wu"

local skill = fk.CreateSkill {
  name = P.JUBAO,
  tags = { Skill.Compulsory },
}
skill.qiaoImplemented = true

local function isPearl(id)
  local card = Fk:getCardById(id, true)
  return card ~= nil and card.name == P.PEARL
end

local function isTreasure(id)
  local card = Fk:getCardById(id, true)
  return card ~= nil and card.type == Card.TypeEquip
    and card.sub_type == Card.SubtypeTreasure
end

local function equippedPearlIds(player)
  return table.filter(player:getEquipments(Card.SubtypeTreasure), isPearl)
end

local function pearlOnField(room)
  if table.find(room.discard_pile, isPearl) ~= nil then return true end
  for _, p in ipairs(room:getPresentPlayers()) do
    if not p.dead and not p:isRemoved() then
      for _, id in ipairs(p:getCardIds("ej")) do
        if isPearl(id) then return true end
      end
    end
  end
  return false
end

skill:addEffect(fk.BeforeCardsMove, {
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(skill.name) then return false end
    for _, move in ipairs(data or {}) do
      if move.from == player and move.to ~= move.from and move.moveReason ~= fk.ReasonDiscard
        and move.proposer ~= nil and move.proposer ~= player then
        for _, info in ipairs(move.moveInfo or {}) do
          if info.fromArea == Card.PlayerEquip and isTreasure(info.cardId) then return true end
        end
      end
    end
    return false
  end,
  on_use = function(self, event, target, player, data)
    local ids = {}
    for _, move in ipairs(data or {}) do
      if move.from == player and move.to ~= move.from and move.moveReason ~= fk.ReasonDiscard
        and move.proposer ~= nil and move.proposer ~= player then
        for _, info in ipairs(move.moveInfo or {}) do
          if info.fromArea == Card.PlayerEquip and isTreasure(info.cardId) then
            table.insert(ids, info.cardId)
          end
        end
      end
    end
    if #ids > 0 then player.room:cancelMove(data, ids) end
  end,
})

skill:addEffect(fk.EventPhaseStart, {
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and player.phase == Player.Finish
      and player:hasSkill(skill.name) and pearlOnField(player.room)
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    player:drawCards(1, skill.name)
    if player.dead then return end
    local targets = table.filter(room:getPresentPlayers(), function(p)
      return not p.dead and not p:isRemoved() and #equippedPearlIds(p) > 0
    end)
    if #targets == 0 then return end
    room:sortByAction(targets)
    for _, t in ipairs(targets) do
      local flag = t == player and "e" or "he"
      local card = room:askToChooseCard(player, {
        target = t,
        flag = flag,
        skill_name = skill.name,
        prompt = "#qiao__em_wu001_jubao-obtain::" .. t.id .. ":" .. skill.name,
      })
      if card ~= nil then
        room:obtainCard(player, card, false, fk.ReasonPrey, player, skill.name)
      end
    end
  end,
})

Fk:loadTranslationTable {
  [P.JUBAO] = "聚宝",
  ["#qiao__em_wu001_jubao-obtain"] = "聚宝：选择 %dest 的一张牌获得",
  [":" .. P.JUBAO] = "锁定技，防止其他角色不因弃置而移动你装备着的宝物牌。结束阶段，若【定澜夜明珠】在场上或弃牌堆，你摸一张牌，获得装备着该牌的角色一张牌。",
}

return skill
