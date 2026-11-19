-- 群势力标准包：濒死入口的共享状态与小流程。
--
-- 只供济世（QUN001）和模式级 qun_dying_rule 使用：
--   * qun_dying_rule 在 EnterDying 给本次濒死分配序号；
--   * 济世用 after_use 把“本次濒死由哪张华佗将牌使用”绑定到该序号；
--   * qun_dying_rule 在 AfterDying 消费该记录，按普通逆时针顺序逐人询问
--     是否用一张明置武将牌交换该华佗，并独立清理完杀标记。
--
-- 交换本身仍走通用 general_exchange 的 validate/exchange；这里只提供来源
-- 定位、跨势力显式许可和首次成功即止的循环。房间 tag 仅服务端使用，不参与
-- 客户端可用性判定；来源位置一律以公开的已明置状态校验。
local M = {}

M.RESCUE_TAG = "qiao_qun_jishi_rescue_v1"
M.ACTIVE_TAG = "qiao_qun_dying_active_v1"
M.SEQ_TAG = "qiao_qun_dying_seq_v1"
M.RULE_SKILL = "qiao__qun_dying_rule"
M.JISHI_SKILL = "qiao__skill_qun001_1"
-- 完杀标记不属于任何技能来源，交换时不会被当作技能标记迁走。
M.WANSHA_MARK = "qiao_qun007_wansha_dying"

local function exchange()
  return require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
end

local function pairHp()
  return require "packages.qiao.pkg.qiao_mode.rules.pair_hp"
end

local function heg()
  return require "packages.hegemony.util"
end

--- 给本次濒死分配递增序号，供同一角色嵌套濒死时区分记录。
--- active[player.id] 是序号栈：嵌套濒死结束后恢复外层的本次序号。
---@param room Room
---@param dying ServerPlayer
---@return integer
function M.beginDying(room, dying)
  local seq = (room:getTag(M.SEQ_TAG) or 0) + 1
  room:setTag(M.SEQ_TAG, seq)
  local active = room:getTag(M.ACTIVE_TAG)
  if type(active) ~= "table" then active = {} end
  local stack = active[dying.id]
  if type(stack) ~= "table" then stack = {} end
  table.insert(stack, seq)
  active[dying.id] = stack
  room:setTag(M.ACTIVE_TAG, active)
  return seq
end

