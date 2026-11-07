// Compatibilidad con Omarchy · qs.Ui.TextField: campo de texto (QtQuick.Controls) con el tema.
import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Commons as Commons

TextField {
    id: root
    property color foreground: Commons.Color.foreground
    property color accent: Commons.Color.accent
    property color selectionTint: Style.selectionFillFor(foreground, accent)
    property bool password: false
    property real horizontalPadding: Style.spacing.controlPaddingX
    property real verticalPadding: Style.spacing.inputPaddingY
    property bool hasCursor: false
    readonly property bool _focused: activeFocus
    readonly property bool _hot: hovered || hasCursor
    readonly property var _borderSpec: Border.controlSpec(_focused ? "focus" : (_hot ? "hover-cursor" : "normal"), foreground, accent)
    echoMode: password ? TextInput.Password : TextInput.Normal
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    color: foreground
    selectionColor: selectionTint
    selectedTextColor: foreground
    placeholderTextColor: Qt.darker(foreground, 1.6)
    leftPadding: horizontalPadding + 1
    rightPadding: horizontalPadding + 1
    topPadding: verticalPadding + 1
    bottomPadding: verticalPadding + 1
    background: BorderSurface {
        color: Style.controlFill(root._focused, root._hot, root.foreground, root.accent)
        borderSpec: root._borderSpec
        radius: Style.cornerRadius
    }
}
