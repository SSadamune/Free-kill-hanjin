-- 权包偏将（限一） · 胡车儿（张绣统领【顺手牵羊】）
-- 轮次技，与你相互处于彼此攻击范围的角色出牌阶段开始时，
-- 你可以获得其装备区的一张牌且可以使用之，若你因此离开其攻击范围，你摸一张牌。
local R = require "packages.qiao.pkg.qiao_generals.util.retinue_instances"
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"
local Wu = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wu"

local skill = fk.CreateSkill {
  name = "qiao__retinue_skill_hucheer",
}
skill.qiaoImplemented = true

local function selectableEquips(owner, chooser)
  return table.filter(owner:getCardIds("e"), function(id)
    return not (owner:hasShownSkill(Wu.JUBAO) and Wu.isProtectedTreasure(owner, chooser, id))
  end)
end

local function triggerEach(self, event, target, player, data)
  if #R.instancesForSkill(player, skill.name) == 0 then
    return self:doCost(event, target, player, data)
  end
  return R.triggerEach(self, event, target, player, data)
end

skill:addEffect(fk.EventPhaseStart, {
  anim_type = "control",
  on_trigger = triggerEach,
  can_trigger = function(self, event, target, player, data)
    return target ~= nil and target ~= player and target.phase == Player.Play
      and RemovedTargets.isPresent(player) and RemovedTargets.isPresent(target)
      and player:hasSkill(skill.name)
      and player:usedSkillTimes(skill.name, Player.HistoryRound) == 0
      and player:inMyAttackRange(target) and target:inMyAttackRange(player)
      and #selectableEquips(target, player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__retinue_skill_hucheer-invoke::" .. target.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    if not RemovedTargets.isPresent(player) or not RemovedTargets.isPresent(target) then return end
    local equips = selectableEquips(target, player)
    if #equips == 0 then return end
    local id = #equips == 1 and equips[1] or room:askToChooseCard(player, {
      target = target,
      flag = { card_data = { { "$Equip", equips } } },
      skill_name = skill.name,
      prompt = "#qiao__retinue_skill_hucheer-choose::" .. target.id,
    })
    if id == nil or not table.contains(equips, id) then id = equips[1] end
    if id == nil then return end

    room:obtainCard(player, id, true, fk.ReasonPrey, player, skill.name)

    if RemovedTargets.isPresent(player) and table.contains(player:getCardIds("h"), id) then
      local card = Fk:getCardById(id)
      if card ~= nil and not card.is_passive and not player:prohibitUse(card) then
        -- askToUseRealCard 按物理牌 ID 锁定刚获得的这一张牌并直接执行使用，兼容回合外使用装备牌。
        room:askToUseRealCard(player, {
          pattern = { id },
          skill_name = skill.name,
          prompt = "#qiao__retinue_skill_hucheer-use:::" .. card:toLogString(),
          cancelable = true,
          extra_data = { bypass_times = true, extraUse = true },
        })
      end
    end

    if RemovedTargets.isPresent(player) and RemovedTargets.isPresent(target)
      and not target:inMyAttackRange(player) then
      player:drawCards(1, skill.name)
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "胡车儿",
  [":" .. skill.name] = "轮次技，与你相互处于彼此攻击范围的角色出牌阶段开始时，你可以获得其装备区的一张牌且可以使用之，若你因此离开其攻击范围，你摸一张牌。",
  ["#qiao__retinue_skill_hucheer-invoke"] = "胡车儿：是否获得 %dest 装备区的一张牌（且可使用之）？",
  ["#qiao__retinue_skill_hucheer-choose"] = "胡车儿：选择获得 %dest 装备区的一张牌",
  ["#qiao__retinue_skill_hucheer-use"] = "胡车儿：是否使用刚获得的 %arg？",
}

return skill
