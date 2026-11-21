-- EM(JIN001) 诸王敕封册
-- 首次双亮全局记账（无持旗者也记），持旗者在 GeneralRevealed 实际发动；
-- “赐”按持有者公开表标记保存，客户端可读取自身赐与分支可用性。
local Change = require "packages.qiao.pkg.qiao_mode.rules.general_change"
local Discard = require "packages.qiao.pkg.qiao_mode.rules.general_discard"
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
local Ban = require "packages.qiao.pkg.qiao_mode.rules.faction_ban"
local Versions = require "packages.qiao.pkg.qiao_mode.rules.general_versions"
local Commander = require "packages.qiao.pkg.qiao_mode.rules.commander_retinue"
local First = require "packages.qiao.pkg.qiao_generals.util.jin_first_reveal"
local Flags = require "packages.qiao.pkg.qiao_mode.rules.lord_flag_display"
local Ci = require "packages.qiao.pkg.qiao_generals.util.jin_ci"

local skill = fk.CreateSkill { name = Ci.SKILL }
skill.qiaoImplemented = true

local SHOWN_MARK = "qiao_jin001_first_double"
local USED_MARK = "qiao_jin001_change_used"
local CI_MARK = "@[qiao_ci]"
local CHANGE = "qiao__jin001_banner-change"

local function lord(room)
  if room == nil then return nil end
  for _, p in ipairs(room:getPresentPlayers()) do
    local kingdom = p.kingdom
    if kingdom ~= "jin" and p:getMark("__heg_kingdom") == "jin" then kingdom = "jin" end
    if not p.dead and not p:isRemoved() and kingdom == "jin"
      and p:hasShownSkill("qiao__skill_em_jin001_1")
      and p:hasSkill(skill.name) then
      return p
    end
  end
  return nil
end

local function affiliations(general)
  return general and Ban.affiliations(general) or {}
end

local function deputyName(target)
  local name = target.deputyGeneral
  if name == "anjiang" or name == nil or name == "" then
    name = target:getMark("__heg_deputy")
  end
  return type(name) == "string" and name or nil
end

local function ciList(holder)
  return table.simpleClone(holder:getTableMark(skill.name))
end

local function refreshCiMark(room, holder)
  local count = #holder:getTableMark(skill.name)
  -- 0 会移除标记，持旗者的空列表也需要能打开。
  local value = (count > 0 or holder:hasShownSkill(skill.name, true)) and count + 1 or 0
  if holder:getMark(CI_MARK) ~= value then room:setPlayerMark(holder, CI_MARK, value) end
end

local function refreshFlag(self, holder)
  Flags.refresh(holder, self.name)
  refreshCiMark(holder.room, holder)
end

skill:addAcquireEffect(refreshFlag)
skill:addLoseEffect(refreshFlag)

