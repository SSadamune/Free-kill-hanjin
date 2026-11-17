-- 翼从实例登记（正式最小模块）：独立实例、独立可选发动、独立计次。
--
-- 规则依据 docs/rules/commander-retinue.md「拥有数量与独立实例」：翼从按角色实际
-- 拥有的实例计数，不按兵种或技能名去重；每份翼从提供一份独立技能来源，
-- 同名实例各自保留发动次数与效果，移除一份只撤销该份实例。
--
-- 锁定引擎不能直接用技能名表达同名多份（均为 .dev 内锁定版本源码）：
--   * Player:hasSkill 是布尔关系，ltk/core/player.lua:996-1041；
--   * Player:addSkill 以 table.insertIfNeed 合并同名技能，
--     ltk/core/player.lua:1064-1106；
--   * TriggerEvent:exec 的 invoked_times 也以技能名为键，
--     lua/core/trigger_event.lua:115-125、174；拒绝一次会把同名的后续询问
--     一并停止（lua/core/trigger_event.lua:176-178）。
-- 因此实例身份保存在 room tag 中，技能骨架仍只保留一份；同名实例的可选发动
-- 在同一个 on_trigger 内逐份调用 TriggerSkill:doCost 完成（见 triggerEach），
-- 每份单独询问、单独结算，拒绝一份不阻止询问下一份。
--
-- 授予/撤销使用独立的来源技能（SOURCE_SKILL）作 source_skill，只增删本模块
-- 登记的那一份导数来源；角色原有或其他来源的同名技能保持不变。
-- 客户端数量只读公开 mark（PUBLIC_MARK）；实例 id、兵种、位置、来源、计次
-- 等仅保存在服务端 room tag，不写入公开 mark。
--
-- 本模块提供实例登记与来源事实；实体位置同步由 retinue_instance_sources 接入，
-- 额外授予、龙飞共享及各兵种效果通过该实例接口分别实现。

local M = {}

M.TAG = "qiao_retinue_instances"
M.PUBLIC_MARK = "@@qiao_retinue_public"
-- 实例管理的导数来源技能；只用于 getActualSkill 与 derivative_skills 记账。
M.SOURCE_SKILL = "#qiao_retinue_instance_source"
M.CURRENT_KEY = "retinue_instance_current"

-- 实例增删后的通用变更通知。阵/势包翼从用它同步公开的逐实例已用次数；
-- 模块本身不依赖具体技能内容。
M.changeListeners = {}

function M.addChangeListener(listener)
  assert(type(listener) == "function", "retinue_instances: listener must be a function")
  table.insert(M.changeListeners, listener)
  return listener
end

local function notifyChange(player)
  for _, listener in ipairs(M.changeListeners) do
    listener(player)
  end
end

-- 原子位置交换完成后发布最终实例状态，供公开计次和共享来源刷新。
M.notifyChange = notifyChange

local function checkPlayer(player)
  return player ~= nil and player.room ~= nil and type(player.id) == "number"
end

local function registry(room)
  local reg = room:getTag(M.TAG)
  if reg == nil then
    reg = { next_id = 1, players = {} }
    room:setTag(M.TAG, reg)
  end
  reg.next_id = reg.next_id or 1
  reg.players = reg.players or {}
  return reg
end

local function entryOf(player, create)
  if not checkPlayer(player) then return nil end
  local reg = registry(player.room)
  local entry = reg.players[player.id]
  if entry == nil and create then
    entry = { instances = {} }
    reg.players[player.id] = entry
  end
  return entry
end

--- 服务端和客户端均由正式技能骨架预注册的派生来源。
local function sourceSkill()
  return assert(Fk.skills[M.SOURCE_SKILL], "Missing pre-registered retinue source")
end

--- 返回该角色当前的实例列表（服务端）。表由登记表直接持有，调用方只读
--- 遍历；增删与计次请使用本模块函数。客户端请用 publicInstances。
--- @param player ServerPlayer
--- @return table[]
function M.instances(player)
  local entry = entryOf(player, false)
  return entry and entry.instances or {}
end

--- 按实例 id 查找（服务端）。实例 id 在整局内唯一。
--- @param player ServerPlayer
--- @param id integer
--- @return table?
function M.get(player, id)
  for _, instance in ipairs(M.instances(player)) do
    if instance.id == id then return instance end
  end
