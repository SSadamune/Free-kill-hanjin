-- Read only public, synchronized state for the character panel. Keep the
-- underlying marks and their existing cleanup rules as the source of truth.
local Deck = require "packages.qiao.pkg.qiao_generals.util.jin_deck"
local Pojun = require "packages.qiao.pkg.qiao_mode.rules.pojun"
local Tieqi = require "packages.qiao.pkg.qiao_mode.rules.tieqi"
local Duanchang = require "packages.qiao.pkg.qiao_mode.rules.qun_duanchang"
local Quan = require "packages.qiao.pkg.qiao_generals.util.quan_common"
local Formation = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_formation"
local ZhenShiJin = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_jin"
local M = {}
Fk:loadTranslationTable {
  ["qiao_skill_status_hand_limit"] = "手牌上限",
}

local suits = { Card.Spade, Card.Club, Card.Heart, Card.Diamond }
function M.fuliSuitMark(suit)
  return "qiao_jin016_1_suit" .. suit .. "-turn"
end
local fuli = table.map(suits, M.fuliSuitMark)

M.hengjiang = "qiao_hengjiang_limit-turn"
M.luoyi = "qiao_wei005_luoyi-turn"
M.luoyiCount = "qiao_wei005_luoyi_activations-turn"

M.jiliCount = "qiao_use_respond_count-turn"
local jiliSkills = { "qiao__skill_shu020_1", "ld__jilis" }
function M.isJili(skillName) return table.contains(jiliSkills, skillName) end
function M.watchesSkill(skillName) return skillName == Deck.QIANBIAN or M.isJili(skillName) end

local function bonus(description, prefix)
  return function(value)
    local amount = ("%+d"):format(value)
    return description:format(amount), (prefix or "") .. amount
  end
end

local function affectedCardName(player, position, own)
  local deputy = position == "deputy"
  local positionName = deputy and "副将牌" or "主将牌"
  local name = deputy and (player.deputyGeneral or "") or player.general
  if name == "anjiang" and own then
    name = player:getMark(deputy and "__heg_deputy" or "__heg_general")
  end
  return Fk.generals[name] and name ~= "anjiang" and Fk:translate(name) or positionName
end

