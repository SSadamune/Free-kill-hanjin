-- WEI004 张辽 · 突袭
--
-- 摸牌阶段，你可以少摸任意张牌并获得等量名其他角色各一张手牌；然后你可以
-- 展示获得的牌，本回合这些牌只能当【杀】使用或打出。
-- 少摸数与实际选择的其他角色数相同。展示后以公共 only-as 机制的 tuxi 来源
-- 限定这批实体牌（cards 集合 / duration = turn）：直接使用/打出被禁止，仅开放
-- 【杀】的使用与打出用途；其他来源的转化权限不因此失效。来源不绑定技能，
-- 失去突袭不会撤销本回合已产生的限制。
local OnlyAs = require "packages.hanjin.pkg.hanjin_mode.rules.only_as"

local skill = fk.CreateSkill {
  name = "hanjin__skill_wei004_1",
}
skill.hanjinImplemented = true

local function handTargets(player)
  local room = player.room
  return table.filter(room:getOtherPlayers(player, false), function(p)
    return p:isAlive() and not p:isRemoved() and not p:isKongcheng()
  end)
end

skill:addEffect(fk.DrawNCards, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and data.n > 0 and #handTargets(player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei004_1-invoke:" .. data.n,
    }) then
      return false
    end
    local targets = handTargets(player)
    local max = math.min(data.n, #targets)
    if max < 1 then return false end
    local tos = room:askToChoosePlayers(player, {
      targets = targets,
      min_num = 1,
      max_num = max,
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei004_1-choose:::" .. max,
      cancelable = true,
    })
    if #tos == 0 then return false end
    room:sortByAction(tos)
    event:setCostData(self, { tos = tos })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local tos = event:getCostData(self).tos
    local obtained = {}
    for _, to in ipairs(tos) do
      if player.dead then break end
      if to.dead or to:isRemoved() or to:isKongcheng() then
        -- 目标中途无手牌时不再获得；少摸数仍按已选择的目标数结算。
      else
        local cid = room:askToChooseCard(player, {
          target = to,
          flag = "h",
          skill_name = skill.name,
          prompt = "#hanjin__skill_wei004_1-take:" .. to.id,
        })
        if cid ~= nil and cid ~= -1 and table.contains(to:getCardIds(Player.Hand), cid) then
          room:obtainCard(player, cid, false, fk.ReasonPrey, player, skill.name)
          table.insert(obtained, cid)
        end
      end
    end
    data.n = math.max(0, data.n - #tos)
    if #obtained == 0 or player.dead then return end
    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei004_1-reveal",
    }) then
      return
    end
    room:showCards(obtained, player)
    OnlyAs.addSource(room, {
      def = "tuxi",
      holder = player,
      cards = obtained,
      duration = "turn",
      reason = skill.name,
    })
  end,
})

Fk:loadTranslationTable {
  ["#hanjin__skill_wei004_1-invoke"] = "突袭：你可以少摸至多 %arg 张牌并获得等量名其他角色各一张手牌",
  ["#hanjin__skill_wei004_1-choose"] = "突袭：选择至多 %arg 名其他角色",
  ["#hanjin__skill_wei004_1-take"] = "突袭：获得 %src 的一张手牌",
  ["#hanjin__skill_wei004_1-reveal"] = "突袭：你可以展示获得的牌，本回合这些牌只能当【杀】使用或打出",
}

return skill
