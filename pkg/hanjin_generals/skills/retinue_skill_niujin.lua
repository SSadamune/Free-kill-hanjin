-- WEI 翼从 · 牛金（限一）
--
-- 规则基线：rules/standard-generals.md 翼从牛金、rules/general-principles.md。
-- 同势力角色回合结束时，牛金持有者可以使用基本/锦囊/装备每类至多一张。
-- 原文没有固定顺序：每次由玩家选择一个尚未使用的类别；每类可放弃，逐次
-- 进入正常用牌窗口。效果内用牌 bypass_times=true + extraUse=true（不占
-- 通常出杀次数），禁止与目标条件照常。来源记录在本次 UseCard.extra_data，
-- Death 时向上追溯本次用牌，避免实体牌复用污染；奖励由房间级延迟监听执行，
-- 不绑定持有者之后是否仍有技能。
local H = require "packages.hegemony.util"

local skill = fk.CreateSkill {
  name = "hanjin__retinue_skill_niujin",
}
skill.hanjinImplemented = true

local SOURCE_KEY = "hanjin_niujin_source"
local ACTIVE_MARK = "hanjin_niujin_window"
local REWARD_SKILL = "#hanjin_niujin_reward"
local OPT_STOP = "#hanjin__retinue_skill_niujin-stop"

local CATEGORIES = {
  basic = { pattern = ".|.|.|.|.|basic", prompt = "#hanjin__retinue_skill_niujin-basic" },
  trick = { pattern = ".|.|.|.|.|trick", prompt = "#hanjin__retinue_skill_niujin-trick" },
  equip = { pattern = ".|.|.|.|.|equip", prompt = "#hanjin__retinue_skill_niujin-equip" },
}
local ORDER = { "basic", "trick", "equip" }

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
          and use.data.extra_data[SOURCE_KEY] == true
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

---@param player ServerPlayer
---@return string[] remaining 类别 key
local function categoryChoices(remaining)
  local choices = {}
  for _, key in ipairs(ORDER) do
    if remaining[key] then table.insert(choices, key) end
  end
  table.insert(choices, OPT_STOP)
  return choices
end

skill:addEffect(fk.TurnEnd, {
  global = true,
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return target ~= nil and player ~= nil and player:hasSkill(skill.name)
      and not player.dead and sameKingdom(player, target)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__retinue_skill_niujin-invoke::" .. target.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    ensureReward(room)
    room:addPlayerMark(player, ACTIVE_MARK, 1)
    local remaining = { basic = true, trick = true, equip = true }
    local used = 0
    while used < 3 and not player.dead do
      local choice = room:askToChoice(player, {
        choices = categoryChoices(remaining),
        skill_name = skill.name,
        prompt = "#hanjin__retinue_skill_niujin-choice",
        cancelable = true,
      })
      if choice == nil or choice == "" or choice == OPT_STOP then break end
      local category = CATEGORIES[choice]
      if category == nil or not remaining[choice] then break end
      remaining[choice] = nil
      used = used + 1

      local use = room:askToUseCard(player, {
        pattern = category.pattern,
        skill_name = skill.name,
        prompt = category.prompt,
        cancelable = true,
        -- 效果内用牌不占通常次数；正常禁止与目标条件仍由用牌流程检查。
        extra_data = { bypass_times = true, extraUse = true },
      })
      if use ~= nil and use.card ~= nil then
        -- 顶层 extraUse 才让引擎不计通常出杀次数；extra_data 仅作技能来源记录。
        use.extraUse = true
        use.extra_data = use.extra_data or {}
        use.extra_data.bypass_times = true
        use.extra_data[SOURCE_KEY] = true
        room:useCard(use)
      end
    end
    room:setPlayerMark(player, ACTIVE_MARK, 0)
  end,
})

Fk:loadTranslationTable {
  ["hanjin__retinue_skill_niujin"] = "牛金",
  [":hanjin__retinue_skill_niujin"] = "与你势力相同的角色回合结束时，你可以使用每种类别至多各一张牌，你以此法杀死角色后摸三张牌。",
  ["#hanjin__retinue_skill_niujin-invoke"] = "牛金：你可以使用每种类别至多各一张牌",
  ["#hanjin__retinue_skill_niujin-choice"] = "牛金：选择一个尚未使用的类别，或结束",
  ["#hanjin__retinue_skill_niujin-basic"] = "牛金：可以使用一张基本牌（可放弃）",
  ["#hanjin__retinue_skill_niujin-trick"] = "牛金：可以使用一张锦囊牌（可放弃）",
  ["#hanjin__retinue_skill_niujin-equip"] = "牛金：可以使用一张装备牌（可放弃）",
  [OPT_STOP] = "结束",
}

return skill