local function saveCi(room, holder, list)
  room:setPlayerMark(holder, skill.name, #list > 0 and list or 0)
  refreshCiMark(room, holder)
end

local function consumeCi(room, holder, chosen)
  local remaining = ciList(holder)
  if not table.removeOne(remaining, chosen) then return false end
  Discard.add(room, { chosen })
  saveCi(room, holder, remaining)
  return true
end

local function drawCi(room, holder, target)
  local name = deputyName(target)
  if name == nil or name:startsWith("blank_") or Commander.isSoldier(name) or Commander.isRetinue(name) then return end
  local deputy = Fk.generals[name]
  if deputy == nil then return end
  local kinds = affiliations(deputy)
  local candidates = {}
  for _, candidate in ipairs(room.general_pile or {}) do
    local general = Fk.generals[candidate]
    if general ~= nil and general.kingdom ~= "wild" and not Versions.is_lord(candidate)
      and not Commander.isSoldier(candidate) and not Commander.isRetinue(candidate)
      and not table.contains(room.disabled_generals or {}, candidate)
      and table.find(kinds, function(k) return table.contains(affiliations(general), k) end) then
      table.insert(candidates, candidate)
    end
  end
  if #candidates == 0 then return end
  local chosen = candidates[room:random(1, #candidates)]
  table.removeOne(room.general_pile, chosen)
  local list = ciList(holder)
  list[#list + 1] = chosen
  saveCi(room, holder, list)
end

skill:addEffect(fk.GeneralRevealed, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if target == nil or not First.isFirst(event) then return false end
    return player == lord(target.room)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__jin001_banner-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local holder = lord(target.room)
    if holder ~= nil then drawCi(target.room, holder, target) end
  end,
})

skill:addEffect(fk.Death, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if target == nil then return false end
    local killer = data and data.killer
    if killer == nil or killer.dead or killer.kingdom ~= "jin" or killer == target then return false end
    return player == lord(target.room) and target:getMark("qiao_jin001_death_ci") == 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__jin001_banner-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = target.room
    local holder = lord(room)
    if holder == nil then return end
    room:setPlayerMark(target, "qiao_jin001_death_ci", 1)
    drawCi(room, holder, target)
  end,
})

skill:addEffect(fk.EventPhaseSkipping, {
  can_trigger = function(self, event, target, player, data)
    return target == player and data.skipped and not player.dead and player:hasSkill(skill.name)
      and #player:getTableMark(skill.name) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local chosen = player.room:askToChoices(player, {
      -- 选一张后确认。保留阶段提示与取消按钮，也适用于只剩一枚赐时。
      choices = ciList(player), min_num = 1, max_num = 1, cancelable = true,
      skill_name = skill.name, prompt = "#qiao__jin001_banner-prevent-skip:::" .. Util.PhaseStrMapper(data.phase),
    })[1]
    if not table.contains(player:getTableMark(skill.name), chosen) then return false end
    event:setCostData(self, chosen)
    return true
  end,
  on_use = function(self, event, target, player, data)
    if data.skipped and player:hasSkill(skill.name) and consumeCi(player.room, player, event:getCostData(self)) then
      data.skipped = false
    end
  end,
})

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
  local okWei, Wei = pcall(require, "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wei")
  for _, isDeputy in ipairs({ false, true }) do
    local name = positionName(player, isDeputy)
    if type(name) == "string" and name ~= "" and name ~= "anjiang"
      and not Versions.is_lord(name) and not Commander.isSoldier(name) and not Commander.isRetinue(name)
      and Fk.generals[name] ~= nil and positionFish(name) == fish
      and not (okWei and Wei.isPositionRestricted and Wei.isPositionRestricted(room, player, isDeputy))
      and not Exchange.isLordPosition(player, isDeputy) then
      result[#result + 1] = isDeputy
    end
  end
  return result
end

skill:addEffect("active", {
  prompt = "#qiao__jin001_banner-active",
  target_num = 0,
  card_num = 0,
  max_phase_use_time = 1,
  -- 只承接赐列表提交的武将 ID，无需创建额外的技能交互组件。
  interaction = function() end,
  can_use = function(self, player)
    return player ~= nil and not player.dead and player.phase == Player.Play
      and #ciList(player) > 0 and player:hasSkill(skill.name)
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
      skill_name = skill.name, prompt = "#qiao__jin001_banner-branch",
    })[1]
    if branch == nil or not table.contains(branches, branch) or not Ci.canChoose(player, chosen) then return end
    if branch == CHANGE then
      local isDeputy
      if #changePositions == 1 then
        isDeputy = changePositions[1]
      else
        local choice = room:askToChoice(player, {
          choices = { "main", "deputy" }, skill_name = skill.name,
          prompt = "#qiao__jin001_banner-position", cancelable = true,
        })
        if choice == "Cancel" then return end
        isDeputy = choice == "deputy"
        if not table.contains(changePositions, isDeputy) then return end
      end
      if not Change.change(room, player, isDeputy, { num = 3, skill_name = skill.name }) then return end
      room:setPlayerMark(player, USED_MARK, 1)
    end
    if not consumeCi(room, player, chosen) then return end
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

Fk:addQmlMark {
  name = "qiao_ci",
  how_to_show = function(_, value) return tostring(value - 1) end,
  qml = function(_, _, holder)
    if not holder then return nil end
    return {
      url = "packages/qiao/pkg/qiao_mode/qml/CiPile.qml",
      prop = { cardNames = ciList(holder), holderId = holder.id },
    }
  end,
}

-- 和诏书一样，弹窗提交普通主动技回包。
Fk:addPostLoadFunc(function()
  Fk.skills[skill.name].visible = false
end)

Fk:loadTranslationTable {
  [skill.name] = "诸王敕封册",
  [":" .. skill.name] = "当一名角色的武将牌首次均明置后，或被晋势力角色杀死后，你可以随机将一张符合其副将牌面势力的剩余武将牌置为“赐”。"
    .. "\n（〖赐〗是一种国战标记：出牌阶段限一次，你可以消耗一枚〖赐〗，然后变更一张与此牌单独阴阳鱼数相同的武将牌（限一次），或根据此牌单独阴阳鱼数执行效果：≤3：本回合手牌上限+3。≥4：摸牌至四张。）"
    .. "\n当你即将跳过一个阶段时，你可以移去你的一枚〖赐〗并防止之。",
  [CI_MARK] = "赐",
  ["qiao__ci_consume"] = "消耗一枚赐",
  ["#qiao__jin001_banner-invoke"] = "诸王敕封册：是否随机将一张符合条件的剩余武将牌置为“赐”",
  ["#qiao__jin001_banner-active"] = "诸王敕封册：消耗一枚赐",
  ["#qiao__jin001_banner-prevent-skip"] = "诸王敕封册：你可以移去一枚“赐”，防止跳过%arg",
  ["#qiao__jin001_banner-branch"] = "诸王敕封册：选择资源效果或变更",
  [CHANGE] = "变更武将",
  ["qiao__jin001_banner-resource-maxcard"] = "本回合手牌上限+3",
  ["qiao__jin001_banner-resource-draw"] = "将手牌摸至四张",
  ["#qiao__jin001_banner-position"] = "诸王敕封册：选择变更位置（main 主将 / deputy 副将）",
}

return skill
