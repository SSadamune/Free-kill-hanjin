-- 势力锦囊的公共入口。
--
-- 规则依据：docs/rules/card-deck.md「5. 势力锦囊（仅通过特殊手段加入）」及
-- 「势力锦囊的结算审阅」，docs/rules/faction-ban.md BAN-004 第 7、8 条。
-- 七张实体牌、牌位与默认牌堆排除仍由 pkg/qiao_cards 与 rules/cards.lua 登记；
-- 本模块只提供两项公共判定，不定义任何牌面效果：
--   * 按牌本身身份取得所属势力（不按同名牌、同花色点数或锁定视为推断）；
--   * 用牌时记录「使用者是否已确定为该牌所属势力」，供本次用牌的势力效果读取。
-- 后续受益者各自的势力条件由各牌在对应时点用 isConfirmedKingdom 自行核对。
local Cards = require "packages.qiao.pkg.qiao_mode.rules.cards"

local M = {}

--- 用牌数据 extra_data 上的快照键；一次用牌只写一次。
M.USE_KEY = "qiao_faction_trick_use"
--- fk.CardUsing 记录快照的防重入标记，值为事件 id。
M.USE_TAG = "qiao_faction_trick_use_event"
--- BeforeCardsMove 移出游戏改道的防重入标记，值为事件 id。
M.MOVE_TAG = "qiao_faction_trick_move"

--- 牌的所属势力。先看实体牌自身元数据，再看独立牌型；两者都不依赖实例区域。
---@param card Card|nil
---@return string|nil
function M.kingdomOf(card)
  if card == nil then return nil end
  local data = card.extra_data
  if type(data) == "table" then
    local kingdom = data.qiao_faction_trick or data.qiao_kingdom
    if kingdom ~= nil then return kingdom end
  end
  local name = card.name or card.trueName
  if name == nil then return nil end
  local registered = Cards.tricks[name]
  if registered ~= nil then return registered end
  -- room:printCard 生成的副本不继承 extra_data；牌型仍带有正式登记。
  local prototype = Fk.all_card_types[name]
  local prototypeData = prototype and prototype.extra_data
  if type(prototypeData) == "table" then
    return prototypeData.qiao_faction_trick or prototypeData.qiao_kingdom
  end
  return nil
end

---@param card Card|nil
---@return boolean
function M.isFactionTrick(card)
  return M.kingdomOf(card) ~= nil
end

--- 角色此刻是否已确定为某势力。势力尚未公开确定时不满足。
--- 只读公开的 player.kingdom：野心家的 kingdom 即 "wild"，与其锦囊的所属势力一致。
---@param player Player|nil
---@param kingdom string|nil
---@return boolean
function M.isConfirmedKingdom(player, kingdom)
  if player == nil or kingdom == nil then return false end
  return player.kingdom == kingdom
end

--- 用牌时写入本次用牌的势力快照；返回写入的记录。
---@param use UseCardData
---@return table|nil
function M.recordUse(use)
  if use == nil then return nil end
  local kingdom = M.kingdomOf(use.card)
  if kingdom == nil then return nil end
  local entry = {
    kingdom = kingdom,
    user = use.from and use.from.id or nil,
    confirmed = M.isConfirmedKingdom(use.from, kingdom),
  }
  use.extra_data = use.extra_data or {}
  use.extra_data[M.USE_KEY] = entry
  return entry
end

--- 本次用牌的势力效果是否成立：只读用牌时的快照，不重新核对此刻的势力。
---@param extra_data table|nil
---@return boolean, table|nil
function M.useConfirmed(extra_data)
  local entry = type(extra_data) == "table" and extra_data[M.USE_KEY] or nil
  return type(entry) == "table" and entry.confirmed == true, entry
end

return M
