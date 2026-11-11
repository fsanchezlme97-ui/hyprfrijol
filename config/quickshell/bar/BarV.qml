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
    readonly property bool secondary: barWindow.screen !== Shell.primaryScreen
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
    readonly property Item topEnd: wsV.visible ? wsV : appsV
    ColumnLayout {
        id: colMain
        anchors.fill: parent
        anchors.topMargin: 6
        anchors.bottomMargin: 6
        spacing: 4
        AppsBtn { id: appsV; side: 26; visible: !root.secondary; Layout.alignment: Qt.AlignHCenter }   // Aplicaciones: logo de la distribución
        Workspaces { id: wsV; visible: Settings.barHas("espacios") || root.secondary; Layout.alignment: Qt.AlignHCenter; screen: root.barWindow.screen; vertical: true }
        Item { id: gap; Layout.fillHeight: true; Layout.minimumHeight: root.compact ? 8 : 0 }
        // Información
        Loader { Layout.alignment: Qt.AlignHCenter; active: Settings.barHas("clima"); visible: !root.secondary && (active && (item?.want ?? false)); sourceComponent: WeatherChip { vertical: true } }
        Loader { Layout.alignment: Qt.AlignHCenter; active: Settings.barHas("recursos"); visible: !root.secondary && (active); sourceComponent: StatsChip { vertical: true } }
        Loader { Layout.alignment: Qt.AlignHCenter; active: Settings.barHas("impresora"); visible: !root.secondary && (active && (item?.want ?? false)); sourceComponent: PrinterChip { vertical: true } }
        Loader { Layout.alignment: Qt.AlignHCenter; visible: !root.secondary && (item?.want ?? false); sourceComponent: DevicesChip { vertical: true } }
        Loader { Layout.alignment: Qt.AlignHCenter; visible: !root.secondary && (item?.want ?? false); sourceComponent: DownloadsChip { vertical: true } }
        Loader { Layout.alignment: Qt.AlignHCenter; visible: !root.secondary && (item?.want ?? false); sourceComponent: TestChip { vertical: true } }
        // Utilidades
        BongoChip { visible: !root.secondary && (Settings.barHas("bongo")); Layout.alignment: Qt.AlignHCenter; vertical: true }
        PomodoroChip { visible: !root.secondary && (Settings.barHas("pomodoro")); Layout.alignment: Qt.AlignHCenter; vertical: true }
        CaffeineChip { visible: !root.secondary && (Settings.barHas("cafeina")); Layout.alignment: Qt.AlignHCenter; vertical: true }
        IconBtn { visible: !root.secondary && (Settings.barHas("portapapeles")); Layout.alignment: Qt.AlignHCenter; implicitHeight: 26; icon: "clipboard"; preload: "spotlight"; onClicked: Shell.toggle("spotlight", "mode:clip") }   // Spotlight en modo portapapeles
        MicBtn { visible: !root.secondary && (Settings.barHas("dictado")); Layout.alignment: Qt.AlignHCenter; implicitHeight: 26 }
        IconBtn { visible: !root.secondary && (Settings.barHas("ia")); Layout.alignment: Qt.AlignHCenter; implicitHeight: 26; icon: "ai"; preload: "ia"; active: Shell.view === "ia" || Shell.sideShown; onClicked: Shell.toggle("ia") }
        IconBtn { visible: !root.secondary && (Settings.barHas("ajustes")); Layout.alignment: Qt.AlignHCenter; implicitHeight: 26; icon: "gear"; onClicked: Shell.open("ajustesapp") }   // Ajustes (tuerca)
        OmarchySlot { barWindow: root.barWindow; visible: any && !root.secondary; vertical: true; place: Settings.get("omarchyBarSlot", "derecha"); Layout.alignment: Qt.AlignHCenter }   // plugins de Omarchy
        Divider { vertical: false; implicitWidth: 14; visible: !root.secondary && (vTray.visible); Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 3; Layout.bottomMargin: 3 }   // botones propios | bandeja
        Tray { id: vTray; barWindow: root.barWindow; vertical: true; visible: !root.secondary && (Settings.get("barTray", true) && any); Layout.alignment: Qt.AlignHCenter }
        // Estado: privacidad + red, sonido, batería, notificaciones y hora (un solo botón: centro de control)
        Rectangle {
            visible: !root.secondary && Audio.micUsers.length > 0
            Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 4
            implicitWidth: 8; implicitHeight: 8; radius: 4
            color: Theme.ter
            MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: Shell.toggle("ajustes") }
        }
        StatusGroup { id: status; vertical: true; visible: !root.secondary; Layout.alignment: Qt.AlignHCenter; Layout.topMargin: root.islands ? root.gapS : 4 }
    }
}
