-- JIN005 羊祜 · 柔克
--
-- 规则基线：docs/rules/generals/jin005-yanghu.md、docs/rules/general-principles.md
-- “易读描述的时机与然后”。
-- 每名同势力角色每回合真实使用的首张【杀】可改为冰【杀】；首张事实读取本回合
-- UseCard 历史，因此技能尚未取得/明置时发生的使用仍然保留。改牌通过
-- UseCardData:changeCard 完成，沿用本次使用与实体材料，不另起第二次使用。
-- 只有实际执行改牌后，才在该次用牌结束、确认未造成伤害时获得横置/重置机会。
-- 手牌上限加的是当前横置角色总数，与本次是否走到横置分支无关。
local StateToggle = require "packages.qiao.pkg.qiao_mode.rules.state_toggle"
local B = require "packages.qiao.pkg.qiao_generals.util.jin_basic"
local J = require "packages.qiao.pkg.qiao_generals.util.jin_chain"

local skill = fk.CreateSkill {
  name = "qiao__skill_jin005_1",
}
skill.qiaoImplemented = true
skill.qiaoCanPrelight = false

local CHANGED_KEY = "qiao_jin005_1_changed"
local FOLLOW_LISTENER = "#qiao__skill_jin005_1_follow"

local followListener

-- 当前横置角色数作为手牌上限修正。maxcards 状态技是房间级的，必须按持有者
-- 过滤，否则所有角色的手牌上限都会被加；hasSkill 是客户端也可用的公开判定。
skill:addEffect("maxcards", {
  correct_func = function(self, player)
    if player == nil or not player:hasSkill(skill.name) then return 0 end
    return J.chainedAliveCount(Fk:currentRoom())
  end,
})

--- 建立/复用“本次改牌”的后续监听器。它不依赖柔克是否仍在，因此技能在本次
--- 用牌结束前失去时，已经发生的改牌后续仍按实际规则处理。
---@param room Room
local function ensureFollowListener(room)
  if room == nil then return end
  if followListener == nil then followListener = Fk.skills[FOLLOW_LISTENER] end
  if followListener == nil then
    local skel = fk.CreateSkill { name = FOLLOW_LISTENER }
    skel:addEffect(fk.CardUseFinished, {
      global = true,
      is_delay_effect = true,
      can_trigger = function(self, event, target, player, data)
        if data == nil or player == nil or player.dead then return false end
        -- 只让实际改牌的来源获得后续；不检查 hasSkill。
        return type(data[CHANGED_KEY]) == "number"
          and player.id == data[CHANGED_KEY]
          and not J.dealtDamage(data)
      end,
      on_cost = function(self, event, target, player, data)
        local chosen = StateToggle.ask(player, {
          max_num = 2,
          skill_name = skill.name,
          prompt = "#qiao__skill_jin005_1-follow",
        })
        if #chosen == 0 then return false end
        event:setCostData(self, { tos = chosen })
        return true
      end,
      on_use = function(self, event, target, player, data)
        for _, to in ipairs(event:getCostData(self).tos) do
          StateToggle.chain(to)
        end
      end,
    })
    followListener = skel:createSkill()
    Fk.skills[FOLLOW_LISTENER] = followListener
  end
  if not room:hasSkill(FOLLOW_LISTENER) then room:addSkill(followListener) end
end

local function roukeOwner(user)
  local candidates = user.room:getPresentPlayers()
  user.room:sortByAction(candidates)
  return table.find(candidates, function(owner)
    return owner:hasShownSkill(skill.name) and B.sameKingdom(user, owner)
  end)
end

skill:addEffect(fk.PreCardUse, {
  anim_type = "offensive",
  -- 引擎将回调的 player 作为发动者，故由当前实际使用者进入触发流程。
  global = true,
  can_trigger = function(self, event, target, player, data)
    if target == nil or target ~= player or player.dead or player:isRemoved() then return false end
    if data == nil or data.card == nil or data.from ~= player then return false end
    if not J.isSlash(data.card) then return false end
    return J.isFirstSlashUseThisTurn(player) and roukeOwner(player) ~= nil
  end,
  on_cost = function(self, event, target, player, data)
    local owner = roukeOwner(player)
    if not owner or not player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_jin005_1-invoke",
    }) then return false end
    event:setCostData(self, { owner = owner.id })
    return true
  end,
  on_use = function(self, event, target, player, data)
    -- 即使属性相同也执行改牌，记录本次使用确实经由柔克。
    if not J.isSlash(data.card) then return end
    data:changeCard(J.ICE_SLASH, nil, nil, skill.name)
    if data.card.name == J.ICE_SLASH then
      -- 记录实际来源；后续监听器只让该来源获得本次改牌的“然后”。
      data[CHANGED_KEY] = event:getCostData(self).owner
      ensureFollowListener(player.room)
    end
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_jin005_1"] = "柔克",
  [":qiao__skill_jin005_1"] = "与你势力相同的角色每回合使用首张【杀】可以改为冰【杀】，然后若此牌未造成伤害，你可以令至多两名角色横置或重置。你的手牌上限+X（X为横置角色数）。",
  ["#qiao__skill_jin005_1-invoke"] = "柔克：是否将你本回合使用的首张【杀】改为冰【杀】",
  ["#qiao__skill_jin005_1-follow"] = "柔克：你可以选择至多两名角色，切换其横置状态",
}

return skill
