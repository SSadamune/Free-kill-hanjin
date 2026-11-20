-- 配将体力贡献：把引擎“半格”表示的体力上限与规则层的“☯️+N”修正集中到一处，
-- 供开局接线（mode.lua 的 broadcastGeneral）与升变公共流程（ascension.lua）复用。
--
-- 引擎以半格为体力单位：1.5 体力记作 3，2 体力记作 4。国战双将的体力上限为
-- （主将贡献 + 副将贡献）// 2；半格合计为奇数时由 `HalfMaxHpLeft` 标记记录
-- 1 个“半个阴阳鱼”。应期的“☯️+2”是 2 个半格（即 1 点体力上限）的组合体力
-- 贡献修正，不是 2 枚可消耗的阴阳鱼标记。2 是偶数，所以余数标记的奇偶不变。
--
-- 本模块只读取正式武将牌面/资料登记，不修改 General 属性，也不写入其他模式：
--   * 牌面写有多个主势力时不受禁选过滤；
--   * 客将只在本局实际按客籍配将时适用；
--   * 普通交换、移除、替换不调用这里的开局计算。
local Ban = require "packages.qiao.pkg.qiao_mode.rules.faction_ban"
local Guest = require "packages.qiao.pkg.qiao_mode.rules.guest_factions"

local M = {}

--- 应期（WEI002/JIN009 同名同文锁定技）的唯一技能 ID。两版司马懿引用同一
--- 技能，不按武将来源另设识别项；君主版/效忠版若沿用同一技能名，也一并识别。
M.YINGQI_SKILLS = {
  ["qiao__skill_wei002_3"] = true,
}

--- 应期的半格修正值：☯️+2。
M.YINGQI_HALF = 2

local function skillList(general)
  if type(general.getSkillNameList) == "function" then
    return general:getSkillNameList()
  end
  return general.skills or {}
end

---@param generalName string?
---@return boolean
function M.has_yingqi(generalName)
  if type(generalName) ~= "string" or generalName == "" then return false end
  local general = Fk.generals[generalName]
  if general == nil then return false end
  for _, name in ipairs(skillList(general)) do
    if M.YINGQI_SKILLS[name] then return true end
  end
  return false
end

--- 一个位置（主将或副将）的体力贡献，单位半格。
---@param generalName string
---@param adjustmentKey string
---@return integer?
local function position_half(generalName, adjustmentKey)
  local general = Fk.generals[generalName]
  if general == nil then return nil end
  return general.maxHp + (general[adjustmentKey] or 0)
end

--- 不含☯️修正的半格合计，供对照与测试。
---@param main string
---@param deputy string
---@return integer?
function M.base_half_hp(main, deputy)
  local a = position_half(main, "mainMaxHpAdjustedValue")
  local b = position_half(deputy, "deputyMaxHpAdjustedValue")
  if a == nil or b == nil then return nil end
  return a + b
end

--- 牌面多势力：牌面左上角多个势力字（kingdom + subkingdom）。与禁选无关。
--- 正式流程传武将名；也接受 General 形态的对象以便纯规则核对。
---@param generalName string|table
---@return boolean
function M.is_multi_faction(generalName, room)
  local general = type(generalName) == "table" and generalName or Fk.generals[generalName]
  return general ~= nil and (#Ban.affiliations(general) > 1
    or (M.is_guest(generalName, room) and #Guest.guestKingdoms(generalName) > 1))
end

--- 按本局选将解析判断客籍已经生效。
---@param generalName string
---@return boolean
function M.is_guest(generalName, room)
  return room ~= nil and type(generalName) == "string" and Guest.isGuest(room, generalName)
end

--- 配将是否满足应期条件（多势力或客将）。
---@param generalName string|table
---@return boolean
function M.qualifies(generalName, room)
  return M.is_multi_faction(generalName, room) or M.is_guest(generalName, room)
end

--- 有应期的一方查另一张将牌，组合的☯️修正为 0 或 2 半格。
---@param main string?
---@param deputy string?
---@return integer
function M.yinyang(main, deputy, room)
  if (M.has_yingqi(main) and M.qualifies(deputy, room))
    or (M.has_yingqi(deputy) and M.qualifies(main, room)) then
    return M.YINGQI_HALF
  end
  return 0
end

--- 含☯️修正的半格合计。
---@param main string
---@param deputy string
---@return integer?
function M.half_hp(main, deputy, room)
  local base = M.base_half_hp(main, deputy)
  if base == nil then return nil end
  return base + M.yinyang(main, deputy, room)
end

local function doubleHeavyPair(main, deputy)
  return position_half(main, "mainMaxHpAdjustedValue") == 5
    and position_half(deputy, "deputyMaxHpAdjustedValue") == 5
end

--- 组合体力上限。双 2.5 贡献组合保留一格给双亮时的两枚阴阳鱼。
---@param main string
---@param deputy string
---@return integer?
function M.max_hp(main, deputy, room)
  local total = M.half_hp(main, deputy, room)
  return total and total // 2 - (doubleHeavyPair(main, deputy) and 1 or 0) or nil
end

--- 双亮待领的阴阳鱼数量，通常为余下的半格，双 2.5 组合为两枚。
---@param main string
---@param deputy string
---@return integer
function M.half_left(main, deputy, room)
  if doubleHeavyPair(main, deputy) then return 2 end
  local total = M.half_hp(main, deputy, room)
  return total and total % 2 or 0
end

--- 实际主将：明置时看牌面，暗置时看选将记录。
---@param player ServerPlayer?
---@return string?
function M.actual_main(player)
  if player == nil then return nil end
  if player.general and player.general ~= "anjiang" then return player.general end
  local mark = player:getMark("__heg_general")
  return type(mark) == "string" and mark ~= "" and mark or nil
end

--- 实际副将：明置时看牌面，暗置时看选将记录。
---@param player ServerPlayer?
---@return string?
function M.actual_deputy(player)
  if player == nil then return nil end
  if player.deputyGeneral and player.deputyGeneral ~= "anjiang" then return player.deputyGeneral end
  local mark = player:getMark("__heg_deputy")
  return type(mark) == "string" and mark ~= "" and mark or nil
end

--- 开局接线：引擎先按“主将贡献 + 副将贡献 // 2”写入 maxHp / hp / 余数标记，
--- 这里再应用应期半格修正或双 2.5 组合的上限与待领奖励。
---@param room Room
---@param player ServerPlayer
---@return boolean @ 是否实际调整了体力上限
function M.apply_start(room, player)
  local main, deputy = M.actual_main(player), M.actual_deputy(player)
  if main == nil or deputy == nil then return false end
  if M.yinyang(main, deputy, room) == 0 and not doubleHeavyPair(main, deputy) then return false end
  local desired = M.max_hp(main, deputy, room)
  if desired == nil then return false end
  local delta = desired - player.maxHp
  room:setPlayerMark(player, "HalfMaxHpLeft", M.half_left(main, deputy, room))
  if delta == 0 then return false end
  room:setPlayerProperty(player, "maxHp", desired)
  room:setPlayerProperty(player, "hp", math.min(player.hp + delta, desired))
  return true
end

--- 技能骨架不注册 GameStart 效果：体力上限只在模式的开局 broadcastGeneral 单点
--- 计算一次，不在这里重算，因此不会因其他 GameStart 效果改动上限而被错误补回，
--- 也不会让暗置武将的技能在开局被假触发而预亮。

return M
