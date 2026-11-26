-- Public description data for the skill detail views. No room or player state
-- is required, so the same references can be used before entering a room.
local M = {}
local Commander = require "packages.qiao.pkg.qiao_mode.rules.commander_retinue"
local Versions = require "packages.qiao.pkg.qiao_mode.rules.general_versions"
local Flags = require "packages.qiao.pkg.qiao_mode.rules.lord_flag_display"
local SameName = require "packages.qiao.pkg.qiao_mode.rules.same_name_skills"
local Ci = require "packages.qiao.pkg.qiao_generals.util.jin_ci"
local Qun = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_qun"

-- The titles without a skill skeleton describe rules that already have a
-- client-facing meaning. Descriptions keyed here reuse the installed text.
local terms = {
  ["先驱"] = { key = ":@!!vanguard" },
  ["阴阳鱼"] = { key = ":@!!yinyangfish" },
  ["珠联璧合"] = { key = ":@!!companion" },
  ["野心家"] = { key = ":@!!wild" },
  ["创"] = { text = "因“不屈”置于武将牌上的牌。每种花色保留一张，同花色的其余“创”按“不屈”的效果移去。" },
  ["合"] = { text = "带有此标记的牌可用于“合纵”。", bare = false },
  ["君主大旗"] = { text = "由对应君主技能获得。点击下列大旗名称可查看各自的说明：霸者求贤状、六师率义旗、缘江烽火图、黄巾天兵符、诸王敕封册。", bare = true },
  ["烽火"] = { text = "以“缘江烽火图”置于旗上的牌，称为“烽火”。旗上的烽火可用于执行该旗的效果。", bare = true },
  ["应变"] = { text = "一张牌可以有一个或多个“条件→效果”条目。使用此牌时逐项检查条件，满足时执行对应效果。", bare = true },
  ["应变牌"] = { text = "具有明确应变条件和应变效果的牌。应变是否实际触发另按每个条目的条件判断。", bare = true },
  ["富甲"] = { text = "应变条件。使用者的手牌数为所有存活角色中最多，允许并列。", bare = true },
  ["残躯"] = { text = "应变条件。使用者的体力值恰好为1。", bare = true },
  ["助战"] = { text = "应变条件。本项询问中有合法的协助者弃置了一张与这张应变牌同类别的手牌。", bare = true },
  ["空巢"] = { text = "应变条件。使用者没有手牌。", bare = true },
  ["孤军"] = { text = "应变条件。使用者已确定势力，且该势力只有其一名存活角色。", bare = true },
  ["统领能力"] = { key = ":qiao_commander_ability", bare = true },
  ["翼从"] = { text = "拥有专属技能的士兵牌。每份翼从提供一份独立来源，同名翼从分别计算。", bare = true },
  ["翼从效果"] = { text = "统领明置或变更势力时，其所在势力已有的普通士兵转为翼从。此后该势力出现普通士兵时也进行转换。持有者从本势力可得兵种中选择。", bare = true },
  ["阵法技"] = { text = "与队列或围攻关系有关的技能。明置带有阵法技的武将牌后，可以按该技能对应的关系发起阵法召唤。", bare = true },
  ["队列"] = { text = "由至少两名座次连续且势力相同的存活角色组成。", bare = true },
  ["围攻"] = { text = "一名角色的上家和下家势力相同，且与该角色的势力不同，三者构成围攻关系。", bare = true },
  ["客将"] = { text = "启用客将替换时，主势力均被禁用的武将牌可以按客将规则以允许的势力出场。", bare = true },
  ["势力锦囊"] = { text = "不在默认牌堆中，通过特殊手段加入本局。部分牌面效果取决于使用者是否为牌上指定的势力。", bare = true },
  ["移出游戏"] = { text = "移出游戏期间，角色不能参与通常的用牌及结算。需要统计人数时仍按对应规则判断。", bare = true },
  ["只能当"] = { text = "受此效果限制的实体牌不能以原牌名直接使用或打出，可以按效果列出的用途和对应操作转换。其他技能仍可按各自的规则使用该实体牌作为转化材料。" },
  ["军令"] = { text = "发起者从随机给出的两项军令中选一项，目标选择是否执行。可执行的军令有军令一、军令二、军令三、军令四、军令五、军令六。", bare = true },
  ["奇珍牌"] = { key = ":rare_treasure", bare = true },
}

for n, title in ipairs({ "军令一", "军令二", "军令三", "军令四", "军令五", "军令六" }) do
  terms[title] = { key = ":command" .. n, bare = true }
end

local historicalCards = {
  "battle_royal_bujinzetui", "battle_royal_fuli", "battle_royal_luoshi",
  "battle_royal_shengzheweiwang", "battle_royal_huoqi", "battle_royal_jili",
}

local adaptationTitles = {
  fujia = "富甲", canqu = "残躯", zhuzhan = "助战", kongchao = "空巢", gujun = "孤军",
}

local aliases = {
  ["六师率义旗"] = { "六师" },
  ["并州狼骑"] = { "并州骑" },
  ["青州精锐"] = { "青州兵" },
  ["庐江上甲"] = { "庐江兵" },
  ["君主大旗"] = { "君主旗" },
}

