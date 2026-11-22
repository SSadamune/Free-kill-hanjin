-- EM(HAN001) 君刘协 · 天授
-- 两段均为移动前替换：其他角色的玉玺/赤霄剑进入场上或弃牌堆时改入刘协装备区；
-- 刘协从装备区失去这些牌时改置于诏书公开牌堆，原去向不执行；替换后摸两张。
local P = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_han"

local skill = fk.CreateSkill {
  name = P.TIANSHOU,
  tags = { Skill.Compulsory },
}
skill.qiaoImplemented = true
-- 移牌替换及后续摸牌有明确的结算时机。
skill.qiaoStateOnly = false

local CARDS = { ["qiao__jade_seal"] = true, ["qiao__chixiao_sword"] = true }
local GUARD = "qiao_em_han001_tianshou_guard"

local function isTargetCard(id)
  local card = Fk:getCardById(id, true)
  return card ~= nil and CARDS[card.name] == true
end

skill:addEffect(fk.BeforeCardsMove, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    if player == nil or not player:hasSkill(skill.name) or player:getMark(GUARD) > 0 then return false end
    for _, move in ipairs(data or {}) do
      for _, info in ipairs(move.moveInfo or {}) do
        if isTargetCard(info.cardId) then
          if move.from ~= nil and move.from ~= player
            and (info.fromArea == Card.PlayerHand or info.fromArea == Card.PlayerEquip)
            and (move.toArea == Card.PlayerEquip or move.toArea == Card.DiscardPile)
            and player:canMoveCardIntoEquip(info.cardId, false) then
            return true
          end
          if move.from == player and info.fromArea == Card.PlayerEquip then
            return true
          end
        end
      end
    end
    return false
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, GUARD, 1)
    local rebuilt = {}
    for _, move in ipairs(data or {}) do
      local normal, toEquip, toPile = {}, {}, {}
      for _, info in ipairs(move.moveInfo or {}) do
        if isTargetCard(info.cardId) then
          if move.from ~= nil and move.from ~= player
            and (info.fromArea == Card.PlayerHand or info.fromArea == Card.PlayerEquip)
            and (move.toArea == Card.PlayerEquip or move.toArea == Card.DiscardPile)
            and player:canMoveCardIntoEquip(info.cardId, false) then
            table.insert(toEquip, info)
          elseif move.from == player and info.fromArea == Card.PlayerEquip then
            table.insert(toPile, info)
          else
            table.insert(normal, info)
          end
        else
          table.insert(normal, info)
        end
      end
      if #normal > 0 then
        move.moveInfo = normal
        table.insert(rebuilt, move)
      end
      if #toEquip > 0 then
        table.insert(rebuilt, MoveCardsData:new {
          from = move.from, to = player, toArea = Card.PlayerEquip,
          moveReason = move.moveReason, proposer = move.proposer,
          skillName = skill.name, moveVisible = false, moveInfo = toEquip,
          moveMark = move.moveMark, visiblePlayers = move.visiblePlayers,
          extra_data = move.extra_data,
        })
      end
      if #toPile > 0 then
        table.insert(rebuilt, MoveCardsData:new {
          from = player, to = player, toArea = Card.PlayerSpecial,
          specialName = P.PILE, moveReason = fk.ReasonPut,
          proposer = player, skillName = skill.name, moveVisible = true,
          moveInfo = toPile, moveMark = move.moveMark,
          visiblePlayers = move.visiblePlayers, extra_data = move.extra_data,
        })
      end
    end
    for i = #data, 1, -1 do data[i] = nil end
    for _, move in ipairs(rebuilt) do table.insert(data, move) end
    room:setPlayerMark(player, GUARD, 0)
  end,
})

skill:addEffect(fk.AfterCardsMove, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    if player == nil or player.dead or player:getMark(GUARD) > 0 then return false end
    for _, move in ipairs(data or {}) do
      if move.to == player and move.toArea == Card.PlayerSpecial
        and move.specialName == P.PILE and move.skillName == skill.name then
        for _, info in ipairs(move.moveInfo or {}) do
          if isTargetCard(info.cardId) then return true end
        end
      end
    end
    return false
  end,
  on_refresh = function(self, event, target, player, data)
    local count = 0
    for _, move in ipairs(data or {}) do
      if move.to == player and move.toArea == Card.PlayerSpecial
        and move.specialName == P.PILE and move.skillName == skill.name then
        for _, info in ipairs(move.moveInfo or {}) do
          if isTargetCard(info.cardId) and info.fromArea == Card.PlayerEquip then count = count + 1 end
        end
      end
    end
    if count > 0 and not player.dead then player:drawCards(count * 2, skill.name) end
  end,
})

Fk:loadTranslationTable {
  [P.TIANSHOU] = "天授",
  [":" .. P.TIANSHOU] = "锁定技，其他角色的【玉玺】或【赤霄剑】置入场上或弃牌堆时，改为置入你装备区。当你从装备区失去这些牌时，改为置于“诏书”上并摸两张牌。",
}

return skill
