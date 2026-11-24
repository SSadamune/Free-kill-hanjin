local Modes = require "packages.qiao.pkg.qiao_mode.modes"
local M = {}

-- 引擎以 TriggerSkill 承载纯 refresh；判断预亮时只认实际可发动的效果。
function M.canPrelight(skillName)
  local skill = Fk.skills[skillName]
  local skeleton = skill and skill:getSkeleton()
  if not skeleton then return true end
  if skeleton.qiaoCanPrelight ~= nil then return skeleton.qiaoCanPrelight end
  if #skeleton.effect_spec_list == 0 then return true end

  for _, effect in ipairs(skeleton.effect_spec_list) do
    local key, attr, spec = effect[1], effect[2], effect[3]
    if type(key) == "table" and not (spec.is_delay_effect or (attr and attr.is_delay_effect)) then
      if not spec.can_refresh or spec.can_trigger or spec.can_wake or spec.on_trigger
        or spec.on_cost or spec.on_use then
        return true
      end
    end
  end
  return false
end

local serverInstalled = false

function M.installServer()
  if serverInstalled then return end
  serverInstalled = true
  local ServerPlayer = require "ltk.server.serverplayer"
  local prelightSkill = ServerPlayer.prelightSkill
  function ServerPlayer:prelightSkill(skill, isPrelight)
    local name = type(skill) == "string" and skill or skill.name
    if isPrelight and Modes.inRoom(self.room) and not M.canPrelight(name) then return end
    return prelightSkill(self, skill, isPrelight)
  end
end

return M