end

--- 翼从数：按实际拥有实例计数，包含同名多份。服务端读登记表；无服务端
--- room 的 ClientPlayer 退回读公开 mark。
--- @param player Player
--- @return integer
function M.count(player)
  if checkPlayer(player) then return #M.instances(player) end
  return M.publicCount(player)
end

--- 某个技能定义当前的实例数。服务端读登记表；客户端按公开摘要计数。
--- @param player Player
--- @param skillName string
--- @return integer
function M.countForSkill(player, skillName)
  if checkPlayer(player) then
    local count = 0
    for _, instance in ipairs(M.instances(player)) do
      if instance.skill == skillName then count = count + 1 end
    end
    return count
  end
  for _, entry in ipairs(M.publicInstances(player)) do
    if entry.skill == skillName then return entry.count end
  end
  return 0
end

--- 某个技能定义当前的实例列表（服务端，按登记顺序）。
--- @param player ServerPlayer
--- @param skillName string
--- @return table[]
function M.instancesForSkill(player, skillName)
  local result = {}
  for _, instance in ipairs(M.instances(player)) do
    if instance.skill == skillName then table.insert(result, instance) end
  end
  return result
end

--- 公开摘要：只含翼从总数与各技能实例数，不含 id、兵种、位置、来源或计次。
--- @param player Player
--- @return table { skill: string, count: integer }[]
function M.publicInstances(player)
  local mark = player and player:getMark(M.PUBLIC_MARK)
  local result = {}
  if type(mark) ~= "table" or type(mark.instances) ~= "table" then return result end
  for _, entry in ipairs(mark.instances) do
    if type(entry) == "table" and type(entry.skill) == "string" then
      table.insert(result, { skill = entry.skill, count = entry.count or 0 })
    end
  end
  return result
end

--- 公开翼从数，供客户端读取。
--- @param player Player
--- @return integer
function M.publicCount(player)
  local mark = player and player:getMark(M.PUBLIC_MARK)
  if type(mark) == "table" and type(mark.count) == "number" then
    return mark.count
  end
  return 0
end

--- 把公开摘要刷新到玩家 mark。room:setPlayerMark 会广播给客户端
--- （lua/server/roombase.lua:530-537），room tag 本身不会下发。
local function publish(player)
  local counts, skills, total = {}, {}, 0
  for _, instance in ipairs(M.instances(player)) do
    counts[instance.skill] = (counts[instance.skill] or 0) + 1
    total = total + 1
  end
  for skillName, count in pairs(counts) do
    table.insert(skills, { skill = skillName, count = count })
  end
  table.sort(skills, function(a, b) return a.skill < b.skill end)
  player.room:setPlayerMark(player, M.PUBLIC_MARK,
    total > 0 and { count = total, instances = skills } or 0)
end

--- 取得一份翼从实例。同一角色可以多次取得同名实例，每次都新增独立 id。
--- 首个实例负责按实例来源授予技能；已有其他来源的同名技能时只追加本模块的
--- 导数来源记账，不重复注册触发，也不会覆盖原有来源。
--- @param player ServerPlayer
--- @param spec table { general: string, skill: string, origin?: "entity"|"granted"|"shared", position?: "main"|"deputy", shared_from?: integer }
--- @return table instance
function M.grant(player, spec)
  assert(checkPlayer(player), "retinue_instances: player must be in a room")
  assert(type(spec) == "table", "retinue_instances: spec must be a table")
  local general = spec.general
  local skillName = spec.skill
  assert(type(general) == "string" and general ~= "",
    "retinue_instances: spec.general is required")
  assert(type(skillName) == "string" and skillName ~= "",
    "retinue_instances: spec.skill is required")
  assert(Fk.skills[skillName] ~= nil,
    "retinue_instances: unknown skill: " .. tostring(skillName))
  local origin = spec.origin or "entity"
  assert(origin == "entity" or origin == "granted" or origin == "shared",
    "retinue_instances: unknown origin: " .. tostring(origin))
  assert(spec.position == nil or spec.position == "main" or spec.position == "deputy",
    "retinue_instances: unknown position: " .. tostring(spec.position))
  assert(origin ~= "shared" or type(spec.shared_from) == "number",
    "retinue_instances: shared instance requires shared_from player id")

  local entry = assert(entryOf(player, true), "retinue_instances: missing registry entry")
  local reg = registry(player.room)
  local instance = {
    id = reg.next_id,
    general = general,
    skill = skillName,
    origin = origin,
    position = spec.position,
    shared_from = spec.shared_from,
    -- 该份实例自身的发动次数；同名其他实例互不影响。
    uses = 0,
  }
  reg.next_id = reg.next_id + 1
  table.insert(entry.instances, instance)
  player.room:setTag(M.TAG, reg)

  local source = sourceSkill()
  local ownedBefore = player:hasSkill(skillName, true, true)
  player.room:handleAddLoseSkills(player, skillName, source, false, true)
  if ownedBefore then
    -- handleAddLoseSkills 在已拥有同名技能时会跳过 addSkill；这里仍按实例来源
    -- 登记一份导数来源，只做记账（player.lua:1087-1095）。
    player:addSkill(skillName, source)
  end
  publish(player)
  notifyChange(player)
  return instance
