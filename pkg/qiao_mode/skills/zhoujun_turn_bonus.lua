-- 州郡领兵印的回合修正：作为模式级常规技能随 qiao_heg_mode 一起注册，
-- 服务端与客户端都有 targetmod/maxcards 状态；数值只读公开玩家标记，
-- 因此装备离场后仍保留到本回合结束。
local DRAW = "qiao_zhoujun_draw"
local SLASH = "qiao_zhoujun_slash"
local HAND = "qiao_zhoujun_hand"

local skill = fk.CreateSkill { name = "qiao__zhoujun_turn_bonus" }
local checkingSlashBase = {}

skill:addEffect(fk.DrawNCards, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    local room = Fk:currentRoom()
    if room:getTag("qiao_zhoujun_draw_event") == event.id then return false end
    return target ~= nil and target:getMark(DRAW) ~= 0
  end,
  on_refresh = function(self, event, target, player, data)
    local room = Fk:currentRoom()
    if room:getTag("qiao_zhoujun_draw_event") == event.id then return end
    room:setTag("qiao_zhoujun_draw_event", event.id)
    data.n = math.max(0, data.n + target:getMark(DRAW))
  end,
})

skill:addEffect("maxcards", {
  correct_func = function(self, player)
    local value = player:getMark(HAND)
    if value ~= 0 then return value end
  end,
})

skill:addEffect("targetmod", {
  residue_func = function(self, player, card_skill, scope, card, to)
    if scope ~= Player.HistoryPhase or not card or card.trueName ~= "slash" then return end
    if checkingSlashBase[player] then return end
    local value = player:getMark(SLASH)
    if value >= 0 then return value end
    -- 再查询一次当前上限，跳过本修正。其他加次数效果中途失效时最多减到零。
    checkingSlashBase[player] = true
    local ok, base = pcall(card_skill.getMaxUseTime, card_skill, player, scope, card, to)
    checkingSlashBase[player] = nil
    if not ok then error(base, 0) end
    return base and math.max(value, -math.max(0, base)) or value
  end,
})

skill:addEffect(fk.TurnEnd, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return target ~= nil and (target:getMark(DRAW) ~= 0
      or target:getMark(SLASH) ~= 0 or target:getMark(HAND) ~= 0)
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = Fk:currentRoom()
    for _, mark in ipairs({ DRAW, SLASH, HAND }) do
      room:setPlayerMark(target, mark, 0)
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "州郡领兵印",
}
return skill
