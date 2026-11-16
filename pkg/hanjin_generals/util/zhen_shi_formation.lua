-- 阵包阵法状态辅助：鹤翼按引擎派生来源授予真实飞影，并给出可靠层数。
--
-- 复核依据：packages/hegemony/util.lua 的 getFormationRelation /
-- inFormationRelation / inSiegeRelation；队列接口只返回其他成员，自身参与
-- 队列必须确实存在同队列者。
--
-- 每个鹤翼持有者使用固定的预注册来源技能（#hanjin__heyi_source_1..8）作为
-- Player:addSkill/loseSkill 的 source_skill，授予真实的 hanjin__feiying。
-- 来源技能在服务端/客户端都由 zhen_shi_formation_state.lua 安装，不依赖
-- 服务端动态 Fk:addSkill。来源 mark 只是公开账本，供增删差分与客户端层数
-- 同步；距离层数由 feiyingLayers 读取真实派生来源数计算。
local H = require "packages.hegemony.util"

local M = {}

M.FEIYING_SKILL = "hanjin__feiying"
M.FEIYING_MARK = "@@hanjin_feiying_sources"
M.FEIYING_LAYERS_MARK = "@@hanjin_feiying_layers"
M.HEYI_SKILL = "hanjin__skill_wei018_2"
M.SOURCE_COUNT = 8

--- 固定来源技能名；1..8 与预注册骨架一致。
--- @param sourceId string|integer
--- @return string
function M.sourceSkillName(sourceId)
  local id = tonumber(sourceId)
  assert(id ~= nil and id >= 1 and id <= M.SOURCE_COUNT,
    "zhen_shi_formation: invalid feiying source id " .. tostring(sourceId))
  return "#hanjin__heyi_source_" .. tostring(id)
end

--- 固定来源技能。服务端与客户端都已由技能骨架预注册。
--- @param sourceId string|integer
--- @return Skill
function M.sourceSkill(sourceId)
  local skill = Fk.skills[M.sourceSkillName(sourceId)]
  assert(skill ~= nil, "zhen_shi_formation: missing pre-registered feiying source")
  return skill
end

--- 当前与角色同队列的其他角色；空表表示队列不存在。
function M.formationOthers(player)
  return H.getFormationRelation(player)
end

--- 角色当前是否处于真实队列（至少一名同势力连续角色）。
function M.inFormation(player)
  return #H.getFormationRelation(player) > 0
end

--- 围攻关系只经上游 public relation 判断。
function M.inSiege(player, target, victim)
  return H.inSiegeRelation(player, target, victim)
end

--- 统计真实飞影层数：每个独立派生来源各一层，外部原飞影（player_skills
--- 或其他来源）也各算一层。服务端读引擎派生表；客户端读公开层数 mark。
--- @param player Player
--- @return integer
function M.feiyingLayers(player)
  if player == nil then return 0 end
  if player.room ~= nil then
    local target = Fk.skills[M.FEIYING_SKILL]
    if target == nil then return 0 end
    local count = 0
    if table.contains(player.player_skills, target) then count = count + 1 end
    for _, list in pairs(player.derivative_skills or {}) do
      if table.contains(list, target) then count = count + 1 end
    end
    return count
  end
  local layers = player:getMark(M.FEIYING_LAYERS_MARK)
  return type(layers) == "number" and layers or 0
end

--- 重新发布公开层数 mark，供 ClientPlayer 距离计算读取。
--- @param room Room
function M.refreshLayers(room)
  if room == nil then return end
  for _, p in ipairs(room.players) do
    room:setPlayerMark(p, M.FEIYING_LAYERS_MARK, M.feiyingLayers(p))
  end
end

--- 按来源授予真实飞影。角色已有同名技能时，用 Player:addSkill 只追加派生
--- 来源；首次取得时走正式 addSkill 流程。
local function grantFeiying(target, sourceId)
  local source = M.sourceSkill(sourceId)
  if target:hasSkill(M.FEIYING_SKILL, true, true) then
    target:addSkill(M.FEIYING_SKILL, source)
  else
    target.room:handleAddLoseSkills(target, M.FEIYING_SKILL, source, false, true)
  end
end

--- 按来源撤销，外部来源/其他鹤翼来源不受影响。
local function revokeFeiying(target, sourceId)
  target.room:handleAddLoseSkills(target, "-" .. M.FEIYING_SKILL,
    M.sourceSkill(sourceId), false, true)
end

--- 重建全场鹤翼来源与公开层数。
--- @param room Room
function M.refreshFormationSources(room)
  if room == nil then return end
  local desired = {}
  for _, holder in ipairs(room.players) do
    local active = holder ~= nil and not holder.dead and not holder:isRemoved()
      and holder:hasShownSkill(M.HEYI_SKILL) and M.inFormation(holder)
    if active then
      local sourceId = tostring(holder.id)
      local function cover(p)
        if p == nil or p.dead or p:isRemoved() then return end
        desired[p.id] = desired[p.id] or {}
        desired[p.id][sourceId] = true
      end
      cover(holder)
      for _, other in ipairs(M.formationOthers(holder)) do cover(other) end
    end
  end

  for _, p in ipairs(room.players) do
    local current = p:getMark(M.FEIYING_MARK)
    current = type(current) == "table" and table.simpleClone(current) or {}
    local nextSources = desired[p.id] or {}
    -- 先补新来源，再撤旧来源；过程中始终有真实技能可依。
    for sourceId in pairs(nextSources) do
      if not current[sourceId] then grantFeiying(p, sourceId) end
    end
    for sourceId in pairs(current) do
      if not nextSources[sourceId] then revokeFeiying(p, sourceId) end
    end
    room:setPlayerMark(p, M.FEIYING_MARK,
      next(nextSources) ~= nil and nextSources or 0)
    room:setPlayerMark(p, M.FEIYING_LAYERS_MARK, M.feiyingLayers(p))
  end
end

--- 是否实际拥有飞影（独立技能或任一鹤翼来源）。
function M.hasFeiying(player)
  return player ~= nil and player:hasSkill(M.FEIYING_SKILL)
end

M.hasFormationFeiying = M.hasFeiying

return M
