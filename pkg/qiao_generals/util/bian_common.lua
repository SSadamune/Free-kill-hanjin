-- 六势力变包共用辅助。
-- 客户端可达查询统一使用 Fk:currentRoom() 与公开标记，不访问服务端 room tag 或私有字段。
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
local WuLord = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wu"

local M = {}

---------------------------------------------------------------------------
-- 装备移动与双副类别坐骑空栏校验（两端共用）
---------------------------------------------------------------------------

function M.isDualMount(card)
  if card == nil then return false end
  local pack = Fk.packages and Fk.packages.qiao_cards
  local api = pack and pack.qiao_cards
  if api and api.isDualMount then return api.isDualMount(card) end
  return card.name == "qiao__liulongcanjia"
    or card.name == "qiao__linxiao_yuyu"
    or card.name == "qiao__feiyun_gaihai"
end

--- 判断 from 装备区的 cardId 能否合法移动到 to 的空置装备栏（含双副类别坐骑双空栏与明置【聚宝】宝物保护）。
function M.canMoveEquipTo(from, to, cardId, mover)
  if from == nil or to == nil or from == to then return false end
  if from.dead or from:isRemoved() or to.dead or to:isRemoved() then return false end
  if not table.contains(from:getCardIds(Player.Equip), cardId) then return false end
  -- 明置【聚宝】防止其他角色不因弃置而移动其装备区宝物牌（仅读公开技能状态，不泄露暗将）。
  if mover ~= nil and mover ~= from and from:hasShownSkill(WuLord.JUBAO)
    and WuLord.isProtectedTreasure(from, mover, cardId) then
    return false
  end
  local card = from:getVirtualEquip(cardId) or Fk:getCardById(cardId)
  if card == nil or card.type ~= Card.TypeEquip then return false end
  if M.isDualMount(card) then
    return #to:getAvailableEquipSlots(Card.SubtypeOffensiveRide) > 0
      and #to:getEquipments(Card.SubtypeOffensiveRide) == 0
      and #to:getAvailableEquipSlots(Card.SubtypeDefensiveRide) > 0
      and #to:getEquipments(Card.SubtypeDefensiveRide) == 0
  end
  return from:canMoveCardInBoardTo(to, cardId)
end

--- 返回在场角色中可参与装备移动的 (froms, tos)，排除 excludedIds 中已操作过的装备与受保护宝物。
function M.boardEquipParticipants(room, excludedIds, mover)
  local froms, tos = {}, {}
  if room == nil then return froms, tos end
  local excluded = excludedIds or {}
  local players = room:getPresentPlayers()
  for _, from in ipairs(players) do
    local equips = from:getCardIds(Player.Equip)
    if #equips > 0 then
      for _, id in ipairs(equips) do
        if not excluded[id] then
          for _, to in ipairs(players) do
            if M.canMoveEquipTo(from, to, id, mover) then
              table.insertIfNeed(froms, from)
              table.insertIfNeed(tos, to)
            end
          end
        end
      end
    end
  end
  return froms, tos
end

--- 两名角色之间当前可移动的装备牌分组（排除 excludedIds），按原持有者座位分组。
function M.movableEquipGroups(one, two, excludedIds, mover)
  local excluded = excludedIds or {}
  local groups = {}
  local function collect(owner, other)
    local ids = {}
    for _, id in ipairs(owner:getCardIds(Player.Equip)) do
      if not excluded[id] and M.canMoveEquipTo(owner, other, id, mover) then
        table.insert(ids, id)
      end
    end
    if #ids > 0 then
      table.insert(groups, { "seat#" .. tostring(owner.seat), ids })
    end
  end
  collect(one, two)
  collect(two, one)
  return groups
end

-- 武将交换完成监听：同步伍琼&种辑个人鏖战状态。
Exchange.addCompletionListener(function(room, context)
  if room == nil or context == nil then return end
  local BattleRoyal = require "packages.qiao.pkg.qiao_mode.rules.battle_royal"
  for _, side in ipairs(context.sides or {}) do
    local p = side.player
    if p ~= nil then
      BattleRoyal.syncPersonal(room, p, "qiao__skill_han023_2",
        not p.dead and p:hasShownSkill("qiao__skill_han023_2", true))
    end
  end
end)

return M
