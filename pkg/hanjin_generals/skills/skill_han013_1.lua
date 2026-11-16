-- HAN013 皇甫嵩 · 奋钺
--
-- 出牌阶段限 X 次（X 为存活且已确定势力的数量，去重；每个野心家独立；
-- 未知势力不计）。与一名角色拼点：
--   * 皇甫嵩赢：该角色不能响应皇甫嵩本回合使用的下张牌；若皇甫嵩的拼点牌
--     点数小于 9，还视为对其使用一张火【杀】。该火【杀】就是“下张牌”时
--     同样消费响应限制。
--   * 皇甫嵩没赢（含平局）：皇甫嵩失去 1 点体力或结束此阶段。
--
-- “下张牌”的响应限制是延迟效果：胜出时只记录待限制角色，真正消费时写入
-- UseCardData.disresponsiveList（不是只写当前目标），因此下张锦囊指定 C 时
-- B 也不能用【无懈可击】响应，【决斗】中双方打出【杀】也受同一名单约束。
-- 监听器是房间级、模块缓存的单一对象，不依赖皇甫嵩当前是否仍有此技能。
-- 本技能没有来源侧自定义限次标记：出牌阶段次数由引擎 skillUsedHistory 记录，
-- 再由正式模式的 #hanjin_exchange_history 逐牌账本随来源武将迁移；待限制
-- 标记属于原角色的延迟效果，刻意不使用技能名前缀、也不注册为 Exchange 标记。
local C = require "packages.hanjin.pkg.hanjin_mode.rules.card_use_targets"
local Ascension = require "packages.hanjin.pkg.hanjin_mode.rules.ascension"

local NEXT_CARD = "hanjin_skill_han013_1_next_card"
local DELAY_SKILL_NAME = "#hanjin_skill_han013_1_delay"
local DELAY_USED = "__hanjin_skill_han013_1_delay_used"

local delay_skill

local function currentRoom(player)
  return player.room or Fk:currentRoom()
end

--- 暗将的当前实际势力预测，沿用密诏及汉晋公共明置/转野判定。
---@param player ServerPlayer | ClientPlayer
---@return string
local function currentKingdom(player)
  if player.kingdom ~= "unknown" then return player.kingdom end
  local room = currentRoom(player)
  local kingdom = player:getMark("__heg_kingdom")
  if player:getMark("__heg_wild") == 1 then return "wild" end
  if kingdom == nil or kingdom == "" or kingdom == "unknown" then return "unknown" end
  if Ascension.population_blocks(room, player, kingdom)
    and not Ascension.has_lord(room, kingdom) then
    return "wild"
  end
  return kingdom
end

--- 存活且已确定势力的去重数量；每个野心家独立计数，未知不计。
---@param player ServerPlayer | ClientPlayer
---@return integer
local function factionCount(player)
  local room = currentRoom(player)
  if room == nil then return 1 end
  local own = currentKingdom(player)
  local seen, count = {}, 0
  for _, p in ipairs(room.alive_players) do
    local kingdom = (p == player) and own or p.kingdom
    if kingdom == "wild" then
      count = count + 1
    elseif kingdom ~= nil and kingdom ~= "" and kingdom ~= "unknown" and not seen[kingdom] then
      seen[kingdom] = true
      count = count + 1
    end
  end
  return math.max(1, count)
end

local skill = fk.CreateSkill {
  name = "hanjin__skill_han013_1",
  max_phase_use_time = function(self, player)
    return factionCount(player)
  end,
}

local function canPindianTargets(player)
  local room = currentRoom(player)
  if room == nil then return {} end
  local ret = {}
  for _, p in ipairs(room.alive_players) do
    if p ~= player and p:isAlive() and not p:isRemoved() and player:canPindian(p) then
      table.insert(ret, p)
    end
  end
  return ret
end

