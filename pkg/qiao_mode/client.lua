-- 汉晋使用引擎的客户端注册接口提供技能交互，不修改本体请求处理类。
local Modes = require "packages.qiao.pkg.qiao_mode.modes"
local BaseClient = require "ltk.client.client"
local AbstractRoom = require "ltk.core.room.abstract_room"
local ReqPlayCard = require "ltk.core.request_type.play_card"
local ReqUseCard = require "ltk.core.request_type.use_card"
local ReqActiveSkill = require "ltk.core.request_type.active_skill"
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"
local ActiveSkillLimits = require "packages.qiao.pkg.qiao_mode.rules.active_skill_limits"
local SkillPrelight = require "packages.qiao.pkg.qiao_mode.rules.skill_prelight"
local TriggerSelection = require "packages.qiao.pkg.qiao_mode.rules.trigger_selection"
local SkillButtons = require "packages.qiao.pkg.qiao_mode.rules.skill_buttons"
local SkillStatus = require "packages.qiao.pkg.qiao_mode.skill_status"
local Han = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_han"
local Ci = require "packages.qiao.pkg.qiao_generals.util.jin_ci"
local Adaptation = require "packages.qiao.pkg.qiao_mode.rules.adaptation"
local Cards = require "packages.qiao.pkg.qiao_mode.rules.cards"
local Guest = require "packages.qiao.pkg.qiao_mode.rules.guest_factions"
local MountDistance = require "packages.qiao.pkg.qiao_cards.mount_distance"
local Retinues = require "packages.qiao.pkg.qiao_generals.util.retinue_instances"
local Commander = require "packages.qiao.pkg.qiao_mode.rules.commander_retinue"
local LtkUI = require "packages.freekill-core.ltk.client.util"

local function checkSelectedTargets(request, targetValidity)
  local selected = request.selected_targets
  if #selected == 0 then return true end
  -- 同一次用牌的所有目标必须能用同一张武将牌支付代价。按原选择顺序复核。
  local prefix = {}
  request.selected_targets = prefix
  local ok, valid = pcall(function()
    for _, id in ipairs(selected) do
      if not targetValidity(request, id) then return false end
      table.insert(prefix, id)
    end
    return true
  end)
  request.selected_targets = selected
  if not ok then error(valid, 0) end
  return valid
end

local function checkCommanderCost(request, targetValidity, check)
  if request.skill_name == Commander.ABILITY_SKILL and Modes.inRoom(Fk:currentRoom()) then
    local card = request:getUsingCard()
    if card then
      return Commander.clientHasLegalCost(request.player, card, function()
        return checkSelectedTargets(request, targetValidity) and check()
      end)
    end
  end
  return check()
end

local function activeSelectionSkill(request)
  if not Modes.inRoom(request.room) or request.sub_selection_flag
    or not TriggerSelection.applies(request.skill_name, request.extra_data) then return end
  local skill = Fk.skills[request.skill_name]
  if skill:isInstanceOf(ActiveSkill) then return skill end
end

local function canReplaceTarget(request)
  local skill = activeSelectionSkill(request)
  return skill ~= nil and skill:getMaxTargetNum(request.player) == 1
end

local function skillTargetRequest(base, name)
  local request = base:subclass(name)

  function request:targetValidity(pid)
    if RemovedTargets.inMode(self.room)
      and RemovedTargets.isRemoved(self.room:getPlayerById(pid)) then return false end
    if self.selected_targets and #self.selected_targets > 0 and canReplaceTarget(self) then
      -- 目标上限为一时，以替换后的空列表判断候选，保留技能原有的目标筛选。
      local previous = self.selected_targets
      self.selected_targets = {}
      local ok, valid = pcall(base.targetValidity, self, pid)
      self.selected_targets = previous
      if not ok then error(valid, 0) end
      return valid
    end
    return checkCommanderCost(self, base.targetValidity, function() return base.targetValidity(self, pid) end)
  end

  function request:selectCard(cid, data)
    local skill = activeSelectionSkill(self)
    if data.selected and skill and skill:getMaxCardNum(self.player) == 0 then return end
    return base.selectCard(self, cid, data)
  end

  function request:selectTarget(pid, data)
    if data.selected and canReplaceTarget(self) then
      if table.contains(self.selected_targets, pid) or not self:targetValidity(pid) then return end
      self.selected_targets = {}
      self.scene:unselectAllTargets()
    end
    return base.selectTarget(self, pid, data)
  end

  return request
