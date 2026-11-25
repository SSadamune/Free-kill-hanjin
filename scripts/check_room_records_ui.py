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
for _, method in ipairs({ "discardCardsForDisplay", "pindianHistory" }) do
  local original = Client[method]
  Client[method] = function(self)
    local data = original(self)
    print("ROOM_PANEL " .. json.encode({ method = method, rows = data }))
    return data
  end
end
return __dofile("../../../tests/room_records.lua")
"""

WINDOW = """
import QtQuick
import QtQuick.Controls
ApplicationWindow {
  id: app
  visible: true; width: 700; height: 500
  property var pileData: []
  property var historyData: []
  DiscardPilePanel { id: pile; parent: app.contentItem; readCards: () => app.pileData }
  PindianPanel {
    id: results; anchors.fill: parent
    readHistory: () => app.historyData
    translate: key => key
  }
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
    piles = [s["rows"] for s in samples if s["method"] == "discardCardsForDisplay"]
    histories = [s["rows"] for s in samples if s["method"] == "pindianHistory"]
    pair = next(rows for rows in histories if rows[0]["reason"] == "first")
    joint = next(rows for rows in histories if rows[0]["joint"])
    initial = next(rows for rows in piles if len(rows) == 2)
    after_take = next(rows for rows in piles if len(rows) == 1)
    empty = next(rows for rows in piles if not rows)

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

    js("historyData = " + json.dumps(pair) + "; results.present(historyData[0]); results.present(historyData[1])")
    assert {"第 1 次拼点 · first", "♥6 → 9点", "平点", "另有 1 名角色，点开查看",
            f"{pair[0]['source']['seat']}号胜"} <= labels()
    assert js("results.pending.length") == 1
    QTest.qWait(6200)
    assert "第 2 次拼点 · second" in labels() and js("results.pending.length") == 0
    title = next(item for item in visible_items(window.contentItem())
                 if item.property("text") == "第 2 次拼点 · second")
    click(title)
    assert {"拼点记录", "第 1 次拼点 · first", "第 2 次拼点 · second",
            f"{pair[0]['targets'][2]['seat']}号胜"} <= labels()
    assert js("results.records.map(r => r.sequence).join(',')") == "2,1"
    close_panel()
    print("PASS pindian: multi-target, changed points, tie, timed sequence, history click")

    js("historyData = " + json.dumps(joint[:1]) + "; results.openHistory()")
    assert {"第 1 次共同拼点 · joint", f"{joint[0]['winner']}号位获胜"} <= labels()
    js("historyData = " + json.dumps(joint) + "; results.present(historyData[1])")
    assert {"第 2 次共同拼点 · joint", "无人获胜"} <= labels()
    close_panel()
    js("results.openHistory()")
    assert js("results.records.length") == 2 and "无人获胜" in labels()
    close_panel()
    assert not warnings, warnings
    print("PASS joint pindian: winner, tied leaders, live update, reopen")


if __name__ == "__main__":
    run()
