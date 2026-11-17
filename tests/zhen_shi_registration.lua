-- 阵/势包新增翼从与统领来源的正式登记验收。
local S = require "packages.hanjin.pkg.hanjin_generals.util.retinue_instance_sources"
local Commander = require "packages.hanjin.pkg.hanjin_mode.rules.commander_retinue"

local QINGZHOU = "hanjin__retinue_qingzhou_jingrui"
local LUJIANG = "hanjin__retinue_lujiang_shangjia"
local BAZHEN = "hanjin__retinue_bazhenbing"

Testhanjin_zhen_shi_registration = {
  setup = function() end,
  tearDown = function() end,
}

function Testhanjin_zhen_shi_registration:testRetinuesAndPackages()
  for _, id in ipairs({ QINGZHOU, LUJIANG, BAZHEN }) do
    local general = assert(Fk.generals[id], "missing retinue general: " .. id)
    lu.assertEquals(general.package.name, "hanjin_zhenshi")
    lu.assertTrue(Commander.isRetinue(id))
    lu.assertNotNil(S.skillFor(id), "missing instance-source mapping: " .. id)
  end
  lu.assertEquals(S.skillFor(QINGZHOU), "hanjin__retinue_skill_qingzhou_jingrui")
  lu.assertEquals(S.skillFor(LUJIANG), "hanjin__retinue_skill_lujiang_shangjia")
  lu.assertEquals(S.skillFor(BAZHEN), "hanjin__retinue_skill_bazhenbing")
end

function Testhanjin_zhen_shi_registration:testCommanders()
  for _, id in ipairs({
    "hanjin__wei023", "hanjin__wu023", "hanjin__shu012",
    "hanjin__jin023", "hanjin__em_qun010",
  }) do
    lu.assertTrue(Commander.isCommander(id), "missing commander source: " .. id)
  end
  lu.assertTrue(Commander.isSoldier(QINGZHOU))
  lu.assertTrue(Commander.isSoldier(LUJIANG))
  lu.assertTrue(Commander.isSoldier(BAZHEN))
end

function Testhanjin_zhen_shi_registration:testLureTigerDependencyIsAvailable()
  local card = assert(Fk.all_card_types["hanjin__lure_tiger"])
  -- 锁定上游的 lure_tiger_skill 已真实注册（非 inert 空壳）；八阵兵入口可复用。
  local skill = assert(Fk.skills[card.skill.name])
  lu.assertTrue(#skill:getSkeleton().effects > 0)
  lu.assertNotNil(Fk.skills["hanjin__retinue_skill_bazhenbing"])
end

function Testhanjin_zhen_shi_registration:testAllReviewedGeneralsRegistered()
  local expected={
    "hanjin__em_shu001",
    "hanjin__em_qun010",
    "hanjin__han014",
    "hanjin__han015",
    "hanjin__han019",
    "hanjin__han022",
    "hanjin__jin006",
    "hanjin__jin017",
    "hanjin__jin022b",
    "hanjin__jin023",
    "hanjin__qun006",
    "hanjin__qun011",
    "hanjin__qun024",
    "hanjin__qun081",
    "hanjin__shu012",
    "hanjin__shu018b",
    "hanjin__shu019",
    "hanjin__shu021",
    "hanjin__wei017",
    "hanjin__wei018",
    "hanjin__wei023",
    "hanjin__wei032",
    "hanjin__wu010",
    "hanjin__wu017",
    "hanjin__wu020",
    "hanjin__wu023",
  }
  lu.assertEquals(#expected,26)
  for _,id in ipairs(expected) do
    local general=assert(Fk.generals[id],"missing reviewed general: "..id)
    lu.assertEquals(general.package.name,"hanjin_zhenshi")
  end
  local Versions=require "packages.hanjin.pkg.hanjin_mode.rules.general_versions"
  lu.assertTrue(Fk.generals["hanjin__em_shu001"].hidden)
  lu.assertTrue(Fk.generals["hanjin__em_qun010"].hidden)
  lu.assertNotNil(Versions.lords["hanjin__em_shu001"])
  lu.assertNotNil(Versions.lords["hanjin__em_qun010"])
end

return { name = "hanjin_zhen_shi_registration" }
