"""Replay public discard and pindian data from the native tests in the room panels."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".dev/qml-qa"))
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")

from PySide6.QtCore import QObject, QPointF, Qt, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine, QQmlExpression
from PySide6.QtQuick import QQuickItem
from PySide6.QtTest import QTest


CAPTURE = """local Client = require "packages.qiao.pkg.qiao_mode.client"
local discard = Client.discardCardsForDisplay
function Client:discardCardsForDisplay()
  local rows = discard(self)
  print("ROOM_PANEL " .. json.encode({ method = "pile", rows = rows }))
  return rows
end
local broadcast = Room.doBroadcastNotify
function Room:doBroadcastNotify(cmd, data, ...)
  if cmd == "QiaoPindianResult" then print("ROOM_PANEL " .. json.encode({ method = "result", rows = data })) end
  return broadcast(self, cmd, data, ...)
end
return __dofile("../../../tests/room_records.lua")
"""

WINDOW = """
import QtQuick
import QtQuick.Controls
ApplicationWindow {
  id: app
  visible: true; width: 960; height: 540
  property var pileData: []
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
    return [json.loads(line.split("ROOM_PANEL ", 1)[1]) for line in result.stdout.splitlines()
            if "ROOM_PANEL " in line]


def visible_items(root):
    for child in root.childItems():
        if child.isVisible():
            yield child
            yield from visible_items(child)


def run():
    samples = capture()
    piles = [s["rows"] for s in samples if s["method"] == "pile"]
    results = [s["rows"] for s in samples if s["method"] == "result"]
    initial = next(rows for rows in piles if len(rows) == 2 and any(c["lord"] for c in rows))
    after_take = next(rows for rows in piles if len(rows) == 1)
    empty = next(rows for rows in piles if not rows)
    pair = [r for r in results if not r["joint"]]
    joint = [r for r in results if r["joint"]]

    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    warnings = []
    engine.warnings.connect(lambda errors: warnings.extend(error.toString() for error in errors))
    url = QUrl.fromLocalFile(str(ROOT / "pkg/qiao_mode/qml/RoomPanelCheck.qml"))
    engine.loadData(WINDOW.encode(), url)
    assert engine.rootObjects(), warnings
    window = engine.rootObjects()[0]

    def js(code):
        expression = QQmlExpression(engine.contextForObject(window), window, code)
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

    js("pileData = " + json.dumps(initial) + "; pile.open()")
    lord = next(card["name"] for card in initial if card["lord"])
    other = after_take[0]["name"]
    assert {lord, other} <= labels()
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
    assert other in labels() and lord not in labels()
    js("pileData = " + json.dumps(empty) + "; pile.refresh()")
    assert "弃牌堆为空" in labels()
    close_panel()
    print("PASS discard: search, lord filter, removed card, shuffle")

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
    updated = [dict(initial[0], id=i) for i in range(4)] + large
    js("pileData = " + json.dumps(updated) + "; pile.refresh()")
    QTest.qWait(80)
    assert first_visible() == first
    js("pileData = pileData.filter(c => c.id !== " + str(int(first)) + "); pile.refresh()")
    QTest.qWait(80)
    assert first_visible() == first + 1
    grid.setProperty("contentY", grid.property("originY"))
    js("pileData = [{id:999,name:'测试'}].concat(pileData); pile.refresh()")
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
