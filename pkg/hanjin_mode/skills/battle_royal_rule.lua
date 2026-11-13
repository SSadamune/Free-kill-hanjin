local BattleRoyal = require "packages.hanjin.pkg.hanjin_mode.rules.battle_royal"
local O = require "packages.hanjin.pkg.hanjin_mode.rules.only_as"

-- 汉晋鏖战的进入时机。与上游 heg_rule 使用相同条件，但优先级更高：汉晋先
-- 进入并设置 BattleRoyalMode tag，上游效果随后看到 tag 已存在而不会调用
-- H.enterBattleRoyalMode。其它技能直接调用 H.enterBattleRoyalMode 的路径由
-- EventAcquireSkill 接管，避免上游技能残留。
local skill = fk.CreateSkill {
  name = "#hanjin_battle_royal_rule",
  tags = { Skill.Compulsory },
}

-- 该触发技因为 global 会进入所有房间的触发表；所有入口必须先确认本房间
-- 是汉晋国战，避免改变普通国战房间的行为。
local function inHanjin(player)
  return player ~= nil and player.room ~= nil
    and player.room:getSettings("gameMode") == "hanjin_heg_mode"
end

skill:addEffect(fk.BeforeTurnStart, {
  global = true,
  mute = true,
  is_delay_effect = true,
  priority = 10,
  can_trigger = function(self, event, target, player)
    return target == player and inHanjin(player)
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player)
    BattleRoyal.onTurnStart(player.room)
  end,
})

skill:addEffect(fk.AfterDrawPileShuffle, {
  global = true,
  mute = true,
  is_delay_effect = true,
  priority = 10,
  can_trigger = function(self, event, target, player)
    return target == player and inHanjin(player)
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player)
    BattleRoyal.onFirstShuffle(player.room)
  end,
})

-- 上游技能被任何技能添加时立即撤下，并补全汉晋来源与事件状态。
skill:addEffect(fk.EventAcquireSkill, {
  global = true,
  mute = true,
  is_delay_effect = true,
  priority = 10,
  can_trigger = function(self, event, target, player, data)
    return target == player and inHanjin(player) and data ~= nil and data.skill ~= nil
      and table.contains(BattleRoyal.UPSTREAM_SKILLS, data.skill.name)
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    BattleRoyal.onAcquire(player.room, target, data.skill.name)
    O.refresh(player.room)
  end,
})

Fk:loadTranslationTable {
  ["#hanjin_battle_royal_rule"] = "汉晋鏖战",
}

return skill
