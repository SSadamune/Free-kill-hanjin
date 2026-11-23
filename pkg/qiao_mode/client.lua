-- 汉晋使用引擎的客户端注册接口提供技能交互，不修改本体请求处理类。
local Modes = require "packages.qiao.pkg.qiao_mode.modes"
local BaseClient = require "ltk.client.client"
local AbstractRoom = require "ltk.core.room.abstract_room"
local ReqPlayCard = require "ltk.core.request_type.play_card"
local ReqActiveSkill = require "ltk.core.request_type.active_skill"
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"
local ActiveSkillLimits = require "packages.qiao.pkg.qiao_mode.rules.active_skill_limits"
local SkillPrelight = require "packages.qiao.pkg.qiao_mode.rules.skill_prelight"
local SkillButtons = require "packages.qiao.pkg.qiao_mode.rules.skill_buttons"
local Han = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_han"
local Ci = require "packages.qiao.pkg.qiao_generals.util.jin_ci"
local Guest = require "packages.qiao.pkg.qiao_mode.rules.guest_factions"
local MountDistance = require "packages.qiao.pkg.qiao_cards.mount_distance"
local Retinues = require "packages.qiao.pkg.qiao_generals.util.retinue_instances"
local LtkUI = require "packages.freekill-core.ltk.client.util"
local MZ = "qiao__skill_han001_2"

--- Only the HanJin room's 密诏 request uses the recipient-replacement UI.
--- The shared board client also serves every upstream room, so all other modes
--- and skills must keep the original request class behavior.
local function isQiaoMZ(request)
  if request.skill_name ~= MZ then return false end
  local room = request.room or Fk:currentRoom()
  return room ~= nil and Modes.inRoom(room)
end

local function recipientRequest(base, name)
  local request = base:subclass(name)

  function request:targetValidity(pid)
    if RemovedTargets.inMode(self.room)
      and RemovedTargets.isRemoved(self.room:getPlayerById(pid)) then return false end
    if not isQiaoMZ(self) then return base.targetValidity(self, pid) end
    local to = self.room:getPlayerById(pid)
    -- 其他合法角色保持可点击；每次点击都是替换收牌者，而非追加目标。
    return to ~= nil and not not Fk.skills[MZ]:targetFilter(
      self.player, to, {}, self.pendings, nil, self.extra_data)
  end

  function request:selectTarget(pid, data)
    if isQiaoMZ(self) and data.selected then
      if not self:targetValidity(pid) then return end
      self.selected_targets = {}
      self.scene:unselectAllTargets()
    end
    return base.selectTarget(self, pid, data)
  end

  return request
end

local QiaoPlayCard = recipientRequest(ReqPlayCard, "QiaoPlayCard")
local QiaoActiveSkill = recipientRequest(ReqActiveSkill, "QiaoActiveSkill")

--- virtual_viewas 的候选牌名可用性要按当前请求的 extra_data 复核。
--- 上游刷新只调用 canUseOrResponseInCurrent(card)，正常出杀后再由仁德等
--- 视为使用【杀】时 bypass_times 未进入次数判断，候选【杀】因此被置灰。
--- 只在本模式的 virtual_viewas 请求上补 extra_data；服务端 choices 仍是
--- 候选上限，canUse 仍保留客户端已知的禁止使用判断，其他请求沿用原行为。
function QiaoActiveSkill:refreshInteraction()
  if self.skill_name ~= "virtual_viewas" or not Modes.inRoom(self.room) then
    return ReqActiveSkill.refreshInteraction(self)
  end

  local skill = Fk.skills.virtual_viewas
  if not (skill and skill.interaction and skill.refresh_interaction) then return end
  local extra_data = self.extra_data or {}
  local refresh_data = skill:refresh_interaction(
    self.player, self.pendings or {},
    table.map(self.selected_targets, Util.Id2PlayerMapper),
    extra_data)
  if refresh_data == nil then return end

  if refresh_data.expandItems and extra_data.choices then
    for _, item in ipairs(refresh_data.expandItems) do
      local prop = item.prop
      if prop and prop.card and prop.additional_prop then
        prop.additional_prop.selectable = table.contains(extra_data.choices, item.name)
          and not not self.player:canUseOrResponseInCurrent(prop.card, extra_data)
      end
    end
  end

  self.scene:update("Interaction", "1", { refresh_data = refresh_data })
