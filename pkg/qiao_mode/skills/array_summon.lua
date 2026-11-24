local Array = require "packages.qiao.pkg.qiao_mode.rules.array_summon"
local Selection = require "packages.qiao.pkg.qiao_mode.rules.trigger_selection"
local skill = fk.CreateSkill { name = Array.skill, mode_skill = true }
local labels = { formation = "qiao_array_formation", siege = "qiao_array_siege" }

skill:addEffect("active", {
  anim_type = "support",
  audio_index = 0,
  card_num = 0, target_num = 0,
  max_phase_use_time = 1,
  prompt = "#qiao_array_choose",
  interaction = Selection.optionButtons(skill, function(player)
    local choices = table.map(Array.choices(Fk:currentRoom(), player), function(kind) return labels[kind] end)
    return choices, { labels.formation, labels.siege }
  end),
  can_use = function(self, player)
    return player:hasShownSkill(self.name)
      and player:usedEffectTimes(self.name, Player.HistoryPhase) == 0
      and #Array.choices(Fk:currentRoom(), player) > 0
  end,
  on_use = function(self, room, effect)
    for kind, label in pairs(labels) do
      if effect.interaction_data == label then Array.resolve(room, effect.from, kind) end
    end
  end,
})

Fk:loadTranslationTable {
  [Array.skill] = "阵法召唤",
  [":" .. Array.skill] = "出牌阶段限一次，你可以依据明置武将牌上的阵法技发动队列或围攻召唤。符合条件的未确定势力角色可明置武将牌响应。两侧均符合时先从下家方向开始，同一角色只询问一次。",
  ["#qiao_array_choose"] = "阵法召唤：选择本次召唤的阵法",
  ["qiao_array_formation"] = "队列召唤",
  ["qiao_array_siege"] = "围攻召唤",
  ["#qiao_array_respond_formation"] = "%src 发动队列召唤，你可以明置武将牌加入队列",
  ["#qiao_array_respond_siege"] = "%src 发动围攻召唤，你可以明置武将牌参与围攻",
  ["#qiao_array_pass_formation"] = "%src 发动队列召唤，你没有可以明置并加入队列的武将牌，请选择取消",
  ["#qiao_array_pass_siege"] = "%src 发动围攻召唤，你没有可以明置并参与围攻的武将牌，请选择取消",
}

return skill
