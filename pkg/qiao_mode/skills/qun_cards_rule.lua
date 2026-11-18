-- 群势力标准包：用牌/响应后的独立房间规则。
--
-- 由模式在 logic:start 时以 `room:addSkill("qiao__qun_cards_rule")` 接入。
-- 这些效果属于「牌已经建立」的后续结算，不能依赖技能本体仍在角色身上：
--   * 乱击：同势力角色实际打出【闪】响应本次万箭后选择摸一张；
--   * 狂斧：按本次【杀】的 damageDealt 结算摸两张/弃两张手牌；
--   * 骁逆：按本次【杀】的 damageDealt 选择未受伤原目标弃两张牌；
--   * 乱击花色记录：每回合结束无条件清理（不要求袁绍仍在场）。
-- 所有后续效果都从 use.extra_data 定位原发动者并只结算一次。
local Heg = require "packages.hegemony.util"

local LUANJI = "qiao__skill_qun004_1"
local LUANJI_SUITS = "@[qiao_luanji_suits]"
local KUANGFU = "qiao__skill_qun017_1"
local KUANGFU_MARK = "qiao_qun017"
local XIAONI = "qiao__skill_qun027_2"
local XIAONI_MARK = "qiao_qun027"

local skill = fk.CreateSkill {
  name = "qiao__qun_cards_rule",
  tags = { Skill.Compulsory },
}

local function isCardSkill(card, skillName)
  return card ~= nil
    and (card.skillName == skillName or table.contains(card.skillNames or {}, skillName))
end

local function damageDealt(data)
  for _, num in pairs(data.damageDealt or {}) do
    if num > 0 then return true end
  end
  return false
end

local function damagedBy(data, target)
  local num = (data.damageDealt or {})[target]
  return num ~= nil and num > 0
end

-- 乱击：响应者实际打出【闪】后，由其选择是否摸一张。
-- response.from 是本次万箭的使用者，避免把其他乱击来源的响应重复计入。
skill:addEffect(fk.CardRespondFinished, {
  mute = true,
  is_delay_effect = true,
  can_trigger = function(self, event, target, player, data)
    -- 房间级技能会在每名角色的触发轮次中被考察；显式只在 target 本人轮次
    -- 执行一次，避免对同一响应/用牌向所有角色重复询问。
    if target == nil or target ~= player or target.dead or target:isRemoved() then return false end
    if data.card == nil or data.card.trueName ~= "jink" then return false end
    local response = data.responseToEvent
    if response == nil or response.from == nil or response.card == nil then return false end
    -- response.from 必须是本次万箭的使用者，不能把其他乱击来源的响应重复计入。
    if response.use ~= nil and response.use.from ~= response.from then return false end
    if not isCardSkill(response.card, LUANJI) then return false end
    if response.from == target then return false end
    return Heg.compareKingdomWith(target, response.from)
  end,
  on_trigger = function(self, event, target, player, data)
    if target.dead or target:isRemoved() then return end
    if target.room:askToSkillInvoke(target, {
      skill_name = LUANJI,
      prompt = "#qiao__qun_cards_rule_luanji_draw",
    }) then
      target:drawCards(1, LUANJI)
    end
  end,
})

-- 狂斧：弃置己方装备且造成伤害摸两张；弃置他方装备且未造成伤害弃两张手牌。
skill:addEffect(fk.CardUseFinished, {
  mute = true,
  is_delay_effect = true,
  can_trigger = function(self, event, target, player, data)
    if target == nil or target ~= player then return false end
    if data.card == nil or data.card.trueName ~= "slash" then return false end
    local mark = (data.extra_data or {})[KUANGFU_MARK]
    return type(mark) == "table" and mark.user == target.id
      and isCardSkill(data.card, KUANGFU)
  end,
  on_trigger = function(self, event, target, player, data)
    local room = target.room
    local mark = (data.extra_data or {})[KUANGFU_MARK]
    if type(mark) ~= "table" then return end
    -- 清除标记，保证同一张牌只结算一次。
    data.extra_data[KUANGFU_MARK] = nil
    local user = room:getPlayerById(mark.user)
    if user == nil or user.dead or user:isRemoved() then return end
    local dealt = damageDealt(data)
    if mark.self then
      if dealt then user:drawCards(2, KUANGFU) end
    elseif not dealt then
      room:askToDiscard(user, {
        min_num = 2,
        max_num = 2,
        include_equip = false,
        skill_name = KUANGFU,
        prompt = "#qiao__skill_qun017_1-discard",
        cancelable = false,
      })
    end
  end,
})

-- 骁逆：从本次【杀】的原目标中选一名未因此受到伤害者弃两张牌。
skill:addEffect(fk.CardUseFinished, {
  mute = true,
  is_delay_effect = true,
  can_trigger = function(self, event, target, player, data)
    if target == nil or target ~= player then return false end
    if data.card == nil or data.card.trueName ~= "slash" then return false end
    local mark = (data.extra_data or {})[XIAONI_MARK]
    return type(mark) == "table" and mark.user == target.id
      and isCardSkill(data.card, XIAONI)
  end,
  on_trigger = function(self, event, target, player, data)
    local room = target.room
    local mark = (data.extra_data or {})[XIAONI_MARK]
    if type(mark) ~= "table" then return end
    data.extra_data[XIAONI_MARK] = nil
    local user = room:getPlayerById(mark.user)
    if user == nil or user.dead or user:isRemoved() then return end
    local eligible = table.filter(data.tos or {}, function(p)
      return p:isAlive() and not p:isRemoved() and not damagedBy(data, p)
        and #p:getCardIds("he") > 0
    end)
    if #eligible == 0 then return end
    local to = eligible[1]
    if #eligible > 1 then
      local chosen = room:askToChoosePlayers(user, {
        min_num = 1,
        max_num = 1,
        targets = eligible,
        skill_name = XIAONI,
        prompt = "#qiao__skill_qun027_2-discard-target",
        cancelable = false,
      })
      to = chosen and chosen[1]
    end
    if to == nil or to.dead or to:isRemoved() then return end
    local count = math.min(2, #to:getCardIds("he"))
    if count == 0 then return end
    local ids = room:askToChooseCards(user, {
      target = to,
      flag = "he",
      min = count,
      max = count,
      skill_name = XIAONI,
      prompt = "#qiao__skill_qun027_2-discard:" .. count,
      cancelable = false,
    })
    if ids == nil or #ids ~= count then return end
    local legal = to:getCardIds("he")
    for _, id in ipairs(ids) do
      if not table.contains(legal, id) then return end
    end
    room:throwCard(ids, XIAONI, to, user)
  end,
})

-- 每回合清理乱击花色记录；即使袁绍已失去乱击或已交换武将也执行。
-- 使用 refresh 通道而不是可发动触发：不进入技能发动/触发选择，避免扰动
-- 承诏、兴图、不屈等回合末/濒死时机的选择顺序。
skill:addEffect(fk.TurnEnd, {
  mute = true,
  can_refresh = function(self, event, target, player, data)
    return target ~= nil and target == player and target.room ~= nil
  end,
  on_refresh = function(self, event, target, player, data)
    local room = target.room
    for _, p in ipairs(room.players) do
      local mark = p:getTableMark(LUANJI_SUITS)
      if type(mark) == "table" and #mark > 0 then
        room:setPlayerMark(p, LUANJI_SUITS, 0)
      end
    end
  end,
})

Fk:loadTranslationTable {
  ["qiao__qun_cards_rule"] = "群势力用牌规则",
  ["#qiao__qun_cards_rule_luanji_draw"] = "乱击：你可以摸一张牌",
}

return skill
