-- SHU012 姜维 · 挑衅
-- 出牌阶段限一次：至多两名攻击范围内有姜维的角色依次可以真实使用【杀】；
-- 每次结算后若姜维未因此受伤，姜维弃置该角色手牌/装备一张（不含判定区）。
local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"

local skill = fk.CreateSkill {
  name = "qiao__skill_shu012_1",
}
skill.qiaoImplemented = true

local SLASH = "qiao__slash"

local function canAttackJiangwei(player, target)
  return target ~= player and target:isAlive() and not target:isRemoved()
    and target:inMyAttackRange(player)
end

skill:addEffect("active", {
  prompt = "#qiao__skill_shu012_1-prompt",
  min_target_num = 1,
  max_target_num = 2,
  max_phase_use_time = 1,
  card_num = 0,
  card_filter = Util.FalseFunc,
  target_filter = function(self, player, to_select, selected)
    return #selected < 2 and canAttackJiangwei(player, to_select)
  end,
  can_use = function(self, player)
    return player ~= nil and not player.dead and player.phase == Player.Play
      and player:hasSkill(skill.name)
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    if player == nil or player.dead then return end
    for _, to in ipairs(effect.tos or {}) do
      if player.dead then break end
      if to:isAlive() and not to:isRemoved() then
        local use = C.askToUseCard(room, to, {
          names = { SLASH },
          pattern = "slash",
          skill_name = skill.name,
          prompt = "#qiao__skill_shu012_1-use:" .. player.id,
          cancelable = true,
          extra_data = { exclusive_targets = { player.id } },
          policy = C.explicit({ other_roles = true }, {
            names = { SLASH }, fixed_targets = { player },
            min_targets = 1, max_targets = 1,
          }),
        })
        -- 显式策略保证唯一目标数；再固定必须是姜维。选择其他目标时不使用。
        if use ~= nil and #use.tos == 1 and use.tos[1] == player then
          room:useCard(use)
          local damage = (use.damageDealt or {})[player] or 0
          if damage <= 0 and not player.dead then
            local ids = table.filter(to:getCardIds("he"), function(id)
              return not to:prohibitDiscard(id)
            end)
            if #ids > 0 then
              local id = room:askToChooseCard(player, {
                target = to,
                flag = { card_data = { { "弃置", ids } } },
                skill_name = skill.name,
                prompt = "#qiao__skill_shu012_1-discard:" .. to.id,
              })
              if id ~= nil and id ~= -1 and table.contains(ids, id) then
                room:throwCard(id, skill.name, to, player)
              end
            end
          end
        elseif use == nil then
          -- 未出杀也属于“未因此受伤”，仍弃其一张牌。
          local ids = table.filter(to:getCardIds("he"), function(id)
            return not to:prohibitDiscard(id)
          end)
          if #ids > 0 then
            local id = room:askToChooseCard(player, {
              target = to,
              flag = { card_data = { { "弃置", ids } } },
              skill_name = skill.name,
              prompt = "#qiao__skill_shu012_1-discard:" .. to.id,
            })
            if id ~= nil and id ~= -1 and table.contains(ids, id) then
              room:throwCard(id, skill.name, to, player)
            end
          end
        end
      end
    end
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_shu012_1"] = "挑衅",
  [":qiao__skill_shu012_1"] = "出牌阶段限一次，你可以令至多两名攻击范围内有你的角色依次执行以下效果：其可以对你使用一张【杀】，若你未因此受到伤害，你弃置其一张牌。",
  ["#qiao__skill_shu012_1-prompt"] = "挑衅：选择至多两名攻击范围内有你的角色",
  ["#qiao__skill_shu012_1-use"] = "挑衅：你可以对姜维使用一张【杀】",
  ["#qiao__skill_shu012_1-discard"] = "挑衅：弃置 %dest 一张牌",
}

return skill
