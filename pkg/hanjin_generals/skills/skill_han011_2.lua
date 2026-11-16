-- HAN011 唐姬 · 诀别
--
-- 规则基线：rules/standard-generals.md 汉区 HAN011、rulebook/events/death.md。
-- 与你势力相同的角色死亡时，其可以令另一名与你势力相同的角色获得其所有牌，
-- 或令该角色摸三张牌。死亡时结算，位于清牌之前；自己死亡也按同一势力定义
-- 适用（比较对象包含死者自身）。
--
-- 「其可以」的发动、选项和受益者均由死亡角色选择；本技能不硬编码只限他人。
local skill = fk.CreateSkill {
  name = "hanjin__skill_han011_2",
}
skill.hanjinImplemented = true

local H = require "packages.hegemony.util"

local OPT_CARDS = "hanjin__skill_han011_2-cards"
local OPT_DRAW = "hanjin__skill_han011_2-draw"

--- 当前势力判断。暗置且未明置时用本局势力标记，避免把 unknown 当作势力。
---@param player ServerPlayer
---@return string
local function kingdomOf(player)
  if player.kingdom ~= "unknown" then return H.getKingdom(player) end
  local kingdom = player:getMark("__heg_kingdom")
  if kingdom == nil or kingdom == "" or kingdom == "unknown" then return "unknown" end
  if player:getMark("__heg_wild") == 1 then return "wild" end
  return kingdom
end

--- 同势力判断。其他角色处于 unknown 时一律不是同势力；只有技能持有者
--- 自己暗置时，才为发动本技能作必要的自身势力预测，不替其他角色猜势力，
--- 也不绕过公共 compareKingdomWith 的构逆/野心家判断。
---@param a ServerPlayer
---@param b ServerPlayer
---@return boolean
local function sameKingdom(a, b)
  if a == b then return true end
  if b.kingdom == "unknown" then return false end
  if a.kingdom ~= "unknown" then return H.compareKingdomWith(a, b) end
  local own = kingdomOf(a)
  if own == "unknown" or own == "" then return false end
  return own == b.kingdom
end

--- 可选择的另一名同势力存活角色（排除死亡角色本人）。
---@param dying ServerPlayer
---@param owner ServerPlayer
---@return ServerPlayer[]
local function candidates(dying, owner)
  return table.filter(owner.room.alive_players, function(p)
    return p ~= dying and p:isAlive() and not p:isRemoved()
      and sameKingdom(owner, p)
  end)
end

skill:addEffect(fk.Death, {
  global = true,
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    local ok = player:hasSkill(skill.name, false, true) and sameKingdom(player, target)
      and #candidates(target, player) > 0
    return ok
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if not room:askToSkillInvoke(target, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_han011_2-invoke",
    }) then
      return false
    end

    local choice = room:askToChoice(target, {
      choices = { OPT_CARDS, OPT_DRAW },
      skill_name = skill.name,
      prompt = "#hanjin__skill_han011_2-choice",
      cancelable = true,
    })
    if choice == nil or choice == "" or choice == "Cancel" then return false end
    if choice ~= OPT_CARDS and choice ~= OPT_DRAW then return false end

    local tos = room:askToChoosePlayers(target, {
      min_num = 1,
      max_num = 1,
      targets = candidates(target, player),
      skill_name = skill.name,
      prompt = "#hanjin__skill_han011_2-target",
      cancelable = true,
    })
    local to = tos and tos[1]
    if to == nil or to == target or not to:isAlive() or to:isRemoved() then return false end
    if not sameKingdom(player, to) then return false end

    event:setCostData(self, { choice = choice, to = to })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self) or {}
    local to = cost.to
    if to == nil or not to:isAlive() or to:isRemoved() then return end

    if cost.choice == OPT_CARDS then
      -- 死亡时清牌之前：获得死者手牌区和装备区里的所有牌。
      local cards = target:getCardIds("he")
      if #cards > 0 then
        room:moveCardTo(cards, Card.PlayerHand, to, fk.ReasonPrey,
          skill.name, nil, true, target)
      end
    elseif cost.choice == OPT_DRAW then
      to:drawCards(3, skill.name)
    end
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_han011_2"] = "诀别",
  [":hanjin__skill_han011_2"] = "与你势力相同的角色死亡时，其可以令另一名与你势力相同的角色获得其所有牌或摸三张牌。",
  ["#hanjin__skill_han011_2-invoke"] = "诀别：是否令一名同势力角色获得你的所有牌或摸三张牌",
  ["#hanjin__skill_han011_2-choice"] = "诀别：选择获得其所有牌，或令其摸三张牌",
  ["#hanjin__skill_han011_2-target"] = "诀别：选择另一名与你势力相同的角色",
  [OPT_CARDS] = "获得其所有牌",
  [OPT_DRAW] = "令其摸三张牌",
}

return skill