end

--- 除本模块来源外，角色是否仍由其他来源持有该技能。
---@param player ServerPlayer
---@param target Skill
---@param source Skill
---@return boolean
local function hasOtherSource(player, target, source)
  if table.contains(player.player_skills, target) then return true end
  for key, list in pairs(player.derivative_skills) do
    if key ~= source and table.contains(list, target) then return true end
  end
  return false
end

--- 移除一份实例。可传实例表或实例 id；只撤销该份来源。
--- 该技能最后一份实例移除后，只删除本模块来源的那一份；角色原有或其他
--- 来源的同名技能保留。
--- @param player ServerPlayer
--- @param instance table|integer
--- @return boolean
function M.remove(player, instance)
  if not checkPlayer(player) or instance == nil then return false end
  local list = M.instances(player)
  local index
  for i, current in ipairs(list) do
    if current == instance or current.id == instance then
      index = i
      break
    end
  end
  if index == nil then return false end
  local removed = table.remove(list, index)
  local reg = registry(player.room)
  player.room:setTag(M.TAG, reg)
  if M.countForSkill(player, removed.skill) == 0 then
    local target = assert(Fk.skills[removed.skill],
      "retinue_instances: missing skill " .. tostring(removed.skill))
    local source = sourceSkill()
    if hasOtherSource(player, target, source) then
      -- 外部仍有同名技能：只摘掉本模块这条来源映射，不调用 loseSkill。
      -- Player:loseSkill 会无条件清空 derivative_skills[skill]，连多效果骨架的
      -- 关联效果一起删掉（player.lua:1128-1131）。
      local sources = player.derivative_skills[source]
      if sources ~= nil then
        table.removeOne(sources, target)
        if #sources == 0 then player.derivative_skills[source] = nil end
      end
    else
      -- 已无任何其他来源：本模块来源仍登记在案，用来源级失技让引擎完整撤销、
      -- 清理关联效果并广播。此时不能先摘来源，否则 handleAddLoseSkills 会因
      -- hasSkill 已为 false 而跳过真正的 loseSkill。
      player.room:handleAddLoseSkills(player, "-" .. removed.skill,
        source, false, true)
    end
  end
  publish(player)
  notifyChange(player)
  return true
end

--- 该角色某主/副将位置上的实体翼从实例（origin=entity）。
--- @param player ServerPlayer
--- @param isDeputy boolean
--- @return table[]
function M.entityInstances(player, isDeputy)
  local position = isDeputy and "deputy" or "main"
  local result = {}
  for _, instance in ipairs(M.instances(player)) do
    if instance.origin == "entity" and instance.position == position then
      table.insert(result, instance)
    end
  end
  return result
end

