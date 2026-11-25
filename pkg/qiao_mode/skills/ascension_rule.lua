local A = require "packages.qiao.pkg.qiao_mode.rules.ascension"
local FaqRules = require "packages.qiao.pkg.qiao_mode.rules.faq_core_rules"
local H = require "packages.hegemony.util"

-- 模式级升变规则。由统领规则在所有包加载完成后挂到实际 Skill 对象上，
-- 避免和其他会话同时修改 mode.lua 的 rule 字段；房间建立时已有的模式技会一并加载。
local skill = fk.CreateSkill {
  name = A.RULE_SKILL,
}

skill:addEffect(fk.GameStart, {
  can_refresh = function(self, event, target, player)
    return player.seat == 1
  end,
  on_refresh = function(self, event, target, player)
    A.reset(player.room)
  end,
})

-- 四人及以下局首亮不获得先驱标记：高优先级早于上游 heg_rule 置位
-- `_vanguard_gained`，保留 `TheFirstToShowRewarded` 记录且不影响技能主动授先驱。
skill:addEffect(fk.GeneralRevealed, {
  priority = 1001,
  can_trigger = function(self, event, target, player)
    local room = player.room
    return target == player and not FaqRules.allows_first_show_vanguard(room)
      and room:getTag("TheFirstToShowRewarded") == player.id
      and player:getMark("_vanguard_gained") == 0
  end,
  on_trigger = function(self, event, target, player)
    player.room:setPlayerMark(player, "_vanguard_gained", 1)
  end,
})

-- 普通双亮奖励实际发放时记录历史资格。priority 高于上游 consume 逻辑，
-- 先读取 pending 快照；不改 event.data。
skill:addEffect(fk.GeneralRevealed, {
  priority = 1000,
  can_trigger = function(self, event, target, player)
    return target == player and player.general ~= "anjiang" and player.deputyGeneral ~= "anjiang"
      and player.deputyGeneral ~= ""
      and (player:getMark("HalfMaxHpLeft") > 0 or player:getMark("CompanionEffect") > 0)
  end,
  on_trigger = function(self, event, target, player)
    local room = player.room
    local fish = player:getMark("HalfMaxHpLeft")
    if fish > 0 then
      room:setPlayerMark(player, A.YINYANG_MARK, 1)
      if fish > 1 then
        room:setPlayerMark(player, "HalfMaxHpLeft", 0)
        H.addHegMark(player, "yinyangfish", fish)
      end
    end
    if player:getMark("CompanionEffect") > 0 then
      player.room:setPlayerMark(player, A.COMPANION_MARK, 1)
    end
  end,
})
skill:addEffect(fk.TurnEnd, {
  priority = -100,
  can_trigger = function(self, event, target, player)
    return target == player
  end,
  on_trigger = function(self, event, target, player)
    A.on_turn_end(player.room, player)
  end,
})

-- 野心家效忠只在自己的准备阶段（Player.Start）询问。
skill:addEffect(fk.EventPhaseStart, {
  priority = 100,
  can_trigger = function(self, event, target, player, data)
    return target == player and data.phase == Player.Start
  end,
  on_trigger = function(self, event, target, player, data)
    A.on_preparation(player.room, player)
  end,
})

-- 10 人局第 5 人起超员转野：先于 ensure_wild_role（priority 1000）与上游 heg_rule
-- （priority 0）修正 kingdom，使随后的 ensure_wild_role 顺带把私有 role 归一为 wild。
skill:addEffect(fk.GeneralShown, {
  priority = 1100,
  can_trigger = function(self, event, target, player, data)
    return target == player and target.kingdom ~= "wild" and target.kingdom ~= "unknown"
  end,
  on_trigger = function(self, event, target, player, data)
    FaqRules.enforce_reveal_overflow(player.room, player)
  end,
})

-- 溢出转野：引擎在触发 GeneralShown 前已把 kingdom 设为 wild，但溢出角色的
-- 私有 role 仍是初始常规势力。上游 heg_rule 的 GeneralShown 会据此弹出
-- “野心家建国”。必须在 priority 0 的上游处理之前归一 role；这里不返回
-- true，保留上游其余明置流程（首亮、君主拉回、同势力胜负检查等）。
skill:addEffect(fk.GeneralShown, {
  priority = 1000,
  can_trigger = function(self, event, target, player, data)
    return target == player and target.kingdom == "wild"
  end,
  on_trigger = function(self, event, target, player, data)
    A.ensure_wild_role(player)
  end,
})

-- 死亡继位窗口必须在游戏结束判定之前，且先于上游君主死亡转野。
skill:addEffect(fk.BeforeGameOverJudge, {
  priority = 100,
  can_trigger = function(self, event, target, player, data)
    return target == player
  end,
  on_trigger = function(self, event, target, player, data)
    A.on_before_game_over(player.room, player)
  end,
})

-- 汉晋自己接管胜负判定；高优先级先于标准规则和上游君主特例执行，避免
-- 上游在胜利时按 heg_* 国号询问野心家建国。无胜利者时交回标准流程。
skill:addEffect(fk.GameOverJudge, {
  priority = 1000,
  can_trigger = function(self, event, target, player, data)
    return target == player and player.rest <= 0
  end,
  on_trigger = function(self, event, target, player, data)
    local room = player.room
    if room:getTag("SkipGameRule") then return false end
    local winner = room:getGameMode():getWinner(player)
    if winner ~= "" then
      room:gameOver(winner)
      return true
    end
  end,
})

Fk:loadTranslationTable {
  [A.RULE_SKILL] = "汉晋升变规则",
  [A.ASCEND_ACCEPT] = "君主升变",
  [A.ASCEND_KINGDOM] = "升变为%arg的君主",
  [A.WILD_ASCEND] = "效忠并加入%arg",
  ["#QiaoSecondLordSuccession"] = "君主死亡：你的主将可继位为君主，是否升变？",
  ["#QiaoWildAllegiance"] = "野心家效忠：你的主将可升变为效忠版，是否升变？",
  ["#QiaoAscension"] = "%from 将主将 %arg 升变为 %arg2，势力改为 %arg3",
  ["#QiaoLordDeathWild"] = "%from 因君主死亡改为野心家（原势力 %arg）",
}

return skill
