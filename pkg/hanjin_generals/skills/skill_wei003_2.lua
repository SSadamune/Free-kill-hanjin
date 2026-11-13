-- WEI003 夏侯惇 · 持重
--
-- 每回合限一次，当你于摸牌阶段外得到牌后，你可以将多于体力值的手牌交给
-- 其他角色。已确认解释不是“只分出超额部分”：选择张数须大于当前体力值
-- （至少体力值+1），选中的手牌全部通过公共分配接口同时分给其他角色。
-- 摸牌阶段按当前回合阶段判断；首次手牌发放前（尚未进入轮次）不触发。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wei003_2",
}
skill.hanjinImplemented = true

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

skill:addEffect(fk.AfterCardsMove, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(skill.name) then return false end
    if player.room:getBanner("RoundCount") == nil then return false end
    if player:usedEffectTimes(self.name, Player.HistoryTurn) > 0 then return false end
    -- “某角色于阶段内”默认指其自身回合的阶段：只检查自己的阶段。
    if player.phase == Player.Draw then return false end
    if #player:getCardIds(Player.Hand) <= player.hp then return false end
    if #otherAlive(player) == 0 then return false end
    return gainedCards(player, data)
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei003_2-invoke",
    }) then
      return false
    end
    local hand = player:getCardIds(Player.Hand)
    local min = math.max(1, player.hp + 1)
    if #hand < min then return false end
    -- 选牌不是弃置：使用不施加弃置禁止的选牌入口，skip 语义由调用方自行处理。
    local cards = room:askToCards(player, {
      min_num = min,
      max_num = #hand,
      include_equip = false,
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei003_2-choose:::" .. min,
      cancelable = false,
    })
    if #cards < min then return false end
    event:setCostData(self, { cards = cards, min = min })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self)
    local cards = cost.cards
    local hand = player:getCardIds(Player.Hand)
    local valid = table.filter(cards, function(id) return table.contains(hand, id) end)
    if #valid < cost.min then return end
    local targets = otherAlive(player)
    if #targets == 0 then return end
    -- 公共“同时分配给任意角色”接口；min=max 指定全部选中牌都必须交出。
    room:askToYiji(player, {
      targets = targets,
      cards = valid,
      min_num = #valid,
      max_num = #valid,
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei003_2-distribute",
    })
  end,
})

Fk:loadTranslationTable {
  ["#hanjin__skill_wei003_2-invoke"] = "持重：你可以将多于体力值的手牌交给其他角色",
  ["#hanjin__skill_wei003_2-choose"] = "持重：选择至少 %arg 张手牌",
  ["#hanjin__skill_wei003_2-distribute"] = "持重：将这些手牌分配给其他角色",
}

return skill
