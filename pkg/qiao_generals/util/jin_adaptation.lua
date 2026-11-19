-- 晋标准包应变相关技能共用的小工具。
--
-- 这里只放不改变规则含义的查询：伤害牌口径、本次使用与伤害事件的关联；
-- 时机、消耗与选项合法性仍由各技能判断。伤害牌按外部 FAQ 的“伤害牌”定义
-- 取可作为伤害渠道的基本牌／普通锦囊，明确排除【闪电】与伤害装备。
local M = {}

-- FAQ 所列可作为伤害渠道的牌：杀、决斗、火攻、万箭齐发、南蛮入侵、
-- 火烧连营、水淹七军、出其不意。杀的各属性版本 trueName 均为 slash。
local DAMAGE_TRUENAMES = {
  slash = true,
  duel = true,
  fire_attack = true,
  archery_attack = true,
  savage_assault = true,
  burning_camps = true,
  drowning = true,
  unexpectation = true,
}

--- 是否为“伤害牌”。延时锦囊（闪电）与装备（三尖两刃刀等）不在此列。
---@param card Card?
---@return boolean
function M.isDamageCard(card)
  if card == nil then return false end
  if card.type == Card.TypeEquip then return false end
  if card.sub_type == Card.SubtypeDelayedTrick then return false end
  return DAMAGE_TRUENAMES[card.trueName] == true
end

--- 当前正在结算的使用事件（伤害、用牌结束等回调中）。
---@param room Room
---@return UseCardData?
function M.currentUse(room)
  if room == nil or room.logic == nil then return nil end
  local event = room.logic:getCurrentEvent()
  local useEvent = event and event:findParent(GameEvent.UseCard, true)
  return useEvent and useEvent.data or nil
end

--- 某次伤害是否由本次使用中的同一张牌造成；返回该使用的伤害类型标记。
---@param room Room
---@param damageData DamageData
---@return integer?
function M.useDamageType(room, damageData)
  if damageData == nil or damageData.card == nil then return nil end
  local use = M.currentUse(room)
  if use == nil or use.card ~= damageData.card then return nil end
  return (use.extra_data or {}).qiao_damage_type
end

--- 本次使用是否记录到真实伤害（damageDealt 以角色对象为键）。
---@param use UseCardData
---@return boolean
function M.dealtDamage(use)
  for _, num in pairs((use or {}).damageDealt or {}) do
    if num > 0 then return true end
  end
  return false
end

return M