--- 幂等同步一个实体位置的翼从实例。
--- 同一位置同一兵种/技能保留原实例；不同兵种只替换该位置的实体实例；
--- 不会删除 origin=granted/shared 的额外来源。
--- @param player ServerPlayer
--- @param isDeputy boolean
--- @param general string 翼从兵种
--- @param skillName string 该兵种唯一技能定义
--- @return table? instance
function M.syncEntity(player, isDeputy, general, skillName)
  assert(checkPlayer(player), "retinue_instances: player must be in a room")
  assert(type(general) == "string" and general ~= "",
    "retinue_instances: entity general is required")
  assert(type(skillName) == "string" and Fk.skills[skillName] ~= nil,
    "retinue_instances: unknown entity skill " .. tostring(skillName))
  local position = isDeputy and "deputy" or "main"
  local matches = {}
  for _, instance in ipairs(M.entityInstances(player, isDeputy)) do
    if instance.general == general and instance.skill == skillName then
      table.insert(matches, instance)
    else
      -- 只撤该位置旧兵种实体，不动额外/共享来源。
      M.remove(player, instance.id)
    end
  end
  if #matches == 0 then
    return M.grant(player, {
      general = general,
      skill = skillName,
      origin = "entity",
      position = position,
    })
  end
  -- 同一位置理论上只保留一份实体；历史重复只留第一份。
  for index = 2, #matches do M.remove(player, matches[index].id) end
  return matches[1]
end

--- 位置不再是翼从时撤掉该位置的实体实例；额外/共享来源保留。
--- @param player ServerPlayer
--- @param isDeputy boolean
--- @return boolean changed
function M.removeEntity(player, isDeputy)
  if not checkPlayer(player) then return false end
  local list = M.entityInstances(player, isDeputy)
  local changed = false
  for _, instance in ipairs(list) do
    if M.remove(player, instance.id) then changed = true end
  end
  return changed
end

--- 在同一个触发时机内，按实例逐份执行触发技的 cost/效果，每份单独询问。
--- 用于同名实例的独立可选发动：拒绝一份只影响该份，循环继续询问下一份。
--- 触发技需在自己的 on_use 中用 currentForEvent 取得本次实例。
---
--- on_trigger 会替换 TriggerSkill.trigger（ltk/core/skill_skeleton.lua:342），
--- 因此这里按 trigger 的默认流程重置 cancel_cost 并调用 doCost
--- （ltk/core/skill_type/trigger.lua:54-93）。
--- @param effectSkill TriggerSkill 触发技自身（on_trigger 的 self）
--- @param event TriggerEvent
--- @param target ServerPlayer?
--- @param player ServerPlayer
--- @param data any
--- @param eligible? fun(instance: table, event: TriggerEvent, target: ServerPlayer?, player: ServerPlayer, data: any): boolean
--- @return boolean? broken
function M.triggerEach(effectSkill, event, target, player, data, eligible)
  if effectSkill == nil or event == nil or player == nil or not checkPlayer(player) then
    return nil
  end
  local skeleton = effectSkill:getSkeleton()
  local skillName = skeleton and skeleton.name
  assert(type(skillName) == "string",
    "retinue_instances: effectSkill must come from a skill skeleton")
  if not player:hasSkill(skillName) then return nil end
  event:setSkillData(effectSkill, "cancel_cost", false)
  local broken = false
  for _, instance in ipairs(M.instancesForSkill(player, skillName)) do
    if not player.dead and M.get(player, instance.id) ~= nil
      and (eligible == nil or eligible(instance, event, target, player, data)) then
      -- 每份实例都是独立的一次可选发动；上一份的取消不得阻断下一份。
      event:setSkillData(effectSkill, "cancel_cost", false)
      event:setSkillData(effectSkill, M.CURRENT_KEY, instance)
      if effectSkill:doCost(event, target, player, data) then
        broken = true
        break
      end
    end
  end
  event:setSkillData(effectSkill, M.CURRENT_KEY, nil)
  return broken or nil
end

--- 取得 triggerEach 正在结算的实例。
--- @param effectSkill TriggerSkill 触发技自身（on_use 的 self）
--- @param event TriggerEvent
--- @return table?
function M.currentForEvent(effectSkill, event)
  if effectSkill == nil or event == nil then return nil end
  return event:getSkillData(effectSkill, M.CURRENT_KEY)
end

--- 记录一份实例自身发动了一次。同名实例各计各的。
--- @param instance table
function M.recordUse(instance)
  assert(type(instance) == "table", "retinue_instances: instance is required")
  instance.uses = (instance.uses or 0) + 1
end

return M
