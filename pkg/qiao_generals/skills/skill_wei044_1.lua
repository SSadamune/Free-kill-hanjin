-- WEI044 胆戾
-- 受到伤害后可选择：1. 摸牌至与来源手牌数相同（至多五张）；2. 移除副将并
-- 回复 1 点体力，然后来源弃置手牌至与你相同。
local H = require "packages.hegemony.util"
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
local Wei = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wei"

local skill = fk.CreateSkill { name = "qiao__skill_wei044_1" }
skill.qiaoImplemented = true

local function canRemoveDeputy(player)
  local name = Exchange.actualGeneral(player, true)
  return Fk.generals[name] ~= nil and name ~= "anjiang" and not Exchange.isSoldier(name)
    and not Exchange.isLordPosition(player, true) and not Wei.isPositionRestricted(player.room, player, true)
end

local function livingSource(data)
  return data.from ~= nil and data.from:isAlive()
end

skill:addEffect(fk.Damaged, {
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and player:hasSkill(skill.name)
      and (livingSource(data) or canRemoveDeputy(player))
  end,
  on_cost = function(self, event, target, player, data)
    local choices = {}
    if livingSource(data) then table.insert(choices, "1") end
    if canRemoveDeputy(player) then table.insert(choices, "2") end
    if #choices == 0 then return false end
    table.insert(choices, "Cancel")
    local choice = player.room:askToChoice(player, {
      choices = choices, all_choices = { "1", "2", "Cancel" },
      skill_name = skill.name,
      prompt = "#qiao__wei044_prompt",
    })
    if choice == "Cancel" or not table.contains(choices, choice) then return false end
    event:setCostData(self, { choice = choice })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self)
    local source = data.from
    if cost.choice == "1" then
      if source == nil or source.dead then return end
      local n = math.min(5, math.max(0, source:getHandcardNum() - player:getHandcardNum()))
      if n > 0 and not player.dead then player:drawCards(n, skill.name) end
      return
    end
    if not canRemoveDeputy(player) then return end
    local oldDeputy = player.deputyGeneral
    local oldMark = player:getMark("__heg_deputy")
    H.removeGeneral(player, true)
    -- 以实际旧牌/记录变化确认移除成功；失败时不回复、不进入后续。
    if player.deputyGeneral == oldDeputy and player:getMark("__heg_deputy") == oldMark then return end
    if not player.dead then
      room:recover { who = player, num = 1, recoverBy = player, skillName = skill.name }
    end
    if source == nil or source.dead then return end
    local excess = source:getHandcardNum() - player:getHandcardNum()
    if excess > 0 then
      room:askToDiscard(source, {
        min_num = excess, max_num = excess, include_equip = false,
        skill_name = skill.name, prompt = "#qiao__wei044_discard", cancelable = false,
      })
    end
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_wei044_1"] = "胆戾",
  [":qiao__skill_wei044_1"] = "当你受到伤害后，你可以选择一项：1.摸牌至与来源相同（至多摸五张）；2.移除副将并回复1点体力，然后来源弃置手牌至与你相同。",
  ["#qiao__wei044_prompt"] = "胆戾：选择一项",
  ["#qiao__wei044_discard"] = "胆戾：弃置手牌至与受伤角色相同",
}

return skill
