-- 汉晋使用引擎的客户端注册接口提供技能交互，不修改本体请求处理类。
local BaseClient = require "ltk.client.client"
local AbstractRoom = require "ltk.core.room.abstract_room"
local ReqPlayCard = require "ltk.core.request_type.play_card"
local ReqActiveSkill = require "ltk.core.request_type.active_skill"
local MZ = "hanjin__skill_han001_2"

--- Only the HanJin room's 密诏 request uses the recipient-replacement UI.
--- The shared board client also serves every upstream room, so all other modes
--- and skills must keep the original request class behavior.
local function isHanjinMZ(request)
  if request.skill_name ~= MZ then return false end
  local room = request.room or Fk:currentRoom()
  return room ~= nil and room:getSettings("gameMode") == "hanjin_heg_mode"
end

local function recipientRequest(base, name)
  local request = base:subclass(name)

  function request:targetValidity(pid)
    if not isHanjinMZ(self) then return base.targetValidity(self, pid) end
    local to = self.room:getPlayerById(pid)
    -- 其他合法角色保持可点击；每次点击都是替换收牌者，而非追加目标。
    return to ~= nil and not not Fk.skills[MZ]:targetFilter(
      self.player, to, {}, self.pendings, nil, self.extra_data)
  end

  function request:selectTarget(pid, data)
    if isHanjinMZ(self) and data.selected then
      if not self:targetValidity(pid) then return end
      self.selected_targets = {}
      self.scene:unselectAllTargets()
    end
    return base.selectTarget(self, pid, data)
  end

  return request
end

local HanjinPlayCard = recipientRequest(ReqPlayCard, "HanjinPlayCard")
local HanjinActiveSkill = recipientRequest(ReqActiveSkill, "HanjinActiveSkill")
local HanjinClient = BaseClient:subclass("HanjinClient")

function HanjinClient:initialize(client)
  BaseClient.initialize(self, client)
  self:addRequestHandler("PlayCard", HanjinPlayCard)
  self:addRequestHandler("AskForUseActiveSkill", HanjinActiveSkill)
end

-- ClientBase.serialize assumes the concrete class is a direct Client subclass and
-- forwards to `self.class.super`.  For this extension subclass that would call
-- back into ClientBase.serialize and recurse; forward to the base room method.
function HanjinClient:serialize()
  local o = AbstractRoom.serialize(self)
  o.you = Self.id
  return o
end

return HanjinClient