end

local QiaoPlayCard = skillTargetRequest(ReqPlayCard, "QiaoPlayCard")
-- 锁定本体按 class.name 识别「使用牌」请求，例如禁止用牌的界面提示。
local QiaoUseCard = skillTargetRequest(ReqUseCard, ReqUseCard.name)
local QiaoActiveSkill = skillTargetRequest(ReqActiveSkill, "QiaoActiveSkill")

local function usesTriggerSelection(request)
  return Modes.inRoom(request.room) and not request.sub_selection_flag
    and TriggerSelection.applies(request.skill_name, request.extra_data, request.cancelable)
end

local function uniqueItem(items, valid)
  local found
  for id, item in pairs(items) do
    if item.enabled and valid(id) then
      if found ~= nil then return nil end
      found = id
    end
  end
  return found
end

local function selectUniqueTarget(request, skill, user)
  if #request.selected_targets ~= 0 or skill:getMinTargetNum(user) ~= 1 then return false end
  local id = uniqueItem(request.scene:getAllItems("Photo"), function(id) return request:targetValidity(id) end)
  if id == nil then return false end
  request:selectTarget(id, { selected = true })
  return true
end

local function withoutAutoTarget(data)
  if type(data) ~= "table" or not data.autoTarget then return data end
  data = table.simpleClone(data)
  data.autoTarget = false
  return data
end

function QiaoActiveSkill:selectUniqueCandidates()
  local skill = Fk.skills[self.skill_name]
  local function selectCard()
    if #self.pendings ~= 0 or skill:getMinCardNum(self.player) ~= 1 then return end
    local id = uniqueItem(self.scene:getAllItems("CardItem"), function(id) return self:cardValidity(id) end)
    if id ~= nil then
      self:selectCard(id, { selected = true })
      self:initiateTargets()
      return true
    end
  end

  local cardSelected = selectCard()
  local card = self:getUsingCard()
  local user = self.player
  if card and self.extra_data and self.extra_data.fix_user then
    user = self.room:getPlayerById(self.extra_data.fix_user) or user
  end
  local targetSkill = card and card:getSkill(user) or skill
  if selectUniqueTarget(self, targetSkill, user) then
    selectCard()
    return true
  end
  return cardSelected
end

function QiaoActiveSkill:refreshAfterUniqueSelection()
  -- Refresh only after an actual automatic selection. View-as interactions
  -- send incremental UI data, so a redundant refresh can discard new entries.
  if self:selectUniqueCandidates() then
    self:refreshInteraction()
    self:updateButtons()
    self:updatePrompt()
  end
end

function QiaoActiveSkill:setup(ignoreInteraction, data)
  if not usesTriggerSelection(self) then return ReqActiveSkill.setup(self, ignoreInteraction, data) end
  ReqActiveSkill.setup(self, ignoreInteraction)
  self:refreshAfterUniqueSelection()
end

function QiaoActiveSkill:update(elemType, id, action, data)
  if not usesTriggerSelection(self) then return ReqActiveSkill.update(self, elemType, id, action, data) end
  if elemType == "Button" and id == "OK" and not self:feasible() then return false end
  local result = ReqActiveSkill.update(self, elemType, id, action, withoutAutoTarget(data))
  if elemType == "Interaction" or ((elemType == "CardItem" or elemType == "Photo") and data.selected) then
    self:refreshAfterUniqueSelection()
  end
  return result
end

local function usesTriggerCard(request)
  return Modes.inRoom(request.room) and request.extra_data and request.extra_data.qiao_trigger_use
end

function QiaoUseCard:selectTriggerTarget()
  local card = self:getUsingCard()
  if card then
    selectUniqueTarget(self, card:getSkill(self.player), self.player)
    self:updateButtons()
    self:updatePrompt()
  end
