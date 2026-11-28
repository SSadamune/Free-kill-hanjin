-- SHU019 马岱·潜袭的跨技能状态与静态限制入口。
--
-- 限制按“目标 + 被弃置颜色”保存，由独立静态技能读取；回合结束时统一清除。
-- 因此马岱后来失去潜袭或暗置都不会撤销已经建立的限制，客户端也能直接读取
-- 公开标记判断可用性，不依赖服务端回合事件。
local PublicState = require "packages.qiao.pkg.qiao_mode.rules.public_state"
local M = {}

M.RULE_SKILL = "qiao__shu019_qianxi_rule"
M.CLEANUP_SKILL = "qiao__shu019_qianxi_cleanup"
M.RESTRICTIONS = "qiao_shu019_qianxi_restrictions"

function M.candidates(room, player)
  return table.filter(room:getPresentPlayers(), function(target)
    return target ~= player and player:distanceTo(target) == 1
  end)
end

--- 确保静态限制与回合结束清理技能已安装到房间；可重复调用。
---@param room Room
function M.ensureRule(room)
  if room == nil then return end
  if not room:hasSkill(M.RULE_SKILL) then room:addSkill(M.RULE_SKILL) end
  if not room:hasSkill(M.CLEANUP_SKILL) then room:addSkill(M.CLEANUP_SKILL) end
end

--- 建立一条限制。不同来源、不同颜色的记录并存，重复记录由读取端去重。
---@param room Room
---@param target ServerPlayer
---@param holder ServerPlayer
---@param color integer
function M.addRestriction(room, target, holder, color)
  if room == nil or target == nil or holder == nil then return end
  local records = target:getTableMark(M.RESTRICTIONS)
  table.insert(records, { color = color, source = holder.id })
  room:setPlayerMark(target, M.RESTRICTIONS, records)
end

--- 清除所有目标的潜袭限制；由静态规则在回合结束时调用。
---@param room Room
function M.clear(room)
  if room == nil then return end
  for _, player in ipairs(room.players) do
    PublicState.setPlayerMark(room, player, M.RESTRICTIONS, 0)
  end
end

--- 当前仍适用的禁止颜色。
---@param player ServerPlayer
---@return integer[]
function M.colorsFor(player)
  local colors = {}
  for _, record in ipairs(player:getTableMark(M.RESTRICTIONS)) do
    if record.color == Card.Red or record.color == Card.Black then
      table.insertIfNeed(colors, record.color)
    end
  end
  return colors
end

--- 该牌是否含被禁止颜色的手牌材料。虚拟牌按 subcards 检查；无实体材料
--- （纯虚拟牌）或材料不在手牌区（装备来源等）不因转化后的牌面颜色被禁止。
---@param player ServerPlayer
---@param card Card
---@return boolean
function M.prohibited(player, card)
  if player == nil or card == nil then return false end
  local colors = M.colorsFor(player)
  if #colors == 0 then return false end
  local hand = player:getCardIds(Player.Hand)
  for _, id in ipairs(Card:getIdList(card)) do
    if table.contains(hand, id) then
      local material = Fk:getCardById(id)
      if material ~= nil and table.contains(colors, material.color) then
        return true
      end
    end
  end
  return false
end

return M
