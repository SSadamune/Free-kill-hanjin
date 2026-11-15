-- QUN001 华佗 · 济世
--
-- 规则基线：rules/generals/qun001-huatuo.md、rules/general-exchange.md。
-- 将自己的红色牌（手牌或装备牌）当【桃】对濒死角色使用，没有回合外限制；
-- 濒死结算结束后的客将交换段由模式级 qun_dying_rule 读取本技能记录的救援
-- 来源后处理，不在客户端预测事件字段。
local Q = require "packages.hanjin.pkg.hanjin_generals.util.qun_dying"

local skill = fk.CreateSkill {
  name = "hanjin__skill_qun001_1",
}
skill.hanjinImplemented = true

--- 一张仍然属于该角色且为红色的实体牌。客户端与服务器共用同一校验。
---@param player ServerPlayer|ClientPlayer
---@param id integer
---@return boolean
local function legalMaterial(player, id)
  if not table.contains(player:getCardIds("he"), id) then return false end
  local card = Fk:getCardById(id)
  return card ~= nil and card.color == Card.Red
end

--- 客户端请求信息：当前“使用桃”请求的固定目标是否都处于濒死。
--- 返回 nil 表示当前上下文没有客户端请求处理器（服务端其它入口），交由
--- before_use 用真实濒死事件复核；false 表示请求信息明确不是濒死救援。
---@return boolean?
local function requestRescuesDying()
  local client = rawget(_G, "ClientInstance")
  local handler = client and client.current_request_handler
  if handler == nil then return nil end
  local extra = handler.extra_data
  if type(extra) ~= "table" then return false end
  local ids = extra.fix_targets
  if type(ids) ~= "table" or #ids == 0 then return false end
  local room = Fk:currentRoom()
  if room == nil then return false end
  for _, id in ipairs(ids) do
    local to = room:getPlayerById(id)
    if to == nil or not to.dying then return false end
  end
  return true
end

--- 服务端复核：当前结算栈中确有本次濒死事件，且（若已带目标）目标就是该
--- 濒死角色。这里读取的是服务端真实事件，不接受客户端伪造的目标。
---@param player ServerPlayer
---@param use table
---@return boolean
local function rescuingCurrentDying(player, use)
  local room = player.room
  local logic = room and room.logic
  local current = logic and logic:getCurrentEvent()
  local dyingEvent = current and current:findParent(GameEvent.Dying, true)
  local dying = dyingEvent and dyingEvent.data and dyingEvent.data.who
  if dying == nil or dying.dead or not dying.dying then return false end
  if type(use) == "table" and type(use.tos) == "table" and #use.tos > 0 then
    for _, to in ipairs(use.tos) do
      if to ~= dying then return false end
    end
  end
  return true
end

skill:addEffect("viewas", {
  pattern = "peach",
  include_equip = true,
  prompt = "#hanjin__skill_qun001_1",
  card_filter = function(self, player, to_select, selected)
    return #selected == 0 and legalMaterial(player, to_select)
  end,
  view_as = function(self, player, cards)
    if cards == nil or #cards ~= 1 or not legalMaterial(player, cards[1]) then return nil end
    local card = Fk:cloneCard("hanjin__peach")
    card.skillName = skill.name
    card:addSubcard(cards[1])
    return card
  end,
  -- 济世只用于救援濒死，不是出牌阶段自我回复的常规【桃】。
  enabled_at_play = Util.FalseFunc,
  -- 求桃是“使用”窗口；客户端若能从请求信息确认目标非濒死则不开放。
  enabled_at_response = function(self, player, cardResponsing)
    if cardResponsing then return false end
    local requestDying = requestRescuesDying()
    if requestDying ~= nil then return requestDying end
    return true
  end,
  -- 服务端在真实使用前复核：必须处于本次濒死结算，且真实目标为濒死角色。
  before_use = function(self, player, use)
    if not rescuingCurrentDying(player, use) then return skill.name end
  end,
})

-- 在牌真正宣告使用时记录救援来源，而不是等 after_use 退出回调：
-- 桃回复成功后 hp.lua 会立刻把 dying 置 false，after_use 再读 to.dying 会漏记
-- 成功救起的这一次。CardUsing 在效果结算前触发，此时濒死上下文仍有效。
skill:addEffect(fk.CardUsing, {
  mute = true,
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and data ~= nil and data.card ~= nil
      and data.card.trueName == "peach" and data.card.skillName == skill.name
      and rescuingCurrentDying(player, data)
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local side = Q.sourcePosition(player, skill.name)
    if side == nil then return end
    for _, to in ipairs(data.tos or {}) do
      if to.dying and not to.dead then
        Q.recordRescue(player.room, to, side)
      end
    end
  end,
})

Fk:loadTranslationTable {
  ["#hanjin__skill_qun001_1"] = "济世：将一张红色牌当【桃】对濒死角色使用",
  ["#hanjin__skill_qun001_1-exchange"] = "济世：是否用你的一张武将牌交换 %dest 的华佗？",
  ["#hanjin__skill_qun001_1-choose-position"] = "济世：选择用哪一张明置武将牌交换此华佗",
  ["#hanjin__skill_qun001_1-main"] = "主将",
  ["#hanjin__skill_qun001_1-deputy"] = "副将",
}

return skill
