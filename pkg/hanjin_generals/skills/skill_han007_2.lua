-- HAN007 王荣 · 追德
--
-- 规则基线：rules/generals/han007-wangrong.md。你死亡时，可以展示任意张
-- 红桃牌并交给一名其他角色，令其摸等量的牌，然后其可以发动一次「敏思」。
--
-- 时机：fk.Death 位于 GameOverJudge 之后、BuryVictim 清理死亡角色牌之前；
-- 国战公共流程在 GameOverJudge 已翻开暗置武将，因此死亡时暗将来源也能
-- 正常触发。给牌走公共牌移动（fk.ReasonGive），不跳过牌移动和展示。
--
-- 额外敏思：复用敏思的共用选牌/效果与辅助主动技，不永久授予技能；
-- 辅助主动技名与敏思本体不同，不占用其出牌阶段限一次的次数。
local skill = fk.CreateSkill {
  name = "hanjin__skill_han007_2",
}
skill.hanjinImplemented = true

local M = require "packages.hanjin.pkg.hanjin_generals.util.minsi"

local MINSI = "hanjin__skill_han007_1"
local MINSI_AUX = "#hanjin__skill_han007_1_aux"
local ZHUDE_AUX = "#hanjin__skill_han007_2_aux"

--- 自己手牌区和装备区里的红桃牌（有效花色，包含锁视技的花色转化）。
---@param player ServerPlayer | ClientPlayer
---@return integer[]
local function ownHearts(player)
  local room = player.room or Fk:currentRoom()
  return table.filter(player:getCardIds("he"), function(id)
    return M.isHeart(room, player, id)
  end)
end

--- 可接收牌的其他存活角色。
---@param player ServerPlayer | ClientPlayer
---@return Player[]
local function otherTargets(player)
  local room = player.room or Fk:currentRoom()
  return table.filter(room.alive_players, function(p)
    return p ~= player and p:isAlive() and not p:isRemoved()
  end)
end

-- 追德的选牌与目标入口。先完成红桃牌和接收者的选择，再由 on_use 展示、
-- 移动并结算后续，避免「只选择」被当成已经执行。
skill:addAuxActiveSkill(ZHUDE_AUX, {
  include_equip = true,
  min_card_num = 1,
  max_card_num = function(self, player) return #ownHearts(player) end,
  card_filter = function(self, player, to_select, selected)
    return table.contains(ownHearts(player), to_select)
      and not table.contains(selected or {}, to_select)
  end,
  target_num = 1,
  target_filter = function(self, player, to_select, selected)
    return #selected == 0 and to_select ~= player
      and to_select:isAlive() and not to_select:isRemoved()
  end,
})

skill:addEffect(fk.Death, {
  global = true,
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name, false, true)
      and #ownHearts(player) > 0 and #otherTargets(player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_han007_2-invoke",
    }) then
      return false
    end

    local ok, ret = room:askToUseActiveSkill(player, {
      skill_name = ZHUDE_AUX,
      prompt = "#hanjin__skill_han007_2-select",
      cancelable = true,
      extra_data = { skillName = skill.name },
    })
    if not ok or ret == nil then return false end

    -- 服务端复核：仍是自己的红桃牌、接收者仍是其他存活角色。
    local hearts = ownHearts(player)
    local cards = {}
    for _, id in ipairs(ret.cards or {}) do
      if table.contains(hearts, id) and not table.contains(cards, id) then
        table.insert(cards, id)
      end
    end
    local to = ret.targets and ret.targets[1]
    if #cards == 0 or to == nil or to == player
      or not to:isAlive() or to:isRemoved() then
      return false
    end

    event:setCostData(self, { cards = cards, to = to })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self) or {}
    local to = cost.to
    if to == nil or not to:isAlive() or to:isRemoved() then return end

    -- 结算前再次核对牌仍属于自己且为红桃；消耗链中可能已发生移动。
    local hearts = ownHearts(player)
    local cards = {}
    for _, id in ipairs(cost.cards or {}) do
      if table.contains(hearts, id) and not table.contains(cards, id) then
        table.insert(cards, id)
      end
    end
    if #cards == 0 then return end

    -- 先展示，再交给；展示不移动牌，给牌使用公共移动事件。
    room:showCards(cards, player)
    room:moveCardTo(cards, Card.PlayerHand, to, fk.ReasonGive,
      skill.name, nil, true, player)

    if to.dead or to:isRemoved() then return end
    to:drawCards(#cards, skill.name)

    -- 然后其可以发动一次敏思。辅助主动技独立于敏思本体的阶段限次。
    if to.dead or to:isRemoved() or not M.canForm13(to) then return end
    local ok, ret = room:askToUseActiveSkill(to, {
      skill_name = MINSI_AUX,
      prompt = "#hanjin__skill_han007_2-minsi",
      cancelable = true,
      extra_data = { skillName = MINSI },
    })
    if ok and ret ~= nil then
      M.perform(room, to, ret.cards, MINSI)
    end
  end,
})

skill:addTest(function(room, me)
  if room:getSettings("gameMode") ~= "hanjin_heg_mode" then return end
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, skill.name, nil, false, true)
  end)
  lu.assertTrue(me:hasSkill(skill.name))
end)

Fk:loadTranslationTable {
  ["hanjin__skill_han007_2"] = "追德",
  [":hanjin__skill_han007_2"] = "你死亡时，你可以展示任意张红桃牌并交给一名其他角色，令其摸等量的牌，然后其可以发动一次“敏思”。",
  ["#hanjin__skill_han007_2-invoke"] = "追德：你可以展示任意张红桃牌交给一名其他角色",
  ["#hanjin__skill_han007_2-select"] = "追德：请选择要展示并交出的红桃牌和接收者",
  ["#hanjin__skill_han007_2-minsi"] = "追德：你可以发动一次“敏思”",
}

return skill
