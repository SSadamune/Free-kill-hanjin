-- HAN003 刘宏 · 鬻爵
-- 每名角色的出牌阶段开始时，你可以弃置一张牌并对其发起“军令”：
-- 若其执行，其本回合下次造成伤害后摸两张牌；
-- 若其不执行，你暗置其一张武将牌且其本回合不能明置之（若其已有暗置的武将牌，则改为令其叠置）。
local Junling = require "packages.qiao.pkg.qiao_mode.rules.junling"
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"
local Quan = require "packages.qiao.pkg.qiao_generals.util.quan_common"

local skill = fk.CreateSkill {
  name = "qiao__skill_han003_1",
}
skill.qiaoImplemented = true

local function hasDiscardableCard(player)
  return table.find(player:getCardIds("he"), function(id)
    return not player:prohibitDiscard(id)
  end) ~= nil
end

skill:addEffect(fk.EventPhaseStart, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    return target ~= nil and target.phase == Player.Play
      and RemovedTargets.isPresent(target)
      and RemovedTargets.isPresent(player)
      and player:hasSkill(skill.name)
      and hasDiscardableCard(player)
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local cards = room:askToDiscard(player, {
      min_num = 1,
      max_num = 1,
      include_equip = true,
      skill_name = skill.name,
      prompt = "#qiao__skill_han003_1-invoke::" .. target.id,
      cancelable = true,
    })
    return type(cards) == "table" and #cards > 0
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    if player.dead or not RemovedTargets.isPresent(target) then return end
    local executed = Junling.ask(player, target, skill.name)
    if not RemovedTargets.isPresent(target) then return end
    if executed then
      Quan.addYujueDraw(room, target)
      return
    end
    -- 不执行分支：已有暗置武将牌则改为汉晋定向叠置；否则暗置一张可暗置武将牌且本回合不能明置。
    if Quan.hasHiddenGeneral(target) then
      Quan.directedStack(target)
      return
    end
    local hideable = {}
    if Quan.canHideGeneralPosition(target, false) then
      table.insert(hideable, { isDeputy = false, label = "qiao_han003_hide_main:::" .. target.general })
    end
    if Quan.canHideGeneralPosition(target, true) then
      table.insert(hideable, { isDeputy = true, label = "qiao_han003_hide_deputy:::" .. target.deputyGeneral })
    end
    if #hideable == 0 then return end
    local chosen = hideable[1]
    if #hideable > 1 then
      local choices = table.map(hideable, function(item) return item.label end)
      local pick = room:askToChoice(player, {
        choices = choices,
        skill_name = skill.name,
        prompt = "#qiao__skill_han003_1-hide::" .. target.id,
        cancelable = false,
      })
      for _, item in ipairs(hideable) do
        if item.label == pick then chosen = item; break end
      end
    end
    local isDeputy = chosen.isDeputy
    local place = isDeputy and "d" or "m"
    local origName = isDeputy and target.deputyGeneral or target.general
    if isDeputy then
      room:setPlayerMark(target, "__heg_deputy", origName)
    else
      room:setPlayerMark(target, "__heg_general", origName)
    end
    target:hideGeneral(isDeputy)
    room:addTableMarkIfNeed(target, MarkEnum.RevealProhibited .. "-turn", place)
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "鬻爵",
  [":" .. skill.name] = "每名角色的出牌阶段开始时，你可以弃置一张牌并对其发起“军令”：若其执行，其本回合下次造成伤害后摸两张牌；若其不执行，你暗置其一张武将牌且其本回合不能明置之（若其已有暗置的武将牌，则改为令其叠置）。",
  ["#qiao__skill_han003_1-invoke"] = "鬻爵：你可以弃置一张牌，对 %dest 发起“军令”",
  ["#qiao__skill_han003_1-hide"] = "鬻爵：选择暗置 %dest 的一张武将牌（本回合不能明置）",
  ["qiao_han003_hide_main"] = "暗置主将 %arg",
  ["qiao_han003_hide_deputy"] = "暗置副将 %arg",
}

return skill
