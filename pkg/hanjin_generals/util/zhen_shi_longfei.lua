-- QUN024 张任 · 龙飞共享实例公共工具。
-- 只把张任自己实际拥有的非 shared 实例，复制为队列队友的 origin=shared 实例；
-- 不传播队友借得的 shared 实例，避免递归。共享实例计入队友实际数量并独立计次。
local H = require "packages.hegemony.util"
local R = require "packages.hanjin.pkg.hanjin_generals.util.retinue_instances"

local M = {}

M.LONG_FEI = "hanjin__skill_qun024_2"
M.RULE = "#hanjin_longfei_rule"
M.LINK_TAG = "hanjin_longfei_links"
M.GUARD_TAG = "hanjin_longfei_refreshing"

local listenerInstalled = false

local function isHanjin(room)
  return room ~= nil and type(room.getSettings) == "function"
    and room:getSettings("gameMode") == "hanjin_heg_mode"
end

--- 为当前房间安装重置规则；只汉晋。
function M.ensureRule(room)
  if not isHanjin(room) then return false end
  if not listenerInstalled then
    listenerInstalled = true
    R.addChangeListener(function(player)
      if player ~= nil and player.room ~= nil and isHanjin(player.room) then
        M.refresh(player.room)
      end
    end)
  end
  local rule = Fk.skills[M.RULE]
  if rule ~= nil and not room:hasSkill(M.RULE) then room:addSkill(rule) end
  return true
end

local function ownInstances(player)
  local result = {}
  for _, instance in ipairs(R.instances(player)) do
    if instance.origin ~= "shared" then table.insert(result, instance) end
  end
  return result
end

--- 重算所有龙飞共享。只增删本工具登记的 shared 实例。
function M.refresh(room)
  if room and room:getTag("hanjin_retinue_exchange_in_progress") then return end
  if not isHanjin(room) then return end
  if room:getTag(M.GUARD_TAG) == true then return end
  room:setTag(M.GUARD_TAG, true)
  local ok, err = pcall(function()
    M.ensureRule(room)
    local desired = {}
    for _, holder in ipairs(room.players) do
      if not holder.dead and not holder:isRemoved()
        and holder:hasShownSkill(M.LONG_FEI) then
        local others = H.getFormationRelation(holder)
        if #others > 0 then
          for _, instance in ipairs(ownInstances(holder)) do
            for _, member in ipairs(others) do
              if member ~= holder and not member.dead and not member:isRemoved() then
                local key = holder.id .. ":" .. instance.id .. ":" .. member.id
                desired[key] = {
                  holder = holder,
                  member = member,
                  instance = instance,
                }
              end
            end
          end
        end
      end
    end

    local links = room:getTag(M.LINK_TAG)
    links = type(links) == "table" and table.simpleClone(links) or {}
    for key, link in pairs(links) do
      if desired[key] == nil then
        local member = room:getPlayerById(link.member_id or 0)
        if member ~= nil then R.remove(member, link.instance_id) end
        links[key] = nil
      end
    end
    for key, plan in pairs(desired) do
      local existing = links[key]
      if existing == nil or R.get(plan.member, existing.instance_id) == nil then
        local instance = R.grant(plan.member, {
          general = plan.instance.general,
          skill = plan.instance.skill,
          origin = "shared",
          shared_from = plan.holder.id,
        })
        links[key] = { member_id = plan.member.id, instance_id = instance.id }
      end
    end
    room:setTag(M.LINK_TAG, links)
  end)
  room:setTag(M.GUARD_TAG, nil)
  if not ok then error(err, 0) end
end

return M
