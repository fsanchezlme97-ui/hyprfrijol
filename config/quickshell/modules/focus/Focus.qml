// Modo sin distracciones (diseño «Enfoque», Super + Z → hl.dsp.global("hf:enfoque") → Shell.setFocusMode).
// Mientras está activo: píldora abajo con el pomodoro (o la hora), avisos en pausa («no molestar») y botón Salir.
// Al salir se restaura el «no molestar» que hubiera antes.
// focusBlock (Ajustes › Enfoque): mientras corre un bloque de foco del pomodoro se cierran las ventanas de esas
// categorías (y las que se abran): youtube / pinterest / whatsapp → web apps del panel lateral (y clientes de WhatsApp),
// juegos → steam_app_* y gamescope, redes → clientes nativos de redes sociales, correo → Thunderbird, Evolution, Geary.
// No toca pestañas del navegador.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../.."
import "../../components"
import "../../services"

Scope {
    id: root
    property bool dndBefore: false

    Connections {
        target: Shell
        function onFocusModeChanged() {
            if (Shell.focusMode) {
                root.dndBefore = Notifs.dnd;
                if (!Notifs.dnd) Notifs.setDnd(true);
            } else if (!root.dndBefore && Notifs.dnd) {
                Notifs.setDnd(false);
            }
        }
    }

    // ---------- Bloqueo durante el foco ----------
    readonly property bool blocking: Pomodoro.running && Pomodoro.mode === "foco"
    readonly property var blockList: { const v = Settings.get("focusBlock", []); return Array.isArray(v) ? v : []; }
    readonly property var blockRules: ({
        whatsapp:  { cls: /^(whatsapp.*|whatsdesk|zapzap|com\.rtosta\.zapzap)$/i },
        juegos:    { cls: /^(steam_app_\d+|gamescope)$/i },
        redes:     { cls: /(tiktok|instagram|facebook|twitter|reddit|mastodon|tuba|tokodon|bluesky)/i },
        correo:    { cls: /^(thunderbird|org\.mozilla\.thunderbird|betterbird|evolution|org\.gnome\.evolution|geary|org\.gnome\.geary)$/i }
    })
    function blockedBy(c): string {
        for (const k of root.blockList) {
            const r = root.blockRules[k];
            if (r?.cls && r.cls.test(c.class ?? "")) return k;
        }
        return "";
    }
    property var closing: ({})          // direcciones ya cerradas (no repetir aviso mientras desaparecen)
    function sweep(): void {
        if (!root.blocking || root.blockList.length === 0) { root.closing = ({}); return; }
        const hit = [];
        for (const c of HyprClients.clients) {
            if (root.closing[c.address] || !root.blockedBy(c)) continue;
            root.closing[c.address] = true;
            Shell.dispatch('hl.dsp.window.close({ window = "address:' + c.address + '" })');
            hit.push(HyprClients.appName(c.class) || c.title || c.class);
        }
        if (hit.length)
            Quickshell.execDetached(["notify-send", "-a", "Enfoque", "Bloqueado durante el foco", [...new Set(hit)].join(", ")]);
    }
    onBlockingChanged: sweep()
    Connections {
        target: HyprClients
        enabled: root.blocking && root.blockList.length > 0
        function onClientsChanged() { root.sweep(); }
    }

    PanelWindow {
        id: win
        screen: Shell.screen
        visible: Shell.focusMode || pill.opacity > 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "hf-enfoque"
        exclusionMode: ExclusionMode.Ignore
        anchors.bottom: true
        margins.bottom: 14
        implicitWidth: pill.implicitWidth + 24
        implicitHeight: 34 + 20

        Item {
            id: pill
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 2
            implicitWidth: row.implicitWidth + 14 + 5
            height: 34
            width: implicitWidth
            opacity: Shell.focusMode ? 1 : 0
            transform: Translate { y: Shell.focusMode ? 0 : 10; Behavior on y { NumberAnimation { duration: Theme.durIn; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } } }
            Behavior on opacity { NumberAnimation { duration: Theme.dur } }

            Glass { anchors.fill: parent; kind: "panel"; radius: Theme.ctl(height) }

            RowLayout {
                id: row
                anchors.left: parent.left; anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                // Pomodoro: punto + tiempo (clic → iniciar/pausar). Sin pomodoro en marcha muestra la hora.
                Item {
                    implicitWidth: pomo.implicitWidth
                    implicitHeight: 24
                    RowLayout {
                        id: pomo
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        Rectangle {
                            id: pomoDot
                            width: 7; height: 7; radius: 3.5
                            color: Pomodoro.running ? Theme.ter : Theme.o
                            SequentialAnimation on opacity {
                                running: Pomodoro.running && !Theme.reduceMotion
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                                onRunningChanged: if (!running) pomoDot.opacity = 1
                            }
                        }
                        Txt {
                            text: Pomodoro.running || Pomodoro.left !== Pomodoro.total ? Pomodoro.time : Time.hhmm
                            size: 13
                            weight: Font.DemiBold
                            tabular: true
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Pomodoro.toggle()
                    }
                }
                Txt {
                    text: "Sin distracciones · avisos en pausa · Super + Z para salir"
                    size: 12.5
                    muted: true
                }
                Rectangle {
                    implicitWidth: salir.implicitWidth + 24
                    implicitHeight: 24
                    radius: Theme.r(6)
                    color: exitMa.containsMouse ? Qt.lighter(Theme.p, 1.08) : Theme.p
                    Txt {
                        id: salir
                        anchors.centerIn: parent
                        text: "Salir"
                        color: Theme.pText
                        weight: Font.DemiBold
                    }
                    MouseArea {
                        id: exitMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Shell.setFocusMode(false)
                    }
                }
            }
        }
    }
}
