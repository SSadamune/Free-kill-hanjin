-- 六势力变包共用辅助：装备空栏/双坐骑校验、限定翼从逐实例计次、左慈「魂」随牌管理。
-- 客户端可达查询统一使用 Fk:currentRoom() 与公开标记，不访问服务端 room tag 或私有字段。
local R = require "packages.qiao.pkg.qiao_generals.util.retinue_instances"
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
local Change = require "packages.qiao.pkg.qiao_mode.rules.general_change"
local Discard = require "packages.qiao.pkg.qiao_mode.rules.general_discard"
local PrivateMarks = require "packages.qiao.pkg.qiao_mode.rules.private_marks"
local WuLord = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wu"

local M = {}

M.FEIXIONG_SKILL = "qiao__retinue_skill_feixiongjun"
M.LIMITED_RETINUE_MARK = "qiao_bian_retinue_limited"

M.ZUOCI_GENERAL = "qiao_heg__qun009"
M.ZUOCI_SKILL = "qiao__skill_qun009_1"
M.ZUOCI_TAG = "qiao_zuoci_hun_v1"
M.ZUOCI_COUNT_MARK = "@qiao_zuoci_hun"
M.ZUOCI_PRIVATE_MARK = "@&qiao_zuoci_hun"
M.ZUOCI_POOL_AVAILABLE = "qiao_zuoci_pool_available"

local function isServerPlayer(player)
  return player ~= nil and player.room ~= nil and type(player.id) == "number"
end

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

---------------------------------------------------------------------------
-- 限定翼从（如飞熊军）逐实例整局计次与公开摘要同步
---------------------------------------------------------------------------

local LIMITED_RETINUE_SKILLS = {
  [M.FEIXIONG_SKILL] = true,
}

function M.isLimitedRetinueSkill(skillName)
  return LIMITED_RETINUE_SKILLS[skillName] == true
end

function M.publishLimitedRetinues(player)
  if not isServerPlayer(player) then return end
  local data = {}
  for skillName in pairs(LIMITED_RETINUE_SKILLS) do
    local list = {}
    for _, instance in ipairs(R.instancesForSkill(player, skillName)) do
      table.insert(list, instance.uses or 0)
    end
    if #list > 0 then data[skillName] = list end
  end
  player.room:setPlayerMark(player, M.LIMITED_RETINUE_MARK, next(data) ~= nil and data or 0)
end

function M.availableLimitedRetinues(player, skillName)
  if not isServerPlayer(player) then return {} end
  local result = {}
  for _, instance in ipairs(R.instancesForSkill(player, skillName)) do
    if (instance.uses or 0) == 0 then table.insert(result, instance) end
  end
  return result
end

function M.usedLimitedRetinues(player, skillName)
  if not isServerPlayer(player) then return {} end
  local result = {}
  for _, instance in ipairs(R.instancesForSkill(player, skillName)) do
    if (instance.uses or 0) > 0 then table.insert(result, instance) end
  end
  return result
end

--- 两端共用：是否存在尚未发动过的该限定翼从实例。
function M.canUseLimitedRetinue(player, skillName)
  if player == nil then return false end
  if isServerPlayer(player) then
    return #M.availableLimitedRetinues(player, skillName) > 0
  end
  local total = R.countForSkill(player, skillName)
  if total <= 0 then return false end
  local mark = player:getMark(M.LIMITED_RETINUE_MARK)
  local list = type(mark) == "table" and mark[skillName] or nil
  for i = 1, total do
    if (type(list) == "table" and list[i] or 0) == 0 then return true end
  end
  return false
end

function M.spendLimitedRetinue(player, instance, skillName)
  if not isServerPlayer(player) or instance == nil then return false end
  R.recordUse(instance)
  M.publishLimitedRetinues(player)
  return true
end

function M.resetOneLimitedRetinue(player, skillName)
  if not isServerPlayer(player) then return false end
  local used = M.usedLimitedRetinues(player, skillName)
  if #used == 0 then return false end
  used[1].uses = 0
  M.publishLimitedRetinues(player)
  return true
end

R.addChangeListener(function(player) M.publishLimitedRetinues(player) end)

---------------------------------------------------------------------------
-- 左慈「魂」随牌管理（仅持有者私密可见内容，全员公开可见数量）
---------------------------------------------------------------------------

-- 服务端按本局实际候选复核；客户端只读取本次出牌请求前同步的可用性。
function M.canDrawSoul(room)
  if room == RoomInstance then
    return #Change.skillAvailablePool(room, { any_kingdom = true, limit = 1 }) > 0
  end
  return room:getBanner(M.ZUOCI_POOL_AVAILABLE) == true
end

local function zuociRegistry(room)
  local reg = room:getTag(M.ZUOCI_TAG)
  if type(reg) ~= "table" then
    reg = {}
    room:setTag(M.ZUOCI_TAG, reg)
  end
  return reg
end

--- 定位左慈「魂」账本键：武将牌自带【化形】按该牌名归属，角色授技按玩家 ID 归属。
function M.zuociKey(room, player)
  if player ~= nil then
    for _, deputy in ipairs({ false, true }) do
      local general = Exchange.actualGeneral(player, deputy)
      if Exchange.cardProvidesSkill(room, general, M.ZUOCI_SKILL) then
        return "card:" .. general
      end
    end
    return "player:" .. tostring(player.id)
  end
  return "card:" .. M.ZUOCI_GENERAL
end

local function zuociEntry(room, key, create)
  local reg = zuociRegistry(room)
  local entry = reg[key]
  if entry == nil and create then
    entry = { souls = {}, first_used = false, holder_id = nil }
    reg[key] = entry
  end
  return entry
end