local entries = {
  { "qiao_wei022_yuejian-turn", "qiao__skill_wei022_2", function(_, player)
    return ("本回合手牌上限的初值为体力上限（%d）。若本回合弃牌阶段未弃置牌，该阶段结束时摸1张牌。"):format(player.maxHp)
  end },
  { "@@qiao__skill_shu004_2_kong", "qiao__skill_shu004_2", "直到下次摸牌前，【杀】和【决斗】对你无效。" },
  { "@[qiao_luanji_suits]", "qiao__skill_qun004_1", function(value)
    local symbols = Deck.suitSymbols(value)
    return "本回合发动〖乱击〗时不能再选择" .. symbols .. "牌。", symbols
  end },
  { M.hengjiang, "qiao__skill_wei023_1", function(value)
    return ("本回合手牌上限−%d。"):format(value), "−" .. value
  end },
  { "qiao_jin017_2_cruise", "qiao__skill_jin017_2", "本回合杀死角色的奖惩改为摸3张牌。" },
  { M.luoyi, "qiao__skill_wei005_1", "本回合使用【杀】或【决斗】造成的伤害+1。" },
  { "qiao_shuangxiong_color", "qiao__qun_cards_state", function(value)
    local color = value == "red" and "黑色" or value == "black" and "红色"
    if color then return "本回合可以将" .. color .. "牌当【决斗】使用。", color end
  end },
  { "qiao__skill_shu004_1_finish-turn", "qiao__skill_shu004_1", "本回合结束阶段额外卜算1次。" },
  { "qiao__skill_shu013_2_turn-turn", "qiao__skill_shu013_2", "本回合结束时可弃1张手牌，令一名其他角色获得额外回合。" },
  { Tieqi.POSITIONS, "qiao__skill_shu006_2", function(value, player, own)
    local names, details = {}, {}
    for _, position in ipairs({ "main", "deputy" }) do
      if table.contains(value, position) then
        local name = affectedCardName(player, position, own)
        table.insert(names, name)
        table.insert(details, name .. "的非锁定技于本回合内失效。")
      end
    end
    return table.concat(details, "\n"), table.concat(names, "／")
  end },
  { "qiao_wu004_zhaxiang_times-turn", "qiao__skill_wu004_2", bonus("本回合使用【杀】的次数上限%s，使用红色【杀】无距离限制。") },
  { "qiao_wu012_tianyi_win-turn", "qiao__skill_wu012_1", function()
    return "本回合使用【杀】无距离限制，可多用1次且每次可多指定1个目标。", "胜"
  end },
  { "qiao_wu012_tianyi_lose-turn", "qiao__skill_wu012_1", function() return "本回合不能使用【杀】。", "负" end },
  { "qiao_skill_han006_1_next_damage-turn", "qiao__skill_han006_1", bonus("本回合下次受到的伤害%s。") },
  { "@@qiao__skill_han008_1_no_damage-turn", "qiao__skill_han008_1", "本回合防止你造成的伤害。" },
  { "qiao__skill_han017_2-bonus-turn", "qiao__skill_han017_2", bonus("本回合拼点牌点数%s。") },
  { "@[qiao_kannan_damage]-turn", "qiao__skill_han017_1", bonus("本回合使用下一张【杀】造成的伤害%s。") },
  { "qiao__skill_wei006_1_granted", "qiao__skill_wei006_1", "因〖轻辎〗获得〖神速〗，直到你的回合结束。" },
  { "qiao_wu_dimeng_granted", "qiao__skill_wu014_2", "因〖缔盟〗获得〖好施〗，直到你的下个回合结束。" },
  { Formation.FEIYING_LAYERS_MARK, Formation.FEIYING_SKILL, bonus("其他角色计算与你的距离%s。飞影来源生效期间适用。") },
  { ZhenShiJin.RANGE, "qiao__skill_jin022b_1", bonus("本回合攻击范围%s。") },
  { "qiao_wei024_extra_draw", "qiao__skill_wei024_1", bonus("本回合摸牌阶段摸牌数%s。") },
  { Quan.YUJUE_DRAW_MARK, "qiao__skill_han003_1", function(value)
    return ("本回合下次造成伤害后，摸牌%d次，每次2张（共%d张）。"):format(value, 2 * value), "摸" .. 2 * value
  end },
  { Quan.ZHENGPI_TWICE_MARK, "qiao__skill_wei021b_1", function()
    return "本回合出牌阶段，〖征辟〗的发动次数上限为2次。", "2次"
  end },
  { Quan.WUDANG_PENDING_MARK, "qiao__retinue_skill_wudang_feijun", function(value)
    return ("本回合还能防止%d次回复体力。回合结束时，每剩1次，你每个区域各弃置1张牌。"):format(value),
      value > 1 and ("×" .. value) or nil
  end },
  { Quan.JUEYAN_DRAW_MARK, "qiao__skill_wu019_1", bonus("本回合摸牌阶段摸牌数%s。", "摸牌") },
  { Quan.JUEYAN_SLASH_MARK, "qiao__skill_wu019_1", bonus("本回合使用【杀】的次数上限%s。", "杀") },
  { Quan.JUEYAN_RANGE_MARK, "qiao__skill_wu019_1", bonus("本回合攻击范围%s。", "范围") },
  { "@qiao_zhaoran-phase", "qiao__skill_jin003_1", function(value)
    if value == " " then return "本出牌阶段手牌公开。尚无花色结算过失去最后一张手牌的效果。" end
    return "本出牌阶段手牌公开。已结算失去最后一张手牌的花色：" .. value .. "。", value
  end },
  { "qiao__skill_wu010_3-cleanup-granted", "qiao__skill_wu010_3", "本回合拥有〖英魂〗和〖英姿〗。" },
  { "qiao_mushun_punish-turn", "qiao__retinue_skill_mushun", "本回合下次弃置牌或被其他角色弃置牌后，失去1点体力。" },
  { "qiao__skill_han017_1-locked-turn", "qiao__skill_han017_1", "本回合不能再次发动〖戡难〗。" },
  { MarkEnum.AddMaxCardsInTurn, "qiao_skill_status_hand_limit", bonus("本回合手牌上限%s。") },
  { "@@lure_tiger-turn", "@@lure_tiger-turn", "移出游戏，直到当前回合结束。" },
  { "@qiao_gongqi-turn", "qiao__skill_wu028_1", bonus("本回合攻击范围%s。") },
  { "@@qiao_xizhen-turn", "qiao__skill_qun079_1", "本回合不能使用或打出牌。" },
  { "@qiao_duduan-turn", "qiao__skill_shu091_1", function(value)
    local names = table.map(value, function(id) return Fk:translate(id) end)
    return "本回合不能使用或打出【" .. table.concat(names, "】或【") .. "】。", table.concat(names, "／")
  end },
  { "@@qiao_skill_han005_2_source-noclear", "qiao__skill_han005_2", "本局因普通【杀】造成或受到的伤害+1。" },
  { "@qiao_jin018_wudu", "qiao__skill_jin018_2", "手牌对所有角色公开，直到你的回合结束。" },
  { "@@qiao_bazhen_viewas", "qiao__retinue_skill_bazhenbing_viewas", "本次【调虎离山】结算中，可以将1张【杀】当【无懈可击】使用。" },
  { "@@command4_effect-turn", "@@command4_effect-turn", "本回合不能使用或打出手牌，非锁定技失效。" },
  { "@@command5_effect-turn", "@@command5_effect-turn", "本回合不能回复体力。" },
  { "@[qiao_keqing]", "qiao__skill_jin013_2", function(value)
    local count = #value
    return ("横置期间使用或打出牌时，当前%d个〖克清〗来源各令你弃置1张牌。来源再次发动〖克清〗或死亡时，其效果结束。"):format(count),
      count > 1 and tostring(count) or nil
  end },
  { "@[qiao_bingzhou_pairs]", "qiao__retinue_skill_bingzhou_langqi", function(value)
    local names = {}
    local room = Fk:currentRoom()
    for _, pair in ipairs(value) do
      local other = room:getPlayerById(type(pair) == "table" and pair.other or pair)
      if other then table.insertIfNeed(names, Fk:translate("seat#" .. other.seat)) end
    end
    if #names == 0 then return end
    return "本回合你与" .. table.concat(names, "、") .. "的双向距离均视为1。", table.concat(names, "／")
  end },
}

