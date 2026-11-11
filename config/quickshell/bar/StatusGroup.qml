// Grupo de estado de la barra, el último a la derecha (o abajo en vertical):
//   [wifi altavoz batería · campana · vie 6 nov 10:11]
// Todo es UN botón: abre el centro de control (vista "ajustes", modules/quicksettings/QuickSettings.qml), que
// junta ajustes rápidos, notificaciones y agenda. La parte pulsada solo dice a qué zona del panel ir
// (Shell.section: iconos → "ajustes", campana → "notificaciones", reloj → "agenda").
//   iconos: clic derecho → con el desplegable de sonido · rueda → volumen
//   campana: punto si hay notificaciones · clic derecho → no molestar
//   reloj: al pasar el cursor, los relojes del mundo (Ajustes › Fecha)
// Módulos de barModules: «red», «bateria», «notificaciones», «reloj» (el volumen siempre está).
import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../services"

Rectangle {
    id: root
    property bool vertical: false
    readonly property bool on: Shell.view === "ajustes"
    readonly property bool hovered: mIcons.containsMouse || mBell.containsMouse || mClock.containsMouse
    onHoveredChanged: if (hovered) Shell.preload("ajustes")   // carga diferida: el centro de control, mientras llega el clic
    readonly property bool showBell: Settings.barHas("notificaciones")
    readonly property bool showClock: Settings.barHas("reloj")
    implicitHeight: vertical ? vcol.implicitHeight + 12 : 24
    implicitWidth: vertical ? 26 : hrow.implicitWidth + 16
    radius: Theme.r(7)
    color: on || hovered ? Theme.fill2 : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }

    function open(section: string, arg): void {
        if (Shell.view === "ajustes" && (arg === undefined || arg === null)) Shell.close();
        else Shell.open(section, arg);
    }

    // Iconos de estado (wifi, volumen, batería)
    component StatusIcons: GridLayout {
        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: 6; columnSpacing: 9
        Icon { visible: Settings.barHas("red"); Layout.alignment: Qt.AlignCenter; name: !Net.wifiEnabled || !Net.connected ? (Net.type === "ethernet" ? "monitor" : "wifi_off") : Net.type === "ethernet" ? "monitor" : "wifi"; opacity: Net.connected ? 1 : 0.6; color: Net.portal ? Theme.danger : Theme.t }   // rojo: la red pide iniciar sesión (portal cautivo)
        Icon { Layout.alignment: Qt.AlignCenter; name: Audio.muted || Audio.volume === 0 ? "volume_low" : Audio.volume > 0.66 ? "volume_high" : "volume" }
        Icon { visible: Battery.present && Settings.barHas("bateria"); Layout.alignment: Qt.AlignCenter; name: Battery.percent < 0.25 ? "battery_low" : "battery"; color: Battery.percent < 0.15 && !Battery.charging ? Theme.danger : Theme.t }
    }
    component Bell: Item {
        implicitWidth: 16; implicitHeight: 16
        Icon { anchors.centerIn: parent; name: Notifs.dnd ? "dnd" : "bell" }
        Rectangle {
            visible: Notifs.list.values.length > 0 && !Notifs.dnd
            width: 5; height: 5; radius: 2.5
            color: Theme.p
            anchors { top: parent.top; right: parent.right; topMargin: 0; rightMargin: 0 }
        }
    }

    // ── Horizontal ──
    RowLayout {
        id: hrow
        visible: !root.vertical
        anchors.centerIn: parent
        spacing: 11
        StatusIcons { id: hIcons }
        Bell { id: hBell; visible: root.showBell }
        RowLayout {
            id: hClock
            visible: root.showClock
            spacing: 7
            Txt { text: Time.shortDate; muted: true }
            Txt { text: Time.hhmm; weight: Font.DemiBold; tabular: true; display: Theme.chroma; size: Theme.chroma ? 15 : 12.5 }   // Chroma: reloj de puntos
            Txt { visible: Time.ampm !== ""; text: Time.ampm; size: 11; muted: true; Layout.leftMargin: -3 }
        }
    }

    // ── Vertical ──
    ColumnLayout {
        id: vcol
        visible: root.vertical
        anchors.centerIn: parent
        spacing: 8
        StatusIcons { id: vIcons; Layout.alignment: Qt.AlignHCenter }
        Bell { id: vBell; visible: root.showBell; Layout.alignment: Qt.AlignHCenter }
        ColumnLayout {
            id: vClock
            visible: root.showClock
            Layout.alignment: Qt.AlignHCenter
            spacing: 0
            Txt { Layout.alignment: Qt.AlignHCenter; text: Time.hhmm.slice(0, 2); weight: Font.DemiBold; size: 12; tabular: true }
            Txt { Layout.alignment: Qt.AlignHCenter; text: Time.hhmm.slice(3); weight: Font.DemiBold; size: 12; tabular: true }
        }
    }

    // Zonas de clic (cada una cubre su parte y la mitad del hueco con la siguiente)
    readonly property Item iconsItem: vertical ? vIcons : hIcons
    readonly property Item bellItem: vertical ? vBell : hBell
    readonly property Item clockItem: vertical ? vClock : hClock
    readonly property Item box: vertical ? vcol : hrow
    // Límite entre zonas a lo largo del grupo (px del grupo)
    function edgeAfter(it: Item): real {
        const p = it.mapToItem(root, 0, 0);
        return vertical ? p.y + it.height + 4 : p.x + it.width + 5;
    }
    // Se recalculan también cuando el grupo cambia de tamaño o la fila se recoloca: antes solo con el tamaño de la fila,
    // y si se calculaba antes de que el grupo tuviera su ancho final (fila centrada con x negativa) la zona de la
    // campana quedaba corrida a la izquierda, ENCIMA de la bandeja (clic en un icono de la bandeja → avisos)
    readonly property real cut1: { box.width; box.height; box.x; box.y; root.width; root.height; iconsItem.x; iconsItem.width; return Math.max(0, edgeAfter(iconsItem)); }
    readonly property real cut2: { box.width; box.height; box.x; box.y; root.width; root.height; bellItem.x; return bellItem.visible ? Math.max(cut1, edgeAfter(bellItem)) : cut1; }
    MouseArea {
        id: mIcons
        x: 0; y: 0
        readonly property bool alone: !root.showBell && !root.showClock
        width: root.vertical || alone ? root.width : Math.min(root.width, root.cut1)
        height: !root.vertical || alone ? root.height : Math.min(root.height, root.cut1)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => root.open("centro", e.button === Qt.RightButton ? "audio" : undefined)
        onWheel: w => Audio.setVolume(Audio.volume + (w.angleDelta.y > 0 ? 0.05 : -0.05))
    }
    MouseArea {
        id: mBell
        visible: root.showBell
        x: root.vertical ? 0 : root.cut1
        y: root.vertical ? root.cut1 : 0
        readonly property real len: Math.max(0, root.showClock ? root.cut2 - root.cut1 : (root.vertical ? root.height : root.width) - root.cut1)
        width: root.vertical ? root.width : len
        height: root.vertical ? len : root.height
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => e.button === Qt.RightButton ? Notifs.setDnd(!Notifs.dnd) : root.open("notificaciones")
    }
    MouseArea {
        id: mClock
        visible: root.showClock
        x: root.vertical ? 0 : root.cut2
        y: root.vertical ? root.cut2 : 0
        width: root.vertical ? root.width : Math.max(0, root.width - root.cut2)
        height: root.vertical ? Math.max(0, root.height - root.cut2) : root.height
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.open("agenda")
        onWheel: w => w.accepted = false
    }
    BarTip { target: mIcons; text: root.on ? "" : "Red, sonido y ajustes rápidos · clic derecho: sonido" }
    BarTip { target: mBell; text: root.on ? "" : Notifs.dnd ? "No molestar activado · clic derecho para quitarlo" : (Notifs.count ? Notifs.count + (Notifs.count === 1 ? " notificación" : " notificaciones") : "Sin notificaciones") + " · clic derecho: no molestar" }
    // Relojes del mundo (Ajustes › Fecha) — «Madrid 18:25 · Tokio 02:25 (mañana)»
    BarTip { target: mClock; text: root.on ? "" : WorldClock.clocks.map(c => c.name + " " + c.time + (c.day ? " (" + c.day + ")" : "")).join("  ·  ") }
}
