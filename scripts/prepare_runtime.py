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
            ('  property int preferredTimeout\n', '  property int preferredTimeout\n  property bool hanjinConsoleStart: false\n  property int hanjinConsoleTimeout: -1\n  readonly property int hanjinOperationTimeout: hanjinConsoleStart ? hanjinConsoleTimeout : preferredTimeout\n'),
        ],
        'Fk/Pages/Common/Init.qml': [
            ('            Backend.startServer(9527);', '            Config.hanjinConsoleStart = true;\n            Config.hanjinConsoleTimeout = -1;\n            Backend.startServer(9527);'),
            ('      Backend.startServer(9527);', '      Config.hanjinConsoleStart = true;\n      Config.hanjinConsoleTimeout = -1;\n      Backend.startServer(9527);'),
            ('            serverDialog.show();', '            Config.hanjinConsoleStart = false;\n            serverDialog.show();'),
            ('data.timeout ?? Config.preferredTimeout', 'data.timeout ?? Config.hanjinOperationTimeout'),
        ],
        'Fk/Pages/Lobby/CreateRoom.qml': [
            ('Config.preferredTimeout', 'Config.hanjinOperationTimeout'),
        ],
        'Fk/Pages/Lobby/RoomGeneralSettings.qml': [
            ('        title: Lua.tr("Operation timeout")\n        from: 10', '        title: Lua.tr("Operation timeout")\n        unlimitedText: Config.hanjinConsoleStart ? "无限" : ""\n        items: Config.hanjinConsoleStart ? [-1, ...Array.from({length: 51}, (_, i) => i + 10)] : []\n        from: Config.hanjinConsoleStart ? -1 : 10'),
            ('        value: Config.preferredTimeout', '        value: Config.hanjinOperationTimeout'),
            ('          Config.preferredTimeout = value;', '          if (Config.hanjinConsoleStart) Config.hanjinConsoleTimeout = value;\n          else Config.preferredTimeout = value;'),
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
    for relative, edits in replacements().items():
        path = runtime / relative
        original = path.read_text(encoding='utf-8')
        updated = original
        for old, new in edits:
            # Exact lines avoid matching an indented occurrence inside another block.
            if new in updated:
                continue
            if old not in updated:
                raise RuntimeError(f'Unsupported runtime content: {relative}')
            if old.startswith(' '):
                updated, count = re.subn('(?m)^' + re.escape(old), lambda _: new, updated)
                if not count:
                    raise RuntimeError(f'Unsupported runtime indentation: {relative}')
            else:
                updated = updated.replace(old, new)
        if updated != original:
            pending[path] = updated
    for path, content in pending.items():
        path.write_text(content, encoding='utf-8')
    print(f'Console timeout compatibility ready ({len(pending)} files updated)')


if __name__ == '__main__':
    apply()
