// Centro de control: UN panel lateral junto a la barra (vista "ajustes"; alias "agenda", "notificaciones" y "centro",
// ver Shell.aliases), a toda la altura y en una sola columna (como la barra lateral derecha de illogical-impulse):
//   · ajustes rápidos (diseño «AjustesRapidos»): cabecera (usuario, batería, ajustes/bloquear/apagar) · brillo y
//     volumen · mosaicos · modo de energía · teléfono (Valent, scripts/hf-phone · scrcpy)
//   · notificaciones (recientes por app e historial: ../notifications/NotifCenter.qml; ocupan el sitio que sobre)
//   · agenda (calendario, eventos del día, relojes del mundo: ../agenda/AgendaCard.qml)
// Estilo, color y Pomodoro viven en Ajustes › Apariencia y en el chip de la barra. El grupo de estado de la barra
// (iconos, campana y hora) lo abre; Shell.section dice a qué parte se desplaza. Si no cabe, la columna se desplaza
// (barra de desplazamiento fina con los colores del tema). Con la barra a la izquierda se abre a la izquierda.
// Todo con datos reales; lo que no existe se oculta.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../.."
import "../../components"
import "../../services"
import "../notifications"
import "../agenda"

Overlay {
    id: win
    view: "ajustes"
    place: barPos === "izquierda" ? "left" : "right"
    panelWidth: 404

    // ── Estado local ───────────────────────────────────────────────
    property string expanded: ""              // "" | "wifi" | "bt" | "audio" | "dnd" | "ventanas"
    property string pwFor: ""                 // red Wi-Fi que pide contraseña
    property string userName: ""
    property bool hasFace: false
    property bool nightOn: false
    property bool vncAvailable: false
    property bool vncOn: false
    property bool vncAuth: false        // ~/.config/wayvnc con contraseña: solo así se escucha en la red (hf-remote)
    readonly property bool vncNet: vncAuth && Settings.get("vncListen", "127.0.0.1") !== "127.0.0.1"
    property var phone: null                  // el primer móvil conectado { id, name, battery } o null (hf-phone)
    property string phoneBackend: ""          // "valent" | "kdeconnect" (alternativa) | "" (sin instalar)
    property bool phoneRunning: false
    // Modo de ventanas del espacio actual: el general (WinMode, ajuste "windowMode") o la excepción que pongas
    // aquí para este espacio durante la sesión (desplegable del mosaico «Modo de ventanas»)
    readonly property int curWs: Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1
    readonly property string wsMode: { WinMode.overrides; WinMode.mode; return WinMode.modeOf(curWs); }
    readonly property bool wsOverride: WinMode.overrides[String(curWs)] !== undefined

    function setNight(on) {
        nightOn = on;
        Shell.exec(on ? [Paths.script("hf-sunset"), "set", String(Settings.get("nightTemp", 4000))] : [Paths.script("hf-sunset"), "off"]);
    }
    function setVnc(on) {
        if (!vncAvailable) return;
        vncOn = on;
        Shell.exec([Paths.script("hf-remote"), "server", on ? "start" : "stop"]);
    }
    function lock() { Shell.close(); Shell.exec("qs -p '" + Paths.root + "/config/quickshell' ipc call lock lock || loginctl lock-session"); }

    // ── Lectores ───────────────────────────────────────────────────
    Process {
        running: true
        command: ["sh", "-c", 'getent passwd "$USER" | cut -d: -f5 | cut -d, -f1; echo "$USER"; command -v wayvnc >/dev/null && echo vnc; [ -s "$HOME/.face" ] && echo face; pgrep -x wayvnc >/dev/null && echo vncon; grep -qs "^enable_auth=true" "$HOME/.config/wayvnc/config" && echo vncauth; true']
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                win.userName = l[0].trim() || l[1].trim();
                win.vncAvailable = l.includes("vnc");
                win.vncOn = l.includes("vncon");
                win.vncAuth = l.includes("vncauth");
                win.hasFace = l.includes("face");
            }
        }
    }
    Process {
        id: nightCheck
        command: [Paths.script("hf-sunset"), "status"]
        onExited: code => win.nightOn = code === 0
    }
    Process {
        id: phoneCheck
        command: [Paths.script("hf-phone"), "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                let r = {};
                try { r = JSON.parse(text || "{}"); } catch (e) {}
                win.phoneBackend = r.backend ?? "";
                win.phoneRunning = !!r.running;
                win.phone = (r.devices ?? []).find(d => d.connected && d.paired) ?? null;
            }
        }
    }
    // scrcpy instalado y estado del móvil en adb (device | unauthorized | offline | "")
    property bool scrcpyOk: false
    property string adbState: ""
    Process {
        id: adbCheck
        command: ["sh", "-c", "command -v scrcpy >/dev/null || exit 0; echo scrcpy; command -v adb >/dev/null && timeout 4 adb devices 2>/dev/null | awk 'NR>1 && NF>=2 { print $2; exit }'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n");
                win.scrcpyOk = l[0] === "scrcpy";
                win.adbState = win.scrcpyOk ? (l[1] ?? "").trim() : "";
            }
        }
    }
    Connections {
        target: Shell
        function onOpened(v) {
            if (v !== win.view) return;
            // Shell.open("ajustes", "audio" | "dnd" | "wifi" | "bt" | "ventanas") abre con ese desplegable
            win.expanded = ["audio", "dnd", "wifi", "bt", "ventanas"].includes(Shell.arg) ? Shell.arg : ""; win.pwFor = "";
            agenda.reset(true);   // teclas del calendario (← → días, N nuevo evento)
            notif.reset(Shell.section === "notificaciones" ? Shell.arg : null);
            nightCheck.running = true;
            phoneCheck.running = true;
            adbCheck.running = true;
            Net.refresh();
            HyprClients.refreshNow();
            flick.contentY = 0;
            scrollTimer.restart();
        }
    }
    // Desplaza la columna a la parte pedida (campana → notificaciones, hora → agenda), cuando ya está colocada
    Timer {
        id: scrollTimer
        interval: 40
        onTriggered: {
            const t = Shell.section === "notificaciones" ? notif : Shell.section === "agenda" ? agenda : null;
            flick.contentY = t ? Math.max(0, Math.min(t.y, flick.contentHeight - flick.height)) : 0;
        }
    }

    // ── Contenido: una columna que se desplaza si no cabe ──────────
    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        // Nunca fuera de los límites si cambia el contenido (p. ej. llega o se descarta una notificación)
        function clamp(): void { contentY = Math.max(0, Math.min(contentY, contentHeight - height)); }
        onContentHeightChanged: clamp()
        onHeightChanged: clamp()
        Behavior on contentY { enabled: !Theme.reduceMotion && !flick.moving; NumberAnimation { duration: Theme.dur; easing.type: Easing.OutCubic } }

        ColumnLayout {
            id: col
            width: flick.width
            // Llena el alto del panel (las notificaciones crecen) o lo que pida el contenido
            height: Math.max(flick.height, implicitHeight)
            spacing: 6

            // ═══ Tarjeta principal ═══
            Glass {
                id: mainCard
                kind: "panel"
                Layout.fillWidth: true
                Layout.preferredHeight: main.implicitHeight + 24
                ColumnLayout {
                    id: main
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                    spacing: 9

                    // Cabecera
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Rectangle {
                            implicitWidth: 30; implicitHeight: 30; radius: 15
                            color: Theme.pc
                            clip: true
                            Icon { anchors.centerIn: parent; name: "user"; color: Theme.pcText; size: 15; visible: face.status !== Image.Ready }
                            Image {
                                id: face
                                anchors.fill: parent
                                source: win.hasFace ? "file://" + Paths.home + "/.face" : ""
                                fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(60, 60)
                                visible: status === Image.Ready
                                layer.enabled: visible
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Txt { Layout.fillWidth: true; text: win.userName; weight: Font.DemiBold }
                            Txt {
                                Layout.fillWidth: true
                                size: 11.5; muted: true
                                text: Battery.present
                                      ? "Batería " + Math.round(Battery.percent * 100) + " %" + (Battery.timeText ? " · " + Battery.timeText + (Battery.charging ? " para cargar" : " restantes") : "")
                                      : (Net.connected ? (Net.type === "ethernet" ? "Cable conectado" : Net.ssid) : "Sin conexión") + " · " + Time.shortDate
                            }
                        }
                        Repeater {
                            model: [
                                { icon: "gear", tip: "Ajustes", run: () => Shell.open("ajustesapp") },
                                { icon: "lock", tip: "Bloquear", run: () => win.lock() },
                                { icon: "power", tip: "Apagar…", run: () => Shell.open("energia") }
                            ]
                            IconBtn {
                                required property var modelData
                                implicitWidth: 30; implicitHeight: 30; radius: Theme.r(6)
                                color: Theme.fill2
                                icon: modelData.icon; iconSize: 15; tooltip: modelData.tip
                                onClicked: modelData.run()
                            }
                        }
                    }

                    // Deslizadores
                    AjusteSlider {
                        Layout.fillWidth: true
                        visible: Brightness.available
                        icon: "sun"
                        value: Brightness.value
                        onMoved: v => Brightness.set(Math.max(0.02, v))
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 5
                        AjusteSlider {
                            Layout.fillWidth: true
                            icon: Audio.muted ? "volume" : Audio.volume < 0.34 ? "volume_low" : "volume_high"
                            value: Audio.volume
                            muted: Audio.muted
                            onMoved: v => Audio.setVolume(v)
                            onIconClicked: Audio.toggleMute()
                        }
                        // Salida, entrada y volumen por app (AudioPanel.qml)
                        IconBtn {
                            implicitWidth: 32; implicitHeight: 32; radius: Theme.ctl(32)
                            color: win.expanded === "audio" ? Theme.fillOn : Theme.fill2
                            fg: win.expanded === "audio" ? Theme.fillOnText : Theme.t
                            icon: win.expanded === "audio" ? "chevron_up" : "chevron_down"; iconSize: 13
                            tooltip: "Salida, entrada y volumen por app"
                            onClicked: win.expanded = win.expanded === "audio" ? "" : "audio"
                        }
                    }
                    Loader {
                        Layout.fillWidth: true
                        active: win.expanded === "audio"
                        visible: active
                        source: "AudioPanel.qml"
                    }

                    // Mosaicos en páginas que se deslizan en horizontal (arrastrar, rueda o los puntos de abajo);
                    // los desplegables (Wi‑Fi, Bluetooth, ventanas, no molestar, cafeína, teléfono) se abren debajo
                    Item {
                        id: pager
                        Layout.fillWidth: true
                        implicitHeight: Math.max(pg1.implicitHeight, pg2.implicitHeight)
                        property int page: 0
                        readonly property int pages: 2
                        function go(i: int): void {
                            page = Math.max(0, Math.min(pages - 1, i));
                            snap.to = page * pflick.width;
                            snap.restart();
                        }
                        Flickable {
                            id: pflick
                            anchors.fill: parent
                            contentWidth: width * pager.pages
                            contentHeight: height
                            flickableDirection: Flickable.HorizontalFlick
                            boundsBehavior: Flickable.StopAtBounds
                            clip: true
                            onMovementEnded: pager.go(Math.round(contentX / Math.max(1, width) + (horizontalVelocity > 300 ? 0.3 : horizontalVelocity < -300 ? -0.3 : 0)))
                            onWidthChanged: contentX = pager.page * width
                            NumberAnimation { id: snap; target: pflick; property: "contentX"; duration: Theme.dur; easing.type: Easing.OutCubic }
                            Row {
                                Item {
                                    width: pflick.width; height: pg1.implicitHeight
                                    Loader { id: pg1; width: parent.width; sourceComponent: page1C }
                                }
                                Item {
                                    width: pflick.width; height: pg2.implicitHeight
                                    Loader { id: pg2; width: parent.width; sourceComponent: page2C }
                                }
                            }
                        }
                        // rueda (horizontal, o vertical con Mayús) cambia de página
                        WheelHandler {
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            property real acc: 0
                            onWheel: e => {
                                const d = e.angleDelta.x !== 0 ? -e.angleDelta.x : (e.modifiers & Qt.ShiftModifier) ? -e.angleDelta.y : 0;
                                if (d === 0) { e.accepted = false; return; }
                                acc += d;
                                if (Math.abs(acc) >= 120) { pager.go(pager.page + (acc > 0 ? 1 : -1)); acc = 0; }
                            }
                        }
                        Component {
                            id: page1C
                            GridLayout {
                                    width: pflick.width
                                    columns: 2
                                    rowSpacing: 5; columnSpacing: 5
                                    AjusteTile {
                                        Layout.fillWidth: true; Layout.preferredWidth: 10
                                        icon: Net.type === "ethernet" ? "monitor" : "wifi_off"
                                        label: Net.type === "ethernet" ? "Red" : "Wi‑Fi"
                                        active: Net.wifiEnabled || Net.type === "ethernet"
                                        sub: Net.type === "ethernet" ? "Cable conectado" : !Net.wifiEnabled ? "Apagado" : Net.connected ? Net.ssid : "Sin conectar"
                                        expandable: true
                                        expanded: win.expanded === "wifi"
                                        onClicked: Net.setWifi(!Net.wifiEnabled)
                                        onExpand: { win.expanded = win.expanded === "wifi" ? "" : "wifi"; win.pwFor = ""; if (win.expanded) Net.scan(); }
                                    }
                                    AjusteTile {
                                        Layout.fillWidth: true; Layout.preferredWidth: 10
                                        icon: "bluetooth"; label: "Bluetooth"
                                        available: Bt.available
                                        active: Bt.enabled
                                        sub: !Bt.available ? "No disponible" : !Bt.enabled ? "Apagado"
                                             : Bt.connected.length === 1 ? (Bt.connected[0].name || "1 dispositivo")
                                             : Bt.connected.length + " dispositivos"
                                        expandable: Bt.available
                                        expanded: win.expanded === "bt"
                                        onClicked: Bt.setEnabled(!Bt.enabled)
                                        onExpand: win.expanded = win.expanded === "bt" ? "" : "bt"
                                    }
                                    // Modo de ventanas: clic = siguiente modo general (como Super + Mayús + Espacio); el desplegable
                                    // elige el general o uno solo para este espacio
                                    AjusteTile {
                                        Layout.fillWidth: true; Layout.preferredWidth: 10
                                        icon: WinMode.icons[win.wsMode] ?? "tiles"; label: "Ventanas"
                                        active: win.wsMode !== "flotante"
                                        sub: (WinMode.labels[win.wsMode] ?? "") + (win.wsOverride ? " · solo aquí" : "")
                                        expandable: true
                                        expanded: win.expanded === "ventanas"
                                        onClicked: WinMode.cycle()
                                        onExpand: win.expanded = win.expanded === "ventanas" ? "" : "ventanas"
                                    }
                                    AjusteTile {
                                        Layout.fillWidth: true; Layout.preferredWidth: 10
                                        icon: "focus"; label: "Sin distracciones"
                                        active: Shell.focusMode
                                        sub: Shell.focusMode ? "Activo" : "Super + Z"
                                        onClicked: Shell.setFocusMode(!Shell.focusMode)
                                    }
                                    AjusteTile {
                                        Layout.fillWidth: true; Layout.preferredWidth: 10
                                        icon: "dnd"; label: "No molestar"
                                        active: Notifs.dnd
                                        sub: Notifs.dnd ? (Notifs.dndUntil > 0 ? Notifs.dndLeft.charAt(0).toUpperCase() + Notifs.dndLeft.slice(1) : "Activado") : "Desactivado"
                                        expandable: true
                                        expanded: win.expanded === "dnd"
                                        onClicked: Notifs.setDnd(!Notifs.dnd)
                                        onExpand: win.expanded = win.expanded === "dnd" ? "" : "dnd"
                                    }
                                    AjusteTile {
                                        Layout.fillWidth: true; Layout.preferredWidth: 10
                                        icon: "moon"; label: "Luz nocturna"
                                        active: win.nightOn
                                        sub: win.nightOn ? "hyprsunset · " + Settings.get("nightTemp", 4000) + " K" : "Desactivada"
                                        onClicked: win.setNight(!win.nightOn)
                                    }
                                }
                        }
                        Component {
                            id: page2C
                            GridLayout {
                                    width: pflick.width
                                    columns: 2
                                    rowSpacing: 5; columnSpacing: 5
                                    AjusteTile {
                                        Layout.fillWidth: true; Layout.preferredWidth: 10
                                        icon: "contrast"; label: "Claro/oscuro auto"
                                        readonly property bool auto: Settings.get("themeMode", "oscuro") === "auto"
                                        active: auto
                                        sub: !auto ? "Manual" : Settings.get("themeSchedule", "horas") === "sol" ? "Según el sol" : "Según la hora"
                                        onClicked: Settings.set("themeMode", auto ? (Theme.light ? "claro" : "oscuro") : "auto")
                                    }
                                    AjusteTile {
                                        Layout.fillWidth: true; Layout.preferredWidth: 10
                                        icon: "monitor"; label: "Escritorio remoto"
                                        available: win.vncAvailable
                                        active: win.vncOn
                                        sub: !win.vncAvailable ? "Instala wayvnc" : win.vncOn ? (win.vncNet ? "Red · con contraseña" : "Solo este equipo") : "Desactivado"
                                        onClicked: win.setVnc(!win.vncOn)
                                    }
                                    // Cafeína (services/Caffeine.qml): sin apagar la pantalla ni suspender por inactividad
                                    AjusteTile {
                                        Layout.fillWidth: true; Layout.preferredWidth: 10
                                        icon: "coffee"; label: "Cafeína"
                                        active: Caffeine.on
                                        sub: Caffeine.on ? (Caffeine.left ? "Quedan " + Caffeine.left : "Pantalla siempre encendida") : "Super + Alt + C"
                                        expandable: true
                                        expanded: win.expanded === "cafe"
                                        onClicked: Caffeine.toggle()
                                        onExpand: win.expanded = win.expanded === "cafe" ? "" : "cafe"
                                    }
                                    // Selector de color (modules/colorpicker): elige un color de la pantalla
                                    AjusteTile {
                                        Layout.fillWidth: true; Layout.preferredWidth: 10
                                        icon: "drop"; label: "Selector de color"
                                        sub: "Super + Mayús + C"
                                        onClicked: Shell.open("color")
                                    }
                                    // Teléfono (Valent o KDE Connect, hf-phone): clic abre la app; el desplegable, sonar y enviar archivo
                                    AjusteTile {
                                        Layout.fillWidth: true; Layout.preferredWidth: 10
                                        icon: "phone"
                                        label: win.phone ? win.phone.name : win.phoneBackend === "kdeconnect" ? "KDE Connect" : "Teléfono"
                                        available: win.phoneBackend !== ""
                                        active: win.phone !== null
                                        sub: win.phoneBackend === "" ? "Instala Valent"
                                            : win.phone ? (win.phone.battery ? "Batería " + win.phone.battery.percentage + " %" + (win.phone.battery.charging ? " · cargando" : "") : "Conectado")
                                            : win.phoneRunning ? "Ningún móvil enlazado" : "Valent no está en marcha"
                                        expandable: win.phone !== null
                                        expanded: win.expanded === "phone"
                                        onClicked: { Shell.close(); Quickshell.execDetached([Paths.script("hf-phone"), "open"].concat(win.phone ? [win.phone.id] : [])); }
                                        onExpand: win.expanded = win.expanded === "phone" ? "" : "phone"
                                    }
                                    // Duplicar la pantalla del móvil con scrcpy (adb por USB o Wi‑Fi)
                                    AjusteTile {
                                        Layout.fillWidth: true; Layout.preferredWidth: 10
                                        icon: "monitor"; label: "Duplicar móvil"
                                        active: win.scrcpyOk && win.adbState === "device"
                                        sub: !win.scrcpyOk ? "Instalar scrcpy"
                                            : ({ device: "Listo · clic para abrir", unauthorized: "Acepta la depuración USB",
                                                 offline: "El móvil no responde a adb" })[win.adbState] ?? "Conecta el móvil por USB"
                                        onClicked: {
                                            if (!win.scrcpyOk) { const t = Pkg.tool("scrcpy"); if (t) { Pkg.install([t], "Instalar scrcpy"); Shell.close(); } }
                                            else if (win.adbState === "device") { Shell.close(); Shell.exec(["scrcpy", "--window-title", win.phone?.name || "Android"]); }
                                            else adbCheck.running = true;
                                        }
                                    }
                                }
                        }
                    }
                    // puntos de página
                    Row {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 6
                        Repeater {
                            model: pager.pages
                            Rectangle {
                                required property int index
                                width: pager.page === index ? 16 : 6; height: 6; radius: 3
                                color: pager.page === index ? Theme.t : Qt.alpha(Theme.t, 0.3)
                                Behavior on width { NumberAnimation { duration: Theme.dur } }
                                MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor; onClicked: pager.go(parent.index) }
                            }
                        }
                    }
                    // Lista desplegable (ocupa las dos columnas, justo debajo de Wi-Fi/Bluetooth)
                    Loader {
                        Layout.fillWidth: true
                        active: win.expanded === "wifi" || win.expanded === "bt"
                        visible: active
                        sourceComponent: win.expanded === "wifi" ? wifiList : btList
                    }
                    Loader {
                        Layout.fillWidth: true
                        active: win.expanded === "ventanas"
                        visible: active
                        sourceComponent: Rectangle {
                            radius: Theme.r(6)
                            color: Theme.fill2
                            implicitHeight: wmCol.implicitHeight + 16
                            ColumnLayout {
                                id: wmCol
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                                spacing: 6
                                Txt { text: "Todos los espacios"; size: 11.5; muted: true }
                                AjusteSeg {
                                    Layout.fillWidth: true
                                    model: WinMode.modes.map(m => ({ key: m, label: WinMode.labels[m] }))
                                    current: WinMode.mode
                                    onPicked: k => WinMode.setMode(k)
                                }
                                // Elegir el mismo modo que el general quita la excepción
                                Txt {
                                    Layout.fillWidth: true; Layout.topMargin: 2
                                    text: "Solo el espacio " + win.curWs + (win.wsOverride ? " · hasta cerrar la sesión" : " · como todos")
                                    size: 11.5; muted: true
                                }
                                AjusteSeg {
                                    Layout.fillWidth: true
                                    model: WinMode.modes.map(m => ({ key: m, label: WinMode.labels[m] }))
                                    current: win.wsMode
                                    onPicked: k => WinMode.setWsMode(win.curWs, k)
                                }
                            }
                        }
                    }
                    // Atajos de «no molestar» (1 h, esta noche, mañana…), bajo su mosaico
                    Loader {
                        Layout.fillWidth: true
                        active: win.expanded === "dnd"
                        visible: active
                        sourceComponent: DndPresets { onPicked: win.expanded = "" }
                    }
                    Loader {
                        Layout.fillWidth: true
                        active: win.expanded === "cafe"
                        visible: active
                        sourceComponent: RowLayout {
                            spacing: 5
                            Repeater {
                                model: [[30, "30 min"], [60, "1 hora"], [120, "2 horas"], [0, "Sin límite"]]
                                Btn {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    h: 28; padX: 6; text: modelData[1]
                                    onClicked: { Caffeine.set(true, modelData[0]); win.expanded = ""; }
                                }
                            }
                        }
                    }
                    // Acciones del móvil enlazado (desplegable del mosaico Teléfono)
                    Loader {
                        Layout.fillWidth: true
                        active: win.expanded === "phone" && win.phone !== null
                        visible: active
                        sourceComponent: RowLayout {
                            spacing: 5
                            Btn { Layout.fillWidth: true; h: 28; padX: 6; icon: "bell"; text: "Hacer sonar"
                                  onClicked: Quickshell.execDetached([Paths.script("hf-phone"), "ring", win.phone.id]) }
                            Btn { Layout.fillWidth: true; h: 28; padX: 6; icon: "upload"; text: "Enviar archivo"
                                  onClicked: { Shell.close(); Quickshell.execDetached([Paths.script("hf-phone"), "share", win.phone.id]); } }
                        }
                    }
                    // Modo de energía
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5
                        Txt { size: 11.5; muted: true; text: "Modo de energía" }
                        AjusteSeg {
                            Layout.fillWidth: true
                            model: [{ key: "ahorro", label: "Ahorro" }, { key: "equilibrado", label: "Equilibrado" }]
                                   .concat(Battery.hasPerformance ? [{ key: "rendimiento", label: "Rendimiento" }] : [])
                            current: Battery.profile
                            onPicked: k => Battery.setProfile(k)
                        }
                    }
                }
            }

            // ═══ Notificaciones (el sitio que sobre) ═══
            // Ocupa solo el hueco entre los ajustes rápidos y la agenda: con muchos avisos se desplazan las listas de
            // Recientes e Historial por dentro y el resto del centro (ajustes, agenda) queda fijo y a la vista.
            // (La columna entera solo se desplaza si ni con el mínimo de 180 px cabe todo: pantallas muy bajas.)
            readonly property real notifRoom: flick.height - mainCard.height
                - (agenda.visible ? agenda.implicitHeight + spacing : 0) - spacing
            NotifCenter {
                id: notif
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: Math.min(implicitHeight, 180)
                Layout.maximumHeight: Math.max(180, col.notifRoom)
                Layout.preferredHeight: Math.min(implicitHeight, Math.max(180, col.notifRoom))
            }

            // ═══ Agenda ═══
            AgendaCard {
                id: agenda
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
            }
        }
    }
    // Barra de desplazamiento (fina, colores del tema; solo si no cabe)
    Rectangle {
        visible: flick.contentHeight > flick.height + 1
        anchors.right: parent.right
        anchors.rightMargin: 2
        y: flick.visibleArea.yPosition * flick.height + 6
        width: barMa.containsMouse || barMa.pressed ? 5 : 3
        height: Math.max(24, flick.visibleArea.heightRatio * flick.height - 12)
        radius: width / 2
        color: Theme.t
        opacity: barMa.containsMouse || barMa.pressed || flick.moving ? 0.45 : 0.22
        Behavior on opacity { NumberAnimation { duration: 140 } }
        Behavior on width { NumberAnimation { duration: 120 } }
        MouseArea {
            id: barMa
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            property real grabY: 0
            property real startY: 0
            onPressed: m => { grabY = mapToItem(win.panel, m.x, m.y).y; startY = flick.contentY; }
            onPositionChanged: m => {
                if (!pressed) return;
                const dy = mapToItem(win.panel, m.x, m.y).y - grabY;
                flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, startY + dy / flick.visibleArea.heightRatio));
            }
        }
    }

    // ── Listas desplegables ────────────────────────────────────────
    Component {
        id: wifiList
        Rectangle {
            radius: Theme.r(6)
            color: Theme.fill2
            implicitHeight: wl.implicitHeight + 8
            ColumnLayout {
                id: wl
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 4 }
                spacing: 1
                Txt {
                    visible: Net.networks.length === 0
                    Layout.fillWidth: true; Layout.preferredHeight: 30; Layout.leftMargin: 8
                    muted: true; size: 11.5
                    text: !Net.wifiEnabled ? "El Wi‑Fi está apagado" : searching.running ? "Buscando redes…" : "No se encontraron redes Wi‑Fi"
                    Timer { id: searching; running: true; interval: 5000 }
                }
                Repeater {
                    model: Net.networks.slice(0, 8)
                    ColumnLayout {
                        id: row
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 2
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 30; radius: Theme.r(5)
                            color: rowMa.containsMouse ? Theme.s1 : "transparent"
                            RowLayout {
                                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                spacing: 8
                                Icon { name: "wifi"; size: 13; opacity: 0.4 + 0.6 * row.modelData.signal / 100 }
                                Txt { Layout.fillWidth: true; text: row.modelData.ssid; weight: row.modelData.active ? Font.DemiBold : Font.Normal }
                                Icon { visible: row.modelData.secure; name: "lock"; size: 11; color: Theme.tv }
                                Icon { visible: row.modelData.active; name: "check"; size: 13; color: Theme.p }
                            }
                            MouseArea {
                                id: rowMa
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const m = row.modelData;
                                    if (m.active) return;
                                    if (m.secure) win.pwFor = win.pwFor === m.ssid ? "" : m.ssid;
                                    else Net.connect(m.ssid, "");
                                }
                            }
                        }
                        Rectangle {
                            visible: win.pwFor === row.modelData.ssid
                            Layout.fillWidth: true
                            implicitHeight: 28; radius: Theme.r(5)
                            color: Theme.s1
                            TextInput {
                                id: pw
                                anchors { fill: parent; leftMargin: 10; rightMargin: 34 }
                                verticalAlignment: TextInput.AlignVCenter
                                echoMode: TextInput.Password
                                color: Theme.t
                                font.family: Theme.font; font.pixelSize: Theme.px(12)
                                focus: parent.visible
                                onVisibleChanged: if (visible) forceActiveFocus()
                                onAccepted: { Net.connect(row.modelData.ssid, text); text = ""; win.pwFor = ""; }
                                Txt { visible: !pw.text; anchors.fill: parent; muted: true; size: 12; text: "Contraseña…" }
                            }
                            IconBtn {
                                anchors { right: parent.right; rightMargin: 3; verticalCenter: parent.verticalCenter }
                                implicitWidth: 22; implicitHeight: 22; radius: 11
                                color: Theme.p; fg: Theme.pText; icon: "arrow_right"; iconSize: 12
                                onClicked: pw.accepted()
                            }
                        }
                    }
                }
            }
        }
    }
    Component {
        id: btList
        Rectangle {
            radius: Theme.r(6)
            color: Theme.fill2
            implicitHeight: bl.implicitHeight + 8
            ColumnLayout {
                id: bl
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 4 }
                spacing: 1
                Txt {
                    readonly property var known: Bt.devices.filter(d => d.paired || d.connected)
                    visible: known.length === 0
                    Layout.fillWidth: true; Layout.preferredHeight: 30; Layout.leftMargin: 8
                    muted: true; size: 11.5
                    text: Bt.enabled ? "No hay dispositivos emparejados" : "El Bluetooth está apagado"
                }
                Repeater {
                    model: Bt.devices.filter(d => d.paired || d.connected)
                    Rectangle {
                        id: dev
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 30; radius: Theme.r(5)
                        color: devMa.containsMouse ? Theme.s1 : "transparent"
                        RowLayout {
                            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                            spacing: 8
                            Icon { name: "bluetooth"; size: 13; color: dev.modelData.connected ? Theme.p : Theme.tv }
                            Txt { Layout.fillWidth: true; text: dev.modelData.name || dev.modelData.deviceName; weight: dev.modelData.connected ? Font.DemiBold : Font.Normal }
                            Txt {
                                visible: dev.modelData.connected && dev.modelData.batteryAvailable
                                size: 11; muted: true; tabular: true
                                text: Math.round((dev.modelData.battery ?? 0) * 100) + " %"
                            }
                            Txt { size: 11; muted: true; text: dev.modelData.connected ? "Desconectar" : "Conectar" ; opacity: devMa.containsMouse ? 1 : 0 }
                        }
                        MouseArea {
                            id: devMa
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: dev.modelData.connected ? dev.modelData.disconnect() : dev.modelData.connect()
                        }
                    }
                }
            }
        }
    }

    // ── Piezas propias (componentes en línea: evitan la carga asíncrona de tipos del LazyLoader) ──
    // Deslizador de ajustes rápidos (design: alto 30, radio 6, relleno p con el icono dentro).
    // Clic/arrastre/rueda. Muestra el porcentaje a la derecha al pasar el ratón (mejora).
    component AjusteSlider: Rectangle {
        id: root
        property string icon: ""
        property real value: 0.5          // 0–1
        property bool muted: false
        signal moved(real value)
        signal iconClicked()
        implicitHeight: 32
        radius: Theme.ctl(height)
        color: Theme.fill2
        clip: true
        readonly property real frac: Math.max(0, Math.min(1, value))
        Rectangle {
            width: Math.max(34, parent.width * root.frac)
            height: parent.height
            radius: parent.radius
            color: root.muted ? Theme.o : Theme.fillOn
            Behavior on width { enabled: !drag.pressed; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: Theme.dur } }
        }
        MouseArea {
            id: drag
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            function upd(mx) { root.moved(Math.max(0, Math.min(1, mx / width))); }
            onPressed: m => { if (m.x < 30) { root.iconClicked(); m.accepted = false; return; } upd(m.x); }
            onPositionChanged: m => { if (pressed) upd(m.x); }
            onWheel: w => root.moved(Math.max(0, Math.min(1, root.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
        }
        MouseArea {
            width: 30; height: parent.height
            cursorShape: Qt.PointingHandCursor
            onClicked: root.iconClicked()
        }
        Icon { x: 11; anchors.verticalCenter: parent.verticalCenter; name: root.icon; color: root.muted ? Theme.t : Theme.fillOnText }
        Txt {
            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            text: Math.round(root.value * 100) + " %"
            size: 11.5
            tabular: true
            color: root.frac > 0.86 ? Theme.fillOnText : Theme.tv
            opacity: drag.containsMouse || drag.pressed ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 140 } }
        }
    }

    // Mosaico 44 px (design: radio 6, relleno 0 11, icono 17, hueco 10). Flecha opcional para desplegar.
    component AjusteTile: Rectangle {
        id: root
        property string icon: ""
        property string label: ""
        property string sub: ""
        property bool active: false
        property bool available: true
        property bool expandable: false
        property bool expanded: false
        signal clicked()
        signal expand()
        implicitHeight: Math.max(46, tcol.implicitHeight + 10)
        radius: Theme.pill ? Math.min(height / 2, Theme.r(11)) : Theme.r(6)
        scale: Theme.estilo !== "flat" && main.pressed ? 0.97 : 1
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 2 } }
        opacity: available ? 1 : 0.55
        color: active ? Theme.fillOn : Theme.fill2
        Behavior on color { ColorAnimation { duration: Theme.dur } }
        readonly property color fg: active ? Theme.fillOnText : Theme.t
        Rectangle {
            anchors.fill: parent; radius: parent.radius
            color: Theme.light ? "#000000" : "#FFFFFF"
            opacity: main.containsMouse ? 0.06 : 0
            Behavior on opacity { NumberAnimation { duration: 140 } }
        }
        Ripple { id: rip; anchors.fill: parent; radius: root.radius; color: root.fg }
        MouseArea {
            id: main
            anchors.fill: parent
            hoverEnabled: true
            onPressed: m => rip.burst(m.x, m.y)
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: root.available ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: m => {
                if (m.button === Qt.RightButton && root.expandable) root.expand();
                else if (root.available) root.clicked();
            }
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: root.expandable ? 2 : 11
            spacing: 10
            Icon { name: root.icon; color: root.fg; size: 17 }
            ColumnLayout {
                id: tcol
                Layout.fillWidth: true
                spacing: 0
                Txt { Layout.fillWidth: true; text: root.label; color: root.fg; weight: Font.DemiBold }
                Txt { Layout.fillWidth: true; text: root.sub; color: root.fg; opacity: 0.85; size: 11.5 }
            }
            Rectangle {
                visible: root.expandable
                implicitWidth: 22
                implicitHeight: 32
                radius: Theme.r(5)
                color: exp.containsMouse ? Qt.alpha(root.fg, 0.12) : "transparent"
                Icon { anchors.centerIn: parent; name: root.expanded ? "chevron_up" : "chevron_down"; color: root.fg; size: 13 }
                MouseArea { id: exp; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.expand() }
            }
        }
    }

    // Segmentado compacto de los ajustes rápidos (design: alto 28, radio 5, relleno 2, botones radio 4).
    component AjusteSeg: Rectangle {
        id: root
        property var model: []          // [{ key, label }]
        property string current: ""
        property real itemRadius: Theme.ctl(24)
        signal picked(string key)
        implicitHeight: 28
        radius: Theme.ctl(28)
        color: Theme.fill2
        RowLayout {
            anchors.fill: parent
            anchors.margins: 2
            spacing: 2
            Repeater {
                model: root.model
                Rectangle {
                    required property var modelData
                    readonly property bool sel: root.current === modelData.key
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 10
                    radius: root.itemRadius
                    color: sel ? Theme.segThumb : hov.hovered ? Qt.alpha(Theme.s1, 0.35) : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.dur } }
                    HoverHandler { id: hov }
                    Txt {
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, parent.width - 6)
                        horizontalAlignment: Text.AlignHCenter
                        text: parent.modelData.label
                        weight: Font.DemiBold
                        color: parent.sel ? Theme.segText : Theme.tv
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.picked(parent.modelData.key) }
                }
            }
        }
    }
}
