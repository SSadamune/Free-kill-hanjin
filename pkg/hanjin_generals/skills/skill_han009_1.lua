-- HAN009 伏完 · 谋溃
--
-- 当你使用【杀】指定目标后，你可以选择一个目标并选择一至两项：
--   1. 摸一张牌；2. 弃置其一张牌。
-- 若选择了两项，当其抵消此【杀】时，其弃置你一张牌。
--
-- 一张【杀】只发动一次谋溃：第一次 TargetSpecified 时在本次 UseCardData 上
-- 记录“已发动”和目标，后续目标事件不再询问。双选后的反弃绑定该 use 与
-- 被选中的目标；其他目标抵消不触发。反弃由房间级延迟监听处理，不依赖
-- 伏完是否仍有谋溃。
local skill = fk.CreateSkill {
  name = "hanjin__skill_han009_1",
}

local USED = "hanjin_skill_han009_1_used"
local COUNTER = "hanjin_skill_han009_1_counter"
local OPTION_DRAW = "#hanjin__skill_han009_1-draw"
local OPTION_DISCARD = "#hanjin__skill_han009_1-discard"
local DELAY_SKILL_NAME = "#hanjin_skill_han009_1_counter_delay"

local delay_skill

local function ensureDelaySkill(room)
  if room == nil then return end
  if delay_skill == nil then delay_skill = Fk.skills[DELAY_SKILL_NAME] end
  if delay_skill == nil then
    local skel = fk.CreateSkill { name = DELAY_SKILL_NAME }
    skel:addEffect(fk.CardEffectCancelledOut, {
      global = true,
      is_delay_effect = true,
      can_refresh = function(self, event, target, player, data)
        local use = data and data.use
        local marker = use and use[COUNTER]
        return marker ~= nil and marker.two == true and not marker.done
          and data.to ~= nil and data.to.id == marker.target
      end,
      on_refresh = function(self, event, target, player, data)
        local use = data.use
        local marker = use[COUNTER]
        marker.done = true
        local owner = use.from
        local canceller = data.to
        if owner == nil or canceller == nil or owner.dead or canceller.dead then return end
        local ids = owner:getCardIds("he")
        if #ids == 0 then return end

        -- “其弃置你一张牌”：由抵消此【杀】的角色选择并弃置伏完的一张牌。
        local chosen = owner.room:askToChooseCard(canceller, {
          target = owner,
          flag = "he",
          skill_name = skill.name,
          prompt = "#hanjin__skill_han009_1-counter",
        })
        local chosenIds = Card:getIdList(chosen)
        if #chosenIds ~= 1 or not table.contains(owner:getCardIds("he"), chosenIds[1]) then return end
        owner.room:throwCard(chosenIds, skill.name, owner, canceller)
      end,
    })
    delay_skill = skel:createSkill()
    Fk.skills[DELAY_SKILL_NAME] = delay_skill
  end
  if not room:hasSkill(DELAY_SKILL_NAME) then
    room:addSkill(delay_skill)
  end
end

skill:addEffect(fk.TargetSpecified, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    if target ~= player or not player:hasSkill(skill.name) then return false end
    if data.card == nil or data.card.trueName ~= "slash" or data.use == nil then return false end
    local use = data.use
    if use[USED] then return false end
    return #(use.tos or {}) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_han009_1-invoke",
    }) then
      return false
    end

    local use = data.use
    local targets = table.filter(use.tos or {}, function(p)
      return p ~= nil and p:isAlive() and not p:isRemoved()
    end)
    if #targets == 0 then return false end
    local chosen = room:askToChoosePlayers(player, {
      min_num = 1,
      max_num = 1,
      targets = targets,
      skill_name = skill.name,
      prompt = "#hanjin__skill_han009_1-target",
      cancelable = false,
    })
    local to = chosen and chosen[1]
    if to == nil or to.dead or to:isRemoved() then return false end

    local options = { OPTION_DRAW }
    if #to:getCardIds("he") > 0 then table.insert(options, OPTION_DISCARD) end
    local picked = room:askToChoices(player, {
      choices = options,
      min_num = 1,
      max_num = #options,
      skill_name = skill.name,
      prompt = "#hanjin__skill_han009_1-options",
      cancelable = false,
    })
    if picked == nil or #picked == 0 then return false end

    -- extra_data 会在目标事件结束时被 AimData 的旧值覆盖，故把本次发动
    -- 与反弃绑定记录挂在 UseCardData 自身字段上。
    use[USED] = true
    use[COUNTER] = {
      target = to.id,
      two = table.contains(picked, OPTION_DRAW) and table.contains(picked, OPTION_DISCARD),
      done = false,
    }
    event:setCostData(self, {
      to = to,
      draw = table.contains(picked, OPTION_DRAW),
      discard = table.contains(picked, OPTION_DISCARD),
      two = use[COUNTER].two,
    })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    ensureDelaySkill(room)
    local cost = event:getCostData(self) or {}
    local to = cost.to
    if to == nil or to.dead or to:isRemoved() then return end

    -- 按选项顺序：先摸一张，再弃置目标一张牌。
    if cost.draw then
      player:drawCards(1, skill.name)
    end
    if cost.discard and to:isAlive() and not to:isRemoved() then
      local ids = to:getCardIds("he")
      if #ids > 0 then
        local chosen = room:askToChooseCard(player, {
          target = to,
          flag = "he",
          skill_name = skill.name,
          prompt = "#hanjin__skill_han009_1-discard",
        })
        local chosenIds = Card:getIdList(chosen)
        if #chosenIds == 1 and table.contains(to:getCardIds("he"), chosenIds[1]) then
          room:throwCard(chosenIds, skill.name, to, player)
        end
      end
    end
  end,
})

skill:addAcquireEffect(function(self, player)
  ensureDelaySkill(player.room)
end)

Fk:loadTranslationTable {
  ["hanjin__skill_han009_1"] = "谋溃",
  [":hanjin__skill_han009_1"] = "当你使用【杀】指定目标后，你可以选择一个目标并选择一至两项：1.摸一张牌；2.弃置其一张牌。若你选择了两项，当其抵消此【杀】时，其弃置你一张牌。",
  ["#hanjin__skill_han009_1-invoke"] = "谋溃：选择此【杀】的一个目标并选择一至两项",
  ["#hanjin__skill_han009_1-target"] = "谋溃：选择此【杀】的一个目标",
  ["#hanjin__skill_han009_1-options"] = "谋溃：选择一至两项",
  ["#hanjin__skill_han009_1-discard"] = "谋溃：弃置其一张牌",
  ["#hanjin__skill_han009_1-counter"] = "谋溃：其抵消了此【杀】，请弃置伏完一张牌",
  [OPTION_DRAW] = "摸一张牌",
  [OPTION_DISCARD] = "弃置其一张牌",
}

skill.hanjinImplemented = true

return skill
