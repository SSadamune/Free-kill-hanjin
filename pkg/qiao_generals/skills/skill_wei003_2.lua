-- WEI003 夏侯惇 · 持重
--
-- 每回合限一次，当你于摸牌阶段外得到牌后，你可以将多于体力值的手牌交给
-- 其他角色。确认发动时恰好交出当前手牌数减体力值张，可取消。
-- 摸牌阶段按当前回合阶段判断；首次手牌发放前（尚未进入轮次）不触发。
local skill = fk.CreateSkill {
  name = "qiao__skill_wei003_2",
}
skill.qiaoImplemented = true

local function otherAlive(player)
  local room = player.room
  return table.filter(room:getOtherPlayers(player, false), function(p)
    return p:isAlive() and not p:isRemoved()
  end)
end

local function gainedCards(player, data)
  for _, move in ipairs(data or {}) do
    if move.to == player and move.toArea == Card.PlayerHand and #(move.moveInfo or {}) > 0 then
      return true
    end
  end
  return false
end

local function excessHandSize(player)
  local count = #player:getCardIds(Player.Hand)
  local excess = count - player.hp
  return excess <= count and excess or 0
end

skill:addEffect(fk.AfterCardsMove, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(skill.name) then return false end
    if player.room:getBanner("RoundCount") == nil then return false end
    if player:usedEffectTimes(self.name, Player.HistoryTurn) > 0 then return false end
    -- “某角色于阶段内”默认指其自身回合的阶段：只检查自己的阶段。
    if player.phase == Player.Draw then return false end
    if excessHandSize(player) <= 0 then return false end
    if #otherAlive(player) == 0 then return false end
    return gainedCards(player, data)
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local count = excessHandSize(player)
    if count <= 0 then return false end
    -- 选牌不是弃置：使用不施加弃置禁止的选牌入口，skip 语义由调用方自行处理。
    local cards = room:askToCards(player, {
      min_num = count,
      max_num = count,
      include_equip = false,
      skill_name = skill.name,
      prompt = "#qiao__skill_wei003_2-choose:::" .. count,
      cancelable = true,
    })
    if #cards ~= count then return false end
    local hand = player:getCardIds(Player.Hand)
    local unique = {}
    for _, id in ipairs(cards) do
      if not table.contains(hand, id) or not table.insertIfNeed(unique, id) then return false end
    end
    event:setCostData(self, { cards = cards })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self)
    local cards = cost.cards
    local hand = player:getCardIds(Player.Hand)
    local valid = table.filter(cards, function(id) return table.contains(hand, id) end)
    if #valid ~= #cards then return end
    local targets = otherAlive(player)
    if #targets == 0 then return end
    -- 公共“同时分配给任意角色”接口；min=max 指定全部选中牌都必须交出。
    room:askToYiji(player, {
      targets = targets,
      cards = valid,
      min_num = #valid,
      max_num = #valid,
      skill_name = skill.name,
      prompt = "#qiao__skill_wei003_2-distribute",
    })
  end,
})

Fk:loadTranslationTable {
  ["#qiao__skill_wei003_2-choose"] = "持重：选择 %arg 张手牌交给其他角色，或取消",
  ["#qiao__skill_wei003_2-distribute"] = "持重：将这些手牌分配给其他角色",
}

return skill
