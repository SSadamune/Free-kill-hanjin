-- EM(QUN010) 张角君主版的黄巾天兵符公共入口。
-- 天兵是张角私人牌堆中的公开旗；这里只负责计数、公开数值修正和变化通知。
local H = require "packages.hegemony.util"

local M = {}

M.PILE = "qiao_em_qun010_tianbing"
M.BANNER_SKILL = "qiao__em_qun010_banner"
-- 旗第二段的视技入口：当前群势力角色可将一张“天兵”当雷【杀】使用或打出。
M.ENTRY = "qiao__skill_em_qun010_tianbing"
M.listeners = {}

--- 当前持旗且仍在场的角色。默认 hasSkill 会同时排除死亡与技能失效状态。
--- 只读技能、在场与势力状态，客户端与服务端共用。
---@param room Room|Client
---@return Player[]
function M.flagHolders(room)
  local holders = {}
  if room == nil then return holders end
  for _, player in ipairs(room.players) do
    if not player:isRemoved() and player:hasSkill(M.BANNER_SKILL) then
      holders[#holders + 1] = player
    end
  end
  return holders
end

--- 旗上全部“天兵”的公开 id 表；旗不存在时为空。
---@param room Room|Client
---@return integer[]
function M.tianbingIds(room)
  local ids = {}
  for _, holder in ipairs(M.flagHolders(room)) do
    table.insertTable(ids, holder:getPile(M.PILE))
  end
  return ids
end

--- 该牌当前是否仍是某面旗上的“天兵”。
---@param room Room|Client
---@param id integer
---@return boolean
function M.isTianbing(room, id)
  if room == nil or id == nil then return false end
  for _, holder in ipairs(M.flagHolders(room)) do
    if table.contains(holder:getPile(M.PILE), id) then return true end
  end
  return false
end

function M.addListener(listener)
  assert(type(listener) == "function", "天兵 listener must be a function")
  table.insert(M.listeners, listener)
  return listener
end

function M.count(player)
  if player == nil then return 0 end
  return #player:getPile(M.PILE)
end

function M.total(room)
  local total = 0
  for _, player in ipairs(room.players) do total = total + M.count(player) end
  return total
end

local function notify(room, old, new)
  for _, listener in ipairs(table.simpleClone(M.listeners)) do
    listener(room, old, new)
  end
end

--- 将牌置于天兵旗；批量只通知一次。
function M.add(player, ids, skillName)
  if player == nil or ids == nil or #ids == 0 then return end
  local old = M.count(player)
  player:addToPile(M.PILE, ids, true, skillName or M.BANNER_SKILL)
  notify(player.room, old, M.count(player))
end

--- 从旗移除天兵；只移动当前确在旗牌堆中的牌。
--- 返回是否确有牌离开旗牌堆；取消、重定向未生效或传入牌不在旗上时不通知监听。
function M.remove(player, ids, skillName)
  if player == nil or ids == nil or #ids == 0 then return false end
  local old = M.count(player)
  local pile = player:getPile(M.PILE)
  local moving = table.filter(ids, function(id) return table.contains(pile, id) end)
  if #moving == 0 then return false end
  player.room:moveCardTo(moving, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile,
    skillName or M.BANNER_SKILL, nil, true, player)
  local new = M.count(player)
  if new ~= old then notify(player.room, old, new) end
  return new < old
end

--- 旗使群势力角色数视为 +天兵数；用于大小势力判断/悟心。
function M.kingdomCount(room, kingdom)
  -- 公共 getKingdomPlayersNum 已在 installCountAdapter 中叠加旗；这里不再重复加。
  return H.getKingdomPlayersNum(room, false)[kingdom] or 0
end

--- 大势力角色数：角色数最大且大于1的每个势力，累计其修正后角色数。
--- 天兵带来的群人数修正只加在群势力的数值上，不虚构角色对象。
function M.largeCount(room)
  local counts = H.getKingdomPlayersNum(room, false)
  local max = 0
  for _, count in pairs(counts) do max = math.max(max, count) end
  if max < 2 then return 0 end
  local total = 0
  for _, count in pairs(counts) do
    if count == max then total = total + count end
  end
  return total
end

local function isQiaoRoom(room)
  return room ~= nil and type(room.getSettings) == "function"
    and room:getSettings("gameMode") == "qiao_heg_mode"
end

-- 将旗的天兵数接入公共人数 API；只在汉晋房间生效，其他模式调用原函数。
local installed = false
local physicalKingdom, physicalSame
local suppressed = setmetatable({}, {__mode="k"})
function M.physicalCounts(room, includeDead)
  return physicalKingdom(room, includeDead)
end
function M.withPhysicalCount(room, fn)
  local previous=suppressed[room]
  suppressed[room]=true
  local results=table.pack(pcall(fn))
  suppressed[room]=previous
  if not results[1] then error(results[2],0) end
  return table.unpack(results,2,results.n)
end
function M.installCountAdapter()
  if installed then return end
  installed = true
  local originalKingdom = H.getKingdomPlayersNum
  local originalSame = H.getSameKingdomPlayersNum
  physicalKingdom,physicalSame=originalKingdom,originalSame
  H.getKingdomPlayersNum = function(room, includeDead)
    local result = originalKingdom(room, includeDead)
    if isQiaoRoom(room) and not suppressed[room] then
      result.qun = (result.qun or 0) + M.total(room)
    end
    return result
  end
  H.getSameKingdomPlayersNum = function(room, player, kingdom, includeDead)
    local count = originalSame(room, player, kingdom, includeDead)
    if isQiaoRoom(room) and not suppressed[room] then
      local k = kingdom
      if player ~= nil then k = H.getKingdom(player) end
      if k == "qun" then count = count + M.total(room) end
    end
    return count
  end
end

M.installCountAdapter()

return M
