-- Read only public, synchronized state for the character panel. Keep the
-- underlying marks and their existing cleanup rules as the source of truth.
local Deck = require "packages.qiao.pkg.qiao_generals.util.jin_deck"
local Tieqi = require "packages.qiao.pkg.qiao_mode.rules.tieqi"
local Formation = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_formation"
local ZhenShiJin = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_jin"
local M = {}
Fk:loadTranslationTable {
  ["qiao_skill_status"] = "状态",
  ["qiao_skill_status_hand_limit"] = "手牌上限",
}

local suits = { Card.Spade, Card.Club, Card.Heart, Card.Diamond }
function M.fuliSuitMark(suit)
  return "qiao_jin016_1_suit" .. suit .. "-turn"
end
local fuli = table.map(suits, M.fuliSuitMark)

M.hengjiang = "qiao_hengjiang_limit-turn"

M.jiliCount = "qiao_use_respond_count-turn"
local jiliSkills = { "qiao__skill_shu020_1", "ld__jilis" }
function M.isJili(skillName) return table.contains(jiliSkills, skillName) end

local entries = {
  { "qiao_wei022_yuejian-turn", "qiao__skill_wei022_2", "本回合手牌上限的初值为体力上限。弃牌阶段结束时，若本阶段未弃置牌，摸一张牌。" },
  { "@@qiao__skill_shu004_2_kong", "qiao__skill_shu004_2", "下次摸牌前，【杀】和【决斗】对你无效。" },
  { "@[qiao_luanji_suits]", "qiao__skill_qun004_1", "本回合发动【乱击】时，不能再选择这些花色。", Deck.suitSymbols },
  { M.hengjiang, "qiao__skill_wei023_1", "本回合手牌上限减少所示数值。", function(value) return "−" .. value end },
  { "qiao_jin017_2_cruise", "qiao__skill_jin017_2", "本回合杀死角色的奖惩改为摸三张牌。" },
  { "qiao_wei005_luoyi-turn", "qiao__skill_wei005_1", "本回合使用【杀】或【决斗】造成的伤害增加所示数值。", function(value) return "+" .. value end },
  { "qiao_shuangxiong_color", "qiao__qun_cards_state", "本回合可以将所示颜色的牌当【决斗】使用。", function(value)
    if value == "red" then return "黑色" end
    if value == "black" then return "红色" end
  end },
  { "qiao__skill_shu004_1_finish-turn", "qiao__skill_shu004_1", "本回合结束阶段额外卜算一次。" },
  { "qiao__skill_shu013_2_turn-turn", "qiao__skill_shu013_2", "本回合结束时可弃一张手牌，令一名其他角色获得额外回合。" },
  { Tieqi.POSITIONS, "qiao__skill_shu006_2", "所示武将牌的技能于本回合内按【铁骑】的限制无效。", function(value)
    local positions = {}
    if table.contains(value, "main") then table.insert(positions, "主将") end
    if table.contains(value, "deputy") then table.insert(positions, "副将") end
    return table.concat(positions, "／")
  end },
  { "qiao_wu004_zhaxiang_times-turn", "qiao__skill_wu004_2", "本回合使用【杀】的次数增加所示数值，使用红色【杀】无距离限制。", function(value) return "+" .. value end },
  { "qiao_wu012_tianyi_win-turn", "qiao__skill_wu012_1", "本回合使用【杀】无距离限制，可多用一次并多指定一个目标。" },
  { "qiao_wu012_tianyi_lose-turn", "qiao__skill_wu012_1", "本回合不能使用【杀】。" },
  { "qiao_skill_han006_1_next_damage-turn", "qiao__skill_han006_1", "本回合下次受到的伤害增加所示数值。", function(value) return "+" .. value end },
  { "@@qiao__skill_han008_1_no_damage-turn", "qiao__skill_han008_1", "本回合防止你造成的伤害。" },
  { "qiao__skill_han017_2-bonus-turn", "qiao__skill_han017_2", "本回合拼点牌点数增加所示数值。", function(value) return "+" .. value end },
  { "@[qiao_kannan_damage]-turn", "qiao__skill_han017_1", "本回合下一张【杀】的伤害增加所示数值。", function(value) return "+" .. value end },
  { "qiao__skill_wei006_1_granted", "qiao__skill_wei006_1", "因【轻辎】获得【神速】，直到你的回合结束。" },
  { "qiao_wu_dimeng_granted", "qiao__skill_wu014_2", "因【缔盟】获得【好施】，直到你的下个回合结束。" },
  { Formation.FEIYING_LAYERS_MARK, Formation.FEIYING_SKILL, "其他角色计算与你的距离增加所示数值。", function(value) return "+" .. value end },
  { ZhenShiJin.RANGE, "qiao__skill_jin022b_1", "本回合攻击范围增加所示数值。", function(value) return "+" .. value end },
  { "@@qiao_duanchang", "qiao__skill_qun012_2", "场上的武将牌因【断肠】失去了技能。" },
  { "qiao_wei024_extra_draw", "qiao__skill_wei024_1", "本回合摸牌阶段多摸所示数量的牌。", function(value) return "+" .. value end },
  { "@qiao_zhaoran-phase", "qiao__skill_jin003_1", "本出牌阶段手牌公开，所示花色已结算过失去最后一张手牌的效果。", function(value)
    return value == " " and "" or value
  end },
  { Deck.BAN_DISPLAY, Deck.QIANBIAN, "本阶段不能使用所示花色的手牌。" },
  { "qiao__skill_wu010_3-cleanup-granted", "qiao__skill_wu010_3", "本回合拥有【英魂】与【英姿】。" },
  { "qiao_mushun_punish-turn", "qiao__retinue_skill_mushun", "本回合下次弃置牌或被其他角色弃置牌后，失去一点体力。" },
  { "qiao__skill_han017_1-locked-turn", "qiao__skill_han017_1", "本回合不能再次发动【戡难】。" },
  { MarkEnum.AddMaxCardsInTurn, "qiao_skill_status_hand_limit", "本回合的手牌上限加成。", function(value) return "+" .. value end },
  { "@@lure_tiger-turn", "@@lure_tiger-turn", "暂时移出游戏。" },
}

local watched = { [M.jiliCount] = true }
for _, entry in ipairs(entries) do watched[entry[1]] = true end
for _, mark in ipairs(fuli) do watched[mark] = true end

function M.watches(mark) return watched[mark] == true end

local function append(states, id, skill, description, value)
  table.insert(states, {
    id = id, title = Fk:translate(skill), description = description, value = value or "",
  })
end

function M.forPlayer(player)
  local states = {}
  if not player or player.dead then return states end
  for _, entry in ipairs(entries) do
    local mark, skill, description, format = table.unpack(entry)
    local value = player:getMark(mark)
    if value ~= 0 and (type(value) ~= "table" or next(value)) then
      append(states, mark, skill, description, format and format(value))
    end
  end

  local banned = {}
  for index, mark in ipairs(fuli) do
    if player:getMark(mark) > 0 then table.insert(banned, suits[index]) end
  end
  if #banned > 0 then
    append(states, "fuli", "qiao__skill_jin016_1",
      "本回合不能使用或打出所示花色的牌。", Deck.suitSymbols(banned))
  end

  for _, name in ipairs(jiliSkills) do
    if Fk.skills[name] and player:hasShownSkill(name) then
      append(states, "jili", name,
        "本回合已使用或打出的牌数。使用或打出第 X 张牌时可摸 X 张，X 为当前攻击范围。", tostring(player:getMark(M.jiliCount)))
      break
    end
  end
  return states
end

return M
