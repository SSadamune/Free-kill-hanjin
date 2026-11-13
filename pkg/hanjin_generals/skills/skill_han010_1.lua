-- HAN010 董承 · 承诏
--
-- 每回合结束时（任意角色的回合），若董承本回合得到过至少两张牌，可与一名
-- 角色拼点；若董承赢，视为对其使用一张无视防具的【杀】。
-- “得到”直接查询本回合的 GameEvent.MoveCards 历史，按进入手牌区的牌张计数；
-- 装备区与当前手牌数都不参与条件，暗置/晚获得技能也不漏掉此前得牌。
-- 拼点对象在 on_cost 中选定并保存，早于 SkillEffect 的明置/技能效果结算。
local skill = fk.CreateSkill {
  name = "hanjin__skill_han010_1",
}

local C = require "packages.hanjin.pkg.hanjin_mode.rules.card_use_targets"
local History = require "packages.hanjin.pkg.hanjin_generals.util.han_history"

local ARMOR_MARK = "hanjin_skill_han010_1_ignore_armor"

--- 可与董承拼点的其他存活角色。
---@param player ServerPlayer
---@return ServerPlayer[]
local function pindianTargets(player)
  local room = player.room
  local ret = {}
  for _, p in ipairs(room.alive_players) do
    if p ~= player and p:isAlive() and not p:isRemoved() and player:canPindian(p) then
      table.insert(ret, p)
    end
  end
  return ret
end

skill:addEffect(fk.TurnEnd, {
  anim_type = "offensive",
  global = true,
  can_trigger = function(self, event, target, player, data)
    return player ~= nil and player:hasSkill(skill.name) and not player.dead
      and History.count(player.room, player) >= 2
      and #pindianTargets(player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_han010_1-invoke",
    }) then
      return false
    end

    local targets = pindianTargets(player)
    if #targets == 0 then return false end
    local chosen = room:askToChoosePlayers(player, {
      min_num = 1,
      max_num = 1,
      targets = targets,
      skill_name = skill.name,
      prompt = "#hanjin__skill_han010_1-pindian",
      cancelable = false,
    })
    local to = chosen and chosen[1]
    if to == nil or player.dead or to.dead or to:isRemoved() then return false end
    if not player:canPindian(to) then return false end

    event:setCostData(self, { to = to })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self) or {}
    local to = cost.to
    if to == nil or player.dead or to.dead or to:isRemoved() then return end
    if not player:canPindian(to) then return end

    local pindian = player:pindian({ to }, skill.name)
    local result = pindian.results and pindian.results[to]
    if result == nil or result.winner ~= player then return end
    if player.dead or to.dead or to:isRemoved() then return end

    -- 效果指定唯一目标，按显式目标策略处理（不叠加【杀】的距离条件）；仅
    -- 此次使用带有无视防具标记，TargetSpecified 复用青釭剑的公共无视防具
    -- 机制，只在该次用牌结算中令目标防具无效。
    C.useVirtualCard(room, player, "hanjin__slash", nil, { to }, skill.name, true,
      { [ARMOR_MARK] = true },
      C.explicit({ other_roles = true }, { names = { "hanjin__slash" } }))
  end,
})

-- 承诏生成的【杀】在指定目标后套用“无视防具”。这里只处理本技能带标记的
-- 那次用牌，不改变其他【杀】。TargetSpecified 的 target 为使用者。
skill:addEffect(fk.TargetConfirmed, {
  global = true,
  priority = 0,
  is_delay_effect = true,
  can_trigger = function(self, event, target, player, data)
    return target == data.to and data.card ~= nil and data.card.trueName == "slash"
      and (data.card.skillName == skill.name
        or table.contains(data.card.skillNames or {}, skill.name))
      and target:isAlive()
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    target:addQinggangTag(data)
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_han010_1"] = "承诏",
  [":hanjin__skill_han010_1"] = "每回合结束时，若你于本回合得到过至少两张牌，你可以与一名角色拼点：若你赢，你视为对其使用一张无视防具的【杀】。",
  ["#hanjin__skill_han010_1-invoke"] = "承诏：你本回合得到过至少两张牌，可以与一名角色拼点",
  ["#hanjin__skill_han010_1-pindian"] = "承诏：选择拼点角色",
}

skill.hanjinImplemented = true

return skill
