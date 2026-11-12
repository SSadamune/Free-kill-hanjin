-- HAN001 刘协 · 密诏
--
-- 规则基线：rules/generals/han001-liuxie.md 第 3 节，以及
-- rules/card-use-targets.md。主动技的选择阶段只完成“自己的牌”和收牌者
-- B 的选择；交牌移动完成后再选择第三人 C 并发起拼点。
local skill = fk.CreateSkill {
  name = "hanjin__skill_han001_2",
  max_phase_use_time = 1,
}

local C = require "packages.hanjin.pkg.hanjin_mode.rules.card_use_targets"
local Ascension = require "packages.hanjin.pkg.hanjin_mode.rules.ascension"

--- 取技能计算所需的房间。服务端 ServerPlayer 有 room 字段；客户端
--- ClientPlayer 没有，改由引擎当前房间（Client 实例）提供 players/
--- alive_players 等同一套只读接口。客户端因此能按公开信息完成预测。
---@param player ServerPlayer | ClientPlayer
---@return Room | Client
local function currentRoom(player)
  return player.room or Fk:currentRoom()
end

--- 当前实际势力的预测值。暗将尚未明置时，用本局势力标记和明置后的
--- 转野条件预测，保证选牌下限与明置后实际计算的 X 一致。
---@param player ServerPlayer | ClientPlayer
---@return string
local function currentKingdom(player)
  if player.kingdom ~= "unknown" then return player.kingdom end
  local room = currentRoom(player)
  local kingdom = player:getMark("__heg_kingdom")
  if player:getMark("__heg_wild") == 1 then return "wild" end
  if kingdom == nil or kingdom == "" or kingdom == "unknown" then return "unknown" end

  -- 与汉晋公共明置/转野判定保持一致：君主按显式登记表识别，不按名字。
  if Ascension.population_blocks(room, player, kingdom)
    and not Ascension.has_lord(room, kingdom) then
    return "wild"
  end
  return kingdom
end

--- X：与当前角色不同、且已确定的实际势力数。每个野心家独立计数，
--- 全暗置的 unknown 不计。
---@param player ServerPlayer | ClientPlayer
---@return integer
local function differentFactionCount(player)
  local own = currentKingdom(player)
  local seen, count = {}, 0
  local alive = currentRoom(player).alive_players
  for _, p in ipairs(alive) do
    if p ~= player then
      local kingdom = p.kingdom
      if kingdom == "wild" then
        count = count + 1
      elseif kingdom ~= "unknown" and kingdom ~= own and not seen[kingdom] then
        seen[kingdom] = true
        count = count + 1
      end
    end
  end
  return count
end

local function minimumCards(player)
  return math.max(1, differentFactionCount(player))
end

local function ownedCards(player)
  return player:getCardIds("he")
end

skill:addEffect("active", {
  anim_type = "offensive",
  min_card_num = function(self, player) return minimumCards(player) end,
  max_card_num = function(self, player) return #ownedCards(player) end,
  include_equip = true,
  target_num = 1,
  card_filter = function(self, player, to_select, selected, selected_targets)
    return table.contains(ownedCards(player), to_select)
      and #selected < #ownedCards(player)
  end,
  target_filter = function(self, player, to_select, selected, selected_cards, card, extra_data)
    return to_select ~= player and to_select:isAlive() and not to_select:isRemoved()
      and not table.contains(selected, to_select)
  end,
  can_use = function(self, player)
    return player:usedSkillTimes(skill.name, Player.HistoryPhase) == 0
      and #ownedCards(player) >= minimumCards(player)
  end,
  prompt = function(self, player)
    return "#hanjin__skill_han001_2-prompt:::" .. minimumCards(player)
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local to = effect.tos and effect.tos[1]
    if player.dead or to == nil or to == player or to.dead or to:isRemoved() then return end
    if not player:hasSkill(skill.name) then return end

    local X = minimumCards(player)
    local required = math.max(1, X)
    local owned = ownedCards(player)
    local cards = {}
    for _, id in ipairs(effect.cards or {}) do
      if table.contains(owned, id) and not table.contains(cards, id) then
        table.insert(cards, id)
      end
    end
    -- 交牌是发动消耗；不足 max(1, X) 时不移动、不进入后续。
    if #cards < required then return end

    room:moveCardTo(cards, Card.PlayerHand, to, fk.ReasonGive, skill.name, nil, true, player)

    -- 交牌结算完成后再选择 C；发动者或收牌者在中途死亡则不继续。
    if player.dead or to.dead or to:isRemoved() then return end

    local candidates = {}
    for _, p in ipairs(room.alive_players) do
      if p ~= player and p ~= to and p:isAlive() and not p:isRemoved() and to:canPindian(p) then
        table.insert(candidates, p)
      end
    end
    if #candidates == 0 then return end

    local chosen = room:askToChoosePlayers(player, {
      min_num = 1,
      max_num = 1,
      targets = candidates,
      skill_name = skill.name,
      prompt = "#hanjin__skill_han001_2-pindian",
      cancelable = false,
    })
    local third = chosen and chosen[1]
    if third == nil or player.dead or to.dead or third.dead or third:isRemoved() then return end
    if not to:canPindian(third) then return end

    local pindian = to:pindian({ third }, skill.name)
    local result = pindian.results and pindian.results[third]
    local winner = result and result.winner
    if winner == nil then return end

    local loser = (winner == to) and third or to
    if winner == loser or winner.dead or loser.dead or winner:isRemoved() or loser:isRemoved() then return end

    -- 效果明确指定“没赢的角色”为唯一目标，按汉晋显式目标策略处理：
    -- 不叠加【杀】的普通距离条件，但仍检查禁止使用/禁止指定。
    local policy = C.explicit({ other_roles = true }, { names = { "hanjin__slash" } })
    C.useVirtualCard(room, winner, "hanjin__slash", nil, { loser },
      skill.name, true, nil, policy)
  end,
})

skill:addTest(function(room, me)
  if room:getSettings("gameMode") ~= "hanjin_heg_mode" then return end
  lu.assertTrue(Fk.skills[skill.name]:getMinCardNum(me) >= 1)
end)

Fk:loadTranslationTable {
  ["hanjin__skill_han001_2"] = "密诏",
  [":hanjin__skill_han001_2"] = "出牌阶段限一次，你可以将至少X张牌交给一名其他角色（X为与你不同的势力数），然后令其与另一名由你选择的其他角色拼点：赢的角色视为对没赢的角色使用一张【杀】。",
  ["#hanjin__skill_han001_2-prompt"] = "密诏：交给一名其他角色至少 %arg 张牌，然后令其与另一名角色拼点",
  ["#hanjin__skill_han001_2-pindian"] = "密诏：选择与收牌角色拼点的第三人",
}

return skill
