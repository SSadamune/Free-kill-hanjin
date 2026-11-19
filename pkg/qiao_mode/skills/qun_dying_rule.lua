-- 群势力标准包：濒死入口的房间级规则（QUN001 济世 / QUN007 完杀）。
--
-- 由模式在 logic:start 时以 `room:addSkill("qiao__qun_dying_rule")` 接入；
-- 不设 global 触发，避免进入非汉晋房间。本技能是独立的房间来源：
--   * 完杀的用桃禁止在此注册，不依赖贾诩的完杀技能本体在濒死中是否仍存在；
--   * EnterDying/AfterDying 的序号、清理走 refresh，不进入同时机技能发动选择，
--     避免干扰不屈等原有濒死触发；
--   * AfterDying 的 refresh 先取走本次救援记录并弹栈，再把记录挂到事件 data；
--     只有存在该记录的濒死才进入实际交换触发。
local Q = require "packages.qiao.pkg.qiao_generals.util.qun_dying"

local skill = fk.CreateSkill {
  name = Q.RULE_SKILL,
  tags = { Skill.Compulsory },
}

-- 完杀：本次濒死结算中，除濒死角色外均不能对其使用【桃】，贾诩本人也无豁免。
-- 标记只由完杀的 EnterDying 设置，本房间规则负责维持和清理。
skill:addEffect("prohibit", {
  is_prohibited = function(self, from, to, card)
    if from == nil or to == nil or card == nil then return false end
    if card.trueName ~= "peach" then return false end
    if from == to then return false end
    return to:getMark(Q.WANSHA_MARK) > 0
  end,
})

-- refresh：只维护事实序号，不参与技能发动选择。
skill:addEffect(fk.EnterDying, {
  can_refresh = function(self, event, target, player, data)
    return target == player and not target.dead
  end,
  on_refresh = function(self, event, target, player, data)
    Q.beginDying(player.room, target)
  end,
})

-- refresh：清理完杀标记，取走救援记录并弹栈；记录暂存到本次事件 data。
skill:addEffect(fk.AfterDying, {
  can_refresh = function(self, event, target, player, data)
    return target == player
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(target, Q.WANSHA_MARK, 0)
    Q.finishDying(room, target, data)
  end,
})

-- 仅当 refresh 留下了本次济世救援记录时才实际交换；无记录不进入触发池。
skill:addEffect(fk.AfterDying, {
  priority = -1,
  mute = true,
  can_trigger = function(self, event, target, player, data)
    return target == player and data ~= nil and data.qiao_jishi_exchange ~= nil
  end,
  on_trigger = function(self, event, target, player, data)
    Q.exchangeRescue(player.room, target, data.qiao_jishi_exchange)
  end,
})

return skill