local watched = {
  [M.jiliCount] = true,
  [M.luoyiCount] = true,
  [Deck.BAN_DISPLAY] = true,
  [Deck.BAN_SUITS] = true,
  [Deck.USED_SUITS] = true,
  [Pojun.COUNT] = true,
  [Pojun.CARDS] = true,
  [Duanchang.DISPLAY_MARK] = true,
  [Duanchang.PRIVATE_MARK] = true,
}
for _, entry in ipairs(entries) do watched[entry[1]] = true end
for _, mark in ipairs(fuli) do watched[mark] = true end

function M.watches(mark) return watched[mark] == true end

local function append(states, id, skill, description, value)
  table.insert(states, {
    id = id, title = Fk:translate(skill), description = description, value = value or "",
    parameterized = value ~= nil,
  })
end

local function appendDuanchang(states, player, own)
  local affected = player:getMark(Duanchang.DISPLAY_MARK)
  if affected == 0 then return end
  if type(affected) ~= "table" then
    append(states, Duanchang.DISPLAY_MARK, Duanchang.SKILL, "一张武将牌因〖断肠〗永久失去当时拥有的技能。")
    return
  end

  local function add(name)
    append(states, Duanchang.DISPLAY_MARK, Duanchang.SKILL,
      name .. "因〖断肠〗永久失去当时拥有的技能。", name)
  end
  for _, name in ipairs(affected.shown) do add(Fk:translate(name)) end
  local hidden = own and player:getTableMark(Duanchang.PRIVATE_MARK) or {}
  for i = 1, affected.hidden do
    add(hidden[i] and Fk:translate(hidden[i]) or "暗置武将牌")
  end
