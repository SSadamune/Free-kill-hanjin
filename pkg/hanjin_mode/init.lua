local extension = Package:new("hanjin_mode", Package.SpecialPack)
extension.extensionName = "hanjin"
extension:loadSkillSkelsByPath("./packages/hanjin/pkg/hanjin_mode/skills")

-- Register after all extensions are installed; hanjin may load before hegemony.
Fk:addPostLoadFunc(function()
  local base = assert(Fk.game_modes.new_heg_mode, "Hanjin requires the hegemony extension")
  local mode = require("packages.hanjin.pkg.hanjin_mode.mode").create(base)
  extension:addGameMode(mode)
  Fk:addGameMode(mode)
  Fk:loadDisabled()
end)

Fk:loadTranslationTable {
  ["hanjin_mode"] = "紫乔汉晋·规则",
  ["han"] = "汉",
  ["hanjin_heg_mode"] = "紫乔汉晋国战",
  [":hanjin_heg_mode"] = "继承国战规则；分发武将前确定四个允许势力，遵守同房间上一局胜负及禁选记录。可设置野心家专属武将数量。",
  ["hanjin_rule_settings"] = "紫乔汉晋规则",
  ["hanjin_wild_count"] = "野心家专属武将数量",
  ["help: hanjin_wild_count"] = "随机保留至多此数量的野心家专属武将。默认4；设为0则全部禁选。",
  ["#HanjinFactionBan"] = "本局禁选势力：%arg；允许势力：%arg2",
}
return extension
