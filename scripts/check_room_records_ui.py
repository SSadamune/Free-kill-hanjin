"""Replay public discard and pindian data from the native tests in the room panels."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
RUNTIME = ROOT / ".dev/runtime/FreeKill-release"
sys.path.insert(0, str(ROOT / ".dev/qml-qa"))
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

from PySide6.QtCore import QObject, QPointF, Qt, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine, QQmlExpression
from PySide6.QtQuick import QQuickItem
from PySide6.QtTest import QTest


CAPTURE = """local Client = require "packages.qiao.pkg.qiao_mode.client"
local function emit(method, rows)
  -- FreeKill's Windows console may use a locale encoding when stdout is piped.
  local payload = json.encode({ method = method, rows = rows })
  print("ROOM_PANEL " .. (payload:gsub(".", function(byte) return string.format("%02x", byte:byte()) end)))
end
local discard = Client.discardCardsForDisplay
function Client:discardCardsForDisplay()
  local rows = discard(self)
  emit("pile", table.map(rows, function(row)
    local sample = table.simpleClone(row)
    if row.id then
      local card = Fk:getCardById(row.id, true)
      sample.face = { name = card.name, suit = card:getSuitString(), number = card.number }
    end
    return sample
  end))
  return rows
end
local broadcast = Room.doBroadcastNotify
function Room:doBroadcastNotify(cmd, data, ...)
  if cmd == "QiaoPindianResult" then emit("result", data) end
  return broadcast(self, cmd, data, ...)
end
return __dofile("../../../tests/room_records.lua")
"""

WINDOW = """
import QtQuick
import QtQuick.Controls
import LunarLtk
ApplicationWindow {
  id: app
  visible: true; width: 960; height: 540
  property var pileData: []
  onPileDataChanged: {
    for (const card of pileData) {
      if (card.face) Ltk.cards[card.id] = card.face;
    }
  }
  property int selectedSeat: 0
  property int inspected: 0
  Repeater {
    model: 7
    Rectangle {
      required property int index
      x: 120 + index * 90; y: 260; width: 88; height: 105
      MouseArea { anchors.fill: parent; onClicked: app.selectedSeat = parent.index + 1 }
    }
  }
  DiscardPilePanel { id: pile; parent: app.contentItem; readCards: () => app.pileData; onInspect: id => app.inspected = id }
  DiscardPileButton {
    id: discardButton
    anchors.top: parent.top; anchors.topMargin: 32
    anchors.right: parent.right; anchors.rightMargin: 120
    count: app.pileData.length
    onClicked: pile.open()
  }
  PindianDisplay { id: results; x: 144; y: 244; width: 672; cardPicture: name => "" }

}
"""


def capture():
    with tempfile.TemporaryDirectory(dir=ROOT / ".dev") as directory:
        runner = Path(directory) / "capture.lua"
        runner.write_text(CAPTURE, encoding="utf-8")
        command = [sys.executable, "scripts/test.py", "--file", str(runner), "--timeout", "90"]
        result = subprocess.run(command, cwd=ROOT, capture_output=True, encoding="utf-8",
                                env={**os.environ, "PYTHONIOENCODING": "utf-8"})
    if result.returncode:
        raise RuntimeError((result.stdout + result.stderr)[-4000:])
    return [json.loads(bytes.fromhex(line.split("ROOM_PANEL ", 1)[1])) for line in result.stdout.splitlines()
            if "ROOM_PANEL " in line]


def visible_items(root):
    for child in root.childItems():
        if child.isVisible():
            yield child
            yield from visible_items(child)


def install_card_fixture(engine, directory):
    """Load the engine's card renderer with an offscreen Lua/model bridge."""
    core = RUNTIME / "packages/freekill-core"
    originals = {
        "LunarLtk/Components": ("CardItem",),
        "LunarLtk/Models": ("CardModel",),
        "Fk/Components/Common": ("GlowText",),
        "Fk/Components/GameCommon": ("BasicItem", "BasicCard", "PokerCard"),
        "Fk/Widgets": ("TapHandler",),
    }

    def write(path, contents):
        file = directory / path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(contents, encoding="utf-8")

    for module, names in originals.items():
        module_name = module.replace("/", ".")
        write(module + "/qmldir", f"module {module_name}\n" + "".join(f"{name} 1.0 {name}.qml\n" for name in names))
        for name in names:
            rel = f"{module}/{name}.qml"
            shutil.copyfile(core / rel, directory / rel)

    write("LunarLtk/qmldir", "module LunarLtk\nimport LunarLtk.Models auto\nsingleton Ltk 1.0 Ltk.qml\n")
    write("LunarLtk/Ltk.qml", """
pragma Singleton
import QtQuick
import LunarLtk.Models
QtObject {
  property var cards: ({})
  function createCardModel(id, props) {
    const card = cards[id];
    return Qt.createComponent("LunarLtk.Models", "CardModel").createObject(null,
      Object.assign({cardId: id, extension: "qiao", picName: card.name}, card, props));
  }
}
""")
    write("Fk/qmldir", """module Fk
singleton Config 1.0 Config.qml
singleton Lua 1.0 Lua.qml
singleton SkinBank 1.0 SkinBank.qml
MediaArea 1.0 MediaArea.qml
""")
    write("Fk/Config.qml", 'pragma Singleton\nimport QtQuick\nQtObject { property string libianName: "Microsoft YaHei"; property string li2Name: libianName }\n')
    write("Fk/Lua.qml", "pragma Singleton\nimport QtQuick\nQtObject { function tr(text) { return text; } }\n")
    write("Fk/MediaArea.qml", "import QtQuick\nImage {}\n")
    write("Fk/SkinBank.qml", f"""
pragma Singleton
import QtQuick
QtObject {{
  readonly property string runtime: {json.dumps(RUNTIME.as_uri())}
  readonly property string project: {json.dumps(ROOT.as_uri())}
  readonly property string cardDir: runtime + "/image/card/"
  readonly property string cardSuitDir: cardDir + "suit"
  function searchBuiltinPic(folder, name) {{ return runtime + folder + name + ".png"; }}
  function getCardPicture(name) {{
    return typeof name === "string" && name.startsWith("qiao__")
      ? project + "/image/card/" + name + ".png"
      : cardDir + "unknown.png";
  }}
}}
""")
    write("Qt5Compat/GraphicalEffects/qmldir", "module Qt5Compat.GraphicalEffects\nGlow 1.0 Glow.qml\nRectangularGlow 1.0 RectangularGlow.qml\n")
    write("Qt5Compat/GraphicalEffects/Glow.qml",
          "import QtQuick\nItem { property Item source; property real radius; property real spread; property color color }\n")
    write("Qt5Compat/GraphicalEffects/RectangularGlow.qml",
          "import QtQuick\nItem { property real glowRadius; property real spread; property real cornerRadius; property color color }\n")
    engine.addImportPath(str(directory))


