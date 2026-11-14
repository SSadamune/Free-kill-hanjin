-- 吴包：诈降、天义已确定回合效果的静态模式辅助技能。
--
-- 由 mode.lua 在 logic:start 时安装（整合接线）；也可由技能取得时确保存在。
-- 本文件在扩展加载期注册，客户端与服务端都能按技能名找到，避免运行期
-- createSkill 造成的客户端 nil skill。效果只读取同步的公开标记，不检查持有者
-- 当前是否仍有来源技能，因此失去来源技能后已建立的回合效果继续生效。
local skill = fk.CreateSkill {
  name = "hanjin__wu_turn_effects",
}

-- 不以来源技能名前缀开头，避免武将交换把效果标记当作来源技能标记整批迁走。
local ZHAXIANG_TIMES = "hanjin_wu004_zhaxiang_times-turn"
local TIANYI_WIN = "hanjin_wu012_tianyi_win-turn"
local TIANYI_LOSE = "hanjin_wu012_tianyi_lose-turn"

local function isSlash(card)
  return card ~= nil and card.trueName == "slash"
end

skill:addEffect("targetmod", {
  residue_func = function(self, player, card_skill, scope, card, to)
    -- 上游 slash_skill 的可用性与目标过滤按 HistoryPhase 查询次数。
    if scope ~= Player.HistoryPhase or not isSlash(card) then return 0 end
    local n = 0
    local times = player:getMark(ZHAXIANG_TIMES)
    if times > 0 then n = n + times end
    if player:getMark(TIANYI_WIN) > 0 then n = n + 1 end
    return n
  end,
  extra_target_func = function(self, player, card_skill, card)
    if player:getMark(TIANYI_WIN) > 0 and isSlash(card) then return 1 end
  end,
  bypass_distances = function(self, player, card_skill, card, to)
    if not isSlash(card) then return false end
    if player:getMark(TIANYI_WIN) > 0 then return true end
    return player:getMark(ZHAXIANG_TIMES) > 0 and card.color == Card.Red
  end,
})

skill:addEffect("prohibit", {
  prohibit_use = function(self, player, card)
    return player:getMark(TIANYI_LOSE) > 0 and isSlash(card)
  end,
})

-- 好施：DrawNCards 在本次 phase data 上留下事件绑定的 pending 标记；
-- AfterDrawNCards 由本静态技能完成既定给牌，不依赖好施技能是否仍在。
-- 不给 pending 使用来源技能名前缀的玩家标记，避免武将交换迁移或跨摸牌阶段泄漏。
local HAOSHI_PENDING = "__hanjin_haoshi_pending_player"

local function leastHandOthers(player)
  local others = table.filter(player.room.alive_players, function(p)
    return p ~= player and p:isAlive() and not p:isRemoved()
  end)
  if #others == 0 then return {} end
  local min = math.huge
  for _, p in ipairs(others) do
    min = math.min(min, #p:getCardIds(Player.Hand))
  end
  return table.filter(others, function(p)
    return #p:getCardIds(Player.Hand) == min
  end)
end

skill:addEffect(fk.AfterDrawNCards, {
  global = true,
  is_delay_effect = true,
  can_trigger = function(self, event, target, player, data)
    return target == player and data ~= nil and data[HAOSHI_PENDING] == player.id
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = player.room
    data[HAOSHI_PENDING] = nil
    if player.dead then return end
    local hand = player:getCardIds(Player.Hand)
    if #hand <= 5 then return end

    local tos = leastHandOthers(player)
    if #tos == 0 then return end
    local chosen = room:askToChoosePlayers(player, {
      targets = tos,
      min_num = 1,
      max_num = 1,
      skill_name = "hanjin__skill_wu014_1",
      prompt = "#hanjin__skill_wu014_1-target",
      cancelable = false,
    })
    local to = chosen and chosen[1]
    if to == nil or to.dead or to:isRemoved() then return end

    local count = math.floor(#player:getCardIds(Player.Hand) / 2)
    if count <= 0 then return end
    local cards = room:askToCards(player, {
      min_num = count,
      max_num = count,
      include_equip = false,
      skill_name = "hanjin__skill_wu014_1",
      prompt = "#hanjin__skill_wu014_1-cards:::" .. count,
      cancelable = false,
    })
    local give = {}
    for _, id in ipairs(cards or {}) do
      if table.contains(player:getCardIds(Player.Hand), id) and not table.contains(give, id) then
        table.insert(give, id)
      end
    end
    if #give ~= count then return end
    room:moveCardTo(give, Card.PlayerHand, to, fk.ReasonGive,
      "hanjin__skill_wu014_1", nil, true, player)
  end,
})

return skill
