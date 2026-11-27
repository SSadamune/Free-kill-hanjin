local H = require "packages.hegemony.util"
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
local Interaction = require "packages.qiao.pkg.qiao_bingqing.interaction"
local M = { give = Interaction.give }

M.present = require("packages.qiao.pkg.qiao_mode.rules.removed_targets").isPresent

function M.allies(p, other)
  return H.compareKingdomWith(p, other)
end

function M.pick(room, chooser, targets, skill, optional, max)
  return Interaction.choosePlayers(room, chooser, targets, skill, max, optional)
end

-- 只生成公共交换接口此刻允许的组合，保留选中时的牌名供最终防陈旧校验。
function M.pairs(room, a, b, generalA, generalB)
  local pairs = {}
  if not M.present(a) or not M.present(b) then return pairs end
  for _, deputyA in ipairs({ false, true }) do
    local first = { player = a, isDeputy = deputyA, general = Exchange.publicGeneral(a, deputyA) }
    for _, deputyB in ipairs({ false, true }) do
      local second = { player = b, isDeputy = deputyB, general = Exchange.publicGeneral(b, deputyB) }
      if (not generalA or first.general == generalA) and (not generalB or second.general == generalB)
        and Exchange.validate(room, first, second) then
        table.insert(pairs, { first, second })
      end
    end
  end
  return pairs
end

function M.exchange(room, chooser, pairs, skill, optional)
  if #pairs == 0 or not M.present(chooser) then return end
  local choices = {}
  for _, pair in ipairs(pairs) do
    table.insert(choices, "qiao_shi_exchange:::" .. pair[1].general .. ":" .. pair[2].general)
  end
  if optional then table.insert(choices, "Cancel") end
  local choice = #choices == 1 and choices[1] or room:askToChoice(chooser, {
    choices = choices, skill_name = skill,
  })
  local pair = pairs[table.indexOf(choices, choice)]
  if pair then return Exchange.exchange(room, pair[1], pair[2]) end
end

Fk:loadTranslationTable { ["qiao_shi_exchange"] = "交换 %arg 与 %arg2" }
return M
