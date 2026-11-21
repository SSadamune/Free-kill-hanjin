"""Replay native array-summon requests on FreeKill's offscreen ChoicesBox.

Uses the same PySide6 environment as check_free_assign_ui.py.
"""
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

from PySide6.QtCore import QPointF, Qt, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickItem
from PySide6.QtTest import QTest


# Capture the public request format and the translations of this test room.
# Only the player's display name and Lua translation bridge are supplied to Qt.
CAPTURE = '''local setData = Request.setData
function Request:setData(player, data)
  if self.command == "AskForChoices" and data[5] == "qiao__array_summon" then
    local key, id = data[6]:match("^(.-):(-?%d+)$")
    if id then
      local owner = self.room.current
      assert(owner.id == tonumber(id), "array prompt names the wrong player")
      local source = Fk:translate(owner.general)
      local labels = {[key] = Fk:translate(key), Cancel = Fk:translate("Cancel")}
      for _, raw in ipairs(data[2]) do
        local parts = raw:split(":")
        labels[parts[1]] = Fk:translate(parts[1])
        if parts[4] then labels[parts[4]] = Fk:translate(parts[4]) end
      end
      print("ARRAY_QT " .. json.encode({data, source, labels}))
    end
  end
  return setData(self, player, data)
end
return __dofile("../../../tests/array_summon.lua")
'''


def samples(directory):
    runner = directory / "capture.lua"
    runner.write_text(CAPTURE, encoding="utf-8")
    result = subprocess.run([sys.executable, str(ROOT / "scripts/test.py"), "--file",
                             str(runner), "--timeout", "150"], cwd=ROOT, capture_output=True,
                            encoding="utf-8", env={**os.environ, "PYTHONIOENCODING": "utf-8"})
    if result.returncode:
        raise RuntimeError((result.stdout + result.stderr)[-5000:])
    return [json.loads(line.split("ARRAY_QT ", 1)[1]) for line in result.stdout.splitlines()
            if "ARRAY_QT " in line]


def prepare(directory):
    for name in ("LunarLtk/Pages/Popups/GraphicsBox", "LunarLtk/Pages/Popups/ChoicesBox",
                 "LunarLtk/Models/Popups/ChoicesModel", "Fk/Components/Common/MetroButton",
                 "Fk/Widgets/TapHandler"):
        source = Path(name + ".qml")
        destination = directory / source
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(RUNTIME / source, destination)
        with (destination.parent / "qmldir").open("a", encoding="utf-8") as manifest:
            manifest.write(f"{source.stem} 1.0 {source.name}\n")

    for module, name, body in (
        ("Fk", "Lua", "function tr(key) { return labels[key] ?? key }"),
        ("LunarLtk", "Ltk", """function processPrompt(raw) {
          let [key, , , arg] = raw.split(":")
          return (labels[key] ?? key).replace("%src", senderName).replace("%arg", labels[arg] ?? "")
        }"""),
    ):
        path = directory / module
        (path / "qmldir").write_text(f"singleton {name} 1.0 {name}.qml\n", encoding="utf-8")
        (path / f"{name}.qml").write_text("pragma Singleton\nimport QtQml\nQtObject {\n"
                                          + body + "\n}", encoding="utf-8")
    (directory / "Check.qml").write_text("""import QtQuick
import LunarLtk.Pages.Popups
import LunarLtk.Models.Popups
Window {
  id: roomScene
  width: 1200; height: 540; visible: true
  property Item dashboard: Item { y: 450 }
  property var reply
  ChoicesBox {
    objectName: "choicesBox"
    anchors.centerIn: parent
    readonly property bool titleShown: title.visible
    readonly property string displayedPrompt: title.text
    dataModel: ChoicesModel {
      choices: packet[0]; allChoices: packet[1]; minNum: packet[2][0]; maxNum: packet[2][1]
      cancelable: packet[3]; skillName: packet[4]; prompt: packet[5]
      detailed: packet[6]; single: packet[7]
      onAccepted: roomScene.reply = Array.from(result)
    }
    Component.onCompleted: shown()
  }
}""", encoding="utf-8")


def buttons(item):
    if item.isVisible() and item.metaObject().indexOfSignal("clicked()") >= 0:
        yield item
    for child in item.childItems():
        yield from buttons(child)


def check(directory, packet, sender, labels):
    engine = QQmlApplicationEngine()
    engine.addImportPath(str(directory))
    for key, value in (("packet", packet), ("labels", labels), ("senderName", sender)):
        engine.rootContext().setContextProperty(key, value)
    engine.load(QUrl.fromLocalFile(str(directory / "Check.qml")))
    if not engine.rootObjects():
        raise RuntimeError("ChoicesBox failed to load")
    window = engine.rootObjects()[0]
    QTest.qWait(120)
    popup = window.findChild(QQuickItem, "choicesBox")
    text = popup.property("displayedPrompt")
    kind = "队列" if "formation" in packet[5] else "围攻"
    if not (popup.property("titleShown") and sender in text and kind in text):
        raise AssertionError(f"Missing visible initiator or array type: {text!r}")
    if packet[0] == ["Cancel"] and not ("明置" in text and "取消" in text):
        raise AssertionError(f"Missing reason on Cancel-only prompt: {text!r}")
    button = next(b for b in buttons(popup) if b.property("text") == labels["Cancel"])
    center = button.mapToScene(QPointF(button.width() / 2, button.height() / 2))
    QTest.mouseClick(window, Qt.LeftButton, Qt.NoModifier, center.toPoint())
    QTest.qWait(30)
    reply = window.property("reply")
    if reply is None or reply.toVariant() != ["Cancel"]:
        raise AssertionError("Cancel click failed to produce the expected reply")
    window.close()


def main():
    app = QGuiApplication(sys.argv)
    with tempfile.TemporaryDirectory(prefix="qiao-array-") as tmp:
        directory = Path(tmp)
        packets = samples(directory)
        prepare(directory)
        covered = set()
        for packet, sender, labels in packets:
            key = packet[5].split(":")[0], tuple(packet[0])
            if key not in covered:
                check(directory, packet, sender, labels)
                covered.add(key)
        expected = {"#qiao_array_respond_formation", "#qiao_array_respond_siege",
                    "#qiao_array_pass_formation"}
        if not expected.issubset({key for key, choices in covered}):
            raise AssertionError("Missing a native request for a required popup scenario")
        print(f"PASS: {len(covered)} distinct native prompts displayed and cancelled in offscreen Qt")
    app.quit()


if __name__ == "__main__":
    main()
