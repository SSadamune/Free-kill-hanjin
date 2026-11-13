-- HAN017 刘繇 · 逆拒
--
-- 锁定技。你每次拼点没赢（含平局）后，先摸一张牌，再令你本回合拼点牌点数
-- +3；累计增益保留，单次点数由拼点接口封顶 13，两者分别处理；增益只作用于
-- 之后进行/亮出的拼点，不回溯已经确定的拼点结果。
-- 该技能在刘繇作为发起者或他人拼点目标时都生效。
--
-- “没赢”通过 PindianResultConfirmed 的结果事实检测，但实际效果进入一次
-- 正规 SkillEffect（room:useSkill）：会正常明置技能来源并记录技能发动次数，
-- 暗将预亮不能绕过。点数 +3 的应用则是独立、房间级的延迟效果，不依赖
-- 当前是否仍有逆拒；失技/暗置/交换后已建立的本回合增益仍会生效。
local skill = fk.CreateSkill {
  name = "hanjin__skill_han017_2",
  tags = { Skill.Compulsory },
}

local BONUS = "hanjin__skill_han017_2-bonus-turn"
local BONUS_DELAY_NAME = "#hanjin_skill_han017_2_bonus_delay"

local bonus_delay

local function ensureBonusDelay(room)
  if room == nil then return end
  if bonus_delay == nil then bonus_delay = Fk.skills[BONUS_DELAY_NAME] end
  if bonus_delay == nil then
    local skel = fk.CreateSkill { name = BONUS_DELAY_NAME }
    skel:addEffect(fk.PindianCardsDisplayed, {
      global = true,
      can_refresh = function(self, event, target, player, data)
        if player == nil or player:getMark(BONUS) <= 0 then return false end
        return data.from == player or (data.results and data.results[player] ~= nil)
      end,
      on_refresh = function(self, event, target, player, data)
        local bonus = player:getMark(BONUS)
        if bonus <= 0 then return end
        player.room:changePindianNumber(data, player, bonus, skill.name)
      end,
    })
    bonus_delay = skel:createSkill()
    Fk.skills[BONUS_DELAY_NAME] = bonus_delay
  end
  if not room:hasSkill(BONUS_DELAY_NAME) then
    room:addSkill(bonus_delay)
  end
end

-- PindianResultConfirmed 的 target 为 nil；带 can_trigger 的 global 效果会
-- 覆盖 TriggerSkill 的基类 target 门槛，因此可以直接走正规 trigger/on_cost/
-- on_use，正常明置来源并记录技能发动。
skill:addEffect(fk.PindianResultConfirmed, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return player ~= nil and player:hasSkill(skill.name)
      and (data.from == player or data.to == player)
      and data.winner ~= player
      and not data.__hanjin_han017_2_loss_done
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    data.__hanjin_han017_2_loss_done = true
    local room = player.room
    ensureBonusDelay(room)
    -- 先摸一张，再累计本回合 +3；顺序不可交换。
    player:drawCards(1, skill.name)
    room:addPlayerMark(player, BONUS, 3)
  end,
})

skill:addAcquireEffect(function(self, player)
  ensureBonusDelay(player.room)
end)

Fk:loadTranslationTable {
  ["hanjin__skill_han017_2"] = "逆拒",
  [":hanjin__skill_han017_2"] = "锁定技，你拼点没赢后，你摸一张牌，令你本回合拼点牌点数+3。",
}

skill.hanjinImplemented = true

return skill
