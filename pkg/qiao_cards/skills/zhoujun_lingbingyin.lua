-- 州郡领兵印：进入装备区后按装备者当前的大／小势力类别逐人询问同类别角色
-- 是否交一张自己的手牌或装备；准备阶段可建立本回合摸牌/出杀/手牌上限修正。
-- 准备阶段的修正由独立房间触发器保留，失去装备后仍持续到本回合结束。
local Heg = require "packages.hegemony.util"

local skill = fk.CreateSkill {
  name = "qiao__zhoujun_lingbingyin_skill",
  attached_equip = "qiao__zhoujun_lingbingyin",
}

local function enteringSeal(player, moves)
  local room = player.room
  for _, move in ipairs(moves) do
    if move.to == player and move.toArea == Card.PlayerEquip then
      for _, info in ipairs(move.moveInfo) do
        local id = info.cardId
        if (move.from ~= player or info.fromArea ~= Card.PlayerEquip)
          and room:getCardArea(id) == Card.PlayerEquip and room:getCardOwner(id) == player then
          local equipped = player:getVirtualEquip(id) or Fk:getCardById(id)
          if equipped.name == skill.attached_equip then return true end
        end
      end
    end
  end
  return false
end

local function giftCandidates(player)
  local same
  if Heg.isBigKingdomPlayer(player) then
    same = Heg.isBigKingdomPlayer
  elseif Heg.isSmallKingdomPlayer(player) then
    same = Heg.isSmallKingdomPlayer
  else
    return {}
  end
  return table.filter(player.room:getPresentPlayers(), function(other)
    return other ~= player and #other:getCardIds("he") > 0 and same(other)
  end)
end

-- 置入装备区后2。同优先级下引擎先处理该角色的武将技能，再处理其装备技能。
skill:addEffect(fk.AfterCardsMove, {
  mute = true,
  can_trigger = function(self, event, target, player, data)
    return not player.dead and player:hasSkill(skill.name)
      and enteringSeal(player, data) and #giftCandidates(player) > 0
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local candidates = giftCandidates(player)
    room:sortByAction(candidates)
    for _, other in ipairs(candidates) do
      if player.dead then break end
      if not other.dead and not other:isRemoved() and #other:getCardIds("he") > 0 then
        local card = room:askToCards(other, {
          min_num = 1, max_num = 1, include_equip = true, cancelable = true,
          skill_name = skill.name,
          prompt = "#qiao__zhoujun-give::" .. player.id,
        })[1]
        if card ~= nil and table.contains(other:getCardIds("he"), card) then
          room:obtainCard(player, card, false, fk.ReasonGive)
        end
      end
    end
  end,
})

local DRAW = "qiao_zhoujun_draw"
local SLASH = "qiao_zhoujun_slash"
local HAND = "qiao_zhoujun_hand"

local function addMark(player, mark, value)
  player.room:setPlayerMark(player, mark, value)
end

local function slashLimit(player)
  local slash = Fk:cloneCard("qiao__slash")
  local maxUse = slash:getSkill(player):getMaxUseTime(player, Player.HistoryPhase, slash)
  return math.max(0, maxUse or 1)
end

--- 引擎只在 DrawNCards 事件内暴露本次额定摸牌数；准备阶段没有公共 getter。
--- 当前基数取游戏流程默认 2，其他效果在摸牌事件内的特别修正无法提前得知。
local function currentValues(player)
  return { draw = 2, slash = slashLimit(player), hand = player:getMaxCards() }
end

--- 生成准备阶段可选的增减组合，扣减不得超过对应基数。
local function optionsFor(values)
  local result = {}
  local function add(draw, slash, hand)
    if values.draw + draw < 0 or values.slash + slash < 0 or values.hand + hand < 0 then return end
    table.insert(result, { draw = draw, slash = slash, hand = hand })
  end
  -- +2 的三种合法分配：另外两项各 -1，或任一项足额 -2。
  add(2, -1, -1)
  add(2, -2, 0)
  add(2, 0, -2)
  add(1, -1, 0)
  add(1, 0, -1)
  add(-1, 2, -1)
  add(-2, 2, 0)
  add(0, 2, -2)
  add(-1, 1, 0)
  add(0, 1, -1)
  add(-1, -1, 2)
  add(-2, 0, 2)
  add(0, -2, 2)
  add(-1, 0, 1)
  add(0, -1, 1)
  return result
end

--- 只接受与服务端合法组合完全一致的数值；取消、超时、非法回复均不产生修正。
local function optionFromReply(options, reply)
  if type(reply) ~= "table" then return nil end
  local draw, slash, hand = tonumber(reply.draw), tonumber(reply.slash), tonumber(reply.hand)
  if draw == nil or slash == nil or hand == nil then return nil end
  return table.find(options, function(option)
    return option.draw == draw and option.slash == slash and option.hand == hand
  end)
end

local function askPrepare(player)
  local room = player.room
  local values = currentValues(player)
  local options = optionsFor(values)
  if #options == 0 then return end
  -- AI 或离线/无客户端时 CustomDialog 返回空串，不能回退到任意组合。
  local reply = room:askToCustomDialog(player, {
    skill_name = skill.name,
    component = {
      url = "packages/qiao/pkg/qiao_mode/qml/ZhoujunValueBox.qml",
      prop = {
        baseValues = values,
        options = options,
        prompt = "#qiao__zhoujun-prepare",
      },
    },
  })
  local option = optionFromReply(options, reply)
  if option then option = optionFromReply(optionsFor(currentValues(player)), option) end
  if option == nil then return end
  addMark(player, DRAW, option.draw)
  addMark(player, SLASH, option.slash)
  addMark(player, HAND, option.hand)
end

-- 准备阶段：三项修正建立在本回合，独立于装备是否仍在。
skill:addEffect(fk.EventPhaseStart, {
  can_trigger = function(self, event, target, player, data)
    return target == player and data.phase == Player.Start
      and player:hasSkill(skill.name) and #optionsFor(currentValues(player)) > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__zhoujun-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    askPrepare(player)
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "州郡领兵印",
  ["#qiao__zhoujun-invoke"] = "州郡领兵印：是否调整本回合的摸牌、出杀与手牌上限",
  ["#qiao__zhoujun-prepare"] = "州郡领兵印：调整三项增减值",
  ["#qiao__zhoujun-give"] = "州郡领兵印：是否交给 %dest 一张自己的手牌或装备",
}

return skill
