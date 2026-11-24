-- EM(WEI001) 曹操 · 霸者求贤状
-- 魏势力角色准备阶段：弃一张牌并实际暗置其一张可暗置的武将牌，按该牌牌面
-- 体力 4/3 获得一项场上没有的已实装技能，直到其下回合开始。
local W = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wei"
local Versions = require "packages.qiao.pkg.qiao_mode.rules.general_versions"
local Flags = require "packages.qiao.pkg.qiao_mode.rules.lord_flag_display"
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
local CardSkills = require "packages.qiao.pkg.qiao_mode.rules.general_card_skills"
local Selection = require "packages.qiao.pkg.qiao_mode.rules.trigger_selection"

local skill = fk.CreateSkill {
  name = W.BANNER,
}
skill.qiaoImplemented = true

skill:addAcquireEffect(function(self, player) Flags.refresh(player, self.name) end)
skill:addLoseEffect(function(self, player) Flags.refresh(player, self.name) end)

local HIGH = {
  "qiao__skill_wei004_1", -- 突袭
  "qiao__skill_wei016_1", -- 骁果
  "qiao__skill_wei024_1", -- 常令
  "qiao__skill_wei009_1", -- 巧变
  "qiao__skill_wei010_1", -- 断粮
}
local LOW = {
  "qiao__skill_wei013_1", -- 驱虎
  "qiao__skill_wei020_1", -- 奇策
  "qiao__skill_qun007_1", -- 完杀
  "qiao__skill_wei044_1", -- 胆戾
  "qiao__skill_wei006_2", -- 遗计
}

local function implemented(id)
  local skel = Fk.skill_skels[id] or Fk.skills[id]
  return skel ~= nil and skel.qiaoImplemented == true
end

-- 供实现/测试核对十项授技清单；实际候选仍按牌面分组与场上公开技能过滤。
skill.qiaoPools = { high = HIGH, low = LOW }

-- 预检只扣除将被暗置的那张牌提供的来源，保留另一张明将和独立授技。
local function remainsShown(room, player, id, isDeputy)
  local hiding = Exchange.publicGeneral(player, isDeputy)
  if not Exchange.cardProvidesSkill(room, hiding, id) then return true end
  local other = Exchange.publicGeneral(player, not isDeputy)
  if Exchange.cardProvidesSkill(room, other, id) then return true end
  local skill = Fk.skills[id]
  for source, list in pairs(player.derivative_skills) do
    if source ~= Fk.skills[CardSkills.SOURCE] and table.contains(list, skill) then return true end
  end
  -- 后天附将的来源即将消失，但角色也可能独立持有此技。
  return not table.contains(Fk.generals[hiding]:getSkillNameList(true), id)
    and table.contains(player.player_skills, skill)
end

local function onField(room, id, hidingPlayer, isDeputy)
  for _, p in ipairs(room:getPresentPlayers()) do
    if p:hasShownSkill(id, true) and (p ~= hidingPlayer or remainsShown(room, p, id, isDeputy)) then
      return true
    end
  end
  return false
end

local function pool(room, generalName, hidingPlayer, isDeputy)
  local general = Fk.generals[generalName]
  if general == nil then return {} end
  local base = (general.maxHp or 0) >= 4 and HIGH or LOW
  return table.filter(base, function(id)
    return implemented(id) and not onField(room, id, hidingPlayer, isDeputy)
  end)
end

local function publicName(target, isDeputy)
  local name = isDeputy and target.deputyGeneral or target.general
  return type(name) == "string" and name or nil
end

--- 真正可暗置且对应技能池非空的位置。君主牌不能暗置，士兵不算武将牌。
local function hideCandidates(room, target)
  local result = {}
  for _, isDeputy in ipairs({ false, true }) do
    local name = publicName(target, isDeputy)
    if name ~= nil and name ~= "anjiang" and name ~= "" and not Versions.is_lord(name)
      and not Exchange.isSoldier(name) then
      local choices = pool(room, name, target, isDeputy)
      if #choices > 0 then
        result[#result + 1] = { isDeputy = isDeputy, general = name }
      end
    end
  end
  return result
end

local function chooseCandidate(room, target, list)
  local choices = table.map(list, function(candidate) return candidate.isDeputy and "d" or "m" end)
  local choice = Selection.askOption(room, target, {
    choices = choices,
    all_choices = { "m", "d" },
    skill_name = skill.name,
    prompt = "#qiao__em_wei001_banner-position",
  })
  for _, candidate in ipairs(list) do
    if (choice == "m" and not candidate.isDeputy) or (choice == "d" and candidate.isDeputy) then
      return candidate
    end
  end
  return nil
end

skill:addEffect(fk.EventPhaseStart, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if target.dead or target.phase ~= Player.Start then return false end
    if target.kingdom ~= "wei" or target:isRemoved() then return false end
    if W.lord(target.room) == nil then return false end
    if #target:getCardIds("he") == 0 then return false end
    return #hideCandidates(target.room, target) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = target.room
    local list = hideCandidates(room, target)
    if #list == 0 then return false end
    local candidate = chooseCandidate(room, target, list)
    if candidate == nil then return false end
    local cards = room:askToDiscard(target, {
      min_num = 1, max_num = 1, include_equip = true,
      skill_name = skill.name, prompt = "#qiao__em_wei001_banner-ask", cancelable = true,
    })
    if cards == nil or #cards == 0 then return false end
    event:setCostData(self, candidate)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = target.room
    local candidate = event:getCostData(self)
    if candidate == nil or target.dead or W.lord(room) == nil
      or publicName(target, candidate.isDeputy) ~= candidate.general then return end
    -- 只暗置预先选定的位置；不交给公共入口再选一次。
    room:setPlayerMark(target,
      candidate.isDeputy and "__heg_deputy" or "__heg_general", candidate.general)
    target:hideGeneral(candidate.isDeputy)
    local hidden = publicName(target, candidate.isDeputy)
    if hidden ~= "anjiang" then return end
    local choices = pool(room, candidate.general)
    if #choices == 0 then return end
    local chosen = choices[1]
    if #choices > 1 then
      -- 只有授技选项带 detailed，按技能 ID 显示正式说明；暗置位置选择仍是 m/d。
      chosen = room:askToChoice(target, {
        choices = choices,
        skill_name = skill.name,
        prompt = "#qiao__em_wei001_banner-choice",
        cancelable = false,
        detailed = true,
      })
    end
    if chosen == nil then return end
    W.addTempSkill(room, target, chosen)
    W.bind(room, target, candidate.isDeputy, candidate.general)
  end,
})

Fk:loadTranslationTable {
  [W.BANNER] = "霸者求贤状",
  [":" .. W.BANNER] = "魏势力角色的准备阶段，其可以弃置一张牌并暗置一张武将牌，直到其下回合开始，其不能明置、移除、交换或变更此武将牌，且其根据此武将牌的单独阴阳鱼数获得以下一项场上没有的技能："
    .. "\n≥4：“突袭”、“骁果”、“常令”、“巧变”、“断粮”；\n≤3：“驱虎”、“奇策”、“完杀”、“胆戾”、“遗计”。",
  ["#qiao__em_wei001_banner-ask"] = "霸者求贤状：弃置一张牌并暗置所选武将牌",
  ["#qiao__em_wei001_banner-position"] = "霸者求贤状：选择要暗置的武将牌（m 主将 / d 副将）",
  ["#qiao__em_wei001_banner-choice"] = "霸者求贤状：选择获得一项场上没有的技能",
}

return skill
