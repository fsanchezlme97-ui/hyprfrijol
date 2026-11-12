// Captura una combinación de teclas → "SUPER + SHIFT + W" (formato de hl.bind).
//   KeyCapture { value: "SUPER + W"; onCaptured: k => … }   Esc cancela, Retroceso borra.
import QtQuick
import "../../.."
import "../../../components"
import "keys.js" as KeyNames

Rectangle {
    id: root
    property string value: ""
    property bool listening: false
    property string placeholder: "Asignar"
    signal captured(string keys)
    implicitHeight: 28
    implicitWidth: Math.max(70, row.implicitWidth + 14)
    radius: Theme.r(6)
    color: listening ? Theme.selBg : "transparent"
    border.width: listening ? 0 : (value === "" ? 1 : 0)
    border.color: Theme.ov
    focus: listening
    function keyName(e) {
        const map = { [Qt.Key_Return]: "RETURN", [Qt.Key_Enter]: "RETURN", [Qt.Key_Space]: "SPACE", [Qt.Key_Tab]: "TAB",
            [Qt.Key_Left]: "left", [Qt.Key_Right]: "right", [Qt.Key_Up]: "up", [Qt.Key_Down]: "down", [Qt.Key_Print]: "PRINT",
            [Qt.Key_Delete]: "DELETE", [Qt.Key_Home]: "HOME", [Qt.Key_End]: "END", [Qt.Key_Plus]: "plus", [Qt.Key_Minus]: "minus",
            [Qt.Key_Equal]: "equal", [Qt.Key_Comma]: "comma", [Qt.Key_Period]: "period", [Qt.Key_Slash]: "slash" };
        if (map[e.key]) return map[e.key];
        if (e.key >= Qt.Key_F1 && e.key <= Qt.Key_F24) return "F" + (e.key - Qt.Key_F1 + 1);
        if (e.key >= Qt.Key_A && e.key <= Qt.Key_Z) return String.fromCharCode(e.key);
        if (e.key >= Qt.Key_0 && e.key <= Qt.Key_9) return String.fromCharCode(e.key);
        return "";
    }
    Keys.onPressed: e => {
        e.accepted = true;
        if (e.key === Qt.Key_Escape) { listening = false; return; }
        if (e.key === Qt.Key_Backspace && e.modifiers === Qt.NoModifier) { listening = false; captured(""); return; }
        const k = keyName(e);
        if (!k) return;   // solo modificadores aún
        const mods = [];
        if (e.modifiers & Qt.MetaModifier) mods.push("SUPER");
        if (e.modifiers & Qt.ControlModifier) mods.push("CTRL");
        if (e.modifiers & Qt.AltModifier) mods.push("ALT");
        if (e.modifiers & Qt.ShiftModifier) mods.push("SHIFT");
        listening = false;
        captured(mods.concat([k]).join(" + "));
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4
        Repeater {
            model: root.listening ? [] : (root.value ? root.value.split(" + ") : [])
            Rectangle {
                required property string modelData
                width: kt.implicitWidth + 12; height: 22; radius: Theme.r(4)
                color: "transparent"; border.width: 1; border.color: Theme.o
                Txt { id: kt; anchors.centerIn: parent; text: KeyNames.label(parent.modelData); size: 11.5; weight: Font.Medium }
            }
        }
        Txt { visible: root.listening || !root.value; text: root.listening ? "Pulsa la combinación…" : root.placeholder; size: 11.5; color: root.listening ? Theme.selText : Theme.tv }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.listening = true; root.forceActiveFocus(); } }
}
