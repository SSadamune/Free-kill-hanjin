-- 铜雀：每回合限一次，你使用应变牌时，可以无视一项应变条件。
--
-- 规则基线：docs/rules/card-deck.md「普通锦囊与装备的审阅结论 · 铜雀」、
-- 《势备应变牌堆差异》「每回合限一次，且自己选择是否发动。时机在使用牌时」
-- 与「同一张牌有多个应变条件时，只能声明其中一个」。
--   * 时机在 fk.AfterCardUseDeclared：在 PreCardUse 锁定“无视次数”之后、应变
--     常规结算之前，因此【铜雀】来不及补上已经使用的雷【杀】「孤军 → 无视次数」，
--     该条目不出现在可选项里。
--   * 选择一个条目即发动；取消不消耗本回合次数。
--   * 一个令牌只作用于一条被明确指定的条目，不能开启全部条目。
local A = require "packages.qiao.pkg.qiao_mode.rules.adaptation"
local Selection = require "packages.qiao.pkg.qiao_mode.rules.trigger_selection"

local skill = fk.CreateSkill {
  name = "qiao__bronze_sparrow_skill",
  attached_equip = "qiao__bronze_sparrow",
}

Fk:loadTranslationTable {
  ["qiao__bronze_sparrow_skill"] = "铜雀",
  ["#qiao__bronze_sparrow-choose"] = "铜雀：你可以选择一项应变效果，无视其条件",
  ["qiao__bronze_sparrow_option"] = "%arg（%arg2）",
  ["qiao__bronze_sparrow_option_satisfied"] = "%arg（%arg2）（已满足）",
}

--- 本次使用中【铜雀】可忽略的条目。“无视次数”在 PreCardUse 已经锁定，
--- 此后的令牌无法追认，故不作为选项。
local function ignorableEntries(use)
  return table.filter(A.getEntries(use.card, use), function(entry)
    return type(entry.effect) == "string" and entry.effect ~= ""
      and entry.effect ~= "ignore_times"
  end)
end

skill:addEffect(fk.AfterCardUseDeclared, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and player:usedSkillTimes(skill.name, Player.HistoryTurn) == 0
      and A.isAdaptationCard(data.card, data)
      and #ignorableEntries(data) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local entries = ignorableEntries(data)
    -- 仅用于按钮提示，实际条件仍按应变自己的时序判断。
    local natural = A.snapshot(room, data)
    local choices = {}
    for index, entry in ipairs(entries) do
      local label = natural[entry.condition] and "qiao__bronze_sparrow_option_satisfied"
        or "qiao__bronze_sparrow_option"
      -- 将序号放入模板未使用的来源字段，避免效果和条件相同的条目使用同一回包。
      choices[index] = string.format("%s:%d::qiao_adaptation_%s:qiao_condition_%s",
        label, index, entry.effect, entry.condition)
    end
    local choice = Selection.askOption(room, player, {
      choices = choices,
      skill_name = skill.name,
      prompt = "#qiao__bronze_sparrow-choose",
    })
    local picked = entries[table.indexOf(choices, choice)]
    if picked == nil then return false end
    event:setCostData(self, { entry_id = picked.id })
    return true
  end,
  on_use = function(self, event, target, player, data)
    player:setSkillUseHistory(skill.name, 1, Player.HistoryTurn)
    A.grantIgnore(data, skill.name, event:getCostData(self).entry_id)
  end,
})

return skill
