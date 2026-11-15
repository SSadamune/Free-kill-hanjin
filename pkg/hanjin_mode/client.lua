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

-- 实体牌和虚拟牌脚注共用 parseMsg(msg, true)，但引擎仍给玩家名加 font/b
-- 标签。汉晋脚注去除这些标签，避免标签泄漏到结算区；普通日志及其他模式沿用原格式。
local function stripRichText(text)
  if type(text) ~= "string" then return text end
  text = text:gsub("<%s*/?%s*[Bb]%s*>", "")
  text = text:gsub("<%s*/?%s*[Ff][Oo][Nn][Tt][^>]*>", "")
  return text
end

local function isHanjinMode()
  local room = Fk:currentRoom()
  if room == nil or type(room.getSettings) ~= "function" then return false end
  return room:getSettings("gameMode") == "hanjin_heg_mode"
end

--- 脚注/虚拟牌提示的纯文本化：只覆盖 nocolor == true 的调用，继承
--- setCardNote 与 showVirtualCard 两条通知路径，不另写重复的脚注流程。
function HanjinClient:parseMsg(msg, nocolor, visible_data)
  local text = BaseClient.parseMsg(self, msg, nocolor, visible_data)
  if nocolor == true and isHanjinMode() then
    return stripRichText(text)
  end
  return text
end

return HanjinClient
