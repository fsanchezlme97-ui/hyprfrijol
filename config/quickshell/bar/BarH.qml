// Contenido de la barra horizontal (design/Main.dc.html, «Barra»), de izquierda a derecha:
//   [Aplicaciones][一 二 三 … 九] | título ······ onda ······
//   información (clima · sistema · impresora) → utilidades (pomodoro · cafeína · portapapeles · IA · ajustes) → bandeja
//   | [privacidad] [wifi vol bat · campana · vie 6 nov 10:11] ← grupo de estado: abre el centro de control
// Archipiélago: izquierda, onda, información+utilidades+bandeja y grupo de estado, cada uno en su píldora.
import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../components"
import "../services"

Item {
    id: root
    required property var barWindow
    property bool compact: false          // isla central: los tres grupos seguidos, sin huecos
    property bool islands: false          // archipiélago: cada grupo en su propia píldora (BarPill)
    // Pantalla secundaria: solo sus espacios (sin aplicaciones, título, onda, chips, bandeja ni estado)
    readonly property bool secondary: barWindow.screen !== Shell.primaryScreen
    // Píldoras del archipiélago (Bar.qml las usa de máscara para el ratón)
    readonly property var pills: [pillL, pillC, pillR, pillS]
    readonly property real gapC: 14
    readonly property real naturalLength: left.implicitWidth + (wave.active ? wave.width + gapC * 2 : gapC) + (secondary ? 0 : right.implicitWidth) + 6
    // Título de la ventana activa: tope fijo (isla) o 30 % de la barra (máx. 300 px), y nunca hasta la onda
    // central (ni hasta el grupo derecho sin onda). Se calcula sin depender del propio título (sin bucles).
    readonly property real titleStart: left.x + (ws.visible ? ws.x + ws.width : apps.x + apps.width) + 16
    // Barra entera (fija / flotante): onda centrada sin pisar el grupo derecho; si no cabe tras los espacios, se oculta
    readonly property real waveX: Math.min((width - wave.width) / 2, right.x - gapC - wave.width)
    // Archipiélago: la onda va en su píldora entre la izquierda y los chips; si no cabe (pantalla estrecha o barra
    // grande), se oculta en lugar de montarse sobre la píldora de los chips
    readonly property bool waveFits: compact || (islands ? titleStart + 12 + wave.width <= right.x - 26 : waveX >= titleStart - 8)
    readonly property real centerStart: !wave.active || !waveFits ? (secondary ? width : right.x)
        : islands ? Math.min((width - wave.width) / 2, right.x - 26 - wave.width) - 22 - 10
        : waveX
    readonly property real titleMax: compact ? 240 : Math.max(0, Math.min(300, width * 0.3, centerStart - gapC - titleStart))

    BarPill { id: pillL; bar: root.barWindow; visible: root.islands; x: 0; height: parent.height; width: left.x + left.implicitWidth + (title.visible ? 10 : 3) }
    BarPill { id: pillC; bar: root.barWindow; visible: root.islands && wave.active && root.waveFits; x: wave.x - 10; height: parent.height; width: wave.width + 20 }
    // Píldora de los chips (si hay alguno) y la del grupo de estado
    readonly property real statusX: right.x + statusBox.x
    readonly property bool anyChip: statusBox.x > 4
    BarPill { id: pillR; bar: root.barWindow; visible: root.islands && root.anyChip && !root.secondary; x: right.x - 4; height: parent.height; width: root.statusX - root.gapS - x + 4 }
    BarPill { id: pillS; bar: root.barWindow; visible: root.islands && !root.secondary; x: root.anyChip ? root.statusX - 4 : right.x - 4; height: parent.height; width: parent.width - x }
    readonly property real gapS: 16          // hueco entre las islas de chips y de estado (8 px visibles)

    RowLayout {
        id: left
        x: 3
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        AppsBtn { id: apps; visible: !root.secondary }   // Aplicaciones (Spotlight): logo de la distribución
        Workspaces { id: ws; visible: Settings.barHas("espacios") || root.secondary; screen: root.barWindow.screen }
        Divider { visible: Settings.barHas("espacios") && title.visible }
        ActiveTitle { id: title; visible: !root.secondary && Settings.get("barShowTitle", true) && Settings.barHas("titulo") && text !== "" && root.titleMax >= 48; Layout.leftMargin: 2; Layout.maximumWidth: root.titleMax }
        OmarchySlot { barWindow: root.barWindow; place: "izquierda"; visible: any && !root.secondary }   // widgets de plugins de Omarchy (omarchyBarSlot)
    }

    Loader {
        id: wave
        active: Settings.barHas("musica") && !root.secondary
        visible: root.waveFits
        anchors.verticalCenter: parent.verticalCenter
        // Archipiélago: centrada, pero sin pisar las píldoras de los lados (12 px de hueco como mínimo)
        x: root.compact ? left.x + left.implicitWidth + root.gapC
         : root.islands ? Math.max(pillL.width + 22, Math.min((parent.width - width) / 2, right.x - 26 - width))
         : root.waveX
        sourceComponent: Waveform { barHeight: root.height }
    }

    readonly property bool hasInfo: Settings.barHas("clima") || Settings.barHas("recursos") || Settings.barHas("impresora")
    readonly property bool hasUtil: pomo.visible || cafe.visible || bongo.visible || dictBtn.visible || clipBtn.visible || aiBtn.visible || gearBtn.visible || tray.visible
    RowLayout {
        id: right
        visible: !root.secondary
        x: root.compact ? (wave.active ? wave.x + wave.width + root.gapC : left.x + left.implicitWidth + root.gapC) : parent.width - implicitWidth - 3
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        // Información
        Loader { active: Settings.barHas("clima"); visible: active && (item?.want ?? false); sourceComponent: WeatherChip {} }
        Loader { active: Settings.barHas("recursos"); visible: active; sourceComponent: StatsChip {} }
        Loader { active: Settings.barHas("impresora"); visible: active && (item?.want ?? false); sourceComponent: PrinterChip {} }
        // Memorias USB montadas y descargas en curso: solo aparecen cuando hay algo (devicesBarIcon, downloadsBarIcon)
        Loader { visible: item?.want ?? false; sourceComponent: DevicesChip {} }
        Loader { visible: item?.want ?? false; sourceComponent: DownloadsChip {} }
        Loader { visible: item?.want ?? false; sourceComponent: TestChip {} }   // solo con una prueba de dev/try.sh en marcha
        // Utilidades
        Divider { visible: root.hasInfo && root.hasUtil; Layout.leftMargin: 4; Layout.rightMargin: 4 }
        PomodoroChip { id: pomo; visible: Settings.barHas("pomodoro") }
        BongoChip { id: bongo; visible: Settings.barHas("bongo") }   // gato bongo: golpea al escribir (junto al pomodoro)
        CaffeineChip { id: cafe; visible: Settings.barHas("cafeina") }
        IconBtn { id: dictBtn; visible: Settings.barHas("dictado"); icon: "mic"; active: Shell.dictPhase === "rec"; tooltip: Shell.dictPhase === "rec" ? "Dictando · clic para terminar" : "Dictado · Super + Alt + D"; onClicked: Shell.dictToggle() }
        IconBtn { id: clipBtn; visible: Settings.barHas("portapapeles"); icon: "clipboard"; tooltip: "Portapapeles"; preload: "spotlight"; onClicked: Shell.toggle("spotlight", "mode:clip") }   // abre Spotlight en modo portapapeles
        IconBtn { id: aiBtn; visible: Settings.barHas("ia"); icon: "ai"; preload: "ia"; active: Shell.view === "ia" || Shell.sideShown; onClicked: Shell.toggle("ia") }
        IconBtn { id: gearBtn; visible: Settings.barHas("ajustes"); icon: "gear"; onClicked: Shell.open("ajustesapp") }   // Ajustes (tuerca; opcional, ya está en el panel)
        OmarchySlot { barWindow: root.barWindow; place: "derecha" }     // widgets de plugins de Omarchy (omarchyBarSlot)
        // Separa los botones propios (asistente, ajustes…) de los iconos de las apps (bandeja)
        Divider { visible: tray.visible && (pomo.visible || cafe.visible || bongo.visible || clipBtn.visible || aiBtn.visible || gearBtn.visible); Layout.leftMargin: 4; Layout.rightMargin: 0 }
        Tray { id: tray; barWindow: root.barWindow; visible: Settings.get("barTray", true) && any; Layout.leftMargin: 4 }
        // Estado: privacidad + red, sonido, batería, notificaciones y reloj (un solo botón: centro de control)
        Item {
            id: statusBox
            Layout.leftMargin: root.islands ? root.gapS : 0
            implicitWidth: statusRow.implicitWidth
            implicitHeight: statusRow.implicitHeight
            RowLayout {
                id: statusRow
                spacing: 4
                Divider { visible: !root.islands && (root.hasInfo || root.hasUtil); Layout.leftMargin: 4; Layout.rightMargin: 2 }
                PrivacyPill {}
                StatusGroup {}
            }
        }
    }
}
