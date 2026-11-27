"""Verify the stock lobby's selection controls, room requests, and settings summary.

Run with PySide6 available and the development runtime's freekill-core checkout
present. The fixture loads unpatched stock QML. Services and the Lua bridge are
stubbed, with the real Lua feasibility rules covered by tests/locked_factions.lua.
"""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from tempfile import TemporaryDirectory

ROOT = Path(__file__).resolve().parents[1]
CORE = ROOT / '.dev/runtime/FreeKill-release/packages/freekill-core'
sys.path.insert(0, str(ROOT / '.dev/qml-qa'))
os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
os.environ.setdefault('QT_QUICK_BACKEND', 'software')
os.environ.setdefault('QT_QUICK_CONTROLS_STYLE', 'Basic')

from PySide6.QtCore import QTimer, QUrl, qInstallMessageHandler
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
widgets = [
    'ActionRow', 'EntryRow', 'PreferenceGroup', 'PreferencePage', 'SpinRow',
    'SwitchRow',
]
lobby = ['CreateRoom', 'LuaSettingsPage', 'RoomGeneralSettings']
singletons = {
    'Config': '''
  property int preferedPlayerNum: 8
  property int preferredTimeout: 30
  property int roomTimeout: 29
  property string preferedMode: ""
  property string headerName: ""
  property bool hideScreenName: false
  property var serverHiddenPacks: []
  property var curScheme: ({ banPkg: {}, normalPkg: {}, banCardPkg: [] })
  function saveConf() {}
''',
    'Self': 'property string screenName: "Tester"',
    'App': 'function setBusy(busy) {} function showToast(text) { console.log(text); }',
    'ClientInstance': '''
  property var lastRequest
  function notifyServer(method, payload) { lastRequest = [method, payload]; }
''',
    'Db': '''
  property var data: ({})
  function getModeSettings(key) { return JSON.parse(data[key] ?? "{}"); }
  function saveModeSettings(key, cfg) { data[key] = JSON.stringify(cfg); }
  function sanitizeRoomName(name) { return name; }
''',
    'Lua': '''
  property var client
  function tr(label) {
    const ruleHelp = RULE_HELP;
    return ruleHelp[label] ?? ({
      qiao_locked_landlord: "斗地主", qiao_locked_2v2: "2v2", qiao_locked_human_vs_ai: "人机对抗",
      "Player num": "房间人数",
      qiao_locked_game_rule: "游戏规则", "Enable free assign": "自由选将", "$RoomName": "%1",
    })[label] ?? (label === undefined ? "" : String(label));
  }
  function hasTranslate(label) {
    return label === "#Enable free assign" ? "自由选将" : null;
  }
  function getUIDataOfSettings(mode, cfg, board) {
    return fn("GetUIDataOfSettings")(mode, cfg, board);
  }
  function fn(code) {
    if (code === "GetUIDataOfSettings") return (mode, cfg, board) => {
      const group = { _qml: { name: "PreferenceGroup" }, _needcopy: true, _children: [] };
      const properties = { _qml: { ext: "GameProperties" }, _needcopy: true, _children: [] };
      if (board) {
        properties.title = "Properties";
        if (mode === "qiao_free_mode") properties._children.push({
          _qml: { name: "SpinRow" }, _settingsKey: "luckTime", _children: [],
          title: "Luck Card Times", from: 0, to: 999,
        });
        if (mode !== "qiao_locked_mode") group._children.push({
          _qml: { name: "SwitchRow" }, _settingsKey: "enableFreeAssign", _children: [],
          title: "Enable free assign",
        });
        return group._children.length ? [properties, group] : [properties];
      }
      properties.selectionSettings = true;
      const locked = mode === "qiao_locked_mode";
      properties._children = [
        { _qml: { name: "SpinRow" }, _settingsKey: "qiao_offer_count", _children: [],
          title: "qiao_offer_count", from: locked ? 2 : 5, to: locked ? 5 : 10, editable: true,
          value: cfg._mode.qiao_offer_count ?? (locked ? 5 : 7) },
        { _qml: { name: "SpinRow" }, _settingsKey: "generalTimeout", _children: [],
          title: "Choose General timeout", from: 10, to: 300, editable: true,
          value: cfg._mode.generalTimeout ?? 90 },
      ];
      if (locked) {
        group._children.push({
          _qml: { ext: "LockedGameRuleRow" }, _settingsKey: "qiao_locked_game_rule", _children: [],
          title: "qiao_locked_game_rule", model: ["qiao_locked_landlord", "qiao_locked_2v2", "qiao_locked_human_vs_ai"],
          modeName: mode, roomSizes: { qiao_locked_landlord: 3, qiao_locked_2v2: 4 },
          value: cfg._mode.qiao_locked_game_rule ?? "qiao_locked_landlord",
        });
      }
      return [group, properties];
    };
    if (code.includes("minPlayer =")) return mode =>
      mode === "qiao_locked_mode" ? { minPlayer: 2, maxPlayer: 10 } : { minPlayer: 2, maxPlayer: 8 };
    if (code.includes("mode:feasible")) return (mode, cfg) => {
      if (mode !== "qiao_locked_mode") return true;
      const rule = cfg._mode.qiao_locked_game_rule;
      const validCount = rule === "qiao_locked_human_vs_ai" ? cfg.playerNum >= 2 && cfg.playerNum <= 10 :
        cfg.playerNum === (rule === "qiao_locked_2v2" ? 4 : 3);
      return validCount && !cfg.qiaoLockedBanScheme?.normalPkg?.qiao;
    };
    if (code.includes("getBoardGame")) return () => "lunarltk";
    if (code.includes(" ~= nil")) return mode => !!mode;
    throw new Error("Unexpected Lua query: " + code);
  }
  function createComponent(spec) {
    return spec.ext ? Qt.createComponent(Qt.resolvedUrl("../" + spec.ext + ".qml")) :
      Qt.createComponent("Fk.Widgets", spec.name);
  }
''',
}

