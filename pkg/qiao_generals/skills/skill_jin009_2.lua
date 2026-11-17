-- JIN009 司马懿 · 骤霆
--
-- 规则基线：rules/generals/jin009-simayi.md。
-- 限定技，出牌阶段发动。每次只从牌堆顶亮出一张，移入处理区后用正式
-- askToUseRealCard（默认已执行，且 extraUse 不占空闲杀次数）实际使用；
-- 完整结算后重新取下一张。无法使用或亮出数达到当前角色数即止；不能任意取消。
-- expand_pile 只授权本次亮出的处理区牌，不把牌先拿入手牌，因此不会触发权变。
local skill = fk.CreateSkill {
  name = "qiao__skill_jin009_2",
  tags = { Skill.Limited },
}

---@param room Room
---@return integer
local function aliveCount(room)
  if room == nil then return 0 end
  if type(room.getAlivePlayers) == "function" then
    return #room:getAlivePlayers()
  end
  return #(room.alive_players or {})
end

skill:addEffect("active", {
  anim_type = "offensive",
  prompt = "#qiao__skill_jin009_2-prompt",
  max_phase_use_time = 1,
  card_num = 0,
  target_num = 0,
  card_filter = Util.FalseFunc,
  target_filter = Util.FalseFunc,
  can_use = function(self, player)
    -- 客户端没有 player.room；客户端与服务端共用当前房间的公开存活列表。
    return player:usedSkillTimes(skill.name, Player.HistoryGame) == 0
      and not player.dead and aliveCount(Fk:currentRoom()) > 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    if player == nil or player.dead then return end
    local revealed = 0

    while not player.dead and revealed < aliveCount(room) do
      local ids = room:getNCards(1)
      local id = ids and ids[1]
      if id == nil then break end
      revealed = revealed + 1
      room:moveCardTo({ id }, Card.Processing, nil, fk.ReasonPut,
        skill.name, nil, true, player)

      -- 选择并执行一次；返回 nil 即这张亮出牌无法使用，立即停止。
      -- pattern 必须锁定本次唯一亮出的处理区牌，不能回落到普通手牌。
      local use = room:askToUseRealCard(player, {
        pattern = { id },
        skill_name = skill.name,
        prompt = "#qiao__skill_jin009_2-use",
        cancelable = false,
        expand_pile = { id },
      })
      -- 使用成功时牌已离开处理区；失败时收尾；clean 只处理仍在处理区的牌。
      room:cleanProcessingArea({ id }, skill.name)
      if use == nil then break end
    end
  end,
})

skill.qiaoImplemented = true

Fk:loadTranslationTable {
  ["#qiao__skill_jin009_2-prompt"] = "骤霆：连续亮出并使用牌堆顶牌，直到无法使用或达到角色数",
  ["#qiao__skill_jin009_2-use"] = "骤霆：使用当前亮出的牌",
}

return skill
