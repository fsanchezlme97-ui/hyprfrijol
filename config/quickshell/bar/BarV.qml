// Barra vertical (izquierda o derecha, 36 px), como «Barra lateral» del diseño. De arriba abajo, el mismo orden
// que la horizontal: aplicaciones y espacios · información (clima, sistema, impresora) → utilidades (pomodoro,
// cafeína, portapapeles, IA, ajustes) → bandeja · grupo de estado (red, sonido, batería, campana y hora: abre el
// centro de control). Archipiélago: arriba, chips y estado, cada uno en su píldora.
import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../components"
import "../services"

Item {
    id: root
    required property var barWindow
    property bool compact: false
    property bool islands: false          // archipiélago: cada grupo en su píldora (BarPill)
    // Pantalla secundaria: solo sus espacios (sin aplicaciones, chips, bandeja ni estado)
    readonly property bool secondary: Shell.barModeFor(barWindow.screen) === "sencilla"
    readonly property var pills: [pillT, pillB, pillS]
    readonly property real naturalLength: colMain.implicitHeight + 24
    BarPill { id: pillT; bar: root.barWindow; visible: root.islands; y: 0; width: parent.width; height: colMain.y + topEnd.y + topEnd.height + 6 }
    // Chips (si hay alguno entre el hueco y el estado) y grupo de estado
    readonly property real chipsTop: colMain.y + gap.y + gap.height
    readonly property real statusTop: colMain.y + status.y
    readonly property bool anyChip: statusTop - chipsTop > 12
    readonly property real gapS: 20
    BarPill { id: pillB; bar: root.barWindow; visible: root.islands && root.anyChip && !root.secondary; y: root.chipsTop - 6; width: parent.width; height: root.statusTop - root.gapS + 6 - y }
    BarPill { id: pillS; bar: root.barWindow; visible: root.islands && !root.secondary; y: root.statusTop - 6; width: parent.width; height: parent.height - y }
    readonly property Item topEnd: leftZoneV.visible ? leftZoneV : wsV.visible ? wsV : appsV
    readonly property var zoneL: Settings.barZone("izquierda")
    readonly property var zoneR: Settings.barZone("derecha")
    function zoneOf(m: string): var { return zoneL.includes(m) ? zoneL : zoneR; }
    function autoSep(m: string, prev: string): bool { const g = Settings.barGroup(m), h = Settings.barGroup(prev); return g !== "sep" && h !== "sep" && g !== h; }
    // Un widget de una isla, con un separador delante si cambia de grupo (información → utilidades)
    Component {
        id: zoneItem
        ColumnLayout {
            id: zi
            required property string modelData
            required property int index
            visible: w.shown
            spacing: 4
            Layout.alignment: Qt.AlignHCenter
            Divider { vertical: false; implicitWidth: 14; visible: zi.index > 0 && root.autoSep(zi.modelData, root.zoneOf(zi.modelData)[zi.index - 1] ?? zi.modelData); Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 2; Layout.bottomMargin: 2 }
            BarWidget { id: w; wid: zi.modelData; vertical: true }
        }
    }
    ColumnLayout {
        id: colMain
        anchors.fill: parent
        anchors.topMargin: 6
        anchors.bottomMargin: 6
        spacing: 4
        AppsBtn { id: appsV; side: 26; visible: !root.secondary; Layout.alignment: Qt.AlignHCenter }   // Aplicaciones: logo de la distribución
        Workspaces { id: wsV; visible: Settings.barHas("espacios") || root.secondary; Layout.alignment: Qt.AlignHCenter; screen: root.barWindow.screen; vertical: true }
        // Widgets puestos arriba (la isla «izquierda» de Ajustes › Widgets de la barra)
        ColumnLayout {
            id: leftZoneV
            visible: !root.secondary && root.zoneL.length > 0
            spacing: 4
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            Repeater { model: root.zoneL; delegate: zoneItem }
        }
        Item { id: gap; Layout.fillHeight: true; Layout.minimumHeight: root.compact ? 8 : 0 }
        ColumnLayout {
            visible: !root.secondary && root.zoneR.length > 0
            spacing: 4
            Layout.alignment: Qt.AlignHCenter
            Repeater { model: root.zoneR; delegate: zoneItem }
        }
        Loader { Layout.alignment: Qt.AlignHCenter; visible: !root.secondary && (item?.want ?? false); sourceComponent: DevicesChip { vertical: true } }
        Loader { Layout.alignment: Qt.AlignHCenter; visible: !root.secondary && (item?.want ?? false); sourceComponent: DownloadsChip { vertical: true } }
        Loader { Layout.alignment: Qt.AlignHCenter; visible: !root.secondary && (item?.want ?? false); sourceComponent: TestChip { vertical: true } }
        OmarchySlot { barWindow: root.barWindow; visible: any && !root.secondary; vertical: true; place: Settings.get("omarchyBarSlot", "derecha"); Layout.alignment: Qt.AlignHCenter }   // plugins de Omarchy
        Divider { vertical: false; implicitWidth: 14; visible: !root.secondary && (vTray.visible); Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 3; Layout.bottomMargin: 3 }   // botones propios | bandeja
        Tray { id: vTray; barWindow: root.barWindow; vertical: true; visible: !root.secondary && (Settings.get("barTray", true) && any); Layout.alignment: Qt.AlignHCenter }
        // Estado: privacidad + red, sonido, batería, notificaciones y hora (un solo botón: centro de control)
        Rectangle {
            visible: !root.secondary && Audio.micUsers.length > 0
            Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 4
            implicitWidth: 8; implicitHeight: 8; radius: 4
            color: Theme.ter
            MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onPressed: Shell.toggle("ajustes") }
        }
        StatusGroup { id: status; vertical: true; visible: !root.secondary; Layout.alignment: Qt.AlignHCenter; Layout.topMargin: root.islands ? root.gapS : 4 }
    }
}
