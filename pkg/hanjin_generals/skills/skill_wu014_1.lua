-- WU014 鲁肃 · 好施
--
-- 摸牌阶段，可以多摸两张牌；然后若手牌数大于 5，将半数（向下取整）手牌交给
-- 一名手牌最少的其他角色。多摸承诺后的给牌由预注册静态技能
-- `hanjin__wu_turn_effects` 在本次 AfterDrawNCards 完成，不依赖好施是否仍在；
-- pending 绑定在本次摸牌事件的 data 上，不使用可迁移的玩家标记。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wu014_1",
}
skill.hanjinImplemented = true

local TURN_EFFECTS = "hanjin__wu_turn_effects"
local HAOSHI_PENDING = "__hanjin_haoshi_pending_player"

local function ensureTurnEffects(room)
  if room == nil then return end
  if not room:hasSkill(TURN_EFFECTS) then
    room:addSkill(TURN_EFFECTS)
  end
end

skill:addEffect(fk.DrawNCards, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and not player.dead
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_wu014_1-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    ensureTurnEffects(player.room)
    data.n = data.n + 2
    -- 事件绑定：AfterDrawNCards 仍拿到同一个 data；用后立即消费。
    data[HAOSHI_PENDING] = player.id
  end,
})

skill:addAcquireEffect(function(self, player)
  ensureTurnEffects(player.room or Fk:currentRoom())
end)

Fk:loadTranslationTable {
  ["hanjin__skill_wu014_1"] = "好施",
  [":hanjin__skill_wu014_1"] = "摸牌阶段，你可以多摸两张牌，然后若你的手牌数大于5，你将半数（向下取整）手牌交给一名手牌最少的其他角色。",
  ["#hanjin__skill_wu014_1-invoke"] = "好施：你可以多摸两张牌",
  ["#hanjin__skill_wu014_1-target"] = "好施：选择一名手牌最少的其他角色",
  ["#hanjin__skill_wu014_1-cards"] = "好施：将 %arg 张手牌交给其",
}

return skill
