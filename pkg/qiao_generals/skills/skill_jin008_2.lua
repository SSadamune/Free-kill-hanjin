-- JIN008 夏侯徽 · 识度
--
-- 规则基线：rules/generals/jin008-xiahouhui.md。
-- 出牌阶段限一次，与一名合法其他角色真实拼点；赢才获得其所有手牌，然后按
-- 此时自己全部手牌数向下取半交还，不是只分刚获得的牌，也不使用拼点前快照。
-- 平局为没赢，不进入获得与交还分支。客户端可用性不读取 player.room。
local skill = fk.CreateSkill {
  name = "qiao__skill_jin008_2",
  max_phase_use_time = 1,
}

---@return ServerPlayer[] | ClientPlayer[]
local function alivePlayers()
  local room = Fk:currentRoom()
  if room == nil then return {} end
  if room.alive_players ~= nil then return room.alive_players end
  if type(room.getAlivePlayers) == "function" then return room:getAlivePlayers() end
  return {}
end

local function candidates(player)
  return table.filter(alivePlayers(), function(p)
    return p ~= player and not p.dead and not p:isRemoved() and player:canPindian(p)
  end)
end

skill:addEffect("active", {
  anim_type = "offensive",
  prompt = "#qiao__skill_jin008_2-prompt",
  max_phase_use_time = 1,
  card_num = 0,
  target_num = 1,
  card_filter = Util.FalseFunc,
  target_filter = function(self, player, to_select, selected)
    return #selected == 0 and to_select ~= player and not to_select.dead
      and not to_select:isRemoved() and player:canPindian(to_select)
  end,
  can_use = function(self, player)
    return self:withinTimesLimit(player, Player.HistoryPhase) and #candidates(player) > 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local to = effect.tos and effect.tos[1]
    if player == nil or player.dead or to == nil or to.dead or to:isRemoved() then return end
    if not player:canPindian(to) then return end

    local pindian = player:pindian({ to }, skill.name)
    local result = pindian.results and pindian.results[to]
    if result == nil or result.winner ~= player then return end

    -- 实际获得其所有手牌，再以获得后的自己全部手牌数计算交还数量。
    local hand = to:getCardIds(Player.Hand)
    if #hand > 0 and to:isAlive() then
      room:moveCardTo(hand, Card.PlayerHand, player, fk.ReasonPrey,
        skill.name, nil, false, player)
    end

    local total = #player:getCardIds(Player.Hand)
    local giveCount = math.floor(total / 2)
    if giveCount < 1 or not to:isAlive() or to:isRemoved() then return end
    -- “交给”不是弃置；只从手牌选择，避免禁弃牌被错误过滤。
    local _, chosen = room:askToChooseCardsAndPlayers(player, {
      targets = { player },
      min_num = 1,
      max_num = 1,
      min_card_num = giveCount,
      max_card_num = giveCount,
      pattern = ".|.|.|hand",
      skill_name = skill.name,
      prompt = "#qiao__skill_jin008_2-give::" .. giveCount,
      cancelable = false,
    })
    chosen = chosen or {}
    local give = {}
    local legal = player:getCardIds(Player.Hand)
    for _, id in ipairs(chosen) do
      if table.contains(legal, id) and not table.contains(give, id) then
        table.insert(give, id)
      end
    end
    if #give ~= giveCount then return end
    room:moveCardTo(give, Card.PlayerHand, to, fk.ReasonGive,
      skill.name, nil, false, player)
  end,
})

skill.qiaoImplemented = true

Fk:loadTranslationTable {
  ["#qiao__skill_jin008_2-prompt"] = "识度：与一名角色拼点，赢则获得其所有手牌并交还半数",
  ["#qiao__skill_jin008_2-give"] = "识度：选择交给其的 %arg 张手牌",
}

return skill
