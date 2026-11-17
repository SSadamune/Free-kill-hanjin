-- JIN017 王浑 · 遄征
-- 限定技：出牌阶段实际移除副将武将牌，永久获得“献捷”；本回合杀死角色的
-- 奖惩由独立房间规则改为摸3，不依赖遄征是否仍被持有。
local H = require "packages.hegemony.util"
local Commander = require "packages.qiao.pkg.qiao_mode.rules.commander_retinue"

local skill = fk.CreateSkill {
  name = "qiao__skill_jin017_2",
  tags = { Skill.Limited },
}
skill.qiaoImplemented = true

local XIANJIE = "qiao__skill_jin017_3"
local CRUISE_MARK = "qiao_jin017_2_cruise"
local CRUISE_RULE = "#qiao_jin017_cruise"
local REMOVED_TAG = "qiao_jin017_2_removed"

local function removableDeputy(player)
  local name = player.deputyGeneral
  if name == "anjiang" then name = player:getMark("__heg_deputy") end
  return type(name) == "string" and name ~= "" and name ~= "anjiang"
    and Fk.generals[name] ~= nil and not Commander.isSoldier(name)
end

local function ensureCruiseRule(room)
  local rule = Fk.skills[CRUISE_RULE]
  if rule ~= nil and not room:hasSkill(CRUISE_RULE) then room:addSkill(rule) end
end

local function grantXianjie(player)
  if not player:hasSkill(XIANJIE) then
    player.room:handleAddLoseSkills(player, XIANJIE, nil, false, true)
  end
end

-- 用真实 GeneralRemoved 事件确认副将武将牌确实被移除；不用公开 anjiang 比较。
skill:addEffect(H.GeneralRemoved, {
  global = true,
  priority = 10,
  can_refresh = function(self, event, target, player, data)
    return target == player and data ~= nil and data.isDeputy == true
  end,
  on_refresh = function(self, event, target, player, data)
    player.room:setTag(REMOVED_TAG, { who = player.id, orig = data.origName })
  end,
})

skill:addEffect("active", {
  prompt = "#qiao__skill_jin017_2-prompt",
  target_num = 0,
  card_num = 0,
  max_game_use_time = 1,
  can_use = function(self, player)
    return player.phase == Player.Play and not player.dead and removableDeputy(player)
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    if player == nil or player.dead or not removableDeputy(player) then return end
    room:setTag(REMOVED_TAG, nil)
    H.removeGeneral(player, true)
    local removed = room:getTag(REMOVED_TAG)
    room:setTag(REMOVED_TAG, nil)
    if removed == nil or removed.who ~= player.id or player.dead then return end

    ensureCruiseRule(room)
    grantXianjie(player)
    room:setPlayerMark(player, CRUISE_MARK, 1)
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_jin017_2"] = "遄征",
  ["#qiao__skill_jin017_2-prompt"] = "遄征：移除副将，获得“献捷”，本回合杀死角色改为摸三张牌",
}

return skill