--- 同步持有者的公开数量标记与私密武将列表（绝不向其他角色广播私密列表）。
function M.syncZuociMarks(room, holder, souls)
  if room == nil or holder == nil then return end
  souls = souls or {}
  room:setPlayerMark(holder, M.ZUOCI_COUNT_MARK, #souls)
  PrivateMarks.notify(holder, M.ZUOCI_PRIVATE_MARK, #souls > 0 and souls or 0)
end

function M.zuociSouls(room, player)
  if room == nil or player == nil then return {} end
  local entry = zuociEntry(room, M.zuociKey(room, player), false)
  if entry == nil then return {} end
  return table.simpleClone(entry.souls)
end

function M.zuociFirstUsed(room, player)
  if room == nil or player == nil then return false end
  local entry = zuociEntry(room, M.zuociKey(room, player), false)
  return entry ~= nil and entry.first_used == true
end

function M.addZuociSouls(room, player, names, markFirst)
  if room == nil or player == nil then return {} end
  local key = M.zuociKey(room, player)
  local entry = zuociEntry(room, key, true)
  entry.holder_id = player.id
  if markFirst then entry.first_used = true end
  for _, name in ipairs(names or {}) do
    table.insertIfNeed(entry.souls, name)
  end
  room:setTag(M.ZUOCI_TAG, zuociRegistry(room))
  M.syncZuociMarks(room, player, entry.souls)
  return table.simpleClone(entry.souls)
end

function M.removeZuociSoul(room, player, name)
  if room == nil or player == nil or type(name) ~= "string" then return false end
  local key = M.zuociKey(room, player)
  local entry = zuociEntry(room, key, false)
  if entry == nil then return false end
  local removed = table.removeOne(entry.souls, name)
  if removed then
    entry.holder_id = player.id
    room:setTag(M.ZUOCI_TAG, zuociRegistry(room))
    M.syncZuociMarks(room, player, entry.souls)
  end
  return removed
end

function M.discardZuociEntry(room, key, holder)
  local reg = zuociRegistry(room)
  local entry = reg[key]
  if entry == nil then return end
  local souls = entry.souls or {}
  if #souls > 0 then
    Discard.add(room, souls)
  end
  local owner = holder or (entry.holder_id and room:getPlayerById(entry.holder_id))
  entry.souls = {}
  reg[key] = nil
  room:setTag(M.ZUOCI_TAG, reg)
  if owner ~= nil then
    M.syncZuociMarks(room, owner, {})
  end
end

function M.discardPlayerZuociSouls(room, player)
  if room == nil or player == nil then return end
  local reg = zuociRegistry(room)
  local keys = {}
  for key, entry in pairs(reg) do
    if entry.holder_id == player.id then table.insert(keys, key) end
  end
  for _, key in ipairs(keys) do
    M.discardZuociEntry(room, key, player)
  end
end

function M.cleanupDetachedZuociCards(room)
  if room == nil then return end
  local reg = zuociRegistry(room)
  local toDiscard = {}
  for key, entry in pairs(reg) do
    if key:startsWith("card:") then
      local general = key:sub(6)
      local stillHeld = false
      for _, p in ipairs(room.alive_players) do
        if Exchange.actualGeneral(p, false) == general or Exchange.actualGeneral(p, true) == general then
          stillHeld = true
          break
        end
      end
      if not stillHeld then table.insert(toDiscard, key) end
    end
  end
  for _, key in ipairs(toDiscard) do
    M.discardZuociEntry(room, key)
  end
end

--- 汉晋房间级接线：重连序列化时仅为「魂」当前持有者本人的快照补入私密武将名列表，
--- 不向其他座位或旁观者（tellRoomToObserver 借用首座视角生成的 Observe 快照）泄露。
function M.installServer(room)
  PrivateMarks.register(room, M.ZUOCI_PRIVATE_MARK, function(currentRoom, viewer)
    local souls = {}
    for _, entry in pairs(currentRoom:getTag(M.ZUOCI_TAG) or {}) do
      if entry.holder_id == viewer.id then
        for _, name in ipairs(entry.souls) do table.insertIfNeed(souls, name) end
      end
    end
    if #souls > 0 then return souls end
  end)
end

-- 武将变更完成监听：暗置或明置左慈武将牌被变更换走后，余下「魂」立即置入武将弃牌堆并清标记。
Change.addCompletionListener(function(room)
  M.cleanupDetachedZuociCards(room)
end)

-- 武将交换完成监听：同步左慈「魂」归属与伍琼&种辑个人鏖战状态。
Exchange.addCompletionListener(function(room, context)
  if room == nil or context == nil then return end
  local BattleRoyal = require "packages.qiao.pkg.qiao_mode.rules.battle_royal"
  local reg = zuociRegistry(room)
  for _, move in ipairs(context.moved or {}) do
    local key = "card:" .. tostring(move.general)
    local entry = reg[key]
    if entry ~= nil and move.from and move.to and move.from.player ~= move.to.player then
      local oldOwner, newOwner = move.from.player, move.to.player
      entry.holder_id = newOwner.id
      room:setTag(M.ZUOCI_TAG, reg)
      M.syncZuociMarks(room, oldOwner, {})
      M.syncZuociMarks(room, newOwner, entry.souls)
    end
  end
  for _, side in ipairs(context.sides or {}) do
    local p = side.player
    if p ~= nil then
      BattleRoyal.syncPersonal(room, p, "qiao__skill_han023_2",
        not p.dead and p:hasShownSkill("qiao__skill_han023_2", true))
    end
  end
end)

Fk:loadTranslationTable {
  [M.ZUOCI_COUNT_MARK] = "魂",
  [M.ZUOCI_PRIVATE_MARK] = "魂",
}

return M
