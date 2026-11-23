-- “赐”的出牌阶段效果属于标记持有者，和诸王敕封册的触发技能分开。
local Ci = require "packages.qiao.pkg.qiao_generals.util.jin_ci"
local Change = require "packages.qiao.pkg.qiao_mode.rules.general_change"
local Commander = require "packages.qiao.pkg.qiao_mode.rules.commander_retinue"

local skill = fk.CreateSkill { name = Ci.CONSUME, tags = { Skill.Permanent } }
skill.qiaoImplemented = true
local USED_MARK = "qiao_jin001_change_used"
local CHANGE = "qiao__jin001_banner-change"

local function positionFish(name)
  local general = Fk.generals[name]
  return general and general.maxHp or nil
end

local function positionName(player, isDeputy)
  local name = isDeputy and player.deputyGeneral or player.general
  if name == "anjiang" or name == "" then
    name = player:getMark(isDeputy and "__heg_deputy" or "__heg_general")
  end
  return name
end

--- 只接受实际普通武将牌、同鱼数、非君主、未建安锁定的位置。
--- 君主牌所在位置不能变更（含暗置牌），普通副将位置仍可选。
local function matchingPosition(room, player, fish)
  local result = {}
  for _, isDeputy in ipairs({ false, true }) do
    local name = positionName(player, isDeputy)
    if type(name) == "string" and not Commander.isSoldier(name) and positionFish(name) == fish
      and #Change.candidates(room, player, isDeputy) > 0 then
      result[#result + 1] = isDeputy
    end
  end
  return result
end

skill:addEffect("active", {
  prompt = "#qiao__jin001_banner-active",
  target_num = 0,
  card_num = 0,
  -- 只承接赐列表提交的武将 ID，无需创建额外的技能交互组件。
  interaction = function() end,
  can_use = function(self, player)
    return Ci.canSpend(player)
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local chosen = effect.interaction_data
    if not Ci.canChoose(player, chosen) then return end
    local fish = positionFish(chosen)
    if fish == nil then return end
    local changePositions = matchingPosition(room, player, fish)
    -- “提供资源”按所选赐的牌面单独阴阳鱼数显示实际效果，仍消耗同一枚赐。
    local resource = fish <= 3
      and "qiao__jin001_banner-resource-maxcard"
      or "qiao__jin001_banner-resource-draw"
    local branches = { resource }
    if #changePositions > 0 and player:getMark(USED_MARK) == 0 then table.insert(branches, CHANGE) end
    local branch = room:askToChoices(player, {
      choices = branches, all_choices = { resource, CHANGE },
      min_num = 1, max_num = 1, single = true, cancelable = true,
      skill_name = Ci.SKILL, prompt = "#qiao__jin001_banner-branch",
    })[1]
    if branch == nil or not table.contains(branches, branch) or not Ci.canChoose(player, chosen) then return end
    if branch == CHANGE then
      local isDeputy
      if #changePositions == 1 then
        isDeputy = changePositions[1]
      else
        local choice = room:askToChoice(player, {
          choices = { "main", "deputy" }, skill_name = Ci.SKILL,
          prompt = "#qiao__jin001_banner-position", cancelable = true,
        })
        if choice ~= "main" and choice ~= "deputy" then return end
        isDeputy = choice == "deputy"
        if not table.contains(changePositions, isDeputy) then return end
      end
      if not Change.change(room, player, isDeputy, { num = 3, skill_name = Ci.SKILL }) then return end
      room:setPlayerMark(player, USED_MARK, 1)
    end
    if not Ci.consume(room, player, chosen) then return end
    room:setPlayerMark(player, Ci.SPENT, 1)
    if branch == resource then
      if fish <= 3 then
        room:addPlayerMark(player, MarkEnum.AddMaxCardsInTurn, 3)
      else
        local n = math.max(0, 4 - #player:getCardIds("h"))
        if n > 0 then player:drawCards(n, skill.name) end
      end
    end
  end,
})

Fk:addPostLoadFunc(function() Fk.skills[Ci.CONSUME].visible = false end)

Fk:loadTranslationTable {
  [Ci.CONSUME] = "赐",
  [":" .. Ci.CONSUME] = "出牌阶段限一次，你可以消耗一枚〖赐〗，然后变更一张与此牌单独阴阳鱼数相同的武将牌（限一次），或根据此牌单独阴阳鱼数执行效果：≤3：本回合手牌上限+3。≥4：摸牌至四张。",
}
return skill
