-- HAN006 王允 · 连计
--
-- 规则基线：rules/standard-generals.md 的 HAN006 原文；目标角色每出牌阶段
-- 限一次，交出一张手牌后令其本回合下一次受到的伤害 +1。
--
-- 伤害加成是挂在目标身上的延迟效果：房间级监听器在第一次发动时安装并保留，
-- 不随王允失技/暗置/武将交换而消失。目标身上只保留该已建立的延迟加伤，
-- 其标记刻意不采用技能名前缀，避免被 Exchange 当成来源技能标记迁走；
-- “每名角色限一次”的已选目标表则记在发动者身上，随王允的武将牌迁移。
local skill = fk.CreateSkill {
  name = "hanjin__skill_han006_1",
}

-- 限次状态在发动者身上，且以技能名 + "-" 开头，Exchange 会按来源武将迁移。
-- 目标身上只保留“下一次伤害 +1”这一已建立的延迟效果。
local USED_TARGETS = "hanjin__skill_han006_1-given_targets-phase"
local NEXT_DAMAGE = "hanjin_skill_han006_1_next_damage-turn"
local DELAY_SKILL_NAME = "#hanjin_skill_han006_1_delay"

local delay_skill

local function currentRoom(player)
  return player.room or Fk:currentRoom()
end

--- 本出牌阶段尚未以此法得到过牌的其他存活角色。
---@param player ServerPlayer | ClientPlayer
---@return ServerPlayer[]
local function eligibleTargets(player)
  local room = currentRoom(player)
  if room == nil then return {} end
  local ret = {}
  local given = player:getTableMark(USED_TARGETS)
  for _, p in ipairs(room.alive_players) do
    if p ~= player and p:isAlive() and not p:isRemoved()
      and not table.contains(given, p.id) then
      table.insert(ret, p)
    end
  end
  return ret
end

--- 安装/复用房间级伤害监听器。模块级缓存保证 Fk.skills 中同名对象只有一个，
--- 后续房间/后续发动只复用该对象，不再创建第二个同名 Skill。
---@param room Room
local function ensureDelaySkill(room)
  if room == nil then return end
  if delay_skill == nil then delay_skill = Fk.skills[DELAY_SKILL_NAME] end
  if delay_skill == nil then
    local skel = fk.CreateSkill { name = DELAY_SKILL_NAME }
    skel:addEffect(fk.DamageInflicted, {
      global = true,
      can_refresh = function(self, event, target, player, data)
        return target ~= nil and data.damage > 0
          and not data.hanjin_skill_han006_1_boosted
          and target:getMark(NEXT_DAMAGE) > 0
      end,
      on_refresh = function(self, event, target, player, data)
        local bonus = target:getMark(NEXT_DAMAGE)
        if bonus <= 0 then return end
        data:changeDamage(bonus)
        data.hanjin_skill_han006_1_boosted = true
        data.hanjin_skill_han006_1_target = target
      end,
    })
    skel:addEffect(fk.Damaged, {
      global = true,
      can_refresh = function(self, event, target, player, data)
        return data.hanjin_skill_han006_1_boosted
          and target == data.hanjin_skill_han006_1_target
      end,
      on_refresh = function(self, event, target, player, data)
        target.room:setPlayerMark(target, NEXT_DAMAGE, 0)
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
  prompt = "#hanjin__skill_han006_1-prompt",
  card_filter = function(self, player, to_select, selected)
    return #selected < 1 and table.contains(player:getCardIds(Player.Hand), to_select)
  end,
  target_filter = function(self, player, to_select, selected)
    return #selected == 0 and to_select ~= player
      and to_select:isAlive() and not to_select:isRemoved()
      and not table.contains(player:getTableMark(USED_TARGETS), to_select.id)
  end,
  can_use = function(self, player)
    return #player:getCardIds(Player.Hand) > 0 and #eligibleTargets(player) > 0
  end,
  card_num = 1,
  target_num = 1,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos and effect.tos[1]
    if player == nil or target == nil or player.dead or target.dead or target:isRemoved() then return end
    if target == player or table.contains(player:getTableMark(USED_TARGETS), target.id) then return end

    -- 晚获得/暗置发动时也要确保延迟监听器已存在。
    ensureDelaySkill(room)

    -- 交给的是手牌；服务端按当前手牌重新筛选，伪造/过期的选牌不生效。
    local owned = player:getCardIds(Player.Hand)
    local card
    for _, id in ipairs(effect.cards or {}) do
      if table.contains(owned, id) then
        card = id
        break
      end
    end
    if card == nil then return end

    room:moveCardTo({ card }, Card.PlayerHand, target, fk.ReasonGive, skill.name, nil, true, player)
    if player.dead then return end

    room:addTableMarkIfNeed(player, USED_TARGETS, target.id)
    room:addPlayerMark(target, NEXT_DAMAGE, 1)
  end,
})

skill:addAcquireEffect(function(self, player)
  ensureDelaySkill(player.room)
end)

Fk:loadTranslationTable {
  ["hanjin__skill_han006_1"] = "连计",
  [":hanjin__skill_han006_1"] = "出牌阶段每名角色限一次，你可以交给其他角色一张手牌，令其本回合下次受到的伤害+1。",
  ["#hanjin__skill_han006_1-prompt"] = "连计：交给一名其他角色一张手牌，令其本回合下次受到的伤害+1",
}

skill.hanjinImplemented = true

return skill