--- 安装/复用房间级“下张牌”监听器。模块级缓存保证 Fk.skills 中同名对象唯一；
--- 监听器不检查皇甫嵩是否仍有技能，故失技/暗置/交换后已建立的限制仍会结算。
---@param room Room
local function ensureDelaySkill(room)
  if room == nil then return end
  if delay_skill == nil then delay_skill = Fk.skills[DELAY_SKILL_NAME] end
  if delay_skill == nil then
    local skel = fk.CreateSkill { name = DELAY_SKILL_NAME }
    skel:addEffect(fk.AfterCardUseDeclared, {
      global = true,
      can_refresh = function(self, event, target, player, data)
        return target ~= nil and type(data) == "table" and not data[DELAY_USED]
          and #target:getTableMark(NEXT_CARD .. "-turn") > 0
      end,
      on_refresh = function(self, event, target, player, data)
        data[DELAY_USED] = true
        local ids = table.simpleClone(target:getTableMark(NEXT_CARD .. "-turn"))
        local room = target.room
        room:setPlayerMark(target, NEXT_CARD .. "-turn", 0)

        -- 直接写 UseCardData 的名单：后续目标、无懈可击响应者以及【决斗】
        -- 的双方响应都通过 isDisresponsive 读取这一份实际使用数据。
        data.disresponsiveList = data.disresponsiveList or {}
        for _, id in ipairs(ids) do
          local p = room:getPlayerById(id)
          if p ~= nil and p:isAlive() then
            table.insertIfNeed(data.disresponsiveList, p)
          end
        end
      end,
    })
    delay_skill = skel:createSkill()
    Fk.skills[DELAY_SKILL_NAME] = delay_skill
  end
  if not room:hasSkill(DELAY_SKILL_NAME) then
    room:addSkill(delay_skill)
  end
end

skill:addEffect("active", {
  anim_type = "offensive",
  prompt = "#hanjin__skill_han013_1-prompt",
  card_filter = Util.FalseFunc,
  target_filter = function(self, player, to_select, selected)
    return #selected == 0 and to_select ~= player
      and to_select:isAlive() and not to_select:isRemoved()
      and player:canPindian(to_select)
  end,
  can_use = function(self, player)
    return #player:getCardIds(Player.Hand) > 0 and #canPindianTargets(player) > 0
  end,
  target_num = 1,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos and effect.tos[1]
    if player == nil or target == nil or player.dead or target.dead or target:isRemoved() then return end
    if not player:canPindian(target) then return end

    -- 第一次发动时安装延迟监听器；本次火杀也必须经过它。
    ensureDelaySkill(room)

    local pindian = player:pindian({ target }, skill.name)
    local result = pindian.results and pindian.results[target]
    local winner = result and result.winner

    if winner == player then
      room:addTableMarkIfNeed(player, NEXT_CARD .. "-turn", target.id)
      local point = pindian.fromCard and pindian.fromCard.number or 13
      if point < 9 and target:isAlive() and not target:isRemoved() then
        C.useVirtualCard(room, player, "hanjin__fire__slash", nil, { target }, skill.name, true,
          nil, C.explicit({ other_roles = true }, { names = { "hanjin__fire__slash" } }))
      end
      return
    end

    local choice = room:askToChoice(player, {
      choices = { "#hanjin__skill_han013_1-lose_hp", "#hanjin__skill_han013_1-end_phase" },
      skill_name = skill.name,
      prompt = "#hanjin__skill_han013_1-choice",
      cancelable = false,
    })
    if choice == "#hanjin__skill_han013_1-end_phase" then
      player:endPlayPhase()
    else
      room:loseHp(player, 1, skill.name)
    end
  end,
})

skill:addAcquireEffect(function(self, player)
  ensureDelaySkill(player.room)
end)

Fk:loadTranslationTable {
  ["hanjin__skill_han013_1"] = "奋钺",
  [":hanjin__skill_han013_1"] = "出牌阶段限X次（X为势力数），你可以与一名角色拼点：若你赢，其不能响应你本回合使用的下张牌，且若你拼点牌点数小于9，你视为对其使用一张火【杀】；若你没赢，你失去1点体力或结束此阶段。",
  ["#hanjin__skill_han013_1-prompt"] = "奋钺：与一名角色拼点",
  ["#hanjin__skill_han013_1-choice"] = "奋钺：你选择失去1点体力或结束此阶段",
  ["#hanjin__skill_han013_1-lose_hp"] = "失去1点体力",
  ["#hanjin__skill_han013_1-end_phase"] = "结束此阶段",
}

skill.hanjinImplemented = true

return skill
