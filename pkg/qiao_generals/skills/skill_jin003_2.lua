-- JIN003 司马昭 · 挟征
--
-- 规则基线：docs/rules/generals/jin003-simazhao.md。
-- 限定技，出牌阶段：令一名角色将一张基本牌当【杀】对指定角色实际使用；
-- 用出后即使被闪也不进入惩罚。未实际用出才获得其所有手牌，再交给其等同于
-- 其体力值的自己的牌（不限于刚获得的牌）。目标由效果显式指定，独立禁止仍
-- 由公共目标策略复核。
local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"
local SLASH = "slash"

local skill = fk.CreateSkill {
  name = "qiao__skill_jin003_2",
  tags = { Skill.Limited },
}

skill:addEffect("active", {
  anim_type = "offensive",
  prompt = "#qiao__skill_jin003_2-prompt",
  max_phase_use_time = 1,
  card_num = 0,
  min_target_num = 2,
  max_target_num = 2,
  card_filter = Util.FalseFunc,
  target_filter = function(self, player, to_select, selected)
    if to_select.dead or to_select:isRemoved() then return false end
    if #selected == 0 then
      -- “一名角色”不排除自己；至少施术者与指定目标两名不同角色。
      return true
    end
    local user = selected[1]
    if to_select == user then return false end
    local slash = Fk:cloneCard(SLASH)
    return not user:prohibitUse(slash) and not user:isProhibited(to_select, slash)
  end,
  can_use = function(self, player)
    return player:usedSkillTimes(skill.name, Player.HistoryGame) == 0
      and not player.dead and #Fk:currentRoom():getPresentPlayers() >= 2
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local user = effect.tos and effect.tos[1]
    local victim = effect.tos and effect.tos[2]
    if player == nil or player.dead or user == nil or victim == nil then return end
    if user.dead or victim.dead or user == victim then return end

    -- 被要求者在同一个手牌请求中选择素材或拒绝。
    local id = room:askToCards(user, {
      min_num = 1, max_num = 1, cancelable = true,
      pattern = ".|.|.|hand|.|basic",
      skill_name = skill.name,
      prompt = "#qiao__skill_jin003_2-require:" .. player.id .. ":" .. victim.id,
    })[1]
    local use
    if id ~= nil and table.contains(user:getCardIds("h"), id)
      and Fk:getCardById(id).type == Card.TypeBasic then
      use = C.useVirtualCard(room, user, SLASH, { id }, { victim },
        skill.name, true, nil, C.explicit({ other_roles = true }, { names = { SLASH } }))
    end
    if use ~= nil then return end

    -- 未实际用出：一次批量获得其所有手牌，再交给其体力值张自己的牌。
    local hand = user:getCardIds(Player.Hand)
    if #hand > 0 and not player.dead then
      room:obtainCard(player, hand, false, fk.ReasonPrey, user, skill.name)
    end
    if player.dead then return end
    local own = player:getCardIds("he")
    local count = math.min(user.hp, #own)
    if count < 1 then return end
    local cards = room:askToCards(player, {
      min_num = count,
      max_num = count,
      include_equip = true,
      skill_name = skill.name,
      prompt = "#qiao__skill_jin003_2-give:::" .. count,
      cancelable = false,
    })
    local give = {}
    for _, id in ipairs(cards or {}) do
      if table.contains(player:getCardIds("he"), id) and not table.contains(give, id) then
        table.insert(give, id)
      end
    end
    if #give == count and user:isAlive() then
      room:moveCardTo(give, Card.PlayerHand, user, fk.ReasonGive,
        skill.name, nil, false, player)
    end
  end,
})

skill.qiaoImplemented = true

Fk:loadTranslationTable {
  ["#qiao__skill_jin003_2-prompt"] = "挟征：令一名角色将一张基本牌当【杀】对指定角色使用",
  ["#qiao__skill_jin003_2-use"] = "挟征：将一张基本牌当【杀】对指定角色使用",
  ["#qiao__skill_jin003_2-require"] = "挟征：请选择是否将一张基本牌当【杀】对 %dest 使用",
  ["#qiao__skill_jin003_2-give"] = "挟征：交给其 %arg 张自己的牌",
}

return skill
