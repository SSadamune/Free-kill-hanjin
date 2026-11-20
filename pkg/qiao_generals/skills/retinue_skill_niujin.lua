-- WEI 翼从 · 牛金（限一）
--
-- 规则基线：docs/rules/standard-generals.md 翼从牛金、docs/rules/general-principles.md。
-- 同势力角色回合结束时，牛金持有者可以使用基本/锦囊/装备每类至多一张。
-- 自由用牌窗口同时提供尚未使用的所有类别，取消即结束。效果内用牌 bypass_times=true + extraUse=true（不占
-- 通常出杀次数），禁止与目标条件照常。来源记录在本次 UseCard.extra_data，
-- Death 时向上追溯本次用牌，避免实体牌复用污染；奖励由房间级延迟监听执行，
-- 不绑定持有者之后是否仍有技能。
local H = require "packages.hegemony.util"
local FreeUse = require "packages.qiao.pkg.qiao_mode.rules.free_use"

local skill = fk.CreateSkill {
  name = "qiao__retinue_skill_niujin",
}
skill.qiaoImplemented = true

local SOURCE_KEY = "qiao_niujin_source"
local ACTIVE_MARK = "qiao_niujin_window"
local REWARD_SKILL = "#qiao_niujin_reward"

local CATEGORIES = { "basic", "trick", "equip" }
local CATEGORY_LABELS = {
  basic = "qiao_niujin_basic",
  trick = "qiao_niujin_trick",
  equip = "qiao_niujin_equip",
}

local reward_skill

---@param room Room
local function ensureReward(room)
  if reward_skill == nil then reward_skill = Fk.skills[REWARD_SKILL] end
  if reward_skill == nil then
    local skel = fk.CreateSkill { name = REWARD_SKILL }
    skel:addEffect(fk.Death, {
      global = true,
      is_delay_effect = true,
      can_refresh = function(self, event, target, player, data)
        local killer = data.killer
        if killer == nil or player ~= killer or player.dead then return false end
        if killer:getMark(ACTIVE_MARK) == 0 then return false end
        local current = player.room.logic:getCurrentEvent()
        local use = current and current:findParent(GameEvent.UseCard, true)
        return use ~= nil and use.data ~= nil and use.data.extra_data ~= nil
          and use.data.extra_data[SOURCE_KEY] == killer.id
      end,
      on_refresh = function(self, event, target, player, data)
        local killer = data.killer
        killer:drawCards(3, skill.name)
      end,
    })
    reward_skill = skel:createSkill()
    Fk.skills[REWARD_SKILL] = reward_skill
  end
  if not room:hasSkill(REWARD_SKILL) then room:addSkill(reward_skill) end
end

---@param player ServerPlayer
---@param target ServerPlayer
---@return boolean
local function sameKingdom(player, target)
  return player == target or H.compareKingdomWith(player, target)
end

local function askForCard(player, remaining)
  local labels = table.map(remaining, function(category)
    return Fk:translate(CATEGORY_LABELS[category])
  end)
  return FreeUse.askToUseCard(player, {
    pattern = ".|.|.|.|.|" .. table.concat(remaining, ","),
    skill_name = skill.name,
    prompt = "#qiao__retinue_skill_niujin-use:::" .. table.concat(labels, "、"),
    cancelable = true,
    extra_data = { bypass_times = true, extraUse = true },
  })
end

skill:addEffect(fk.TurnEnd, {
  global = true,
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return target ~= nil and player ~= nil and player:hasSkill(skill.name)
      and not player.dead and sameKingdom(player, target)
  end,
  on_cost = function(self, event, target, player, data)
    local use = askForCard(player, CATEGORIES)
    if not use then return false end
    event:setCostData(self, { firstUse = use })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    ensureReward(room)
    local previous = player:getMark(ACTIVE_MARK)
    room:addPlayerMark(player, ACTIVE_MARK, 1)
    local remaining = table.simpleClone(CATEGORIES)
    local use = event:getCostData(self).firstUse
    while use and player:isAlive() and not player:isRemoved() do
      local category = use.card:getTypeString()
      if not table.contains(remaining, category) then break end
      -- 顶层 extraUse 才让引擎不计通常出杀次数。
      use.extraUse = true
      use.extra_data = use.extra_data or {}
      use.extra_data.bypass_times = true
      use.extra_data[SOURCE_KEY] = player.id
      room:useCard(use)
      table.removeOne(remaining, category)
      if #remaining == 0 or player.dead or player:isRemoved() then break end
      use = askForCard(player, remaining)
    end
    room:setPlayerMark(player, ACTIVE_MARK, previous)
  end,
})

Fk:loadTranslationTable {
  ["qiao__retinue_skill_niujin"] = "牛金",
  [":qiao__retinue_skill_niujin"] = "与你势力相同的角色回合结束时，你可以使用每种类别至多各一张牌，你以此法杀死角色后摸三张牌。",
  ["#qiao__retinue_skill_niujin-use"] = "牛金：你可以使用一张牌（可以是%arg）。",
  ["qiao_niujin_basic"] = "基本牌",
  ["qiao_niujin_trick"] = "锦囊牌",
  ["qiao_niujin_equip"] = "装备牌",
}

return skill