window = '''
import QtQuick
import QtQuick.Controls
import Fk
import Fk.Pages.Common

ApplicationWindow {
  visible: true
  width: 1050
  height: 700
  Loader { id: lobbyLoader; anchors.fill: parent; source: "Fk/Pages/Lobby/CreateRoom.qml" }
  Component { id: roomSummary; RoomInfoContainer {} }
  readonly property Item createRoom: lobbyLoader.item
  property int phase: 0

  function find(item, predicate) {
    if (predicate(item)) return item;
    for (const child of item.children) {
      const found = find(child, predicate);
      if (found) return found;
    }
    return null;
  }

  function check(value, label) {
    if (!value) throw Error(label);
  }

  function switchMode(mode) {
    Config.preferedMode = mode;
    find(createRoom, item => item.objectName === "gameModeSelectPage").gameMode = mode;
  }

  function checkRuleHelp(rule, id) {
    const key = "help: " + id;
    const subtitle = Lua.tr(key);
    check(subtitle !== key && subtitle.length >= 20 && subtitle.length <= 30, "missing or long rule help");
    check(rule.subTitle === subtitle, "wrong description for " + id);
  }

  function checkSelectionControls(offers, timeout, count, seconds) {
    const properties = find(createRoom, item => item.objectName === "qiaoGameProperties");
    const selection = find(properties, item => item.objectName === "qiaoSelectionSettings");
    check(offers.parent === selection && timeout.parent === selection,
      "selection controls belong to the game properties section");
    check(offers.editable && timeout.editable && offers.value === count && timeout.value === seconds,
      "game properties show editable mode defaults or saved values");
  }

  function checkRoomSummary(settings, count, seconds) {
    Lua.client = { settings };
    const summary = roomSummary.createObject(createRoom, { visible: false, width: 345, height: 500 });
    summary.viewFalse = true;
    const times = summary.settings.filter(row => row[0] === "Choose General timeout");
    check(times.length === 1 && times[0][1] === String(seconds), "room summary should show only the effective timeout");
    check(summary.settings.some(row => row[0] === "qiao_offer_count" && row[1] === String(count)),
      "room summary should show the configured offer count");
    check(!summary.settings.some(row => ["Select generals num", "Luck Card Times", "自由选将"].includes(row[0])),
      "old settings should stay out of the room summary even when false values are shown");
    summary.destroy();
  }

  Timer {
    interval: 75
    running: true
    repeat: true
    onTriggered: {
      try {
        const playerCount = find(createRoom, item => item.title === "房间人数");
        const rule = find(createRoom, item => item.title === "游戏规则");
        const freeAssign = find(createRoom, item => item.title === "自由选将");
        const offers = find(createRoom, item => item.title === "qiao_offer_count");
        const timeout = find(createRoom, item => item.title === "Choose General timeout");
        const confirm = find(createRoom, item => item.text === "OK");
        if (phase === 0) {
          Db.saveModeSettings("lunarltk", { enableFreeAssign: true, generalNum: 3, generalTimeout: 10, luckTime: 1 });
          Db.saveModeSettings("lunarltk:qiao_locked_mode", { generalTimeout: 45 });
          switchMode("qiao_locked_mode");
          find(createRoom, item => item.objectName === "nativeSidebar").currentIndex = 2;
        } else if (phase === 1) {
          check(rule && rule.parent.children[1] === rule, "rule should be the first setting");
          check(freeAssign === null, "locked mode should not display free assignment");
          checkSelectionControls(offers, timeout, 5, 45);
          check(offers.visible && timeout.visible, "the game settings tab should show the relocated controls");
          check(rule.suffixLoader.item.displayText === "斗地主", "default choice");
          checkRuleHelp(rule, "qiao_locked_landlord");
          check(!playerCount.enabled && playerCount.value === 3, "default capacity should be disabled at 3");
          check(createRoom.config.playerNum === 3 && confirm.enabled, "3-player room confirmation");
          confirm.clicked();
          check(ClientInstance.lastRequest[0] === "CreateRoom" && ClientInstance.lastRequest[1][1] === 3,
            "native CreateRoom request should send capacity 3");
          check(ClientInstance.lastRequest[1][3]._mode.qiao_offer_count === 5 &&
            ClientInstance.lastRequest[1][3]._mode.generalTimeout === 45,
            "native request should include both the default and saved selection values");
          checkRoomSummary(ClientInstance.lastRequest[1][3], 5, 45);
          offers.suffixLoader.item.value = 4;
          timeout.suffixLoader.item.value = 55;
          find(createRoom, item => item.objectName === "nativeSidebar").currentIndex = 3;
          rule.suffixLoader.item.popup.open();
        } else if (phase === 2) {
          const popup = rule.suffixLoader.item.popup;
          check(popup.visible, "the game rule dropdown should open");
          const secondOption = find(popup.contentItem, item => item.text === "2v2");
          check(secondOption && secondOption.visible, "2v2 should be a visible popup option");
          secondOption.clicked();
        } else if (phase === 3) {
          check(rule.suffixLoader.item.displayText === "2v2", "2v2 choice");
          checkRuleHelp(rule, "qiao_locked_2v2");
          check(!playerCount.enabled && playerCount.value === 4, "2v2 capacity should be disabled at 4");
          check(createRoom.config.playerNum === 4 && confirm.enabled, "4-player room confirmation");
          confirm.clicked();
          check(ClientInstance.lastRequest[0] === "CreateRoom" && ClientInstance.lastRequest[1][1] === 4,
            "native CreateRoom request should send capacity 4");
          check(ClientInstance.lastRequest[1][3]._mode.qiao_locked_game_rule === "qiao_locked_2v2",
            "native CreateRoom request should send selected rule");
          check(ClientInstance.lastRequest[1][3]._mode.qiao_offer_count === 4 &&
            ClientInstance.lastRequest[1][3]._mode.generalTimeout === 55 &&
            ClientInstance.lastRequest[1][3]._game.generalTimeout === 10,
            "editing game properties should send the mode values and preserve the shared profile");
          checkRoomSummary(ClientInstance.lastRequest[1][3], 4, 55);
          Config.curScheme.normalPkg.qiao = ["qiao_heg__wei001"];
          Config.curSchemeChanged();
        } else if (phase === 4) {
          check(!confirm.enabled, "an infeasible ban scheme should disable room creation");
          Config.curScheme = ({ banPkg: {}, normalPkg: {}, banCardPkg: [] });
        } else if (phase === 5) {
          check(confirm.enabled, "restoring a feasible scheme should re-enable room creation");
          switchMode("qiao_free_mode");
        } else if (phase === 6) {
          check(playerCount.enabled && rule === null, "switching away should release the spinner");
          check(freeAssign?.enabled && freeAssign.suffixLoader.item.checked,
            "switching away should restore the saved free assignment setting");
          checkSelectionControls(offers, timeout, 7, 90);
          const luck = find(createRoom, item => item.title === "Luck Card Times");
          check(luck?.parent === offers.parent.parent && luck.value === 1,
            "free mode should display the effective shared luck setting in game properties");
          playerCount.value = 6;
          check(createRoom.config.playerNum === 6, "the other mode should allow manual capacity");
          switchMode("qiao_locked_mode");
        } else if (phase === 7) {
          check(rule.suffixLoader.item.displayText === "2v2", "saved 2v2 choice should be restored");
          checkSelectionControls(offers, timeout, 4, 55);
          checkRuleHelp(rule, "qiao_locked_2v2");
          check(!playerCount.enabled && playerCount.value === 4, "saved rule should restore capacity 4");
          rule.suffixLoader.item.activated(0);
        } else if (phase === 8) {
          check(!playerCount.enabled && playerCount.value === 3, "switching back should restore capacity 3");
          checkRuleHelp(rule, "qiao_locked_landlord");
          rule.suffixLoader.item.popup.open();
        } else if (phase === 9) {
          const popup = rule.suffixLoader.item.popup;
          const humanVsAI = find(popup.contentItem, item => item.text === "人机对抗");
          check(popup.visible && humanVsAI && humanVsAI.visible, "human vs AI should be visible next to old rules");
          humanVsAI.clicked();
        } else if (phase === 10) {
          check(rule.suffixLoader.item.displayText === "人机对抗", "human vs AI choice");
          checkRuleHelp(rule, "qiao_locked_human_vs_ai");
          check(playerCount.enabled, "human vs AI should enable capacity changes");
          playerCount.value = 9;
        } else if (phase === 11) {
          check(playerCount.value === 9 && createRoom.config.playerNum === 9 && confirm.enabled, "editable capacity above 4");
          createRoom.isChangeRoom = true;
          confirm.clicked();
          check(ClientInstance.lastRequest[0] === "ChangeRoom" && ClientInstance.lastRequest[1][1] === 9,
            "native ChangeRoom request should send the chosen human vs AI capacity");
          check(ClientInstance.lastRequest[1][3]._mode.qiao_locked_game_rule === "qiao_locked_human_vs_ai",
            "native CreateRoom request should send human vs AI");
          find(createRoom, item => item.objectName === "nativeSidebar").currentIndex = 3;
          rule.suffixLoader.item.activated(1);
        } else if (phase === 12) {
          check(!playerCount.enabled && playerCount.value === 4, "switching back to 2v2 should lock capacity at 4");
          checkRuleHelp(rule, "qiao_locked_2v2");
          switchMode("qiao_heg_mode");
        } else if (phase === 13) {
          checkSelectionControls(offers, timeout, 7, 90);
          check(freeAssign?.enabled && find(createRoom, item => item.title === "Luck Card Times") === null,
            "collection mode should show free assignment and omit shared luck");
          console.log("PASS: built-in lobby uses editable game properties and sends isolated mode settings");
          Qt.exit(0);
        }
        phase++;
      } catch (error) {
        console.error("FAIL phase " + phase + ": " + error);
        Qt.exit(1);
      }
    }
  }
}
'''

