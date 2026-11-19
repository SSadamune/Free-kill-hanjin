local M = {}

--- 读取房间 native 原始设置的缓存。Room:initialize 会把模式级禁包追加到
--- 解码后的 settings.disabledPack，但不会改写 native CBOR；因此局内资格判断须
--- 回到 room.room:settings() 的原始设置，房主禁包与模式自动禁包才能区分。
local original_settings_cache = setmetatable({}, { __mode = "k" })

local function originalSettings(room)
  local cached = original_settings_cache[room]
  if cached ~= nil then return cached end
  local result
  local native = room.room
  if native ~= nil and type(native.settings) == "function" then
    local ok, encoded = pcall(native.settings, native)
    if ok and encoded ~= nil then
      if type(encoded) == "table" then
        result = encoded
      else
        local decodedOk, decoded = pcall(cbor.decode, encoded)
        if decodedOk and type(decoded) == "table" then result = decoded end
      end
    end
  end
  -- 兼容没有 native 原始设置的测试替身；正常房间不会走到这里。
  result = result or room.settings
  original_settings_cache[room] = result
  return result
end

--- 按 RoomBase:getSettings 的优先级读取原始设置中的键。
local function originalSetting(room, key)
  local settings = originalSettings(room)
  if type(settings) ~= "table" then return nil end
  local mode = settings._mode
  if type(mode) == "table" and mode[key] ~= nil then return mode[key] end
  local game = settings._game
  if type(game) == "table" and game[key] ~= nil then return game[key] end
  return settings[key]
end

--- 按房主禁将方案查询。创房时，带白名单的禁包已展开为逐将禁用。
--- 君主版、效忠版与翼从等可由局内规则取得的牌仍可按此查询。
function M.allows(room, name)
  if room == nil or type(name) ~= "string" then return false end
  local general = Fk.generals[name]
  if general == nil then return false end
  local explicit = originalSetting(room, "disabledGenerals") or {}
  if table.contains(explicit, name) then return false end
  local package = general.package and general.package.name
  if package ~= nil and table.contains(originalSetting(room, "disabledPack") or {}, package) then
    return false
  end
  return true
end

return M
