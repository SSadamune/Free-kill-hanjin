-- 攻心（《缘江烽火图》授予的同文技能）
--
-- 出牌阶段限一次，你可以观看一名其他角色的手牌，然后你可以展示其中一张♥牌，
-- 弃置之或将此牌置于牌堆顶。
--
-- 观看、选牌与去向合并在同一个私密原生面板（AskForCardsAndChoice）完成：面板
-- 只发给发动者并显示目标全部手牌，只有当前有效红桃可选。结束观看始终可用且为
-- 默认项；禁止弃置的红桃仍可置顶，但弃置按钮由服务器下发的禁令快照关闭。
-- 展示与移动之间在服务端复核原手牌位置、当前有效花色及弃置禁令。
local skill = fk.CreateSkill {
  name = "qiao__gongxin",
}
skill.qiaoImplemented = true

local DISCARD = "#qiao__gongxin-discard"
local ON_TOP = "#qiao__gongxin-top"
local END_CHOICE = "#qiao__gongxin-end"

-- 面板按钮的客户端筛选：只读取随本次请求下发的快照（extra_data），
-- 不访问房间或客户端私有状态。结束项由 QML 固定为始终可用，这里也直接放行。
skill.extra = {
  choiceFilter = function(cards, choice, extra_data)
    if choice == END_CHOICE then return true end
    if type(cards) ~= "table" or #cards ~= 1 then return false end
    local id = cards[1]
    local data = type(extra_data) == "table" and extra_data or {}
    if not table.contains(data.hearts or {}, id) then return false end
    if choice == DISCARD then
      return not table.contains(data.prohibited or {}, id)
    end
    return choice == ON_TOP
  end,
}

--- 客户端没有 player.room；与服务端共用 Fk:currentRoom() 的只读房间。
---@param player ServerPlayer | ClientPlayer
local function otherPlayers(player)
  local room = Fk:currentRoom()
  if room == nil then return {} end
  return table.filter(room:getPresentPlayers(), function(p)
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
    -- 快照：目标全部手牌、当前有效红桃、其中被禁止弃置者。
    -- 这些快照只随本次私密请求发给发动者，面板不从客户端房间自行取牌。
    local hand = target:getCardIds(Player.Hand)
    local hearts = heartsOf(target)
    local prohibited = table.filter(hearts, function(id)
      return target:prohibitDiscard(id)
    end)

    local chosen, choice = room:askToChooseCardsAndChoice(player, {
      cards = hearts,
      all_cards = hand,
      choices = { END_CHOICE, DISCARD, ON_TOP },
      default_choice = END_CHOICE,
      min_num = 0,
      max_num = 1,
      skill_name = skill.name,
      prompt = "#qiao__gongxin-panel:" .. target.id,
      filter_skel_name = skill.name,
      extra_data = { hearts = hearts, prohibited = prohibited },
    })
    -- 结束、超时或无答复：不展示、不移动。
    if choice == nil or choice == END_CHOICE then return end
    if choice ~= DISCARD and choice ~= ON_TOP then return end
    if type(chosen) ~= "table" or #chosen ~= 1 then return end
    local id = chosen[1]
    if not table.contains(hearts, id) then return end

    --- 展示前后共用：仍是该角色手牌区的当前有效红桃。
    local function stillValidHeart()
      if room:getCardArea(id) ~= Card.PlayerHand or room:getCardOwner(id) ~= target then
        return false
      end
      local card = Fk:getCardById(id)
      return card ~= nil and card.suit == Card.Heart
    end

    -- 展示前复核卡牌与动作；弃置分支还须当前无弃置禁令。
    if not stillValidHeart() then return end
    if choice == DISCARD and target:prohibitDiscard(id) then return end

    -- 只公开选中的这一张红桃，其余手牌不展示。
    room:showCards({ id }, target, player)

    -- 移动前再次复核原手牌位置、有效花色和弃置禁令。
    if not stillValidHeart() then return end
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
  ["#qiao__gongxin-panel"] = "攻心：观看 %src 的手牌，选择一张♥牌的处置",
  [END_CHOICE] = "结束观看",
  [DISCARD] = "弃置",
  [ON_TOP] = "置于牌堆顶",
}

return skill
