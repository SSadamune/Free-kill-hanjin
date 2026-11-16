-- JIN014 文鸯 · 翼从「文虎」（限一）
--
-- 规则基线：rules/generals/jin014-wenyang.md、rules/standard-generals.md。
-- 出牌阶段限一次：弃置自己手牌/装备/判定三个区域中任意个非空且可全弃区域的
-- 所有牌，然后视为使用一张【决斗】，目标上限 X 为实际完整弃置的区域数。
-- 区域不能以空区充数，也不把装备栏分别算区域；只弃部分牌不构成该区域。
-- 至少实际弃置一个区域。决斗的其他目标条件沿用原牌，不因本技能放宽距离。
-- 限一取得与统领能力次数由统领公共规则处理，本技能不另建限一逻辑。
local C = require "packages.hanjin.pkg.hanjin_mode.rules.card_use_targets"

local skill = fk.CreateSkill {
  name = "hanjin__retinue_skill_wenhu",
  max_phase_use_time = 1,
}
skill.hanjinImplemented = true

local DUEL = "hanjin__duel"
local ZONES = { "h", "e", "j" }
local OPT_HAND = "#hanjin__retinue_skill_wenhu-hand"
local OPT_EQUIP = "#hanjin__retinue_skill_wenhu-equip"
local OPT_JUDGE = "#hanjin__retinue_skill_wenhu-judge"
local ZONE_LABEL = { h = OPT_HAND, e = OPT_EQUIP, j = OPT_JUDGE }

--- 该区域非空且其中所有牌都可弃置。
---@param player ServerPlayer | ClientPlayer
---@param zone string
---@return boolean
local function canDiscardWholeZone(player, zone)
  local ids = player:getCardIds(zone)
  if #ids == 0 then return false end
  for _, id in ipairs(ids) do
    if player:prohibitDiscard(id) then return false end
  end
  return true
end

---@param player ServerPlayer | ClientPlayer
---@return string[]
local function eligibleZones(player)
  return table.filter(ZONES, function(zone)
    return canDiscardWholeZone(player, zone)
  end)
end

--- 至少存在一名决斗可指定的其他角色。
---@param player ServerPlayer | ClientPlayer
---@return boolean
local function hasDuelTarget(player)
  local card = Fk:cloneCard(DUEL)
  local ok, targets = pcall(function()
    return card:getAvailableTargets(player)
  end)
  return ok and type(targets) == "table" and #targets > 0
end

skill:addEffect("active", {
  anim_type = "offensive",
  prompt = "#hanjin__retinue_skill_wenhu-prompt",
  max_phase_use_time = 1,
  card_num = 0,
  target_num = 0,
  card_filter = Util.FalseFunc,
  can_use = function(self, player)
    return self:withinTimesLimit(player, Player.HistoryPhase)
      and #eligibleZones(player) > 0
      and hasDuelTarget(player)
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    if player == nil or player.dead then return end
    if not player:hasSkill(skill.name) then return end

    local zones = eligibleZones(player)
    if #zones == 0 then return end
    local choices = table.map(zones, function(zone) return ZONE_LABEL[zone] end)
    -- 单选时直接返回；多选时由玩家勾选任意个区域。
    local picked = room:askToChoices(player, {
      choices = choices,
      min_num = 1,
      max_num = #choices,
      skill_name = skill.name,
      prompt = "#hanjin__retinue_skill_wenhu-zones",
      cancelable = false,
    })
    if picked == nil or #picked == 0 then return end

    -- 将界面选项还原为区域，并复核仍非空、仍可全弃且不重复。
    local selected, seen = {}, {}
    for _, label in ipairs(picked) do
      local zone = table.find(zones, function(z) return ZONE_LABEL[z] == label end)
      if zone ~= nil and not seen[zone] and canDiscardWholeZone(player, zone) then
        seen[zone] = true
        table.insert(selected, zone)
      end
    end
    if #selected == 0 then return end

    -- 选择后先固定所有选中区的牌，再用一次弃牌操作同时弃置；不能在逐区弃置
    -- 之间重新读取区域，否则本次弃牌触发的新牌会被一并收走。
    local selectedIds, allIds = {}, {}
    for _, zone in ipairs(selected) do
      local ids = table.simpleClone(player:getCardIds(zone))
      selectedIds[zone] = ids
      table.insertTable(allIds, ids)
    end
    if #allIds == 0 then return end

    room:throwCard(allIds, skill.name, player, player)
    if player.dead then return end

    -- X 按“真弃的完整选中区”计算：只检查选择时固定的原始牌是否仍留在原区域，
    -- 不因弃牌触发技后来摸到的新牌而改变区域是否完整的判断。
    local x = 0
    for _, zone in ipairs(selected) do
      local original = selectedIds[zone] or {}
      local now = player:getCardIds(zone)
      local complete = #original > 0
      for _, id in ipairs(original) do
        if table.contains(now, id) then
          complete = false
          break
        end
      end
      if complete then x = x + 1 end
    end
    if x < 1 then return end

    -- 视为使用【决斗】：保留原牌目标条件，只把目标上限改为 X。
    C.askToUseVirtualCard(room, player, {
      name = DUEL,
      skill_name = skill.name,
      prompt = "#hanjin__retinue_skill_wenhu-duel::" .. x,
      cancelable = false,
      policy = C.default {
        names = { DUEL },
        min_targets = 1,
        max_targets = x,
      },
    })
  end,
})

Fk:loadTranslationTable {
  ["hanjin__retinue_skill_wenhu"] = "文虎",
  [":hanjin__retinue_skill_wenhu"] = "出牌阶段限一次，你可以弃置任意个区域的所有牌，然后视为使用目标上限为X的【决斗】（X为你以此法弃置牌的区域数）。",
  ["#hanjin__retinue_skill_wenhu-prompt"] = "文虎：弃置任意个区域的所有牌，然后视为使用【决斗】",
  ["#hanjin__retinue_skill_wenhu-zones"] = "文虎：选择要完整弃置的区域（至少一个）",
  ["#hanjin__retinue_skill_wenhu-duel"] = "文虎：选择至多 %arg 名【决斗】目标",
  [OPT_HAND] = "手牌区",
  [OPT_EQUIP] = "装备区",
  [OPT_JUDGE] = "判定区",
}

return skill
