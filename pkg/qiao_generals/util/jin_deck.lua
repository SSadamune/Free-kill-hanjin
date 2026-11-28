-- JIN009 权变/骤霆的公共变量与手牌身份判断。
local M = {}

M.BAN_DISPLAY = "@qiao_qianbian-phase"
M.BAN_SUITS = "qiao_jin009_1_ban_suits-phase"
M.USED_SUITS = "qiao_jin009_1_used_suits-phase"
M.RULE_SKILL = "qiao__jin_deck_rule"
M.QIANBIAN = "qiao__skill_jin009_1"
M.ZHOUTING = "qiao__skill_jin009_2"

--- 是否为四种常规花色之一；无花色不计为第五种。
function M.validSuit(suit)
  return suit == Card.Spade or suit == Card.Heart or suit == Card.Club or suit == Card.Diamond
end

--- 本次牌是否完全由该角色手牌区的实体牌组成。
---@param player Player
---@param card Card
---@return boolean
function M.isHandCard(player, card)
  if player == nil or card == nil then return false end
  local ids = Card:getIdList(card)
  if #ids == 0 then return false end
  local hand = player:getCardIds(Player.Hand)
  for _, id in ipairs(ids) do
    if not table.contains(hand, id) then return false end
  end
  return true
end

--- 当前阶段已被权变禁止使用的花色。
---@param player Player
---@return integer[]
function M.bannedSuits(player)
  if player == nil then return {} end
  return player:getTableMark(M.BAN_SUITS)
end

local suitSymbols = {
  [Card.Spade] = "♠", [Card.Heart] = "♥",
  [Card.Club] = "♣", [Card.Diamond] = "♦",
}

function M.suitSymbols(suits)
  local symbols = {}
  for _, suit in ipairs({ Card.Spade, Card.Heart, Card.Club, Card.Diamond }) do
    if table.contains(suits, suit) then table.insert(symbols, suitSymbols[suit]) end
  end
  return table.concat(symbols)
end

---@param room Room
---@param player Player
---@param suit integer
function M.banSuit(room, player, suit)
  if room == nil or player == nil or not M.validSuit(suit) then return end
  room:addTableMarkIfNeed(player, M.BAN_SUITS, suit)
  room:setPlayerMark(player, M.BAN_DISPLAY, M.suitSymbols(M.bannedSuits(player)))
end

return M