end

local QiaoClient = BaseClient:subclass("QiaoClient")

--- 普通出牌请求中，主动技按钮与确认键共用服务端同一份次数声明检查。
--- 辅助/额外发动、ViewAs 与牌使用由 M.appliesTo 排除，其他模式由 M.exhausted 排除。
local function exhaustedActiveSkill(request, name)
  return ActiveSkillLimits.exhausted(Fk.skills[name], request.player, Fk:currentRoom())
end

function QiaoPlayCard:skillButtonValidity(name)
  if exhaustedActiveSkill(self, name) then return false end
  return ReqPlayCard.skillButtonValidity(self, name)
end

function QiaoPlayCard:feasible()
  if self.skill_name and exhaustedActiveSkill(self, self.skill_name) then
    return false
  end
  return ReqPlayCard.feasible(self)
end

local pileActions = {
  QiaoEdict = Han.CONSUME,
  QiaoCi = Ci.CONSUME,
}

local pileActionUpdates = {
  AddSkill = true,
  LoseSkill = true,
  MoveCards = true,
  PlayCard = true,
  PropertyUpdate = true,
  SetPlayerMark = true,
  UpdateRequestUI = true,
}

function QiaoPlayCard:canUsePileAction(holderId, skill)
  return RemovedTargets.inMode(self.room) and self.player.id == holderId
    and self.skill_name == nil and self.selected_card == nil
    and (skill == Ci.CONSUME or self.player:hasSkill(skill)) and self:skillButtonValidity(skill)
end

function QiaoPlayCard:update(elemType, id, action, data)
  local skill = pileActions[elemType]
  if not skill then
    return ReqPlayCard.update(self, elemType, id, action, data)
  end
  if action ~= "click" or not self:canUsePileAction(id, skill) then return false end
  local chosenCi = elemType == "QiaoCi" and data and data.general
  if elemType == "QiaoCi" and not Ci.canChoose(self.player, chosenCi) then return false end
  self:selectSkill(skill, { selected = true })
  if not self:feasible() then
    self:doCancelButton()
    return false
  end
  if chosenCi then Fk.skills[skill].interaction.data = chosenCi end
  local accepted = ReqPlayCard.update(self, "Button", "OK", action, data)
  if chosenCi then Fk.skills[skill].interaction.data = nil end
  return accepted
end

function QiaoClient:initialize(client)
  BaseClient.initialize(self, client)
  self:addRequestHandler("PlayCard", QiaoPlayCard)
  self:addRequestHandler("AskForUseActiveSkill", QiaoActiveSkill)
end

function QiaoClient:canUsePileAction(holderId, action)
  local request = self.current_request_handler
  local skill = pileActions[action]
  return not self.observing and not self.replaying and request ~= nil
    and skill ~= nil and request:isInstanceOf(QiaoPlayCard) and request:canUsePileAction(holderId, skill)
end

function QiaoClient:canConsumeEdict(holderId)
  return self:canUsePileAction(holderId, "QiaoEdict")
end

function QiaoClient:canConsumeCi(holderId, general)
  return self:canUsePileAction(holderId, "QiaoCi")
    and Ci.canChoose(self.current_request_handler.player, general)
end

function QiaoClient:ciCardsForDisplay(holderId)
  local holder = self:getPlayerById(holderId)
  return holder and holder:getMark(Ci.MARK) ~= 0 and Ci.cards(holder) or false
end

function QiaoClient:handleSetBanner(data)
  BaseClient.handleSetBanner(self, data)
  -- The base client forwards only visible (@) banners to QML.
  if data[1] == Han.TRICK_BANNER then
    self:notifyUI("QiaoPileActionChanged", {})
  end
end

