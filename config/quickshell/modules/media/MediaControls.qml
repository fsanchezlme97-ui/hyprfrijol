// Controles de música (vista "musica", Super + M o clic en la onda de la barra).
//   Cabecera: icono y nombre real de la app que suena (entrada .desktop; las web apps integradas, con el suyo)
//   y «Abrir» (trae la app al frente).
//   Tarjeta: carátula, título, artista y álbum · barra de progreso con tiempos (clic o arrastrar = buscar) ·
//   aleatorio, anterior, reproducir/pausar, siguiente, repetir.
//   Volumen de la salida + salida de audio (desplegable con los dispositivos).
//   Reproductores: lista solo si hay más de uno, ya sin duplicados (services/Media.qml: fuera playerctld, el puente de
//   plasma-browser-integration, instancias vacías del navegador y copias de la misma pista).
// Teclas: Espacio reproducir/pausar · ← → buscar 5 s · Mayús+← → pista · ↑ ↓ volumen · Tab cambiar de reproductor ·
// Esc cerrar.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import "../.."
import "../../components"
import "../../services"

Overlay {
    id: win
    view: "musica"
    place: "bottom"            // junto a la onda de la barra (arriba si la barra está arriba)
    panelWidth: 400
    panelHeight: card.implicitHeight

    readonly property var players: Media.players
    property string pinned: ""           // dbusName elegido a mano en la lista
    readonly property var player: players.find(p => p.dbusName === pinned) ?? Media.active
    readonly property var app: Media.appOf(player)
    property real pos: 0
    property bool showDevices: false
    // Duración en segundos (metadatos MPRIS en µs, o `length`). Ojo: VLC anuncia al empezar una estimación
    // y no avisa cuando la corrige, así que con algunos MP3 la duración puede quedar corta.
    readonly property real len: {
        const m = player?.metadata ?? {};
        const us = Number(m["mpris:length"] ?? 0);
        return us > 0 ? us / 1e6 : (player?.lengthSupported ? player.length : 0);
    }

    function fmt(s: real): string {
        if (!isFinite(s) || s < 0) s = 0;
        s = Math.floor(s);
        const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), x = s % 60;
        return (h ? h + ":" + String(m).padStart(2, "0") : m) + ":" + String(x).padStart(2, "0");
    }
    function seekBy(d: real): void {
        if (player?.canSeek && player.positionSupported) player.position = Math.max(0, Math.min(len || 1e9, player.position + d));
    }
    function cycle(d: int): void {
        if (players.length < 2) return;
        const i = Math.max(0, players.indexOf(player));
        pinned = players[(i + d + players.length) % players.length].dbusName;
    }

    onShownChanged: if (shown) { pinned = ""; showDevices = false; panelFocus.forceActiveFocus(); }

    // MPRIS no avisa del avance: se refresca la posición mientras suena y el panel está abierto
    Timer {
        running: win.shown && (win.player?.isPlaying ?? false)
        interval: 500
        repeat: true
        triggeredOnStart: true
        onTriggered: { win.player.positionChanged(); win.pos = win.player.position; }
    }
    Connections {
        target: win.player
        function onPositionChanged() { if (!seek.dragging) win.pos = win.player.position; }
        function onTrackChanged() { win.pos = 0; }
    }
    onPlayerChanged: pos = player?.position ?? 0

    // Icono de una app: el del tema (Papirus) o, si no hay, la inicial
    component AppIcon: Item {
        id: ai
        property var info: ({ name: "", icon: "" })
        property real size: 16
        implicitWidth: size; implicitHeight: size
        Image {
            id: aiImg
            anchors.fill: parent
            source: ai.info?.icon ?? ""
            sourceSize: Qt.size(ai.size * 2, ai.size * 2)
            visible: status === Image.Ready
            asynchronous: true
        }
        Rectangle {
            anchors.fill: parent
            visible: aiImg.status !== Image.Ready
            radius: Theme.r(ai.size / 4)
            color: Theme.sc
            Txt { anchors.centerIn: parent; text: String(ai.info?.name ?? "?").charAt(0).toUpperCase(); size: ai.size * 0.55; weight: Font.Bold; color: Theme.scText }
        }
    }

    Glass {
        id: card
        anchors.fill: parent
        kind: "popup"
        implicitHeight: col.implicitHeight + 32

        Item {
            id: panelFocus
            focus: true
            Keys.onPressed: e => {
                const p = win.player;
                if (e.key === Qt.Key_Escape) Shell.close();
                else if (e.key === Qt.Key_Up) Audio.setVolume(Audio.volume + 0.05);
                else if (e.key === Qt.Key_Down) Audio.setVolume(Audio.volume - 0.05);
                else if (!p) return;
                else if (e.key === Qt.Key_Space || e.key === Qt.Key_K) p.togglePlaying();
                else if (e.key === Qt.Key_Left) { if (e.modifiers & Qt.ShiftModifier) { if (p.canGoPrevious) p.previous(); } else win.seekBy(-5); }
                else if (e.key === Qt.Key_Right) { if (e.modifiers & Qt.ShiftModifier) { if (p.canGoNext) p.next(); } else win.seekBy(5); }
                else if (e.key === Qt.Key_Tab) win.cycle(1);
                else if (e.key === Qt.Key_Backtab) win.cycle(-1);
                else return;
                e.accepted = true;
            }
        }

        ColumnLayout {
            id: col
            x: 16; y: 16
            width: parent.width - 32
            spacing: 14

            // ---------------------------------------------------------------- sin reproductores
            RowLayout {
                visible: !win.player
                Layout.fillWidth: true
                spacing: 14
                Rectangle {
                    Layout.preferredWidth: 56; Layout.preferredHeight: 56; radius: Theme.r(12); color: Theme.fill2
                    Icon { anchors.centerIn: parent; name: "music"; size: 22; color: Theme.tv }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    Txt { text: "No hay nada sonando"; weight: Font.DemiBold; size: 14 }
                    Txt {
                        Layout.fillWidth: true
                        text: "Reproduce algo en Spotify, el navegador o el panel lateral y aparecerá aquí."
                        size: 11.5; muted: true; wrapMode: Text.WordWrap; elide: Text.ElideNone
                    }
                }
            }

            // ---------------------------------------------------------------- cabecera: app
            RowLayout {
                visible: !!win.player
                Layout.fillWidth: true
                spacing: 8
                AppIcon { info: win.app; size: 18 }
                Txt { Layout.fillWidth: true; text: win.app.name; size: 12; weight: Font.Medium; color: Theme.tv }
                Rectangle {
                    visible: win.player?.canRaise ?? false
                    implicitHeight: 24; implicitWidth: openRow.implicitWidth + 16
                    radius: Theme.ctl(24)
                    color: openMa.containsMouse ? Theme.fill2 : "transparent"
                    border.width: 1; border.color: Theme.border
                    Row {
                        id: openRow
                        anchors.centerIn: parent
                        spacing: 5
                        Txt { text: "Abrir"; size: 11; anchors.verticalCenter: parent.verticalCenter }
                        Icon { name: "external"; size: 11; color: Theme.tv; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { id: openMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { win.player.raise(); Shell.close(); } }
                }
            }

            // ---------------------------------------------------------------- pista
            RowLayout {
                visible: !!win.player
                Layout.fillWidth: true
                spacing: 14
                Rectangle {
                    Layout.preferredWidth: 84; Layout.preferredHeight: 84
                    Layout.alignment: Qt.AlignTop
                    radius: Theme.r(12)
                    color: Theme.fill2
                    clip: true
                    AppIcon { anchors.centerIn: parent; visible: art.status !== Image.Ready; info: win.app; size: 34; opacity: 0.9 }
                    Image {
                        id: art
                        anchors.fill: parent
                        source: win.player?.trackArtUrl ?? ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize: Qt.size(168, 168)
                        visible: status === Image.Ready
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 3
                    Txt {
                        Layout.fillWidth: true
                        text: win.player?.trackTitle || "Sin título"
                        size: 15; weight: Font.DemiBold
                        wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                    }
                    Txt { Layout.fillWidth: true; text: win.player?.trackArtist ?? ""; visible: text !== ""; size: 12.5; color: Theme.tv }
                    Txt { Layout.fillWidth: true; text: win.player?.trackAlbum ?? ""; visible: text !== ""; size: 11.5; muted: true }
                }
            }

            // ---------------------------------------------------------------- progreso
            ColumnLayout {
                visible: !!win.player && win.len > 0
                Layout.fillWidth: true
                spacing: 2
                Item {
                    id: seek
                    Layout.fillWidth: true
                    Layout.preferredHeight: 16
                    property bool dragging: seekMa.pressed
                    property real preview: 0
                    readonly property real frac: {
                        const v = dragging ? preview : win.pos;
                        return win.len > 0 ? Math.max(0, Math.min(1, v / win.len)) : 0;
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width; height: seekMa.containsMouse || seek.dragging ? 6 : 4; radius: height / 2
                        color: Theme.fill2
                        Behavior on height { NumberAnimation { duration: 120 } }
                        Rectangle { width: Math.max(parent.height, parent.width * seek.frac); height: parent.height; radius: height / 2; color: Theme.p }
                    }
                    Rectangle {
                        visible: (seekMa.containsMouse || seek.dragging) && (win.player?.canSeek ?? false)
                        x: seek.width * seek.frac - 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 12; height: 12; radius: 6
                        color: Theme.p
                        border.width: 2; border.color: Theme.pText
                    }
                    MouseArea {
                        id: seekMa
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: win.player?.canSeek ?? false
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        function at(mx) { return Math.max(0, Math.min(1, mx / width)) * win.len; }
                        onPressed: m => seek.preview = at(m.x)
                        onPositionChanged: m => { if (pressed) seek.preview = at(m.x); }
                        onReleased: m => { win.player.position = at(m.x); win.pos = at(m.x); }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Txt { text: win.fmt(seek.dragging ? seek.preview : win.pos); size: 11; muted: true; tabular: true }
                    Item { Layout.fillWidth: true }
                    Txt { text: "−" + win.fmt(win.len - (seek.dragging ? seek.preview : win.pos)); size: 11; muted: true; tabular: true }
                }
            }

            // ---------------------------------------------------------------- controles
            Item {
                visible: !!win.player
                Layout.fillWidth: true
                implicitHeight: 48
                IconBtn {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    icon: "shuffle"; implicitWidth: 34; implicitHeight: 32
                    visible: win.player?.shuffleSupported ?? false
                    active: win.player?.shuffle ?? false
                    activeBg: Theme.pc; activeFg: Theme.pcText
                    tooltip: "Aleatorio"
                    onClicked: win.player.shuffle = !win.player.shuffle
                }
                Row {
                    anchors.centerIn: parent
                    spacing: 14
                    IconBtn {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "prev"; iconSize: 17; implicitWidth: 40; implicitHeight: 36
                        opacity: (win.player?.canGoPrevious ?? false) ? 1 : 0.35
                        onClicked: if (win.player?.canGoPrevious) win.player.previous()
                    }
                    Rectangle {
                        width: 48; height: 48; radius: 24
                        color: playMa.containsMouse ? Qt.lighter(Theme.p, 1.08) : Theme.p
                        scale: playMa.pressed ? 0.94 : 1
                        Behavior on scale { NumberAnimation { duration: 120 } }
                        Icon { anchors.centerIn: parent; name: (win.player?.isPlaying ?? false) ? "pause" : "play"; size: 19; color: Theme.pText; stroke: 2.4 }
                        MouseArea { id: playMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (win.player?.canTogglePlaying) win.player.togglePlaying() }
                    }
                    IconBtn {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "next"; iconSize: 17; implicitWidth: 40; implicitHeight: 36
                        opacity: (win.player?.canGoNext ?? false) ? 1 : 0.35
                        onClicked: if (win.player?.canGoNext) win.player.next()
                    }
                }
                IconBtn {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    icon: "repeat"; implicitWidth: 34; implicitHeight: 32
                    visible: win.player?.loopSupported ?? false
                    active: (win.player?.loopState ?? MprisLoopState.None) !== MprisLoopState.None
                    activeBg: Theme.pc; activeFg: Theme.pcText
                    tooltip: win.player?.loopState === MprisLoopState.Track ? "Repetir la pista" : "Repetir la lista"
                    onClicked: {
                        const s = win.player.loopState;
                        win.player.loopState = s === MprisLoopState.None ? MprisLoopState.Playlist
                                             : s === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None;
                    }
                    Txt {
                        visible: win.player?.loopState === MprisLoopState.Track
                        anchors { right: parent.right; top: parent.top; rightMargin: 4; topMargin: 2 }
                        text: "1"; size: 8.5; weight: Font.Bold; color: Theme.pcText
                    }
                }
            }

            // ---------------------------------------------------------------- volumen y salida
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    SliderBar {
                        Layout.fillWidth: true
                        implicitHeight: 28
                        icon: Audio.muted || Audio.volume < 0.01 ? "volume_low" : Audio.volume < 0.5 ? "volume" : "volume_high"
                        value: Audio.muted ? 0 : Audio.volume
                        to: Audio.maxVolume
                        onMoved: v => Audio.setVolume(v)
                        Txt {
                            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            text: Audio.muted ? "Silencio" : Math.round(Audio.volume * 100) + " %"
                            size: 11; tabular: true; color: Theme.tv
                        }
                    }
                    // Salida de audio: abre la lista de dispositivos
                    Rectangle {
                        implicitHeight: 28
                        implicitWidth: Math.min(150, outRow.implicitWidth + 20)
                        radius: Theme.ctl(28)
                        color: win.showDevices ? Theme.fillOn : outMa.containsMouse ? Theme.fill2 : "transparent"
                        border.width: win.showDevices ? 0 : 1; border.color: Theme.border
                        RowLayout {
                            id: outRow
                            anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
                            spacing: 5
                            Icon { name: Audio.kindIcon(Audio.sink); size: 13; color: win.showDevices ? Theme.fillOnText : Theme.t }
                            Txt { Layout.fillWidth: true; Layout.maximumWidth: 92; text: Audio.nodeName(Audio.sink) || "Salida"; size: 11; color: win.showDevices ? Theme.fillOnText : Theme.t }
                            Icon { name: win.showDevices ? "chevron_up" : "chevron_down"; size: 11; color: win.showDevices ? Theme.fillOnText : Theme.tv }
                        }
                        MouseArea { id: outMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.showDevices = !win.showDevices }
                    }
                }
                AudioDevices {
                    visible: win.showDevices
                    Layout.fillWidth: true
                    output: true; compact: true
                }
            }

            // ---------------------------------------------------------------- reproductores
            ColumnLayout {
                visible: win.players.length > 1
                Layout.fillWidth: true
                spacing: 2
                Rectangle { Layout.fillWidth: true; Layout.bottomMargin: 6; implicitHeight: 1; color: Theme.ov }
                Txt { text: "Reproductores"; size: 11; weight: Font.DemiBold; color: Theme.tv; Layout.bottomMargin: 2 }
                Repeater {
                    model: win.players
                    Rectangle {
                        id: prow
                        required property var modelData
                        readonly property bool on: win.player === modelData
                        readonly property var info: Media.appOf(modelData)
                        Layout.fillWidth: true
                        implicitHeight: 36
                        radius: Theme.r(8)
                        color: on ? Theme.selBg : prowMa.containsMouse ? Theme.fill2 : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.dur } }
                        RowLayout {
                            anchors { fill: parent; leftMargin: 8; rightMargin: 6 }
                            spacing: 9
                            AppIcon { info: prow.info; size: 18 }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Txt { Layout.fillWidth: true; text: prow.info.name; size: 11.5; weight: Font.DemiBold; color: prow.on ? Theme.selText : Theme.t }
                                Txt {
                                    Layout.fillWidth: true
                                    text: [prow.modelData.trackTitle, prow.modelData.trackArtist].filter(s => !!s).join(" · ") || "Sin título"
                                    size: 10.5; color: prow.on ? Theme.selText : Theme.tv; opacity: prow.on ? 0.85 : 1
                                }
                            }
                            // Sonando: tres barritas; en pausa: botón para reproducir este
                            Row {
                                visible: prow.modelData.isPlaying
                                spacing: 2
                                Layout.rightMargin: 6
                                Repeater {
                                    model: 3
                                    Rectangle {
                                        required property int index
                                        width: 3; radius: 1.5
                                        anchors.bottom: parent.bottom
                                        color: prow.on ? Theme.selText : Theme.p
                                        height: 5
                                        SequentialAnimation on height {
                                            running: prow.modelData.isPlaying && win.shown
                                            loops: Animation.Infinite
                                            NumberAnimation { to: 12; duration: 260 + index * 90; easing.type: Easing.InOutSine }
                                            NumberAnimation { to: 4; duration: 300 + index * 70; easing.type: Easing.InOutSine }
                                        }
                                    }
                                }
                            }
                            IconBtn {
                                visible: !prow.modelData.isPlaying
                                icon: "play"; iconSize: 11; implicitWidth: 26; implicitHeight: 24
                                fg: prow.on ? Theme.selText : Theme.tv
                                tooltip: "Reproducir"
                                onClicked: { if (prow.modelData.canPlay) prow.modelData.play(); win.pinned = prow.modelData.dbusName; }
                            }
                        }
                        MouseArea {
                            id: prowMa
                            anchors.fill: parent
                            z: -1
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.pinned = prow.modelData.dbusName
                        }
                    }
                }
            }

            Txt {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: win.player ? "Espacio reproducir · ← → 5 s · ↑ ↓ volumen" + (win.players.length > 1 ? " · Tab reproductor" : "")
                                 : "Super + M · Esc cerrar"
                size: 10; muted: true
            }
        }
    }
}
