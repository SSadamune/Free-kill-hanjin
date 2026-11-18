-- 调虎离山（汉晋版）
--
-- 牌面：出牌阶段，对一至两名其他角色使用。目标角色本回合移出游戏。
--
-- 本技能只负责选择目标、防止当前回合角色/濒死角色被实际移出，并建立引擎的
-- PlayerRemoved 标记。“移出期间视为不存在”的统一限制由
-- qiao__removed_player_rule 提供。标记使用 "-turn" 后缀：回合结束时先结算
-- TurnEnd 技能与【敕令】（priority 0），再移回角色；破军等牌的移回由
-- Turn exit 函数在更后执行。
--
-- 接线（集成阶段）：qiao_cards/data/reuse.lua 的 qiao__lure_tiger.skill 须
-- 指向本技能；否则 qiao_cards/init.lua 的复用适配仍会用上游 lure_tiger_skill。
local H = require "packages.hegemony.util"

local skill = fk.CreateSkill {
  name = "qiao__lure_tiger_skill",
}

local REMOVED_TURN = MarkEnum.PlayerRemoved .. "-turn"
-- 上游/既有八阵兵用例读取的公开显示标记；引擎会按 "-turn" 后缀清理。
local UI_MARK = "@@lure_tiger-turn"

skill:addEffect("cardskill", {
  prompt = "#qiao__lure_tiger_skill",
  min_target_num = 1,
  max_target_num = 2,
  mod_target_filter = function(self, player, to_select)
    return to_select ~= player and not to_select.dead and not to_select:isRemoved()
  end,
  target_filter = Util.CardTargetFilter,
  on_effect = function(self, room, effect)
    local target = effect.to
    if target == nil or target.dead or target:isRemoved() then return end
    -- 当前回合角色或濒死角色即将被移出时，防止之；一至两名目标分别判断。
    if target == room.current or target.hp < 1 then
      room:sendLog {
        type = "#qiao__lure_tiger-prevent",
        to = { target.id },
        toast = true,
      }
      return
    end
    room:setPlayerMark(target, REMOVED_TURN, 1)
    room:setPlayerMark(target, UI_MARK, 1)
    room.logic:trigger(H.PlayerRemoved, target, { who = target })
  end,
})

Fk:loadTranslationTable {
  ["qiao__lure_tiger_skill"] = "调虎离山",
  ["#qiao__lure_tiger_skill"] = "选择一至两名其他角色，目标角色本回合移出游戏",
  [":qiao__lure_tiger_skill"] = "锦囊牌<br/><b>时机</b>：出牌阶段<br/>"
    .. "<b>目标</b>：一至两名其他角色<br/>"
    .. "<b>效果</b>：目标角色本回合移出游戏。",
  ["@@lure_tiger-turn"] = "移出游戏",
  ["#qiao__lure_tiger-prevent"] = "【调虎离山】防止 %to 被移出游戏",
}

return skill
