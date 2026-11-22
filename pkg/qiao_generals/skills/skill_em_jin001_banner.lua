-- EM(JIN001) 诸王敕封册
-- 首次双亮全局记账（无持旗者也记），持旗者在 GeneralRevealed 实际发动；
-- “赐”按持有者公开表标记保存，客户端可读取自身赐与分支可用性。
local Ban = require "packages.qiao.pkg.qiao_mode.rules.faction_ban"
local Guest = require "packages.qiao.pkg.qiao_mode.rules.guest_factions"
local Versions = require "packages.qiao.pkg.qiao_mode.rules.general_versions"
local Commander = require "packages.qiao.pkg.qiao_mode.rules.commander_retinue"
local First = require "packages.qiao.pkg.qiao_generals.util.jin_first_reveal"
local Flags = require "packages.qiao.pkg.qiao_mode.rules.lord_flag_display"
local Ci = require "packages.qiao.pkg.qiao_generals.util.jin_ci"
local Discard = require "packages.qiao.pkg.qiao_mode.rules.general_discard"

local skill = fk.CreateSkill { name = Ci.SKILL }
skill.qiaoImplemented = true

local CI_MARK = Ci.MARK
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

local function availableKingdoms(room, name, allowed)
  local entry = Guest.factionsOf(room, name)
  if not entry or entry.wild then return {} end
  -- 自由选将可能在记录里保留已禁的牌面势力；取赐、送赐都只认本局允许的势力。
  return table.filter(entry.kingdoms, function(kingdom) return table.contains(allowed, kingdom) end)
end

local function deputyName(target)
  local name = target.deputyGeneral
  if name == "anjiang" or name == nil or name == "" then
    name = target:getMark("__heg_deputy")
  end
  return type(name) == "string" and name or nil
end

local function refreshFlag(self, holder)
  Flags.refresh(holder, self.name)
  Ci.refreshMark(holder.room, holder)
end

skill:addAcquireEffect(refreshFlag)
skill:addLoseEffect(refreshFlag)