end

function M.forPlayer(player, own)
  local states = {}
  if not player or player.dead then return states end
  for _, entry in ipairs(entries) do
    local mark, skill, render = table.unpack(entry)
    local value = player:getMark(mark)
    if value ~= 0 and (type(value) ~= "table" or next(value)) then
      local description, parameter = render, nil
      if type(render) == "function" then description, parameter = render(value, player, own) end
      if description then
        if parameter then
          append(states, mark, skill, description, parameter)
        else
          -- Constant binary effects can repeat. A renderer may intentionally
          -- leave a single charge unparameterized.
          local count = type(render) == "string" and type(value) == "number" and math.max(1, value) or 1
          if mark == M.luoyi then count = math.max(count, player:getMark(M.luoyiCount)) end
          for _ = 1, count do append(states, mark, skill, description) end
        end
      end
    end
  end
  appendDuanchang(states, player, own)

  local banned = {}
  for index, mark in ipairs(fuli) do
    if player:getMark(mark) > 0 then table.insert(banned, suits[index]) end
  end
  if #banned > 0 then
    local symbols = Deck.suitSymbols(banned)
    append(states, "fuli", "qiao__skill_jin016_1",
      "本回合不能使用或打出" .. symbols .. "牌。", symbols)
  end

  local usedSuits = Deck.suitSymbols(player:getTableMark(Deck.USED_SUITS))
  local bannedSuits = Deck.suitSymbols(Deck.bannedSuits(player))
  local legacySuits = player:getMark(Deck.BAN_DISPLAY)
  if bannedSuits == "" and type(legacySuits) == "string" then bannedSuits = legacySuits end
  if bannedSuits ~= "" or (usedSuits ~= "" and player:hasShownSkill(Deck.QIANBIAN)) then
    local description = "本阶段已使用的手牌花色：" .. (usedSuits == "" and "无" or usedSuits)
      .. "\n本阶段禁止使用的手牌花色：" .. (bannedSuits == "" and "无" or bannedSuits)
    append(states, Deck.BAN_DISPLAY, Deck.QIANBIAN, description, usedSuits == "" and bannedSuits or usedSuits)
  end

  local pojunCount = player:getMark(Pojun.COUNT)
  if pojunCount > 0 then
    local ownCards = Self == player and not Fk:currentRoom().observing and player:getTableMark(Pojun.CARDS) or {}
    append(states, Pojun.COUNT, "qiao__skill_wu020_2",
      ("当前回合结束时返还暂扣的%d张牌。"):format(pojunCount), tostring(pojunCount))
    if #ownCards > 0 then
      states[#states].cards = ownCards
      states[#states].action = "pojun"
    end
  end

  for _, name in ipairs(jiliSkills) do
    if Fk.skills[name] and player:hasShownSkill(name) then
      local count, range = player:getMark(M.jiliCount), player:getAttackRange()
      local details = ("本回合已使用或打出%d张牌，当前攻击范围为%d。"):format(count, range)
      if count < range then
        details = details .. ("若攻击范围维持不变，使用或打出本回合第%d张牌时可以摸%d张牌。"):format(range, range)
      else
        details = details .. "此后累计用牌或打出牌数等于当时攻击范围时，仍可发动〖蒺藜〗。"
      end
      append(states, "jili", name, details, ("%d/%d"):format(count, range))
      break
    end
  end
  return states
end

return M
