"""Apply the local-console timeout compatibility changes to FreeKill v0.5.25."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent
RUNTIME = ROOT / '.dev/runtime/FreeKill-release'


def replacements():
    return {
        'lua/server/request.lua': [
            # v0.5.25 exports Backend only in the GUI process. Its local server
            # is created by Console start; dedicated servers have no Backend.
            ('  room.current_request = self\n', '  room.current_request = self\n  local console = fk.Backend ~= nil\n  local unlimited = console and self.timeout < 0\n'),
            ('  room.room:setRequestTimer(self.timeout * 1000 + 500)', '  if not unlimited then room.room:setRequestTimer(self.timeout * 1000 + 500) end'),
            ('    if self.timeout - elapsed <= 0 or resume_reason == "request_timer" then', '    if not unlimited and (self.timeout - elapsed <= 0 or resume_reason == "request_timer") then'),
            ('          player._timewaste_count = player._timewaste_count + elapsed', '          player._timewaste_count = console and 0 or (player._timewaste_count + elapsed)'),
            ('      local reply = self.timeout > 0 and self:_checkReply(player, use_ai) or "__notready"', '      local reply = (unlimited or self.timeout > 0) and self:_checkReply(player, use_ai) or "__notready"'),
        ],
        'Fk/Base/Config.qml': [
            ('  property int preferredTimeout\n', '  property int preferredTimeout\n  property bool qiaoConsoleStart: false\n  property int qiaoConsoleTimeout: -1\n  readonly property int qiaoOperationTimeout: qiaoConsoleStart ? qiaoConsoleTimeout : preferredTimeout\n'),
        ],
        'Fk/Pages/Common/Init.qml': [
            ('            Backend.startServer(9527);', '            Config.qiaoConsoleStart = true;\n            Config.qiaoConsoleTimeout = -1;\n            Backend.startServer(9527);'),
            ('      Backend.startServer(9527);', '      Config.qiaoConsoleStart = true;\n      Config.qiaoConsoleTimeout = -1;\n      Backend.startServer(9527);'),
            ('            serverDialog.show();', '            Config.qiaoConsoleStart = false;\n            serverDialog.show();'),
            ('data.timeout ?? Config.preferredTimeout', 'data.timeout ?? Config.qiaoOperationTimeout'),
        ],
        'Fk/Pages/Lobby/CreateRoom.qml': [
            ('Config.preferredTimeout', 'Config.qiaoOperationTimeout'),
        ],
        'Fk/Pages/Lobby/RoomGeneralSettings.qml': [
            ('  function refreshGameMode(gameMode) {\n    const data = Lua.fn(`function(mode)\n      local m = Fk.game_modes[mode]', '  function refreshGameMode(gameMode) {\n    // Guard empty/unregistered modes before the settings query. The lobby can\n    // emit the initial empty value before a valid mode is assigned.\n    const valid = Lua.fn(`function(mode)\n      return Fk.game_modes[mode] ~= nil\n    end`)(gameMode);\n    if (!valid) return;\n    const data = Lua.fn(`function(mode)\n      local m = Fk.game_modes[mode]'),
            ('    if (data.playerNums !== undefined) {', '    if (!data) return;\n    if (data.playerNums !== undefined) {'),
            ('        title: Lua.tr("Operation timeout")\n        from: 10', '        title: Lua.tr("Operation timeout")\n        unlimitedText: Config.qiaoConsoleStart ? "无限" : ""\n        items: Config.qiaoConsoleStart ? [-1, ...Array.from({length: 51}, (_, i) => i + 10)] : []\n        from: Config.qiaoConsoleStart ? -1 : 10'),
            ('        value: Config.preferredTimeout', '        value: Config.qiaoOperationTimeout'),
            ('          Config.preferredTimeout = value;', '          if (Config.qiaoConsoleStart) Config.qiaoConsoleTimeout = value;\n          else Config.preferredTimeout = value;'),
        ],
        'Fk/Widgets/SpinRow.qml': [
            ('  property bool editable: false', '  property bool editable: false\n  property string unlimitedText: ""'),
            ('      if (root.items.length === 0) return value;', '      if (value < 0 && root.unlimitedText) return root.unlimitedText;\n      if (root.items.length === 0) return value;'),
        ],
        'LunarLtk/Models/RoomModel.qml': [
            ('    if (total <= elapsed) {', '    if (total >= 0 && total <= elapsed) {'),
            ('    requestDuration = total - elapsed;', '    requestDuration = total < 0 ? -1 : total - elapsed;'),
        ],
        'LunarLtk/Pages/RoomBase.qml': [
            ('      item.progressBar.visible = true;', '      item.progressBar.visible = timeout >= 0;'),
            ('    roomScene.progressAnim.duration = dataModel.requestDuration;', '    roomScene.progressAnim.duration = Math.max(0, dataModel.requestDuration);'),
        ],
        'LunarLtk/Pages/Room.qml': [
            ('        running: progress.visible\n', '        running: progress.visible && roomScene.dataModel.requestDuration >= 0\n'),
            ('          if (!progressAnim.running) return false;', '          if (!progress.visible) return false;'),
        ],
    }


def apply(runtime=RUNTIME):
    """Validate every replacement before writing, and support repeated syncs."""
    pending = {}
    layouts = [path for path in (runtime, runtime / 'packages/freekill-core')
               if (path / 'lua/freekill.lua').is_file()]
    if not layouts:
        raise RuntimeError(f'FreeKill core not found: {runtime}')
    for layout in layouts:
        pending.update(prepare_layout(layout))
    for path, content in pending.items():
        path.write_text(content, encoding='utf-8')
    print(f'Console timeout compatibility ready ({len(pending)} files updated)')


def prepare_layout(layout):
    pending = {}
    for relative, edits in replacements().items():
        path = layout / relative
        original = path.read_text(encoding='utf-8')
        updated = original
        # Migrate markers from earlier local-console patches.
        for old_name in ('hanjinConsoleStart', 'hanjinConsoleTimeout', 'hanjinOperationTimeout'):
            updated = updated.replace(old_name, 'qiao' + old_name[len('hanjin'):])
        for old, new in edits:
            if new in updated:
                continue
            if old.startswith(' '):
                # Avoid matching an indented occurrence inside another block.
                updated, count = re.subn('(?m)^' + re.escape(old), lambda _: new, updated)
            else:
                count = updated.count(old)
                updated = updated.replace(old, new)
            if not count:
                raise RuntimeError(f'Unsupported runtime content: {path}')
        if updated != original:
            pending[path] = updated
    return pending


if __name__ == '__main__':
    apply()