local function translated(key)
  local value = Fk:translate(key)
  if value ~= key and value ~= "" then return value end
end

local function addAliases(entry)
  entry.aliases = aliases[entry.title]
  return entry
end

local function detailOmissions()
  local omissions = {}
  local function register(parent, target, fragments)
    omissions[parent] = { target = target, fragments = fragments }
  end

  -- Derive the fragments from the standalone descriptions. If either text
  -- changes, the renderer leaves any fragment that no longer matches intact.
  local ci = translated(":" .. Ci.MARK)
  if ci then
    register(Ci.SKILL, Ci.CONSUME, {
      "\n（" .. ci .. "）",
      "<br/><b>〔赐〕</b> 本技能另有“赐”的消耗入口。",
    })
  end
  local tianbing = translated(":" .. Qun.ENTRY)
  if tianbing then
    register(Qun.BANNER_SKILL, Qun.ENTRY, {
      "<br/>" .. tianbing:gsub("^群势力角色可以", "群势力角色均可以"),
    })
  end
  local cunsi = translated(":qiao__skill_shu021_3")
  if cunsi then
    register("qiao__skill_shu021_2", "qiao__skill_shu021_3", { "（" .. cunsi .. "）" })
  end
  return omissions
end

local function cardVariants()
  local variants = {}
  local deck = Fk.packages.qiao_cards.qiao_cards
  for _, position in ipairs(deck.allPositions) do
    local conditions = position.extra.qiao_adaptation or {}
    if position.heji or #conditions > 0 then
      local card = Fk:cloneCard(position.card, position.suit, position.number)
      deck.stamp(card, position.id)
      local name, description = Fk:translate(card.name), card:getDynamicDescription()
      local function add(qualifier)
        local title = name .. "·" .. qualifier
        local entries = variants[title] or {}
        if not table.find(entries, function(entry) return entry.description == description end) then
          entries[#entries + 1] = { id = card.name, title = title, description = description }
        end
        variants[title] = entries
      end
      if position.heji then
        add("合纵")
        variants[name .. "·合"] = variants[name .. "·合纵"]
      end
      if #conditions > 0 then add("应变") end
      for _, condition in ipairs(conditions) do add(adaptationTitles[condition.condition] or condition.condition) end
    end
  end
  local full = Fk:translate("qiao__threaten_emperor")
  variants["挟天子·合"] = variants[full .. "·合"]
  return variants
end

function M.catalog()
  local skills, cards, generals, skillAliases = {}, {}, {}, {}
  for id, general in pairs(Fk.generals) do
    if general.package.extensionName == "qiao" then
      local title = translated(id)
      if title and (not general.total_hidden or Commander.isRetinue(id)) then
        local commander = Commander.commanders[id]
        generals[#generals + 1] = addAliases {
          id = id, title = title, variant = translated(general.prefix or ""),
          page = Commander.isRetinue(id) and "retinue" or "general", bare = true,
          lord = Versions.lord_version(id),
          commander = commander and Commander.describeSource(id, commander.retinues),
        }
      end
    end
  end
  for id, skeleton in pairs(Fk.skill_skels) do
    local original = SameName.canonicalHistoryKey(id)
    if original ~= id then
      -- Runtime copies have their own history but share the original's reference entry.
      skillAliases[id] = original
    elseif id:startsWith("qiao_") then
      local title, description = translated(id), translated(":" .. id)
      if title and description then
        local display = Fk:getDescription(id)
        if id == Ci.CONSUME then display = translated(":" .. Ci.MARK) or display end
        skills[#skills + 1] = addAliases {
          id = id, title = title, description = display,
          related = skeleton.related_skills,
          page = Flags.flags[id] and "banner" or nil,
          bare = title:find("旗", 1, true) ~= nil or title == "诏书"
            or title == "霸者求贤状" or title == "缘江烽火图" or title == "黄巾天兵符"
            or title == "诸王敕封册" or title == "阵法召唤" or title == "鏖战",
        }
      end
    end
  end
  for title, term in pairs(terms) do
    local description = term.text or translated(term.key)
    if description then
      skills[#skills + 1] = addAliases {
        id = title, title = title, description = description, bare = term.bare, term = true,
      }
    end
  end
  for id, card in pairs(Fk.all_card_types) do
    local title, description = translated(id), translated(":" .. id)
    if title and description then
      local localCard = card.package and card.package.extensionName == "qiao"
      local priority = localCard and 2 or 1
      local current = cards[title]
      if not current or priority > current.priority or (priority == current.priority and id < current.id) then
        cards[title] = { id = id, title = title, description = description, priority = priority }
      end
    end
  end
  for _, id in ipairs(historicalCards) do
    local title, description = translated(id), translated(":" .. id)
    if title and description and not cards[title] then
      cards[title] = { id = id, title = title, description = description }
    end
  end
  local threatenEmperor = translated("qiao__threaten_emperor")
  if threatenEmperor then cards["挟天子"] = cards[threatenEmperor] end
  table.sort(skills, function(a, b) return a.id < b.id end)
  table.sort(generals, function(a, b) return a.id < b.id end)
  return { skills = skills, cards = cards, generals = generals, variants = cardVariants(),
    omissions = detailOmissions(), skillAliases = skillAliases }
end

return M