def write(folder, name, content):
    path = folder / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding='utf-8')

def copy_from_stock(folder, path):
    output = folder / path
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(subprocess.check_output(['git', '-C', str(CORE), 'show', 'HEAD:' + path]))

def main():
    translations = (ROOT / 'pkg/qiao_mode/init.lua').read_text(encoding='utf-8')
    rule_help = dict(re.findall(
        r'\["(help: qiao_locked_(?:game_rule|landlord|2v2|human_vs_ai))"\] = "([^"]+)"',
        translations,
    ))
    qInstallMessageHandler(lambda _level, _context, message: print(message, flush=True))
    with TemporaryDirectory(dir=ROOT / '.dev') as tmp:
        folder = Path(tmp)
        for name in widgets:
            copy_from_stock(folder, f'Fk/Widgets/{name}.qml')
        for name in lobby:
            copy_from_stock(folder, f'Fk/Pages/Lobby/{name}.qml')
        copy_from_stock(folder, 'Fk/Pages/Common/RoomInfoContainer.qml')
        write(folder, 'Fk/Pages/Common/qmldir', 'module Fk.Pages.Common\n'
              'RoomInfoContainer 1.0 RoomInfoContainer.qml\n')
        write(folder, 'Fk/Components/WaitingRoom/qmldir', 'module Fk.Components.WaitingRoom\n'
              'WButton 1.0 WButton.qml\n')
        write(folder, 'Fk/Components/WaitingRoom/WButton.qml', '''import QtQuick
Item {
  property alias bg: background
  property alias border: background.border
  property alias title: label
  property alias text: label.text
  property alias textFont: label.font
  signal clicked()
  Rectangle { id: background }
  Text { id: label }
}
''')

        write(folder, 'Fk/Widgets/CommonScrollBar.qml', 'import QtQuick.Controls\nScrollBar {}')
        write(folder, 'Fk/Widgets/SideBarSwitcher.qml',
              'import QtQuick\nItem { objectName: "nativeSidebar"; property var model; property int currentIndex: 0 }')
        write(folder, 'Fk/Widgets/ButtonContent.qml', 'import QtQuick.Controls\nButton {}')
        widget_names = widgets + ['CommonScrollBar', 'SideBarSwitcher', 'ButtonContent']
        write(folder, 'Fk/Widgets/qmldir', 'module Fk.Widgets\n' +
              '\n'.join(f'{name} 1.0 {name}.qml' for name in widget_names) + '\n')

        write(folder, 'Fk/Pages/Lobby/GameModeSelectPage.qml',
              'import QtQuick\nItem { objectName: "gameModeSelectPage"; property string gameMode: "" }')
        for name in ('RoomPackageSettings', 'BanGeneralSetting'):
            write(folder, f'Fk/Pages/Lobby/{name}.qml', 'import QtQuick\nItem {}')
        lobby_names = lobby + ['GameModeSelectPage', 'RoomPackageSettings', 'BanGeneralSetting']
        write(folder, 'Fk/Pages/Lobby/qmldir', 'module Fk.Pages.Lobby\n' +
              '\n'.join(f'{name} 1.0 {name}.qml' for name in lobby_names) + '\n')

        write(folder, 'Fk/qmldir', 'module Fk\n' +
              '\n'.join(f'singleton {name} 1.0 {name}.qml' for name in singletons) + '\n')
        for name, body in singletons.items():
            if name == 'Lua':
                body = body.replace('RULE_HELP', json.dumps(rule_help, ensure_ascii=False))
            write(folder, f'Fk/{name}.qml', 'pragma Singleton\nimport QtQuick\nQtObject {\n' + body + '\n}\n')
        write(folder, 'LunarLtk/qmldir', 'module LunarLtk\nsingleton Ltk 1.0 Ltk.qml\n')
        write(folder, 'LunarLtk/Ltk.qml', 'pragma Singleton\nimport QtQuick\n'
              'QtObject { function getAllCardPack() { return []; } }')

        for name in ('GameProperties.qml', 'LockedGameRuleRow.qml'):
            write(folder, name, (ROOT / 'pkg/qiao_mode/qml' / name).read_text(encoding='utf-8'))
        write(folder, 'Test.qml', window)
        app = QGuiApplication([])
        engine = QQmlApplicationEngine()
        engine.addImportPath(str(folder))
        engine.exit.connect(app.exit)
        engine.load(QUrl.fromLocalFile(str(folder / 'Test.qml')))
        if not engine.rootObjects():
            raise SystemExit(1)
        QTimer.singleShot(8000, lambda: app.exit(1))
        return app.exec()

if __name__ == '__main__':
    raise SystemExit(main())
