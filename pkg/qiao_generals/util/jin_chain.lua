-- 晋势力连环/杀相关的小型公共查询。
--
-- 只放跨技能重复、且不改变规则含义的只读判断：哪些牌属于“杀”、本回合首张
-- 真实【杀】的使用事实、当前横置角色与属性伤害。时机、消耗与效果仍由各技能
-- 自行判断。历史读取直接使用房间事件记录，因此技能尚未取得或尚未明置时发生的
-- 用牌事实仍然保留。
local M = {}

M.ICE_SLASH = "qiao__ice__slash"
M.DUEL = "qiao__duel"

-- 正式牌名与上游测试牌名都按“杀”处理；属性杀仍属于【杀】。
local SLASH_NAMES = {
  slash = true,
  ["qiao__slash"] = true,
  ["qiao__fire__slash"] = true,
  ["qiao__ice__slash"] = true,
  ["qiao__thunder__slash"] = true,
  ["qiao__thunder_shell__slash"] = true,
}

---@param card Card?
---@return boolean
function M.isSlash(card)
  if card == nil then return false end
  return SLASH_NAMES[card.name] == true or card.trueName == "slash"
end

--- 本回合该角色真实使用【杀】的次数（包含当前正在进行的使用事件）。
--- 只读取 UseCard 事件，纯“打出”不计入。
---@param player ServerPlayer
---@return integer
function M.slashUseCountThisTurn(player)
  if player == nil or player.room == nil then return 0 end
  return #player.room.logic:getEventsOfScope(GameEvent.UseCard, 2, function(e)
    local data = e.data
    return data ~= nil and data.from == player and M.isSlash(data.card)
  end, Player.HistoryTurn)
end

--- 本回合是否为该角色首次真实使用【杀】。
---@param player ServerPlayer
---@return boolean
function M.isFirstSlashUseThisTurn(player)
  return M.slashUseCountThisTurn(player) == 1
end

--- 服务端与服务端房间/客户端房间兼容的存活角色列表。
---@param room Room | Client
---@return Player[]
function M.alivePlayers(room)
  if room == nil then return {} end
  local players = room.alive_players
  if players == nil and type(room.getAlivePlayers) == "function" then
    players = room:getAlivePlayers()
  end
  return players or {}
end

--- 当前存活且横置的角色。
---@param room Room | Client
---@return Player[]
function M.chainedAlivePlayers(room)
  return table.filter(M.alivePlayers(room), function(p)
    return p ~= nil and not p.dead and p.chained
  end)
end

--- 当前横置角色数（用于手牌上限）。
---@param room Room | Client
---@return integer
function M.chainedAliveCount(room)
  return #M.chainedAlivePlayers(room)
end

--- 是否为属性伤害：火、雷、冰均属属性伤害。
---@param damageType integer?
---@return boolean
function M.isAttributeDamage(damageType)
  return damageType == fk.FireDamage
    or damageType == fk.ThunderDamage
    or damageType == fk.IceDamage
end

--- 本次使用是否实际造成了伤害。
---@param use UseCardData?
---@return boolean
function M.dealtDamage(use)
  if use == nil then return false end
  for _, num in pairs(use.damageDealt or {}) do
    if (num or 0) > 0 then return true end
  end
  return false
end

return M
