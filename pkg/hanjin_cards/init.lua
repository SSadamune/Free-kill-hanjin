-- Formal cards will be independently defined here after their designs are confirmed.
local extension = Package:new("hanjin_cards", Package.CardPack)
extension.extensionName = "hanjin"
extension.game_modes_whitelist = { "hanjin_heg_mode" }
Fk:loadTranslationTable { ["hanjin_cards"] = "紫乔汉晋·卡牌" }
return extension
