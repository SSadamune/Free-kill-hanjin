-- JIN007 王元姬 · 恤下
--
-- 规则基线：docs/rules/generals/jin007-wangyuanji.md。
-- 每回合限一次：实际明置武将牌数少于王元姬的其他角色受到伤害后，王元姬可以
-- 交给其两张自己的牌，然后摸两张。两张牌是发动消耗，不能以零张或一张代替；
-- 比较读取真实明置数，不按技能数、体力或势力。暗将发技的明置由引擎正式
-- SkillEffect 流程处理，本技能不模拟。
local H = require "packages.hegemony.util"

local skill = fk.CreateSkill {
  name = "qiao__skill_jin007_2",
}

--- 当前可交付的两张自己的牌（手牌或装备）。
---@param player ServerPlayer
---@return integer[]
local function ownCards(player)
  return player:getCardIds("he")
end

--- 发动后实际明置数的预测：若技能当前来自预亮/暗置武将，成功发动会先
--- 明置该将。这里只做预测，不自行明置，也不绕开 prohibitReveal。
---@param player ServerPlayer
---@return integer
local function hiddenSource(player)
  if player.general == "anjiang" then
    local main = Fk.generals[player:getMark("__heg_general")]
    if main ~= nil and table.contains(main:getSkillNameList(true), skill.name) then
      return "main"
    end
  end
  if player.deputyGeneral == "anjiang" then
    local deputy = Fk.generals[player:getMark("__heg_deputy")]
    if deputy ~= nil and table.contains(deputy:getSkillNameList(true), skill.name) then
      return "deputy"
    end
  end
  return nil
end

local function predictedRevealedNum(player)
  local n = H.getGeneralsRevealedNum(player)
  -- 预亮注册可能表现为房间技能而非 isFakeSkill；只要暗置武将确有此技能，
  -- 正式发动仍会明置该将。
  if hiddenSource(player) ~= nil then
    n = math.min(2, n + 1)
  end
  return n
end

--- 当前假技能若来自暗置武将，正式发动会在 SkillEffect 明置；先检查这条
--- 来源是否被禁止明置。这里不自行明置。
---@param player ServerPlayer
---@return boolean
local function revealBlocked(player)
  local place = hiddenSource(player)
  if place == "main" then return player:prohibitReveal(false) end
  if place == "deputy" then return player:prohibitReveal(true) end
  return false
end

skill:addEffect(fk.Damaged, {
  anim_type = "support",
  global = true,
  can_trigger = function(self, event, target, player, data)
    if target == player or target == nil or target.dead or player.dead then return false end
    if not player:hasSkill(skill.name) then return false end
    if player:usedSkillTimes(skill.name, Player.HistoryTurn) > 0 then return false end
    if #ownCards(player) < 2 then return false end
    return H.getGeneralsRevealedNum(target) < predictedRevealedNum(player)
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_jin007_2-invoke:" .. target.id,
    }) then
      return false
    end
    -- 询问阶段尚未明置（TriggerSkill:doCost 先于 room:useSkill/SkillEffect），
    -- 不能在此读取“实际”明置数；先检查合法来源是否被禁止明置，并按预测值
    -- 判断，真实明置后的复核放到 on_use。
    if revealBlocked(player) then return false end
    if H.getGeneralsRevealedNum(target) >= predictedRevealedNum(player) then
      return false
    end
    -- “交给”不是弃置，不能用弃置接口过滤禁弃牌。
    local _, cards = room:askToChooseCardsAndPlayers(player, {
      targets = { player },
      min_num = 1,
      max_num = 1,
      min_card_num = 2,
      max_card_num = 2,
      pattern = ".",
      skill_name = skill.name,
      prompt = "#qiao__skill_jin007_2-give",
      cancelable = true,
    })
    if cards == nil or #cards ~= 2 then return false end
    local legal = ownCards(player)
    for _, id in ipairs(cards) do
      if not table.contains(legal, id) then return false end
    end
    event:setCostData(self, { cards = cards })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cards = (event:getCostData(self) or {}).cards or {}
    local legal = ownCards(player)
    local give = {}
    for _, id in ipairs(cards) do
      if table.contains(legal, id) then table.insert(give, id) end
    end
    -- 正式 SkillEffect 已明置来源；此处按真实明置数复核，再交牌。
    if target.dead or H.getGeneralsRevealedNum(target) >= H.getGeneralsRevealedNum(player) then
      return
    end
    if #give ~= 2 then return end
    -- 先真实交给其两张牌，再摸两张；不是同时执行。
    room:moveCardTo(give, Card.PlayerHand, target, fk.ReasonGive,
      skill.name, nil, false, player)
    if not player.dead then
      player:drawCards(2, skill.name)
    end
  end,
})

skill.qiaoImplemented = true

Fk:loadTranslationTable {
  ["#qiao__skill_jin007_2-invoke"] = "恤下：你可以交给 %dest 两张牌，然后摸两张牌",
  ["#qiao__skill_jin007_2-give"] = "恤下：选择交给其的两张牌",
}

return skill