function QiaoClient:guestIllustrationsEnabled()
  return self.settings ~= nil and Guest.replacementEnabled(self)
end

function QiaoClient:mountDistanceLabels()
  return MountDistance.labels(self.players)
end

-- ClientBase.serialize assumes the concrete class is a direct Client subclass and
-- forwards to `self.class.super`.  For this extension subclass that would call
-- back into ClientBase.serialize and recurse; forward to the base room method.
function QiaoClient:serialize()
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

local function isQiaoMode()
  local room = Fk:currentRoom()
  if room == nil or type(room.getSettings) ~= "function" then return false end
  return Modes.inRoom(room)
end

-- 上游国战红颜也通过锁视变更实体牌的有效花色。手牌面板仍显示印刷花色，
-- 判定、出牌、筛选和花色统计继续读取引擎锁视后的牌。
local getCardData = LtkUI.getCardData
function LtkUI:getCardData(id, filterCard)
  local data = getCardData(self, id, filterCard)
  if filterCard and isQiaoMode() and Fk:currentRoom():getCardArea(id) == Card.PlayerHand then
    local card = Fk:getCardById(id)
    if card and card.skillName == "qiao__skill_wu011_2" then
      local printed = Fk:getCardById(id, true)
      data.suit, data.color = printed:getSuitString(), printed:getColorString()
    end
  end
  return data
end

function QiaoClient:virtualCardPicture(name)
  local formal = "qiao__" .. name
  if Fk.all_card_types[formal] and Fk.all_card_types[formal].package.extensionName == "qiao" then
    return formal
  end
  return name
end

function QiaoClient:isStateOnlySkill(skillName)
  return SkillPrelight.isStateOnly(skillName)
end

function QiaoClient:skillButtonLabel(skillName, label, prelight)
  return SkillButtons.label(Fk.skills[skillName], label, prelight, Self)
end

--- 脚注/虚拟牌提示的纯文本化：只覆盖 nocolor == true 的调用，继承
--- setCardNote 与 showVirtualCard 两条通知路径，不另写重复的脚注流程。
function QiaoClient:parseMsg(msg, nocolor, visible_data)
  local text = BaseClient.parseMsg(self, msg, nocolor, visible_data)
  if nocolor == true and isQiaoMode() then
    return stripRichText(text)
  end
  return text
end

function QiaoClient:notifyUI(command, data)
  if command == "SetPlayerMark" and data[2] == Ci.MARK and isQiaoMode() then
    -- Both live updates and the rejoin snapshot take this path. The room's
    -- picture-mark row owns the button, so omit the default text mark.
    return BaseClient.notifyUI(self, "QiaoCiChanged", { data[1] })
  end
  if (command == "AddSkill" or command == "LoseSkill") and data[3]
    and isQiaoMode() and SkillPrelight.isStateOnly(data[2]) then
    data = { data[1], data[2] }
  end
  if command == "SetPlayerMark" and data[2] == Retinues.PUBLIC_MARK and isQiaoMode() then
    return
  end
  -- The native rejoin snapshot may emit fake-skill notifications for active skills.
  if command == "AddSkill" and data[3] and data[2] == "qiao__skill_han007_1"
    and isQiaoMode() then return end
  if command == "Ltk.SkillInvoked" and isQiaoMode() then
    data = stripRichText(data)
  end
  if command == "CustomDialog" and data.component
    and data.component.url == "packages/utility/qml/ChooseGeneralsAndChoiceBox.qml"
    and isQiaoMode() then
    data = table.simpleClone(data)
    data.component = table.simpleClone(data.component)
    data.component.url = "packages/qiao/pkg/qiao_mode/qml/QiaoGeneralChoiceBox.qml"
  end
  BaseClient.notifyUI(self, command, data)
  if command == "ChangeSelf" and isQiaoMode() then
    BaseClient.notifyUI(self, "QiaoRefreshStateSkillButtons", {})
  end
  if pileActionUpdates[command] and isQiaoMode() then
    BaseClient.notifyUI(self, "QiaoPileActionChanged", {})
  end
end

return QiaoClient