def run():
    samples = capture()
    piles = [s["rows"] for s in samples if s["method"] == "pile"]
    results = [s["rows"] for s in samples if s["method"] == "result"]
    initial = next(rows for rows in piles if len(rows) == 2 and any(c["lord"] for c in rows))
    same_rank = next(rows for rows in piles if {"空巢", "孤军"} <= {c.get("marks") for c in rows})
    after_take = next(rows for rows in piles if len(rows) == 1)
    empty = next(rows for rows in piles if not rows)
    pair = [r for r in results if not r["joint"]]
    joint = [r for r in results if r["joint"]]

    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    fixture = tempfile.TemporaryDirectory(dir=ROOT / ".dev")
    install_card_fixture(engine, Path(fixture.name))
    warnings = []
    engine.warnings.connect(lambda errors: warnings.extend(error.toString() for error in errors))
    url = QUrl.fromLocalFile(str(ROOT / "pkg/qiao_mode/qml/RoomPanelCheck.qml"))
    engine.loadData(WINDOW.encode(), url)
    assert engine.rootObjects(), warnings
    window = engine.rootObjects()[0]

    def js(code, scope=window):
        expression = QQmlExpression(engine.contextForObject(scope), scope, code)
        value, _ = expression.evaluate()
        assert not expression.hasError(), expression.error().toString()
        return value

    def labels():
        QTest.qWait(60)
        return {item.property("text") for item in visible_items(window.contentItem())
                if isinstance(item.property("text"), str)}

    def click(item):
        point = item.mapToScene(QPointF(item.width() / 2, item.height() / 2))
        QTest.mouseClick(window, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, point.toPoint())

    def close_panel():
        close = next(i for i in visible_items(window.contentItem()) if i.property("text") == "关闭"
                     and i.metaObject().indexOfSignal("clicked()") >= 0)
        click(close)
        QTest.qWait(200)

    js("pileData = " + json.dumps(initial))
    assert js("discardButton.count") == len(initial)
    button = next(item for item in visible_items(window.contentItem())
                  if item.property("text") == "弃牌堆")
    click(button)
    lord = next(card["name"] for card in initial if card["lord"])
    other = after_take[0]["name"]
    assert {lord, other} <= labels()
    for card in initial:
        face = next(item for item in visible_items(window.contentItem())
                    if item.objectName() == "discardCardFace"
                    and js("dataModel.cardId", item) == card["id"])
        assert face.property("known") and face.property("suit") == card["face"]["suit"]
        assert face.property("number") == card["face"]["number"]
        image_path = face.property("cardFrontSource").toLocalFile()
        assert Path(image_path) == ROOT / "image/card" / (card["face"]["name"] + ".png")
    first_card = next(item for item in visible_items(window.contentItem()) if item.property("text") == lord)
    click(first_card)
    assert js("inspected") == next(c["id"] for c in initial if c["lord"])
    click(window.findChild(QQuickItem, "lordFilter"))
    assert lord in labels() and other not in labels()
    search = window.findChild(QObject, "discardSearch")
    search.setProperty("text", other)
    assert "没有符合条件的牌" in labels()
    click(window.findChild(QQuickItem, "lordFilter"))
    assert other in labels() and lord not in labels()
    search.setProperty("text", "")
    js("pileData = " + json.dumps(after_take) + "; pile.refresh()")
    assert js("discardButton.count") == 1
    assert other in labels() and lord not in labels()
    js("pileData = pileData.concat([{name:'未知牌'}]); pile.refresh()")
    assert "未知牌" in labels()
    covered = next(item for item in visible_items(window.contentItem())
                   if item.objectName() == "discardCardFace" and not item.property("known"))
    click(covered)
    assert js("inspected") == next(c["id"] for c in initial if c["lord"])
    js("pileData = " + json.dumps(empty) + "; pile.refresh()")
    assert "弃牌堆为空" in labels()
    close_panel()
    print("PASS discard: search, lord filter, removed card, shuffle")

    js("pileData = " + json.dumps(same_rank) + "; pile.open()")
    assert {"空巢", "孤军"} <= labels()
    club_fours = {card["id"] for card in same_rank if card["marks"] in {"空巢", "孤军"}}
    visible_faces = [item for item in visible_items(window.contentItem())
                     if item.objectName() == "discardCardFace"
                     and js("dataModel.cardId", item) in club_fours]
    assert len(visible_faces) == 2
    assert all(face.property("suit") == "club" and face.property("number") == 4 for face in visible_faces)
    close_panel()
    print("PASS discard faces: original art, suit, rank, and distinct marks for identical ranks")

    # Scroll partway through the public pile. Insert a row, then remove the first visible card.
    large = [dict(initial[0], id=100+i) for i in range(60)]
    js("pileData = " + json.dumps(large) + "; pile.open()")
    QTest.qWait(200)
    grid = window.findChild(QQuickItem, "discardGrid")
    grid.setProperty("contentY", grid.property("originY") + 5 * grid.property("cellHeight") + 9)
    engine.rootContext().setContextProperty("testedGrid", grid)

    def first_visible():
        return js("testedGrid.model[testedGrid.indexAt(2, testedGrid.contentY + 1)].id")
    first = first_visible()
    columns = round(grid.width() / grid.property("cellWidth"))
    updated = [dict(initial[0], id=i) for i in range(1, columns + 1)] + large
    js("pileData = " + json.dumps(updated) + "; pile.refresh()")
    QTest.qWait(80)
    assert first_visible() == first
    js("pileData = pileData.filter(c => c.id !== " + str(int(first)) + "); pile.refresh()")
    QTest.qWait(80)
    assert first_visible() == first + 1
    grid.setProperty("contentY", grid.property("originY"))
    js("pileData = [Object.assign({}, pileData[0], {id:999})].concat(pileData); pile.refresh()")
    assert first_visible() == 999
    close_panel()
    print("PASS discard viewport: insert, removed anchor, follow newest at top")

    def present(result):
        js("results.present(" + json.dumps(result) + ")")
    present(pair[0])
    assert {"6 → 9", "双方都没赢"} <= {t.lstrip("♥") for t in labels()}
    assert {str(c["seat"]) + " 号位" for c in pair[0]["cards"]} <= labels()
    QTest.mouseClick(window, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, QPointF(464, 290).toPoint())
    assert js("selectedSeat") == 4
    js("results.clear()")
    assert not js("results.visible")
    present(pair[1])
    assert str(pair[1]["cards"][1]["winner"]) + " 号位赢得拼点" in labels()
    present(joint[0])
    assert str(joint[0]["winner"]) + " 号位赢得拼点" in labels()
    present(joint[1])
    assert "无人获胜" in labels()
    QTest.qWait(2650)
    assert js("results.visible")
    QTest.qWait(520)
    assert not js("results.visible")
    assert not warnings, warnings
    print("PASS pindian: seat and points, winners and ties, click through, replace and expire")


if __name__ == "__main__":
    run()