---@param room Room
---@param dying ServerPlayer
---@return integer?
function M.currentDyingSeq(room, dying)
  local active = room:getTag(M.ACTIVE_TAG)
  if type(active) ~= "table" or type(active[dying.id]) ~= "table" then return nil end
  local stack = active[dying.id]
  return stack[#stack]
end

--- 本次濒死结束：弹出该角色的当前序号，恢复外层濒死（若有）。
---@param room Room
---@param dying ServerPlayer
function M.endDying(room, dying)
  local active = room:getTag(M.ACTIVE_TAG)
  if type(active) ~= "table" or type(active[dying.id]) ~= "table" then return end
  local stack = active[dying.id]
  table.remove(stack)
  if #stack == 0 then active[dying.id] = nil end
  room:setTag(M.ACTIVE_TAG, active)
end

--- 提供 `skillName` 的已明置武将牌（主将或副将）。
--- 济世发动后 SkillEffect 已明置来源，因此这里正常情况下总是取得该牌；
--- `general` 同时写入位置参数，供交换时复核仍是同一张牌。
---@param player ServerPlayer
---@param skillName string
---@return table?
function M.sourcePosition(player, skillName)
  local E = exchange()
  local name = E.skillOwner(player, skillName)
  if name == nil then return nil end
  local isDeputy = E.actualGeneral(player, false) ~= name
  if E.actualGeneral(player, isDeputy) ~= name then return nil end
  return { player = player, isDeputy = isDeputy, general = name }
end

--- 记录一次济世救援。记录以本次濒死序号为键，同角色嵌套濒死不会互相覆盖。
---@param room Room
---@param dying ServerPlayer
---@param side table { player, isDeputy, general }
function M.recordRescue(room, dying, side)
  local data = room:getTag(M.RESCUE_TAG)
  if type(data) ~= "table" then data = {} end
  local seq = M.currentDyingSeq(room, dying)
  -- 濒死规则未接线时退化为按角色记录；正式房间必有序号。
  local key = seq ~= nil and ("s" .. seq) or ("p" .. dying.id)
  data[key] = {
    player_id = dying.id,
    seq = seq,
    owner_id = side.player.id,
    general = side.general,
    is_deputy = side.isDeputy,
  }
  room:setTag(M.RESCUE_TAG, data)
end

--- 取走并清空本次濒死的救援记录；只接受与当前濒死序号一致的记录。
---@param room Room
---@param dying ServerPlayer
---@return table?
function M.takeRescue(room, dying)
  local data = room:getTag(M.RESCUE_TAG)
  if type(data) ~= "table" then return nil end
  local seq = M.currentDyingSeq(room, dying)
  local key = seq ~= nil and ("s" .. seq) or ("p" .. dying.id)
  local entry = data[key]
  data[key] = nil
  room:setTag(M.RESCUE_TAG, data)
  if entry == nil or entry.player_id ~= dying.id or entry.seq ~= seq then return nil end
  return entry
end

--- 资料登记的客将，不要求本局已启用客将势力。
---@param generalName string
---@return boolean
function M.isGuestGeneral(generalName)
  return pairHp().is_guest(generalName)
end

--- 候选人合法交换位置：明置、非君主/专属野心家，且不是同一位置。
--- 跨势力由调用方显式传入 cross_kingdom；其余限制沿用交换公共规则。
---@param room Room
---@param player ServerPlayer
---@param source table
---@return table[]
function M.legalPositions(room, player, source)
  local E = exchange()
  local result = {}
  local options = { cross_kingdom = true }
  for _, isDeputy in ipairs({ false, true }) do
    local position = {
      player = player,
      isDeputy = isDeputy,
      general = E.actualGeneral(player, isDeputy),
    }
    if E.validate(room, source, position, options) then
      table.insert(result, position)
    end
  end
  return result
end

local function askPosition(room, candidate, positions)
  local labels, byLabel = {}, {}
  for _, position in ipairs(positions) do
    local label = position.isDeputy
      and "#qiao__skill_qun001_1-deputy" or "#qiao__skill_qun001_1-main"
    labels[#labels + 1] = label
    byLabel[label] = position
  end
  if #labels == 1 then return positions[1] end
  local picked = room:askToChoice(candidate, {
    choices = labels,
    skill_name = M.JISHI_SKILL,
    prompt = "#qiao__skill_qun001_1-choose-position",
    cancelable = true,
  })
  if picked == nil or picked == "" or picked == "Cancel" then return nil end
  return byLabel[picked]
end

--- 濒死结算结束时的刷新阶段处理：先取走本次救援记录并保存到事件 data，
--- 再弹出本次濒死序号。refresh 不参与技能发动选择，也不会丢失嵌套记录。
--- 真正的交换由随后仅在 data 有记录时才进入池的触发完成。
---@param room Room
---@param dying ServerPlayer
---@param data DyingData
---@return table?
function M.finishDying(room, dying, data)
  local entry = M.takeRescue(room, dying)
  M.endDying(room, dying)
  if data ~= nil then data.qiao_jishi_exchange = entry end
  return entry
end

--- 实际执行济世的客将交换段（记录已在 finishDying 中取走并弹栈）。
--- 条件仅为“本技能用于本次濒死”且来源华佗有效（已明置、资料客将）；不因
--- 本次濒死角色是否被救活而跳过。只询问与来源势力不同的存活角色，首次成功
--- 交换即结束，不追踪华佗的新持有者继续询问。
---@param room Room
---@param dying ServerPlayer
---@param entry table
---@return boolean exchanged
function M.exchangeRescue(room, dying, entry)
  if entry == nil then return false end

  local owner = room:getPlayerById(entry.owner_id)
  if owner == nil or owner.dead then return false end
  if not M.isGuestGeneral(entry.general) then return false end

  local E = exchange()
  if not E.isRevealed(owner, entry.is_deputy) then return false end
  local source = {
    player = owner,
    isDeputy = entry.is_deputy,
    general = entry.general,
  }

  local order = table.simpleClone(room:getPresentPlayers())
  room:sortByAction(order)
  for _, candidate in ipairs(order) do
    if candidate ~= owner and not candidate.dead and not candidate:isRemoved()
      and heg().compareKingdomWith(candidate, owner, true) then
      local positions = M.legalPositions(room, candidate, source)
      if #positions > 0 then
        -- 第一项为 no：任何未主动选择 yes 的超时/非法回复都按不交换处理。
        local wants = room:askToChoice(candidate, {
          choices = { "no", "yes" },
          skill_name = M.JISHI_SKILL,
          prompt = "#qiao__skill_qun001_1-exchange::" .. owner.id,
          cancelable = true,
        })
        if wants == "yes" then
          local position = askPosition(room, candidate, positions)
          -- 选择/询问后再次按记录的位置与将名校验来源仍是同一张华佗。
          local options = { cross_kingdom = true }
          if position ~= nil and E.validate(room, source, position, options)
            and E.exchange(room, source, position, options) then
            return true
          end
        end
      end
    end
  end
  return false
end

return M
