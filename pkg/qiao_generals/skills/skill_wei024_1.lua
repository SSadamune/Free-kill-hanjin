-- WEI024 常令（军令）
-- 准备阶段：将一张手牌交给一名其他势力角色，对其发起一次军令。其执行则
-- 自己摸一张；不执行则本回合摸牌阶段多摸三张。
local H = require "packages.hegemony.util"

local skill = fk.CreateSkill { name = "qiao__skill_wei024_1" }
skill.qiaoImplemented = true

local EXTRA = "qiao_wei024_extra_draw"

--- “其他势力角色”取同势力的补集，包含尚未确定势力的其他角色。
--- 规则依据另见 docs/rules/general-principles.md“易读描述中的‘非’”及
--- docs/rules/generals/em-wei001-caocao.md“常令”。
---@param holder ServerPlayer
---@param target ServerPlayer?
---@return boolean
local function isLegalTarget(holder, target)
  return target ~= nil and target ~= holder
    and not target.dead and not target:isRemoved()
    and not H.compareKingdomWith(holder, target)
end

---@param room Room
---@param holder ServerPlayer
---@return ServerPlayer[]
local function legalTargets(room, holder)
  return table.filter(room:getPresentPlayers(), function(p)
    return isLegalTarget(holder, p)
  end)
end

skill:addEffect(fk.EventPhaseStart, {
  can_trigger = function(self, event, target, player, data)
    -- 自定义 can_trigger 会取代 TriggerSkill 默认的持有者校验；临时来源到期后
    -- 触发器仍留在房间里，因此这里显式确认当前准备阶段角色仍持有可生效的常令。
    -- 同一事件内新获得的常令也要能读条，故按实时 hasSkill 判断，不缓存名单。
    if target ~= player or player.dead or player.phase ~= Player.Start then return false end
    if not player:hasSkill(skill.name) then return false end
    if player:isKongcheng() then return false end
    return #legalTargets(player.room, player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local tos = room:askToChoosePlayers(player, {
      targets = legalTargets(room, player),
      min_num = 1, max_num = 1, skill_name = skill.name,
      prompt = "#qiao__wei024_ask_target", cancelable = true,
    })
    if tos == nil or #tos == 0 then return false end
    local to = tos[1]
    -- 触发、选人与提交共用同一目标判断。
    if not isLegalTarget(player, to) then return false end
    local cards = room:askToCards(player, {
      min_num = 1, max_num = 1, include_equip = false,
      skill_name = skill.name, prompt = "#qiao__wei024_ask_card", cancelable = true,
    })
    if cards == nil or #cards == 0 then return false end
    event:setCostData(self, { to = to, card = cards[1] })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self) or {}
    local to, card = cost.to, cost.card
    -- 结算前复核：施放者仍是当前准备阶段角色且常令仍可生效，目标仍符合其他势力条件，
    -- 所选牌仍是其手牌。复核失败则不交牌、不发起军令。
    if target ~= player or player.dead or not player:hasSkill(skill.name) then return end
    if card == nil or not isLegalTarget(player, to) then return end
    if not table.contains(player:getCardIds(Player.Hand), card) then return end
    room:obtainCard(to, card, true, fk.ReasonGive, player, skill.name)
    local executed = H.askToCommand(player, {
      tos = { to },
      skill_name = skill.name,
    })
    if executed then
      if not player.dead then player:drawCards(1, skill.name) end
    else
      room:addPlayerMark(player, EXTRA, 3)
    end
  end,
})

skill:addEffect(fk.DrawNCards, {
  can_refresh = function(self, event, target, player, data)
    return target == player and player:getMark(EXTRA) > 0
  end,
  on_refresh = function(self, event, target, player, data)
    data.n = data.n + player:getMark(EXTRA)
  end,
})

skill:addEffect(fk.TurnEnd, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return target == player and player:getMark(EXTRA) > 0
  end,
  on_refresh = function(self, event, target, player, data)
    player.room:setPlayerMark(player, EXTRA, 0)
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_wei024_1"] = "常令",
  [":qiao__skill_wei024_1"] = "准备阶段，你可以将一张手牌交给一名其他势力角色，对其发起一次“军令”。若其执行，你摸一张牌；若其不执行，你于本回合摸牌阶段多摸三张牌。",
  ["#qiao__wei024_ask_target"] = "常令：选择一名其他势力角色",
  ["#qiao__wei024_ask_card"] = "常令：选择一张手牌交给其",
}

return skill
