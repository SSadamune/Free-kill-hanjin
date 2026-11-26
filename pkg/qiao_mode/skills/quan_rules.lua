-- 六势力权包模式级静态规则：承接已建立持续／延时效果与全房间历史记录，不依赖来源技能后续是否仍在。
-- 包含：
--   1. 刘宏【鬻爵】：本回合下次造成伤害后摸两张牌；
--   2. 曹节【悬壶】：追踪本回合角色手牌/装备区实体红牌置入弃牌堆（含经处理区，不含判定区）；
--   6. 军令四：补充包含手牌的混合转化牌禁使用／打出防护。
local Modes = require "packages.qiao.pkg.qiao_mode.modes"
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"
local Quan = require "packages.qiao.pkg.qiao_generals.util.quan_common"

local skill = fk.CreateSkill { name = "qiao__quan_rules" }

local PROCESSING_OWNER_TAG = "qiao_quan_processing_red_owner_v1"

local function inQiao(room)
  return room ~= nil and type(room.getSettings) == "function" and Modes.inRoom(room)
end

local function processingOwners(room)
  local map = room:getTag(PROCESSING_OWNER_TAG)
  if type(map) ~= "table" then
    map = {}
    room:setTag(PROCESSING_OWNER_TAG, map)
  end
  return map
end

-- 1. 鬻爵：本回合下次造成伤害后摸两张牌（每层独立消费一次，不随刘宏暗置/离场失效）。
skill:addEffect(fk.Damage, {
  global = true,
  is_delay_effect = true,
  mute = true,
  can_trigger = function(self, event, target, player, data)
    return target == player and inQiao(player.room)
      and RemovedTargets.isPresent(player)
      and player:getMark(Quan.YUJUE_DRAW_MARK) > 0
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local stacks = player:getMark(Quan.YUJUE_DRAW_MARK)
    if stacks <= 0 then return end
    room:setPlayerMark(player, Quan.YUJUE_DRAW_MARK, 0)
    for _ = 1, stacks do
      if RemovedTargets.isPresent(player) then
        player:drawCards(2, "qiao__skill_han003_1")
      end
    end
  end,
})

-- 2. 曹节【悬壶】红牌入弃牌堆。
skill:addEffect(fk.AfterCardsMove, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return inQiao(player.room) and player == player.room.alive_players[1] and type(data) == "table"
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    local owners = processingOwners(room)
    for _, move in ipairs(data) do
      -- 悬壶：追踪手牌区/装备区实体红牌直接或经处理区进入弃牌堆（判定区红牌不计入）。
      for _, info in ipairs(move.moveInfo or {}) do
        local id = info.cardId
        local fromHe = info.fromArea == Card.PlayerHand or info.fromArea == Card.PlayerEquip
        if move.toArea == Card.Processing then
          if fromHe and move.from ~= nil then
            owners[id] = move.from.id
          else
            owners[id] = nil
          end
        elseif move.toArea == Card.DiscardPile then
          local ownerId
          if fromHe and move.from ~= nil then
            ownerId = move.from.id
          elseif info.fromArea == Card.Processing then
            ownerId = owners[id]
          end
          owners[id] = nil
          if ownerId ~= nil then
            local card = Fk:getCardById(id, true)
            if card ~= nil and card.color == Card.Red then
              local owner = room:getPlayerById(ownerId)
              if owner ~= nil and owner:getMark(Quan.XUANHU_RED_MARK) == 0 then
                room:setPlayerMark(owner, Quan.XUANHU_RED_MARK, 1)
              end
            end
          end
        elseif info.fromArea == Card.Processing then
          owners[id] = nil
        end
      end
    end
  end,
})

skill:addEffect(fk.TurnEnd, {
  global = true,
  can_refresh = function(self, event, target, player)
    return inQiao(player.room) and player == player.room.alive_players[1]
  end,
  on_refresh = function(self, event, target, player)
    player.room:setTag(PROCESSING_OWNER_TAG, nil)
  end,
})

-- 6. 军令四补充防护：任何包含手牌材料的转化牌同样不得使用或打出。
skill:addEffect("prohibit", {
  prohibit_use = function(self, player, card)
    if player ~= nil and card ~= nil and player:getMark("@@command4_effect-turn") > 0 then
      local subcards = card:isVirtual() and card.subcards or { card.id }
      return #subcards > 0 and table.find(subcards, function(id)
        return table.contains(player:getCardIds(Player.Hand), id)
      end) ~= nil
    end
  end,
  prohibit_response = function(self, player, card)
    if player ~= nil and card ~= nil and player:getMark("@@command4_effect-turn") > 0 then
      local subcards = card:isVirtual() and card.subcards or { card.id }
      return #subcards > 0 and table.find(subcards, function(id)
        return table.contains(player:getCardIds(Player.Hand), id)
      end) ~= nil
    end
  end,
})

Fk:loadTranslationTable {
  ["qiao__quan_rules"] = "权包规则",
}

return skill
