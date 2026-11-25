-- Public description data for the skill detail views. No room or player state
-- is required, so the same references can be used before entering a room.
local M = {}

-- The titles without a skill skeleton describe rules that already have a
-- client-facing meaning. Descriptions keyed here reuse the installed text.
local terms = {
  ["先驱"] = { key = ":@!!vanguard" },
  ["阴阳鱼"] = { key = ":@!!yinyangfish" },
  ["珠联璧合"] = { key = ":@!!companion" },
  ["野心家"] = { key = ":@!!wild" },
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

function M.catalog()
  local skills, cards = {}, {}
  for id, skeleton in pairs(Fk.skill_skels) do
    if id:startsWith("qiao_") then
      local title, description = translated(id), translated(":" .. id)
      if title and description then
        skills[#skills + 1] = addAliases {
          id = id, title = title, description = Fk:getDescription(id),
          related = skeleton.related_skills,
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
  table.sort(skills, function(a, b) return a.id < b.id end)
  return { skills = skills, cards = cards }
end

return M