end

function QiaoUseCard:setup()
  ReqUseCard.setup(self)
  if not usesTriggerCard(self) then return end
  for _, item in pairs(self.scene:getAllItems("SkillButton")) do
    if item.enabled then return end
  end
  local id = uniqueItem(self.scene:getAllItems("CardItem"), function(id) return self:cardValidity(id) end)
  if id ~= nil and #(Fk:getCardById(id).special_skills or {}) == 0 then
    self:selectCard(id, { selected = true })
    self:initiateTargets()
    self:selectTriggerTarget()
  end
end

function QiaoUseCard:update(elemType, id, action, data)
  if not usesTriggerCard(self) or self.sub_selection_flag then
    return ReqUseCard.update(self, elemType, id, action, data)
  end
  if elemType == "Button" and id == "OK" and not self:feasible() then return false end
  local result = ReqUseCard.update(self, elemType, id, action, withoutAutoTarget(data))
  if elemType == "CardItem" and data.selected and not self.sub_selection_flag then self:selectTriggerTarget() end
  return result
end

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

local hiddenGeneralMarks = { __heg_general = true, __heg_deputy = true }

function QiaoClient:ownHiddenGenerals(playerId)
  if self.observing or self.replaying or not Self or Self.id ~= playerId
    or Self.general ~= "anjiang" or Self.deputyGeneral ~= "anjiang" then return false end
  local main = Self:getMark("__heg_general")
  local deputy = Self:getMark("__heg_deputy")
  if not Fk.generals[main] or not Fk.generals[deputy] then return false end
  return { main, deputy }
end

function QiaoClient:handleSetPlayerMark(data)
  BaseClient.handleSetPlayerMark(self, data)
  if SkillStatus.watches(data[2]) then
    self:notifyUI("QiaoSkillStatusChanged", {})
  end
  if hiddenGeneralMarks[data[2]] and Self and data[1] == Self.id then
    self:notifyUI("QiaoOwnHiddenGeneralsChanged", {})
  end
end

function QiaoClient:sendDataToUI(data)
  BaseClient.sendDataToUI(self, data)
  self:notifyUI("QiaoSkillStatusChanged", {})
  self:notifyUI("QiaoGuestFactionsChanged", {})
  self:notifyUI("QiaoOwnHiddenGeneralsChanged", {})
  self:notifyUI("QiaoDiscardChanged", {})
end

function QiaoClient:skillStates(playerId)
  return SkillStatus.forPlayer(self:getPlayerById(playerId))
end

--- 普通出牌请求中，主动技按钮与确认键共用服务端同一份次数声明检查。
--- 辅助／额外发动与无次数声明的转化由 M.appliesTo 排除，其他模式由 M.exhausted 排除。
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
  return checkCommanderCost(self, ReqPlayCard.targetValidity, function() return ReqPlayCard.feasible(self) end)
end

function QiaoUseCard:feasible()
  return checkCommanderCost(self, ReqUseCard.targetValidity, function() return ReqUseCard.feasible(self) end)
end

