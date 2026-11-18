-- JIN023 马隆 · 锋械
-- 出牌阶段限一次：两名角色各一张装备先进入处理区，再分别进入对方手牌区；
-- 若其中一名为自己，随后对另一名或其队列视为使用【杀】。
local H = require "packages.hegemony.util"
local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"

local skill = fk.CreateSkill {
  name = "qiao__skill_jin023_1",
}
skill.qiaoImplemented = true

local SLASH = "qiao__slash"

local function equipIds(player)
  return player:getCardIds("e")
end

local function hasTwoEquipped(room, player)
  local count = 0
  for _, p in ipairs(room:getPresentPlayers()) do
    if not p.dead and not p:isRemoved() and #equipIds(p) > 0 then
      count = count + 1
    end
  end
  return count >= 2
end

local function chooseEquip(room, chooser, target)
  local ids = equipIds(target)
  if #ids == 1 then return ids[1] end
  return room:askToChooseCard(chooser, {
    target = target,
    flag = "e",
    skill_name = skill.name,
    prompt = "#qiao__skill_jin023_1-equip:" .. target.id,
  })
end

local function queueTargets(other)
  local result = { other }
  for _, p in ipairs(H.getFormationRelation(other) or {}) do
    if p ~= other and not p.dead and not p:isRemoved() then table.insertIfNeed(result, p) end
  end
  return result
end

skill:addEffect("active", {
  prompt = "#qiao__skill_jin023_1-prompt",
  target_num = 2,
  card_num = 0,
  max_phase_use_time = 1,
  can_use = function(self, player)
    return player.phase == Player.Play and not player.dead
      and hasTwoEquipped(Fk:currentRoom(), player)
  end,
  target_filter = function(self, player, to_select, selected)
    return #selected < 2 and to_select ~= nil and not to_select.dead
      and not to_select:isRemoved() and #equipIds(to_select) > 0
      and not table.contains(selected, to_select)
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local targets = effect.tos or {}
    if player == nil or player.dead or #targets ~= 2 then return end
    local a, b = targets[1], targets[2]
    if a == nil or b == nil or a == b or a.dead or b.dead then return end

    local idA = chooseEquip(room, player, a)
    local idB = chooseEquip(room, player, b)
    if idA == nil or idB == nil or idA == -1 or idB == -1 then return end
    if not table.contains(equipIds(a), idA) or not table.contains(equipIds(b), idB) then return end

    -- 两张牌先同时移至处理区；随后分别进入对方手牌区，不是互相安装。
    room:moveCards({
      ids = { idA },
      from = a,
      toArea = Card.Processing,
      moveReason = fk.ReasonJustMove,
      skillName = skill.name,
      proposer = player,
    }, {
      ids = { idB },
      from = b,
      toArea = Card.Processing,
      moveReason = fk.ReasonJustMove,
      skillName = skill.name,
      proposer = player,
    })
    -- 交换指定的两张牌：处理区后同时移入对方手牌。
    room:moveCards({
      ids = { idA }, to = b, toArea = Card.PlayerHand,
      moveReason = fk.ReasonExchange, skillName = skill.name, proposer = player,
      moveVisible = true,
    }, {
      ids = { idB }, to = a, toArea = Card.PlayerHand,
      moveReason = fk.ReasonExchange, skillName = skill.name, proposer = player,
      moveVisible = true,
    })

    local other
    if a == player then other = b elseif b == player then other = a end
    if other == nil or other.dead or other:isRemoved() then return end

    local targetsForSlash = { other }
    local queue = queueTargets(other)
    if #queue > 1 then
      local choice = room:askToChoice(player, {
        choices = { "single", "queue" },
        skill_name = skill.name,
        prompt = "#qiao__skill_jin023_1-target-group",
        cancelable = false,
      })
      if choice == "queue" then targetsForSlash = queue end
    end

    local policy = C.explicit({}, {
      names = { SLASH },
      min_targets = 1,
      max_targets = #targetsForSlash,
    })
    C.useVirtualCard(room, player, SLASH, nil, targetsForSlash, skill.name, false, nil, policy)
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_jin023_1"] = "锋械",
  ["#qiao__skill_jin023_1-prompt"] = "锋械：交换两名角色各一张装备牌，然后可对另一名或其队列使用【杀】",
  ["#qiao__skill_jin023_1-equip"] = "锋械：选择 %dest 一张装备牌",
  ["#qiao__skill_jin023_1-target-group"] = "锋械：选择【杀】的目标组",
  ["single"] = "另一名角色",
  ["queue"] = "其队列",
}

return skill
