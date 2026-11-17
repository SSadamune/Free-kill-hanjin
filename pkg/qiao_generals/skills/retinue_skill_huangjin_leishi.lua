-- QUN010 张角 · 黄巾雷使（翼从）
--
-- 每回合首次有角色不因使用手牌而造成伤害时，你可以弃置一张手牌并判定，
-- 若为：黑色，此伤害+1；红色，其获得此判定牌。
--
-- 机会事实由模式级常驻记录器 `qiao__qun_damage_history` 在房间开局安装，
-- 记录“本回合第一个符合描述的伤害时机”的 fk.DamageCaused TriggerEvent id。
-- 本技能只在该时机开放一次选择；未发动、没有手牌或放弃均已消耗本回合机会，
-- 不会因之后取得翼从而重开。事件是否为“不因使用手牌”由记录器按真实
-- DamageData（chain/parent）与 UseCardData:isUsingHandcard 判定，本技能不重复
-- 判断，也不读取客户端无法取得的私有事件。
local skill = fk.CreateSkill {
  name = "qiao__retinue_skill_huangjin_leishi",
}
skill.qiaoImplemented = true

local J = require "packages.qiao.pkg.qiao_generals.util.qun_judgement"
local R = require "packages.qiao.pkg.qiao_generals.util.retinue_instances"

local function triggerEach(self, event, target, player, data)
  if #R.instancesForSkill(player, skill.name) == 0 then
    return self:doCost(event, target, player, data)
  end
  return R.triggerEach(self, event, target, player, data)
end

-- 与 pkg/qiao_mode/skills/qun_damage_history.lua 的 FIRST_DAMAGE_TAG 保持一致。
local FIRST_DAMAGE_TAG = "qiao_qun_damage_history_first"

skill:addEffect(fk.DamageCaused, {
  global = true,
  anim_type = "offensive",
  on_trigger = triggerEach,
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(skill.name) and not player.dead
      and data ~= nil and data.from ~= nil
      and (data.damage or 0) > 0
      and event ~= nil and player.room:getTag(FIRST_DAMAGE_TAG) == event.id
      and #player:getCardIds("h") > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__retinue_skill_huangjin_leishi-invoke:" .. data.from.id,
    }) then
      return false
    end
    local cards = room:askToDiscard(player, {
      min_num = 1,
      max_num = 1,
      include_equip = false,
      skill_name = skill.name,
      prompt = "#qiao__retinue_skill_huangjin_leishi-discard",
      cancelable = true,
    })
    if cards == nil or #cards < 1 then return false end
    event:setCostData(self, { cards = cards })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local card = J.judge(room, player, skill.name)
    if card == nil then return end
    if card.color == Card.Black then
      if (data.damage or 0) > 0 then
        data:changeDamage(1)
      end
    elseif card.color == Card.Red then
      -- 红色：造成伤害的角色获得此判定牌；无来源时无人获得。
      J.obtainJudgeCard(room, data.from, card, skill.name)
    end
  end,
})

Fk:loadTranslationTable {
  ["qiao__retinue_skill_huangjin_leishi"] = "黄巾雷使",
  [":qiao__retinue_skill_huangjin_leishi"] = "每回合首次有角色不因使用手牌而造成伤害时，你可以弃置一张手牌并判定，若为：黑色，此伤害+1；红色，其获得此判定牌。",
  ["#qiao__retinue_skill_huangjin_leishi-invoke"] = "黄巾雷使：你可以弃置一张手牌并判定（伤害来源 %src）",
  ["#qiao__retinue_skill_huangjin_leishi-discard"] = "黄巾雷使：弃置一张手牌",
}

return skill