local function drawCi(room, holder, target)
  local name = deputyName(target)
  if name == nil or Commander.isSoldier(name) then return end
  local allowed = room:getBanner("all_kingdoms") or {}
  local deputyKingdoms = availableKingdoms(room, name, allowed)
  if #deputyKingdoms == 0 then return end
  local candidates = {}
  for _, candidate in ipairs(room.general_pile or {}) do
    if not Versions.is_lord(candidate) and not Commander.isSoldier(candidate)
      and not table.contains(room.disabled_generals or {}, candidate) then
      local kingdoms = availableKingdoms(room, candidate, allowed)
      if table.find(kingdoms, function(k) return table.contains(deputyKingdoms, k) end) then
        table.insert(candidates, candidate)
      end
    end
  end
  if #candidates == 0 then return end
  local chosen = candidates[room:random(1, #candidates)]
  table.removeOne(room.general_pile, chosen)
  local list = Ci.cards(holder)
  list[#list + 1] = chosen
  Ci.save(room, holder, list)
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

-- 先于引擎的掩埋清标记。受赠者和已失去大旗的持有者同样有自己的“赐”。
skill:addEffect(fk.BuryVictim, {
  global = true,
  can_refresh = function(self, event, target, player)
    return target == player and #Ci.cards(player) > 0
  end,
  on_refresh = function(self, event, target, player)
    Discard.add(player.room, Ci.cards(player))
    Ci.save(player.room, player, {})
  end,
})

local function transferGroups(room, holder)
  local allowed = room:getBanner("all_kingdoms") or {}
  local groups = {}
  for _, name in ipairs(Ci.cards(holder)) do
    for _, kingdom in ipairs(availableKingdoms(room, name, allowed)) do
      groups[kingdom] = groups[kingdom] or {}
      table.insert(groups[kingdom], name)
    end
  end
  return groups
end

local function canGive(holder, source)
  return source ~= nil and source ~= holder and source.kingdom == "jin" and not source.dead
    and not source:isRemoved() and not holder.dead and not holder:isRemoved()
    and holder:hasSkill(skill.name) and holder:hasShownSkill(skill.name)
end

skill:addEffect(fk.Damage, {
  can_trigger = function(self, event, target, player, data)
    return canGive(player, target) and #Ci.cards(player) > 0
  end,
  on_cost = function(self, event, target, player)
    local groups = transferGroups(player.room, player)
    local choices = table.filter(Ban.kingdoms, function(k) return groups[k] ~= nil end)
    if #choices == 0 then return false end
    local kingdom = player.room:askToChoices(player, {
      choices = choices, min_num = 1, max_num = 1, cancelable = true,
      skill_name = skill.name, prompt = "#qiao__jin001_banner-transfer::" .. target.id,
    })[1]
    if kingdom == nil or not groups[kingdom] then return false end
    event:setCostData(self, kingdom)
    return true
  end,
  on_use = function(self, event, target, player)
    if not canGive(player, target) then return end
    local room = player.room
    local moved = transferGroups(room, player)[event:getCostData(self)]
    if not moved then return end
    local remaining = table.filter(Ci.cards(player), function(name)
      return not table.contains(moved, name)
    end)
    local received = Ci.cards(target)
    table.insertTable(received, moved)
    Ci.save(room, player, remaining)
    Ci.save(room, target, received)
  end,
})

skill:addEffect(fk.EventPhaseSkipping, {
  can_trigger = function(self, event, target, player, data)
    return target == player and data.skipped and not player.dead and player:hasSkill(skill.name)
      and #Ci.cards(player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local chosen = player.room:askToChoices(player, {
      -- 选一张后确认。保留阶段提示与取消按钮，也适用于只剩一枚赐时。
      choices = Ci.cards(player), min_num = 1, max_num = 1, cancelable = true,
      skill_name = skill.name, prompt = "#qiao__jin001_banner-prevent-skip:::" .. Util.PhaseStrMapper(data.phase),
    })[1]
    if not table.contains(Ci.cards(player), chosen) then return false end
    event:setCostData(self, chosen)
    return true
  end,
  on_use = function(self, event, target, player, data)
    if data.skipped and player:hasSkill(skill.name) and Ci.consume(player.room, player, event:getCostData(self)) then
      data.skipped = false
    end
  end,
})

-- 旗和消费都从面板展示。
Fk:addPostLoadFunc(function()
  Fk.skills[skill.name].visible = false
end)

Fk:loadTranslationTable {
  [skill.name] = "诸王敕封册",
  [":" .. skill.name] = "当一名角色的武将牌首次均明置后，或被晋势力角色杀死后，你可以随机将一张符合其副将牌面势力的剩余武将牌置为“赐”。"
    .. "\n（〖赐〗是一种国战标记：出牌阶段限一次，你可以消耗一枚〖赐〗，然后变更一张与此牌单独阴阳鱼数相同的武将牌（限一次），或根据此牌单独阴阳鱼数执行效果：≤3：本回合手牌上限+3。≥4：摸牌至四张。）"
    .. "\n其他晋势力角色造成伤害后，你可以将你一个势力的所有〖赐〗交给其。"
    .. "\n当你即将跳过一个阶段时，你可以移去你的一枚〖赐〗并防止之。",
  [CI_MARK] = "赐",
  ["qiao__ci_consume"] = "消耗一枚赐",
  ["#qiao__jin001_banner-invoke"] = "诸王敕封册：是否随机将一张符合条件的剩余武将牌置为“赐”",
  ["#qiao__jin001_banner-active"] = "诸王敕封册：消耗一枚赐",
  ["#qiao__jin001_banner-transfer"] = "诸王敕封册：你可以选择一个势力，将该势力的所有“赐”交给 %dest",
  ["#qiao__jin001_banner-prevent-skip"] = "诸王敕封册：你可以移去一枚“赐”，防止跳过%arg",
  ["#qiao__jin001_banner-branch"] = "诸王敕封册：选择资源效果或变更",
  [CHANGE] = "变更武将",
  ["qiao__jin001_banner-resource-maxcard"] = "本回合手牌上限+3",
  ["qiao__jin001_banner-resource-draw"] = "将手牌摸至四张",
  ["#qiao__jin001_banner-position"] = "诸王敕封册：选择变更位置（main 主将 / deputy 副将）",
}

return skill
