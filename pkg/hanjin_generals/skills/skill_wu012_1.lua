-- WU012 太史慈 · 天义
--
-- 出牌阶段限一次：与一名角色拼点。
--   赢：本回合使用【杀】无距离限制、可多指定一个目标、可多使用一张【杀】；
--   没赢（含平局）：本回合不能使用【杀】。
-- 效果由预注册的静态模式技能 `hanjin__wu_turn_effects` 读取公开标记，
-- 失去天义后已建立的回合增益/禁用仍生效。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wu012_1",
}
skill.hanjinImplemented = true

local TURN_EFFECTS = "hanjin__wu_turn_effects"
local WIN_MARK = "hanjin_wu012_tianyi_win-turn"
local LOSE_MARK = "hanjin_wu012_tianyi_lose-turn"

--- 客户端可用性计算时没有 ServerPlayer.room；与现有技能一致回退当前房间。
---@param player ServerPlayer | ClientPlayer
---@return Room?
local function currentRoom(player)
  return player.room or Fk:currentRoom()
end

local function pindianTargets(player)
  local room = currentRoom(player)
  if room == nil then return {} end
  return table.filter(room.alive_players, function(p)
    return p ~= player and p:isAlive() and not p:isRemoved() and player:canPindian(p)
  end)
end

local function ensureTurnEffects(room)
  if room == nil then return end
  if not room:hasSkill(TURN_EFFECTS) then
    room:addSkill(TURN_EFFECTS)
  end
end

skill:addEffect("active", {
  anim_type = "offensive",
  prompt = "#hanjin__skill_wu012_1-prompt",
  target_num = 1,
  max_phase_use_time = 1,
  target_filter = function(self, player, to_select, selected)
    return #selected == 0 and to_select ~= player
      and to_select:isAlive() and not to_select:isRemoved()
      and player:canPindian(to_select)
  end,
  can_use = function(self, player)
    return self:withinTimesLimit(player, Player.HistoryPhase)
      and #player:getCardIds(Player.Hand) > 0 and #pindianTargets(player) > 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos and effect.tos[1]
    if player == nil or target == nil or player.dead or target.dead or target:isRemoved() then return end
    if not player:canPindian(target) then return end

    ensureTurnEffects(room)
    local pindian = player:pindian({ target }, skill.name)
    local result = pindian and pindian.results and pindian.results[target]
    if result == nil then return end

    if result.winner == player then
      room:setPlayerMark(player, LOSE_MARK, 0)
      room:setPlayerMark(player, WIN_MARK, 1)
    else
      room:setPlayerMark(player, WIN_MARK, 0)
      room:setPlayerMark(player, LOSE_MARK, 1)
    end
  end,
})

skill:addAcquireEffect(function(self, player)
  ensureTurnEffects(player.room or Fk:currentRoom())
end)

Fk:loadTranslationTable {
  ["hanjin__skill_wu012_1"] = "天义",
  [":hanjin__skill_wu012_1"] = "出牌阶段限一次，你可以与一名角色拼点。若你赢，本回合你使用【杀】无距离限制、可多指定一个目标且可多使用一张【杀】；若你没赢，本回合你不能使用【杀】。",
  ["#hanjin__skill_wu012_1-prompt"] = "天义：与一名角色拼点",
}

return skill