local pileActions = {
  QiaoEdict = Han.CONSUME,
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
    and self.player:hasSkill(skill) and self:skillButtonValidity(skill)
end

function QiaoPlayCard:update(elemType, id, action, data)
  if elemType == "Interaction" and self.skill_name == Ci.CONSUME then
    if action == "cancel" then
      self:doCancelButton()
    elseif action == "finish" and Ci.validAction(self.player, data) then
      self:updateInteraction(data, true)
      if self:feasible() then return ReqPlayCard.update(self, "Button", "OK", action, data) end
    end
    return false
  end
  local skill = pileActions[elemType]
  if not skill then
    return ReqPlayCard.update(self, elemType, id, action, data)
  end
  if action ~= "click" or not self:canUsePileAction(id, skill) then return false end
  self:selectSkill(skill, { selected = true })
  if not self:feasible() then
    self:doCancelButton()
    return false
  end
  return ReqPlayCard.update(self, "Button", "OK", action, data)
end

function QiaoClient:initialize(client)
  BaseClient.initialize(self, client)
  self.lockedPairing = nil
  self:addRequestHandler("PlayCard", QiaoPlayCard)
  self:addRequestHandler("AskForUseCard", QiaoUseCard)
  self:addRequestHandler("AskForUseActiveSkill", QiaoActiveSkill)
end

function QiaoClient:playCard(data)
  self.qiaoCiActions = type(data) == "table" and data.qiaoCiActions or nil
  return BaseClient.playCard(self, data)
end

function QiaoClient:getSettings(key)
  if key == "enableFreeAssign" and BaseClient.getSettings(self, "gameMode") == Modes.locked then
    return false
  end
  return BaseClient.getSettings(self, key)
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
  if data[1] == "all_kingdoms" then
    self:notifyUI("QiaoGuestFactionsChanged", {})
  end
  if data[1] == "qiao_discard_before_turn" then
    self:notifyUI("QiaoDiscardChanged", {})
  end
end

function QiaoClient:guestIllustrationsEnabled()
  return self.settings ~= nil and Modes.inRoom(self) and Guest.replacementEnabled(self)
end

function QiaoClient:guestCardFactions()
  local allowed = self:getBanner("all_kingdoms")
  if not self:guestIllustrationsEnabled() or not allowed then return {} end
  return Guest.replacementFactionsForDisplay(allowed)
end

-- 读取客户端同步的实体弃牌堆。桌面动画消失时，这些牌可能仍在堆中。
function QiaoClient:discardCardsForDisplay()
  local cards = {}
  local lordEquipment = Fk.packages.qiao_cards.qiao.lordEquipment
  local beforeTurn = self:getBanner("qiao_discard_before_turn")
  local older = {}
  for _, id in ipairs(beforeTurn or {}) do older[id] = true end
  for index = #self.discard_pile, 1, -1 do
    local id = self.discard_pile[index]
    local card = Fk:getCardById(id, true)
    local thisTurn = beforeTurn ~= nil and not older[id]
    if card and Self:cardVisible(id) then
      local fallback = {}
      -- 直接弃置的可见牌可能未经过手牌／处理区的应变显示同步。
      for index, entry in ipairs(Adaptation.displayEntries(card)) do
        local key = Adaptation.markKey(index, entry.condition)
        if card:getMark(key) == 0 then
          table.insert(fallback, { k = key, v = Adaptation.markValue(entry) })
        end
      end
      if Cards.isHeji(card) and not Cards.hasAllianceMark(card) then
        table.insert(fallback, { k = Cards.ALLIANCE_PUBLIC, v = 1 })
      end
      table.insert(cards, {
        id = id, name = Fk:translate(card.name), markFallbacks = fallback,
        lord = lordEquipment[card.name] ~= nil,
        thisTurn = thisTurn,
      })
    else
      table.insert(cards, { name = Fk:translate("unknown_card"), thisTurn = thisTurn })
    end
  end
  return cards
end

function QiaoClient:setCardMark(data)
  BaseClient.setCardMark(self, data)
  if data[2]:startsWith("@") and self:getCardArea(data[1]) == Card.DiscardPile then
    self:notifyUI("QiaoDiscardChanged", {})
  end
end

function QiaoClient:handleShuffleDrawPile(data)
  BaseClient.handleShuffleDrawPile(self, data)
  if Modes.inRoom(self) then self:notifyUI("QiaoDiscardChanged", {}) end
end

function QiaoClient:handleChangeCardArea(data)
  BaseClient.handleChangeCardArea(self, data)
  if Modes.inRoom(self) then self:notifyUI("QiaoDiscardChanged", {}) end
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

local getSameGenerals = LtkUI.getSameGenerals
function LtkUI:getSameGenerals(name)
  local names = getSameGenerals(self, name)
  local room = Fk:currentRoom()
  local pairing = room and room.lockedPairing
  if pairing then
    return table.filter(names, function(alternative) return pairing[alternative] ~= nil end)
  end
  return names
end

function QiaoClient:virtualCardPicture(name)
  local formal = "qiao__" .. name
  if Fk.all_card_types[formal] and Fk.all_card_types[formal].package.extensionName == "qiao" then
    return formal
  end
  return name
end

function QiaoClient:canPrelightSkill(skillName)
  return SkillPrelight.canPrelight(skillName)
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
  if self.settings and self:getSettings("gameMode") == Modes.locked then
    if command == "CustomDialog" then
      local model = data.component and data.component.model
      local extra = model and model.prop and model.prop.extraData
      self.lockedPairing = extra and extra.locked and extra.pairing or nil
    elseif command == "CancelRequest" or command == "GameStart" or command == "GameOver"
      or command == "ChangeSelf" then
      self.lockedPairing = nil
    end
  end
  if command == "SetPlayerMark" and SkillStatus.watches(data[2]) and isQiaoMode() then
    return
  end
  if command == "SetPlayerMark" and data[2] == Ci.MARK and isQiaoMode() then
    -- Both live updates and the rejoin snapshot take this path. The room's
    -- picture-mark row owns the button, so omit the default text mark.
    return BaseClient.notifyUI(self, "QiaoCiChanged", { data[1] })
  end
  if command == "AskForChoices" and data[8] and not data[7]
    and data[3][1] == 1 and data[3][2] == 1 and isQiaoMode() then
    -- Keep the server request and its AI strategy. Let the room choose where to display it.
    return BaseClient.notifyUI(self, "QiaoSingleChoice", data)
  end
  if (command == "AddSkill" or command == "LoseSkill") and data[3]
    and isQiaoMode() and not SkillPrelight.canPrelight(data[2]) then
    if command == "AddSkill" then
      local skill = Fk.skills[data[2]]
      if skill:isInstanceOf(ActiveSkill) or skill:isInstanceOf(ViewAsSkill) then
        -- Rejoin sends the hidden skill straight to the UI. Restore the same
        -- request-handler skill list that Client:addSkill fills during play.
        local player = self:getPlayerById(data[1])
        table.insertIfNeed(player.player_skills, skill)
      end
    end
    data = { data[1], data[2] }
  end
  if command == "SetPlayerMark" and data[2] == Retinues.PUBLIC_MARK and isQiaoMode() then
    return
  end
  if command == "Ltk.SkillInvoked" and isQiaoMode() then
    data = stripRichText(data)
  end
  if command == "CustomDialog" and data.component
    and (data.component.url == "packages/utility/qml/ChooseGeneralsAndChoiceBox.qml"
      or data.component.url == "packages/hegemony/qml/KnownBothBox.qml")
    and isQiaoMode() then
    data = table.simpleClone(data)
    data.component = table.simpleClone(data.component)
    data.component.url = "packages/qiao/pkg/qiao_mode/qml/QiaoGeneralChoiceBox.qml"
    if data.component.model
      and data.component.model.url == "packages/utility/qml/models/ChooseGeneralsAndChoiceModel.qml" then
      data.component.model = table.simpleClone(data.component.model)
      data.component.model.url = "packages/qiao/pkg/qiao_mode/qml/QiaoGeneralChoicesModel.qml"
    end
  end
  -- RoomModel registers MoveCards in its own Component.onCompleted. Route
  -- live moves and reconnect snapshots to the Han-Jin room's separate callback.
  local uiCommand = command
  if command == "MoveCards" and self.settings and Modes.inRoom(self) then
    uiCommand = "QiaoMoveCards"
  end
  BaseClient.notifyUI(self, uiCommand, data)
  if (command == "AddSkill" or command == "LoseSkill") and data[2] == "ld__jilis" and isQiaoMode() then
    BaseClient.notifyUI(self, "QiaoSkillStatusChanged", {})
  end
  if command == "ChangeSelf" and isQiaoMode() then
    BaseClient.notifyUI(self, "QiaoRefreshPrelightButtons", {})
    BaseClient.notifyUI(self, "QiaoOwnHiddenGeneralsChanged", {})
  end
  if pileActionUpdates[command] and isQiaoMode() then
    BaseClient.notifyUI(self, "QiaoPileActionChanged", {})
  end
end

return QiaoClient
