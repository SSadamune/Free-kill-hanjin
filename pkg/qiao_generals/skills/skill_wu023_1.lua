-- WU023 陈武&董袭 · 奋命
--
-- 出牌阶段两个选项各限一次：1.令至多X名角色横置（X为已损失体力且至少1），
-- 然后自己横置；2.若自己横置，弃置所有横置角色各一张牌。横置走 setChainState，
-- 不做翻面；第二项先固定“所有横置角色”集合，再依次执行可弃置部分。
local Selection = require "packages.qiao.pkg.qiao_mode.rules.trigger_selection"

local skill = fk.CreateSkill {
  name = "qiao__skill_wu023_1",
}
skill.qiaoImplemented = true

local OPT_CHAIN = "qiao__skill_wu023_1-chain"
local OPT_DISCARD = "qiao__skill_wu023_1-discard-all"
local USED_CHAIN = "qiao__skill_wu023_1-chain-phase"
local USED_DISCARD = "qiao__skill_wu023_1-discard-phase"

---@param player ServerPlayer
---@return boolean
local function canChain(player)
  return player:getMark(USED_CHAIN) == 0
end

--- 客户端只需要公开状态：已限次与是否横置；不在候选阶段读取其他角色手牌。
---@param player ServerPlayer | ClientPlayer
---@return boolean
local function canDiscardAll(player)
  return player:getMark(USED_DISCARD) == 0 and player.chained
end

skill:addEffect("active", {
  anim_type = "control",
  prompt = "#qiao__skill_wu023_1-prompt",
  card_num = 0,
  target_num = 0,
  card_filter = Util.FalseFunc,
  interaction = Selection.optionButtons(skill, function(player)
    local choices = {}
    if canChain(player) then table.insert(choices, OPT_CHAIN) end
    if canDiscardAll(player) then table.insert(choices, OPT_DISCARD) end
    return choices, { OPT_CHAIN, OPT_DISCARD }
  end),
  can_use = function(self, player)
    return not player.dead and (canChain(player) or canDiscardAll(player))
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    if player == nil or player.dead then return end

    local targets = room:getPresentPlayers()
    local max = math.min(math.max(1, player:getLostHp()), #targets)
    local choice = effect.interaction_data
    if choice == OPT_CHAIN then
      if not canChain(player) or max == 0 then return end
    elseif choice ~= OPT_DISCARD or not canDiscardAll(player) then
      return
    end

    if choice == OPT_CHAIN then
      room:setPlayerMark(player, USED_CHAIN, 1)
      local chosen = room:askToChoosePlayers(player, {
        min_num = 1,
        max_num = max,
        targets = targets,
        skill_name = skill.name,
        prompt = "#qiao__skill_wu023_1-target:::" .. max,
        cancelable = false,
      })
      for _, to in ipairs(chosen or {}) do
        if to:isAlive() and not to:isRemoved() then to:setChainState(true) end
      end
      if not player.dead and player:isAlive() then player:setChainState(true) end
    else
      room:setPlayerMark(player, USED_DISCARD, 1)
      local targets = table.filter(room:getPresentPlayers(), function(p)
        return p.chained and p:isAlive() and not p:isRemoved()
      end)
      for _, to in ipairs(targets) do
        if to:isAlive() and not to:isRemoved() then
          local ids = table.filter(to:getCardIds("he"), function(id) return not to:prohibitDiscard(id) end)
          if #ids > 0 then
            if to == player then
              room:askToDiscard(player, {
                min_num = 1, max_num = 1, include_equip = true, cancelable = false,
                skill_name = skill.name,
                prompt = "#qiao__skill_wu023_1-discard-self",
              })
            else
              local id = room:askToChooseCard(player, {
                target = to,
                flag = "he",
                skill_name = skill.name,
                prompt = "#qiao__skill_wu023_1-discard::" .. to.id .. ":" .. skill.name,
              })
              if id ~= nil and id ~= -1 and table.contains(ids, id) then
                room:throwCard({ id }, skill.name, to, player)
              end
            end
          end
        end
      end
    end
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_wu023_1"] = "奋命",
  [":qiao__skill_wu023_1"] = "出牌阶段各限一次，你可以：1.令至多X名角色横置（X为你已损失的体力值，至少为1），然后你横置；2.若你横置，弃置所有横置的角色各一张牌。",
  ["#qiao__skill_wu023_1-prompt"] = "奋命：横置角色，或弃置所有横置角色各一张牌",
  ["#qiao__skill_wu023_1-target"] = "奋命：选择至多 %arg 名角色横置（可选自己）",
  ["#qiao__skill_wu023_1-discard"] = "奋命：选择 %dest 的一张牌弃置",
  ["#qiao__skill_wu023_1-discard-self"] = "奋命：弃置自己的一张手牌或装备牌",
  [OPT_CHAIN] = "横置角色，再横置自己",
  [OPT_DISCARD] = "弃置所有横置角色各一张牌",
}

return skill
