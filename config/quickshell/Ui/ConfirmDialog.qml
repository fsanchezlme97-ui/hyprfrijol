// Compatibilidad con Omarchy · qs.Ui.ConfirmDialog: confirmación dentro del panel (Cancelar / Confirmar).
import QtQuick
import qs.Commons
import qs.Commons as Commons

Item {
    id: root
    property bool opened: false
    property string message: ""
    property string cancelText: I18n.t("common.cancel")
    property string confirmText: I18n.t("common.confirm")
    property int selectedIndex: 1
    property color background: Commons.Color.background
    property color foreground: Commons.Color.foreground
    property color scrim: Util.alpha(Commons.Color.background, 0.7)
    property color selectedBackground: Util.alpha(Commons.Color.foreground, 0.08)
    property color selectedText: Commons.Color.accent
    property string fontFamily: Style.font.family
    property int cornerRadius: Style.cornerRadius
    signal canceled()
    signal confirmed()
    function handleKey(event) {
        if (!opened) return false;
        if (event.key === Qt.Key_Escape) { opened = false; canceled(); event.accepted = true; return true; }
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Right || event.key === Qt.Key_Tab || event.text === "h" || event.text === "l") { selectedIndex = 1 - selectedIndex; event.accepted = true; return true; }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) { const ok = selectedIndex === 1; opened = false; ok ? confirmed() : canceled(); event.accepted = true; return true; }
        return false;
    }
    visible: opened
    z: 100
    anchors.fill: parent
    Rectangle { anchors.fill: parent; color: root.scrim; radius: root.cornerRadius; MouseArea { anchors.fill: parent } }
    BorderSurface {
        anchors.centerIn: parent
        width: Math.min(parent.width - Style.space(24), Math.max(Style.space(220), box.implicitWidth + Style.space(28)))
        height: box.implicitHeight + Style.space(28)
        color: root.background
        radius: root.cornerRadius
        borderSpec: Border.flat(Util.alpha(root.foreground, 0.2), 1)
        Column {
            id: box
            anchors.centerIn: parent
            width: parent.width - Style.space(28)
            spacing: Style.space(12)
            Text { width: parent.width; text: root.message; textFormat: Text.PlainText; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Style.space(8)
                Repeater {
                    model: [root.cancelText, root.confirmText]
                    Button {
                        required property int index
                        required property string modelData
                        text: modelData
                        selected: root.selectedIndex === index
                        bordered: true
                        foreground: index === 1 && root.selectedIndex === 1 ? root.selectedText : root.foreground
                        onClicked: { root.opened = false; index === 1 ? root.confirmed() : root.canceled(); }
                    }
                }
            }
        }
    }
}
