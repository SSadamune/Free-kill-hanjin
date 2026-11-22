-- EM(QUN010) 张角 · 黄巾天兵符
-- 弘法授予的旗入口：准备阶段没有天兵时，将牌堆顶等同群角色数的牌置于旗上；
-- 持有者将失去体力时，可移去一张天兵防止整个失去体力事件；
-- 旗存在期间，当前群势力角色（含持旗者）获得“天兵当雷【杀】”的视技入口。
local P = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_qun"
local H = require "packages.hegemony.util"
local Flags = require "packages.qiao.pkg.qiao_mode.rules.lord_flag_display"

local skill = fk.CreateSkill {
  name = P.BANNER_SKILL,
  derived_piles = P.PILE,
}

skill:addEffect(fk.EventPhaseStart, {
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and player.phase == Player.Start
      and P.flagActive(player) and P.count(player) == 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__em_qun010_banner-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local count = H.getKingdomPlayersNum(room, false)["qun"] or 0
    if count <= 0 then return end
    local ids = room:getNCards(count)
    P.add(player, ids, skill.name)
  end,
})

-- 持有者将失去体力时，可移去一张天兵防止这次失去体力。防止作用于整个
-- 失去体力事件（含多点）；伤害不走 fk.PreHpLost，不在此处结算。
-- 选牌只开放旗牌堆；实际移出该牌后才调用 preventHpLost，取消或移动未生效
-- 时不防止，本次失去体力按正常流程结算。
skill:addEffect(fk.PreHpLost, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and P.flagActive(player)
      and data ~= nil and not data.prevented and (data.num or 0) > 0
      and P.count(player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local cards = room:askToCards(player, {
      min_num = 1,
      max_num = 1,
      include_equip = false,
      skill_name = skill.name,
      pattern = ".|.|.|" .. P.PILE,
      prompt = "#qiao__em_qun010_banner-prevent",
      cancelable = true,
      expand_pile = P.PILE,
    })
    if cards == nil or #cards ~= 1 then return false end
    -- 请求结果必须仍是该角色旗牌堆中的实际牌。
    if not table.contains(player:getPile(P.PILE), cards[1]) then return false end
    event:setCostData(self, { cards = { cards[1] } })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local id = ((event:getCostData(self) or {}).cards or {})[1]
    if id == nil or not table.contains(player:getPile(P.PILE), id) then return end
    -- 走实际旗牌堆移动，AfterCardsMove 仍可被悟心观察；remove 只移动旗上的牌。
    if not P.remove(player, { id }, skill.name) then return end
    data:preventHpLost()
  end,
})

-- 第二段：当前群势力角色（含持旗者）可将一张“天兵”当雷【杀】使用或打出。
-- 入口来源记为旗自身；授予/撤回应按同一来源对称，已有其他独立来源时只追加或
-- 只撤回旗这份，不吞并、不误删。同步自身授技用 no_trigger，但仍会回到本函数，
-- 以房间为键的弱表阻止同一次同步重入。
local SYNCING = setmetatable({}, {__mode = "k"})

local function grantEntry(player)
  if player:hasSkill(P.ENTRY, true, true) then
    -- insertIfNeed 幂等；已有其他来源时不广播、不替换。
    player:addSkill(P.ENTRY, P.BANNER_SKILL)
  else
    player.room:handleAddLoseSkills(player, P.ENTRY, P.BANNER_SKILL, false, true)
  end
end

local function removeEntry(player)
  player.room:handleAddLoseSkills(player, "-" .. P.ENTRY, P.BANNER_SKILL, false, true)
end

local function syncEntries(room)
  if room == nil or SYNCING[room] then return end
  SYNCING[room] = true
  local hasFlag = #P.flagHolders(room) > 0
  for _, player in ipairs(room.players) do
    local eligible = hasFlag and player:isAlive() and not player:isRemoved()
      and player.kingdom == "qun"
    if eligible then
      grantEntry(player)
    elseif player:hasSkill(P.ENTRY) then
      removeEntry(player)
    end
  end
  SYNCING[room] = nil
end

-- 旗失去时 Player:loseSkill 先清掉持旗者的派生入口，SkillSkeleton:onLose 再把
-- 旗牌堆移入弃牌堆，随后触发本回调；这里只负责清理其余角色的入口。
local function syncFlag(self, player)
  syncEntries(player.room)
  Flags.refresh(player, self.name)
end
skill:addAcquireEffect(syncFlag)
skill:addLoseEffect(syncFlag)

-- 与嘉禾的旗入口同一时机集合；旗技能实例在首次授予时才注册这些全局监听。
local syncSpec = {
  global = true,
  can_refresh = function(self, event, target, player)
    if player == nil or player.room == nil then return false end
    if event == fk.GameStart then return player.seat == 1 end
    return target == player
  end,
  on_refresh = function(self, event, target, player)
    syncEntries(player.room)
  end,
}
for _, event in ipairs({
  fk.GameStart, fk.GeneralRevealed, fk.GeneralShown, fk.GeneralHidden,
  fk.EventAcquireSkill, fk.EventLoseSkill, fk.Death,
  fk.AfterPropertyChange, fk.TurnStart,
}) do
  skill:addEffect(event, syncSpec)
end

Fk:loadTranslationTable {
  [P.BANNER_SKILL] = "黄巾天兵符",
  [P.PILE] = "天兵",
  [":" .. P.BANNER_SKILL] = "准备阶段，若没有“天兵”，你可以将牌堆顶等同群势力角色数的牌置于此牌上，称为“天兵”。"
    .. "有角色因技能或判断大小势力而计算角色数时，群势力角色数视为+X（X为“天兵”数）。<br/>"
    .. "群势力角色均可以将一张“天兵”当雷【杀】使用或打出。<br/>"
    .. "当你失去体力时，你可以移去一张“天兵”并防止之。",
  ["#qiao__em_qun010_banner-invoke"] = "黄巾天兵符：是否将牌堆顶等同群角色数的牌置于旗上作为天兵",
  ["#qiao__em_qun010_banner-prevent"] = "黄巾天兵符：移去一张“天兵”，防止此次失去体力",
}

return skill
