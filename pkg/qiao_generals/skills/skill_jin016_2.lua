-- JIN016 张华 · 风物
--
-- 出牌阶段限一次：令至多三名角色依次可以使用一张牌，每人可放弃。全部询问结束
-- 后，按本回合全体角色真实使用过的牌检查四种花色，满足则摸两张且回复1点体力。
-- 不是只检查本次询问，也不把纯打出计入；技能效果内的用牌不占用空闲出杀次数。
local H = require "packages.qiao.pkg.qiao_mode.rules.wu_history"
local FreeUse = require "packages.qiao.pkg.qiao_mode.rules.free_use"

local skill = fk.CreateSkill {
  name = "qiao__skill_jin016_2",
}
skill.qiaoImplemented = true

local function allSuitsThisTurn(room)
  local seen = {}
  for _, p in ipairs(room.players) do
    for _, record in ipairs(H.used(p)) do
      local suit = record.suit
      if suit == Card.Spade or suit == Card.Heart
        or suit == Card.Club or suit == Card.Diamond then
        seen[suit] = true
      end
    end
  end
  return seen[Card.Spade] and seen[Card.Heart]
    and seen[Card.Club] and seen[Card.Diamond] or false
end

skill:addEffect("active", {
  anim_type = "support",
  prompt = "#qiao__skill_jin016_2-prompt",
  card_num = 0,
  max_phase_use_time = 1,
  min_target_num = 1,
  max_target_num = 3,
  target_filter = function(self, player, to_select, selected)
    return to_select ~= nil and not to_select.dead and not to_select:isRemoved()
      and not table.contains(selected, to_select) and #selected < 3
  end,
  can_use = function(self, player)
    local room = Fk:currentRoom()
    return self:withinTimesLimit(player, Player.HistoryPhase)
      and room ~= nil and #room:getPresentPlayers() > 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    if player == nil or player.dead then return end
    local targets = table.simpleClone(effect.tos or {})
    if #targets == 0 or #targets > 3 then return end
    room:sortByAction(targets)

    for _, target in ipairs(targets) do
      if player.dead then break end
      if not target.dead and not target:isRemoved() then
        -- 自由用牌：请求声明 not_passive，客户端不提供【闪】【无懈可击】
        -- 等无响应时机的被动牌；返回后由公共入口按本次请求复核禁止、转换
        -- 与目标，伪造的被动牌按放弃处理。
        local use = FreeUse.askToUseCard(target, {
          pattern = ".",
          skill_name = skill.name,
          prompt = "#qiao__skill_jin016_2-use:" .. target.id,
          cancelable = true,
          extra_data = { extraUse = true },
        })
        if use ~= nil and use.card ~= nil then
          room:useCard(use)
        end
      end
    end

    if player.dead or not allSuitsThisTurn(room) then return end
    player:drawCards(2, skill.name)
    if not player.dead then
      room:recover { who = player, num = 1, recoverBy = player, skillName = skill.name }
    end
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_jin016_2"] = "风物",
  ["#qiao__skill_jin016_2-prompt"] = "风物：令至多三名角色依次使用一张牌",
  ["#qiao__skill_jin016_2-use"] = "风物：你可以使用一张牌",
}

return skill
