-- 配将体力贡献：把引擎“半格”表示的体力上限与规则层的“☯️+N”修正集中到一处，
-- 供开局接线（mode.lua 的 broadcastGeneral）与升变公共流程（ascension.lua）复用。
--
-- 引擎以半格为体力单位：1.5 体力记作 3，2 体力记作 4。国战双将的体力上限为
-- （主将贡献 + 副将贡献）// 2；半格合计为奇数时由 `HalfMaxHpLeft` 标记记录
-- 1 个“半个阴阳鱼”。应期的“☯️+2”是 2 个半格（即 1 点体力上限）的组合体力
-- 贡献修正，不是 2 枚可消耗的阴阳鱼标记。2 是偶数，所以余数标记的奇偶不变。
--
-- 本模块只读取正式武将牌面/资料登记，不修改 General 属性，也不写入其他模式：
--   * “多势力”按牌面 kingdom + subkingdom 认定，不看本局禁选结果；
--   * “客将”按 Guest 的资料登记认定，不要求本局已启用客将势力；
--   * 普通交换、移除、替换不调用这里的开局计算。
local Ban = require "packages.hanjin.pkg.hanjin_mode.rules.faction_ban"
local Guest = require "packages.hanjin.pkg.hanjin_mode.rules.guest_factions"

local M = {}

--- 应期（WEI002/JIN009 同名同文锁定技）的技能名。君主版/效忠版若沿用同一
--- 技能名，也一并识别；两个版本同场时只修正一次。
M.YINGQI_SKILLS = {
  ["hanjin__skill_wei002_3"] = true,
  ["hanjin__skill_jin009_3"] = true,
}

--- 应期的半格修正值：☯️+2。
M.YINGQI_HALF = 2

--- 开局登记的房间 tag；只用于核对/调试，不参与体力上限计算。
M.START_TAG = "hanjin_yingqi_start"

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
function M.is_multi_faction(generalName)
  local general = type(generalName) == "table" and generalName or Fk.generals[generalName]
  return general ~= nil and #Ban.affiliations(general) > 1
end

--- 资料登记的客将：主势力之外另列副势力。本局是否启用客将势力是另一问题。
---@param generalName string
---@return boolean
function M.is_guest(generalName)
  if type(generalName) ~= "string" then return false end
  return #Guest.guestKingdoms(generalName) > 0
end

--- 配将是否满足应期条件（多势力或客将）。
---@param generalName string|table
---@return boolean
function M.qualifies(generalName)
  return M.is_multi_faction(generalName) or M.is_guest(generalName)
end

--- 有应期的一方看另一方（配将）。两端都有应期时仍只修正一次。
---@param main string
---@param deputy string
---@return string?
function M.yingqi_partner(main, deputy)
  if M.has_yingqi(main) then return deputy end
  if M.has_yingqi(deputy) then return main end
  return nil
end

--- 组合的☯️修正，单位半格：0 或 2。
---@param main string?
---@param deputy string?
---@return integer
function M.yinyang(main, deputy)
  local partner = M.yingqi_partner(main, deputy)
  if partner == nil then return 0 end
  if M.qualifies(partner) then return M.YINGQI_HALF end
  return 0
end

--- 含☯️修正的半格合计。
---@param main string
---@param deputy string
---@return integer?
function M.half_hp(main, deputy)
  local base = M.base_half_hp(main, deputy)
  if base == nil then return nil end
  return base + M.yinyang(main, deputy)
end

--- 组合体力上限（向下取整）。
---@param main string
---@param deputy string
---@return integer?
function M.max_hp(main, deputy)
  local total = M.half_hp(main, deputy)
  return total and total // 2 or nil
end

--- 组合的奇偶余数（HalfMaxHpLeft 标记值）。
---@param main string
---@param deputy string
---@return integer
function M.half_left(main, deputy)
  local total = M.half_hp(main, deputy)
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
--- 这里再把应期的 2 个半格补上。只增加、不减少；重复调用幂等，因此模式流程与
--- 技能效果在同一时点先后触发也不会叠加。
---@param room Room
---@param player ServerPlayer
---@return boolean @ 是否实际调整了体力上限
function M.apply_start(room, player)
  local main, deputy = M.actual_main(player), M.actual_deputy(player)
  if main == nil or deputy == nil then return false end
  if M.yinyang(main, deputy) == 0 then return false end
  local total = M.half_hp(main, deputy)
  if total == nil then return false end
  local desired = total // 2
  local delta = desired - player.maxHp
  if delta <= 0 then return false end
  room:setPlayerProperty(player, "maxHp", desired)
  room:setPlayerProperty(player, "hp", math.min(player.hp + delta, desired))
  room:setPlayerMark(player, "HalfMaxHpLeft", total % 2)
  return true
end

--- 技能骨架的 GameStart 效果只登记“本局哪个配将组合含应期”。体力上限只在
--- 模式的开局 broadcastGeneral 单点计算一次，不在这里重算，因此不会因其他
--- GameStart 效果改动上限而被错误补回。
---@param room Room
---@param player ServerPlayer
---@return boolean
function M.register_start(room, player)
  local main, deputy = M.actual_main(player), M.actual_deputy(player)
  local extra = M.yinyang(main, deputy)
  if extra == 0 then return false end
  local tag = room:getTag(M.START_TAG) or {}
  tag[player.id] = {
    main = main,
    deputy = deputy,
    base_half = M.base_half_hp(main, deputy),
    yingqi_half = extra,
  }
  room:setTag(M.START_TAG, tag)
  return true
end

return M
