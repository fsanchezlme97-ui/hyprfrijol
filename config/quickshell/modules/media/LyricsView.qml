// Letra a pantalla completa (vista "letra"; botón del panel de música, ajuste lyricsView, por defecto sí).
//   Izquierda: carátula grande, título, artista, progreso y anterior · reproducir · siguiente.
//   Derecha: la letra sincronizada (services/Lyrics.qml, lrclib.net) desplazándose con la línea que suena en el
//   centro, grande y encendida; el resto se va apagando. Clic en una línea = saltar ahí. Sin sincronizar: el texto
//   entero con desplazamiento. Pedir la letra sigue siendo a mano (musicLyrics): si no está activada se explica qué se
//   manda y a quién, como en el panel.
//   Fondo: la carátula a 12 px estirada (el escalado la difumina sin efectos: barato en cualquier gráfica).
// Abre con el reproductor que tenía el panel (Shell.arg = su dbusName). Teclas: Espacio reproducir/pausar ·
// ← → buscar 5 s · Mayús+← → pista · Esc cerrar.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import "../.."
import "../../components"
import "../../services"

Overlay {
    id: win
    view: "letra"
    place: "fill"
    dim: true

    property string pinned: ""
    readonly property var player: Media.players.find(p => p.dbusName === pinned) ?? Media.active
    property real pos: 0
    readonly property real len: {
        const m = player?.metadata ?? {};
        const us = Number(m["mpris:length"] ?? 0);
        return us > 0 ? us / 1e6 : (player?.lengthSupported ? player.length : 0);
    }
    readonly property string art: player?.trackArtUrl ?? ""

    onShownChanged: if (shown) { pinned = Shell.arg ?? ""; pos = player?.position ?? 0; keys.forceActiveFocus(); }

    // Posición (MPRIS no avisa del avance) y letra: propias de esta vista, el panel de música ya está cerrado
    Timer {
        running: win.shown && (win.player?.isPlaying ?? false)
        interval: 500; repeat: true; triggeredOnStart: true
        onTriggered: { win.player.positionChanged(); win.pos = win.player.position; }
    }
    Connections {
        target: win.player
        function onPositionChanged() { win.pos = win.player.position; }
        function onTrackChanged() { win.pos = 0; }
    }
    readonly property string lyricKey: shown && Lyrics.enabled ? (player?.trackArtist ?? "") + "\n" + (player?.trackTitle ?? "") + "\n" + Math.round(len) : ""
    onLyricKeyChanged: if (lyricKey) Lyrics.want(player?.trackArtist ?? "", player?.trackTitle ?? "", len)
    readonly property int lyricIdx: Lyrics.indexAt(pos)

    function seekBy(d: real): void {
        if (player?.canSeek && player.positionSupported) player.position = Math.max(0, Math.min(len || 1e9, player.position + d));
    }
    function fmt(s: real): string {
        if (!isFinite(s) || s < 0) s = 0;
        s = Math.floor(s);
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Theme.panelRadius
        color: Theme.s1
        clip: true
        Image {
            anchors.fill: parent
            source: win.art
            sourceSize: Qt.size(12, 12)
            fillMode: Image.PreserveAspectCrop
            smooth: true
            asynchronous: true
            opacity: status === Image.Ready ? 0.6 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.dur } }
        }
        Rectangle { anchors.fill: parent; color: Qt.alpha("#000000", 0.5) }
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => {
            const p = win.player;
            if (e.key === Qt.Key_Escape) Shell.close();
            else if (!p) return;
            else if (e.key === Qt.Key_Space || e.key === Qt.Key_K) p.togglePlaying();
            else if (e.key === Qt.Key_Left) { if (e.modifiers & Qt.ShiftModifier) { if (p.canGoPrevious) p.previous(); } else win.seekBy(-5); }
            else if (e.key === Qt.Key_Right) { if (e.modifiers & Qt.ShiftModifier) { if (p.canGoNext) p.next(); } else win.seekBy(5); }
            else return;
            e.accepted = true;
        }
    }

    IconBtn {
        anchors { top: parent.top; right: parent.right; margins: 16 }
        icon: "x"; implicitWidth: 34; implicitHeight: 34; tooltip: "Cerrar (Esc)"
        onClicked: Shell.close()
    }

    Txt {
        visible: !win.player
        anchors.centerIn: parent
        text: "No hay nada sonando"
        size: 18; muted: true
    }

    RowLayout {
        visible: !!win.player
        anchors { fill: parent; margins: 48 }
        spacing: 48

        // ---------------------------------------------------------------- carátula y controles
        ColumnLayout {
            Layout.preferredWidth: Math.min(360, bg.width * 0.32)
            Layout.maximumWidth: Layout.preferredWidth
            Layout.alignment: Qt.AlignVCenter
            spacing: 16
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: width
                Rectangle { anchors.fill: parent; radius: Theme.r(20); color: Theme.fill2 }
                Icon { anchors.centerIn: parent; visible: cover.status !== Image.Ready; name: "music"; size: 56; color: Theme.tv }
                Item {
                    id: coverMask
                    anchors.fill: parent; visible: false; layer.enabled: true
                    Rectangle { anchors.fill: parent; radius: Theme.r(20) }
                }
                Image {
                    id: cover
                    anchors.fill: parent
                    source: win.art
                    sourceSize: Qt.size(720, 720)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                    layer.enabled: true
                    layer.effect: MultiEffect { maskEnabled: true; maskSource: coverMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
                }
            }
            Txt {
                Layout.fillWidth: true
                text: win.player?.trackTitle || "Sin título"
                size: 22; weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
            }
            Txt {
                Layout.fillWidth: true
                text: win.player?.trackArtist ?? ""
                visible: text !== ""
                size: 14; color: Theme.tv
                horizontalAlignment: Text.AlignHCenter
            }
            // progreso (clic = saltar)
            ColumnLayout {
                visible: win.len > 0
                Layout.fillWidth: true
                spacing: 2
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 14
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width; height: 4; radius: 2
                        color: Qt.alpha(Theme.t, 0.18)
                        Rectangle { width: Math.max(4, parent.width * Math.min(1, win.pos / Math.max(1, win.len))); height: 4; radius: 2; color: Theme.p }
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: win.player?.canSeek ?? false
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: m => { win.player.position = Math.max(0, Math.min(1, m.x / width)) * win.len; win.pos = win.player.position; }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Txt { text: win.fmt(win.pos); size: 11; muted: true; tabular: true }
                    Item { Layout.fillWidth: true }
                    Txt { text: win.fmt(win.len); size: 11; muted: true; tabular: true }
                }
            }
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 24
                IconBtn {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "prev"; iconSize: 18; implicitWidth: 42; implicitHeight: 38
                    opacity: (win.player?.canGoPrevious ?? false) ? 1 : 0.35
                    onClicked: if (win.player?.canGoPrevious) win.player.previous()
                }
                Rectangle {
                    width: 56; height: 56; radius: 28
                    color: playMa.containsMouse ? Qt.lighter(Theme.p, 1.08) : Theme.p
                    Icon { anchors.centerIn: parent; name: (win.player?.isPlaying ?? false) ? "pause" : "play"; size: 22; color: Theme.pText; stroke: 2.4 }
                    MouseArea { id: playMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (win.player?.canTogglePlaying) win.player.togglePlaying() }
                }
                IconBtn {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "next"; iconSize: 18; implicitWidth: 42; implicitHeight: 38
                    opacity: (win.player?.canGoNext ?? false) ? 1 : 0.35
                    onClicked: if (win.player?.canGoNext) win.player.next()
                }
            }
        }

        // ---------------------------------------------------------------- letra
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // sin activar: qué se manda y a quién (no se activa sola)
            Txt {
                visible: !Lyrics.enabled
                anchors.centerIn: parent
                width: Math.min(parent.width, 460)
                text: "<a href='#'>Ver la letra</a> · se la pide a lrclib.net con el artista y el título de lo que suena"
                textFormat: Text.StyledText; linkColor: Theme.p
                size: 15; muted: true; horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap; elide: Text.ElideNone
                onLinkActivated: Settings.set("musicLyrics", true)
                HoverHandler { cursorShape: Qt.PointingHandCursor }
            }
            Txt {
                visible: Lyrics.enabled && Lyrics.state !== "ok"
                anchors.centerIn: parent
                text: Lyrics.state === "buscando" ? "Buscando la letra…" : Lyrics.state === "nada" ? "lrclib.net no tiene la letra de esta canción"
                    : Lyrics.state === "error" ? "No se pudo buscar la letra (¿sin conexión?)" : ""
                size: 15; muted: true
            }

            // sincronizada: la que suena en el centro
            ListView {
                id: lv
                visible: Lyrics.enabled && Lyrics.lines.length > 0
                anchors.fill: parent
                clip: true
                interactive: false
                model: Lyrics.lines
                spacing: 24
                currentIndex: Math.max(0, win.lyricIdx)
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: height / 2 - 30
                preferredHighlightEnd: height / 2 + 30
                highlightMoveDuration: 450
                delegate: Txt {
                    id: line
                    required property var modelData
                    required property int index
                    readonly property int d: Math.abs(index - win.lyricIdx)
                    width: lv.width
                    text: modelData.text || "♪"
                    size: 26; weight: Font.Bold
                    color: d === 0 ? Theme.t : Theme.tv
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap; elide: Text.ElideNone
                    scale: d === 0 ? 1 : 0.84
                    opacity: d === 0 ? 1 : Math.max(0.14, 0.55 - d * 0.1)
                    Behavior on scale { NumberAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
                    Behavior on opacity { NumberAnimation { duration: Theme.dur } }
                    MouseArea {
                        anchors.fill: parent
                        enabled: win.player?.canSeek ?? false
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: { win.player.position = line.modelData.t; win.pos = line.modelData.t; }
                    }
                }
            }

            // sin sincronizar: el texto entero
            Flickable {
                visible: Lyrics.enabled && Lyrics.plain !== ""
                anchors.fill: parent
                contentHeight: plainTxt.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Txt {
                    id: plainTxt
                    width: parent.width
                    text: Lyrics.plain
                    size: 18; horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap; elide: Text.ElideNone
                }
            }
        }
    }
}
