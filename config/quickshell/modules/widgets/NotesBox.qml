// Notas rápidas (un solo texto, en notas.txt): widget «Notas» y mosaico «Notas» de Herramientas (centro de control).
import QtQuick
import Quickshell.Io
import "../.."
import "../../components"

Rectangle {
    implicitHeight: Math.max(70, Math.min(180, notes.contentHeight + 16))
    radius: Theme.r(6)
    color: Theme.fill2
    clip: true
    TextEdit {
        id: notes
        anchors.fill: parent
        anchors.margins: 8
        wrapMode: TextEdit.Wrap
        color: Theme.t
        selectionColor: Theme.pc
        selectedTextColor: Theme.pcText
        font.family: Theme.font
        font.pixelSize: Theme.px(12.5)
        onTextChanged: if (activeFocus) saveTimer.restart()
        Txt { visible: notes.text === ""; text: "Escribe algo…"; muted: true }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onPressed: e => { notes.forceActiveFocus(); e.accepted = false; } }
    FileView {
        id: notesFile
        path: Paths.state + "/notas.txt"
        printErrors: false
        watchChanges: true           // lo escrito en la otra vista
        onFileChanged: reload()
        onLoaded: if (!notes.activeFocus) notes.text = text()
    }
    Timer { id: saveTimer; interval: 600; onTriggered: notesFile.setText(notes.text) }
    // al plegar o cerrar antes de que salte el temporizador
    Component.onDestruction: if (saveTimer.running) notesFile.setText(notes.text)
}
