-- 攻心（《缘江烽火图》授予的同文技能）
--
-- 出牌阶段限一次，你可以观看一名其他角色的手牌，然后你可以展示其中一张♥牌，
-- 弃置之或将此牌置于牌堆顶。
--
-- 观看只对发动者开放（viewCards），不等同于展示其全部手牌；选牌候选只列
-- 当前手牌区的红桃，可不选或取消。展示后再按弃置／置顶各自正常移动原因处理，
-- 弃置仍受禁止弃置效果约束。移动前复核该牌仍在原角色手牌区且花色仍为红桃。
local skill = fk.CreateSkill {
  name = "qiao__gongxin",
}
skill.qiaoImplemented = true

local DISCARD = "#qiao__gongxin-discard"
local ON_TOP = "#qiao__gongxin-top"
local HEARTS = "#qiao__gongxin-hearts"

--- 客户端没有 player.room；与服务端共用 Fk:currentRoom() 的只读房间。
---@param player ServerPlayer | ClientPlayer
local function otherPlayers(player)
  local room = Fk:currentRoom()
  if room == nil then return {} end
  return table.filter(room.alive_players, function(p)
    return p ~= player and p:isAlive() and not p:isRemoved()
  end)
end

--- 目标当前手牌区的红桃。
---@param target ServerPlayer
---@return integer[]
local function heartsOf(target)
  return table.filter(target:getCardIds(Player.Hand), function(id)
    local card = Fk:getCardById(id)
    return card ~= nil and card.suit == Card.Heart
  end)
end

skill:addEffect("active", {
  anim_type = "control",
  prompt = "#qiao__gongxin-prompt",
  max_phase_use_time = 1,
  target_num = 1,
  min_card_num = 0,
  max_card_num = 0,
  can_use = function(self, player)
    if player == nil or player.dead or player.phase ~= Player.Play then return false end
    if not player:hasSkill(skill.name) then return false end
    return #otherPlayers(player) > 0
  end,
  target_filter = function(self, player, to_select, selected)
    return #selected == 0 and to_select ~= player
      and to_select:isAlive() and not to_select:isRemoved()
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos and effect.tos[1]
    if player == nil or target == nil or player.dead or target.dead
      or target:isRemoved() or target == player then
      return
    end

    -- 私看：只发给发动者；不是 showCards 的全体展示。
    local hand = target:getCardIds(Player.Hand)
    if #hand > 0 then
      room:viewCards(player, {
        cards = hand,
        skill_name = skill.name,
        prompt = "#qiao__gongxin-view:" .. target.id,
      })
    end
    if player.dead or target.dead or target:isRemoved() then return end

    -- 观看后按当前手牌重新取候选；无红桃时只完成观看。
    local hearts = heartsOf(target)
    if #hearts == 0 then return end
    local chosen = room:askToChooseCards(player, {
      target = target,
      flag = { card_data = { { HEARTS, hearts } } },
      min = 0,
      max = 1,
      skill_name = skill.name,
      prompt = "#qiao__gongxin-show:" .. target.id,
      cancelable = true,
    })
    local id = chosen and chosen[1]
    if id == nil or not table.contains(hearts, id) then return end

    -- 展示前复核：仍是该角色的手牌，花色仍为红桃。
    if room:getCardArea(id) ~= Card.PlayerHand
      or room:getCardOwner(id) ~= target then
      return
    end
    local card = Fk:getCardById(id)
    if card == nil or card.suit ~= Card.Heart then return end

    -- 展示所选红桃，然后选择弃置或置于牌堆顶。
    room:showCards({ id }, target, player)
    local choice = ON_TOP
    if not target:prohibitDiscard(id) then
      choice = room:askToChoice(player, {
        choices = { DISCARD, ON_TOP },
        skill_name = skill.name,
        prompt = "#qiao__gongxin-move:" .. target.id,
      })
    end

    -- 移动前再次复核原手牌与花色；弃置与置顶分别按真实移动原因处理。
    if room:getCardArea(id) ~= Card.PlayerHand
      or room:getCardOwner(id) ~= target then
      return
    end
    card = Fk:getCardById(id)
    if card == nil or card.suit ~= Card.Heart then return end
    if choice == DISCARD then
      if target:prohibitDiscard(id) then return end
      room:throwCard({ id }, skill.name, target, player)
    else
      room:moveCardTo(id, Card.DrawPile, nil, fk.ReasonPut, skill.name, nil, true, player)
    end
  end,
})

Fk:loadTranslationTable {
  ["qiao__gongxin"] = "攻心",
  [":qiao__gongxin"] = "出牌阶段限一次，你可以观看一名其他角色的手牌，然后你可以展示其中一张♥牌，弃置之或将此牌置于牌堆顶。",
  ["#qiao__gongxin-prompt"] = "攻心：观看一名其他角色的手牌",
  ["#qiao__gongxin-view"] = "攻心：观看 %src 的手牌",
  ["#qiao__gongxin-show"] = "攻心：可展示 %src 的一张♥手牌",
  ["#qiao__gongxin-move"] = "攻心：展示的♥牌弃置或置于牌堆顶",
  [HEARTS] = "红桃手牌",
  [DISCARD] = "弃置",
  [ON_TOP] = "置于牌堆顶",
}

return skill
