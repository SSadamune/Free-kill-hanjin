local A = require "packages.hanjin.pkg.hanjin_mode.rules.ascension"

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

-- 普通君主升变沿用“首个回合开始”的原有时机；一回合只询问一次。
skill:addEffect(fk.TurnStart, {
  priority = 200,
  can_trigger = function(self, event, target, player)
    return target == player
  end,
  on_trigger = function(self, event, target, player)
    A.on_turn_start(player.room, player)
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
  [A.ASCEND_ACCEPT] = "升变为君主",
  [A.ASCEND_KINGDOM] = "升变为%arg的君主",
  [A.WILD_ASCEND] = "效忠并加入%arg",
  ["#HanjinSecondLordConvert"] = "国战规则：你的主将可升变为君主，是否升变？",
  ["#HanjinSecondLordSuccession"] = "君主死亡：你的主将可继位为君主，是否升变？",
  ["#HanjinWildAllegiance"] = "野心家效忠：你的主将可升变为效忠版，是否升变？",
  ["#HanjinAscension"] = "%from 将主将 %arg 升变为 %arg2，势力改为 %arg3",
  ["#HanjinLordDeathWild"] = "%from 因君主死亡改为野心家（原势力 %arg）",
}

return skill
