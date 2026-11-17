-- QUN010 张角 · 雷击
--
-- 规则基线：rules/standard-generals.md 群区 QUN010、群包审阅
-- docs/development/implementation/generals/qun-standard.md。
-- 「使用或打出【闪】」是两个不同的引擎入口，分别接 fk.CardUsing（使用，
-- 包括响应【杀】时使用【闪】）与 fk.CardResponding（纯打出），不以一个
-- 入口覆盖两者。结算由张角令一名其他角色判定：
--   * 黑桃：张角对其造成 2 点雷电伤害；
--   * 梅花：张角先回复 1 点体力，再对其造成 1 点雷电伤害。
-- 判定牌使用最终生效的结果，改判（含鬼道）后按新结果结算。
local skill = fk.CreateSkill {
  name = "qiao__skill_qun010_1",
}
skill.qiaoImplemented = true

-- 一次【闪】只询问一次：使用与响应是两条互斥的引擎入口（普通使用产生
-- UseCard 事件 → CardUsing；响应打出产生 RespondCard 事件 → CardResponding），
-- 单次出牌只会命中其中一个，两个入口共用同一套 askTarget，不会重复询问。
local function canTrigger(self, target, player, data)
  if not player:hasSkill(skill.name) then return false end
  if data.card == nil or data.card.trueName ~= "jink" then return false end
  if data.from ~= player then return false end
  return #player.room:getOtherPlayers(player, false) > 0
end

-- 回调签名固定为 (self, event, target, player, data)：target 是本事件的目标，
-- player 才是技能拥有者，不能把第三个参数当 player 使用。
local function askTarget(self, event, target, player)
  local room = player.room
  local targets = table.filter(room:getOtherPlayers(player, false), function(p)
    return not p.dead and not p:isRemoved()
  end)
  if #targets == 0 then return false end
  local chosen = room:askToChoosePlayers(player, {
    min_num = 1,
    max_num = 1,
    targets = targets,
    skill_name = skill.name,
    prompt = "#qiao__skill_qun010_1-target",
    cancelable = true,
  })
  local to = chosen and chosen[1]
  if to == nil or to.dead or to:isRemoved() then return false end
  event:setCostData(self, { to = to })
  return true
end

local function resolveJudge(self, event, target, player)
  local room = player.room
  local cost = event:getCostData(self) or {}
  local to = cost.to
  if to == nil or to.dead or to:isRemoved() or player.dead then return end

  local judge = { who = to, reason = skill.name }
  room:judge(judge)
  local card = judge.card
  if card == nil or card.suit == Card.NoSuit then return end

  if card.suit == Card.Spade then
    room:damage {
      from = player,
      to = to,
      damage = 2,
      damageType = fk.ThunderDamage,
      skillName = skill.name,
    }
  elseif card.suit == Card.Club then
    if not player.dead then
      room:recover {
        who = player,
        num = 1,
        recoverBy = player,
        skillName = skill.name,
      }
    end
    if not to.dead then
      room:damage {
        from = player,
        to = to,
        damage = 1,
        damageType = fk.ThunderDamage,
        skillName = skill.name,
      }
    end
  end
end

skill:addEffect(fk.CardUsing, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return canTrigger(self, target, player, data)
  end,
  on_cost = askTarget,
  on_use = resolveJudge,
})

skill:addEffect(fk.CardResponding, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return canTrigger(self, target, player, data)
  end,
  on_cost = askTarget,
  on_use = resolveJudge,
})

Fk:loadTranslationTable {
  ["qiao__skill_qun010_1"] = "雷击",
  [":qiao__skill_qun010_1"] = "当你使用或打出【闪】时，你可令一名其他角色判定，若为：黑桃，你对其造成2点雷电伤害；梅花，你回复1点体力，对其造成1点雷电伤害。",
  ["#qiao__skill_qun010_1-target"] = "雷击：令一名其他角色判定",
}

return skill
