"""Parse extension Lua with the exact Lua 5.4 DLL shipped by FreeKill."""
import ctypes
import os
from pathlib import Path

root = Path(__file__).resolve().parent.parent
runtime = root / '.dev/runtime/FreeKill-release'
with os.add_dll_directory(str(runtime)):
    lua = ctypes.CDLL(str(runtime / 'lua54.dll'))
lua.luaL_newstate.restype = ctypes.c_void_p
lua.luaL_loadbufferx.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p, ctypes.c_char_p]
lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
lua.lua_tolstring.restype = ctypes.c_char_p
lua.lua_settop.argtypes = [ctypes.c_void_p, ctypes.c_int]
lua.lua_close.argtypes = [ctypes.c_void_p]
state = lua.luaL_newstate()
if not state:
    raise MemoryError('Cannot create Lua state')
failed = False
try:
    for path in [root / 'init.lua', *sorted((root / 'pkg').rglob('*.lua')), *sorted((root / 'tests').rglob('*.lua'))]:
        source = path.read_bytes()
        name = str(path.relative_to(root)).encode('utf-8')
        if lua.luaL_loadbufferx(state, source, len(source), name, b't'):
            print(lua.lua_tolstring(state, -1, None).decode('utf-8', errors='replace'))
            failed = True
        else:
            print(f'OK {path.relative_to(root)}')
        lua.lua_settop(state, 0)
finally:
    lua.lua_close(state)
raise SystemExit(1 if failed else 0)
