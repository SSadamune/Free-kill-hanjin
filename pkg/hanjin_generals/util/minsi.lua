-- HAN007 王荣 · 敏思的共用选牌与效果
--
-- 敏思本体（出牌阶段主动技）与追德给予的额外发动共用这份实现，避免把
-- 「展示任意张红桃牌」「摸两倍的牌」等效果写成两套。此模块不创建技能，
-- 也不永久授予技能：额外发动只是通过辅助主动技让受赠者完成一次同效果的
-- 选牌与结算。
--
-- 规则依据：rules/generals/han007-wangrong.md、rules/general-principles.md。
-- 弃置的牌可以是自己的手牌或装备区里的牌；点数之和必须正好为 13。
-- 只有此次摸到的红桃牌本回合不计入手牌上限，其他来源的红桃牌不受影响。
local M = {}

--- 点数之和为 13 的目标值。
M.TARGET = 13

--- 敏思摸到的红桃牌「本回合不计入手牌上限」的卡牌标记。
--- 值记录受益者 id，避免已经转给其他角色的牌继续替原角色豁免。
--- 「-turn」后缀由房间在回合结束时统一清理。
local MARK_PREFIX = "hanjin__skill_han007_1_"

---@param player ServerPlayer | ClientPlayer
---@return string
local function markName(player)
  return MARK_PREFIX .. player.id .. "-turn"
end

M.markName = markName

---@param card Card
---@return integer
local function pointOfCard(card)
  local number = card.number or 0
  if number < 0 then return 0 end
  return number
end

---@param id integer
---@return integer
function M.pointOf(id)
  -- 点数取实体牌的原始信息；花色另经 room:filterCard 取有效花色。
  return pointOfCard(Fk:getCardById(id, true))
end

---@param cards integer[]
---@return integer
function M.sumOf(cards)
  local sum = 0
  for _, id in ipairs(cards or {}) do
    sum = sum + M.pointOf(id)
  end
  return sum
end

--- 取一张牌在指定角色处的有效花色。
--- `Fk:getCardById` 只在房间已应用锁视技时返回过滤结果，且过滤缓存按牌 id
--- 共享；因此这里显式调用房间的公开 filterCard 接口，以持有者为参数取得
--- 有效花色，不使用实体牌的原始 suit 猜测。
---@param room Room | Client
---@param player ServerPlayer | ClientPlayer
---@param id integer
---@return integer
function M.suitOf(room, player, id)
  local card = room:filterCard(id, player)
  return card and card.suit or Card.NoSuit
end

--- 一张牌在指定角色处是否为红桃（有效花色）。
---@param room Room | Client
---@param player ServerPlayer | ClientPlayer
---@param id integer
---@return boolean
function M.isHeart(room, player, id)
  return M.suitOf(room, player, id) == Card.Heart
end

--- 当前可用于敏思的牌：自己的手牌区和装备区、且未被技能禁止弃置。
---@param player ServerPlayer | ClientPlayer
---@return integer[]
function M.legalCards(player)
  return table.filter(player:getCardIds("he"), function(id)
    return not player:prohibitDiscard(id)
  end)
end

--- 是否存在点数之和正好为 13 的合法牌组合。
--- 0 点牌不能帮助凑出 13，但仍可作为额外选牌进入合法组合。
---@param player ServerPlayer | ClientPlayer
---@return boolean
function M.canForm13(player)
  local reachable = { [0] = true }
  for _, id in ipairs(M.legalCards(player)) do
    local point = M.pointOf(id)
    if point > 0 and point <= M.TARGET then
      for sum = M.TARGET, point, -1 do
        if reachable[sum - point] then reachable[sum] = true end
      end
    end
  end
  return reachable[M.TARGET] == true
end

--- 主动技选牌：只能选自己的合法牌，且选中后的点数和不能超过 13。
---@param player ServerPlayer | ClientPlayer
---@param to_select integer
---@param selected integer[]
---@return boolean
function M.cardFilter(player, to_select, selected)
  if table.contains(selected or {}, to_select) then return false end
  if not table.contains(M.legalCards(player), to_select) then return false end
  return M.sumOf(selected) + M.pointOf(to_select) <= M.TARGET
end

--- 确认键条件：至少一张，且点数和正好为 13。
---@param selected integer[]
---@return boolean
function M.feasible(selected)
  return #(selected or {}) > 0 and M.sumOf(selected) == M.TARGET
end

--- 执行敏思的弃牌、摸牌、展示与手牌上限标记。
--- 服务端会重新校验牌仍归自己所有、未被禁止弃置且点数之和为 13；
--- 非法提交不移动任何牌。技能名用于牌移动与日志来源。
---@param room Room
---@param player ServerPlayer
---@param cards integer[]
---@param skillName string
---@return boolean
function M.perform(room, player, cards, skillName)
  if player == nil or player.dead then return false end

  local legal = M.legalCards(player)
  local chosen = {}
  for _, id in ipairs(cards or {}) do
    if table.contains(legal, id) and not table.contains(chosen, id) then
      table.insert(chosen, id)
    end
  end
  if #chosen == 0 or M.sumOf(chosen) ~= M.TARGET then return false end

  room:throwCard(chosen, skillName, player, player)
  if player.dead then return true end

  local drawn = player:drawCards(2 * #chosen, skillName)
  if player.dead then return true end

  -- 「展示之」：展示过程不移动牌，随后仅给本次摸到的红桃牌加上本回合
  -- 的手牌上限豁免标记。花色按持有者处的有效花色判断。
  room:showCards(drawn, player)
  for _, id in ipairs(drawn) do
    if M.isHeart(room, player, id) then
      room:setCardMark(Fk:getCardById(id, true), markName(player), 1)
    end
  end

  return true
end

return M
