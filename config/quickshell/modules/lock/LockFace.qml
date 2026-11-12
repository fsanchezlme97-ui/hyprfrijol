// Lo que se ve en la pantalla de bloqueo (fondo, reloj, widgets y campo de contraseña), sin PAM: lo usan Lock.qml
// (ctl = el bloqueo de verdad) y la vista previa de Ajustes › Bloqueo e inicio de sesión (preview: true, ctl de muestra).
// Ajustes: lockLayout (izquierda|centro|derecha) · lockClock (fino|grueso|pequeno|oculto) · lockBg (fondo|desenfocado|
// paisaje|color) · lockWallpaper ("" = el fondo del escritorio; si no, esa imagen) · lockScene (paisaje) · lockDim (0-60, % de oscurecido) · lockPalette ("" = la del escritorio) ·
// lockWidgets [fecha, clima, musica, bateria, nomolestar] · notifyLock (aviso de notificaciones, sin contenido).
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../.."
import "../../components"
import "../../services"

Item {
    id: face
    // ctl: password, state ("" | checking | error | ok), message, caps, hasFprint, hasFace, realName, userName,
    //      lockedAt, submit(), señales shake() y clearInput()
    property var ctl
    property bool preview: false
    property string video: ""                       // vídeo de fondo (solo con lockBg = fondo)

    readonly property var widgets: Settings.get("lockWidgets", ["fecha", "musica", "bateria", "nomolestar"])
    function has(k: string): bool { return Array.isArray(widgets) && widgets.includes(k); }
    readonly property string layout: Settings.get("lockLayout", "izquierda")
    readonly property string clockStyle: Settings.get("lockClock", "fino")
    readonly property string bg: Settings.get("lockBg", "fondo")
    readonly property string wallFile: Settings.get("lockWallpaper", "")   // "" = el fondo del escritorio
    readonly property real dim: Math.max(0, Math.min(80, Number(Settings.get("lockDim", 0)) || 0)) / 100
    readonly property int align: layout === "centro" ? Qt.AlignHCenter : layout === "derecha" ? Qt.AlignRight : Qt.AlignLeft

    // Colores: una paleta propia (palettes.json + las importadas) o los del escritorio
    readonly property string palKey: Settings.get("lockPalette", "")
    property var pals: ({})
    property var userPals: ({})
    FileView {
        path: face.palKey ? Paths.root + "/config/themes/palettes.json" : ""
        printErrors: false
        onLoaded: { try { face.pals = JSON.parse(text()); } catch (e) {} }
    }
    FileView {
        path: face.palKey ? Paths.userDir + "/palettes-user.json" : ""
        printErrors: false
        onLoaded: { try { const j = JSON.parse(text()); face.userPals = j && typeof j === "object" ? j : {}; } catch (e) {} }
    }
    readonly property var pal: palKey ? (userPals[palKey] ?? pals[palKey] ?? null) : null
    readonly property color cBg: pal ? pal.bg : Theme.bg
    readonly property color cP: pal ? pal.p : Theme.p
    readonly property color cPText: pal ? pal.onP : Theme.pText
    readonly property color cPc: pal ? pal.pc : Theme.pc
    readonly property color cPcText: pal ? pal.onPc : Theme.pcText
    readonly property color cT: pal ? pal.t : Theme.t
    readonly property color cTv: pal ? pal.tv : Theme.tv
    readonly property color cTer: pal ? pal.ter : Theme.ter
    readonly property color cPanel: pal ? Qt.alpha(pal.s1, 0.74) : Theme.glassPanel
    readonly property color cBorder: pal ? Qt.alpha(pal.t, 0.12) : Theme.border
    // Sobre una foto el texto grande va claro (con velo y sombra); sobre un color liso, el de la paleta
    readonly property bool onPhoto: bg !== "color"
    readonly property color cBig: onPhoto ? "#F2F2F4" : cT
    readonly property color cBig2: onPhoto ? "#E6E6EA" : cTv

    // El reloj grande usa peso 300: si Inter no está instalada, una familia con «Light» real
    readonly property string clockFont: Qt.fontFamilies().includes(Theme.font) ? Theme.font : "Noto Sans"
    readonly property bool forceScene: ctl?.forceScene === true
    readonly property bool photo: (bg === "fondo" || bg === "desenfocado") && wall.status === Image.Ready

    // El tiempo solo se pide si el widget está puesto (Weather.users; el bloqueo no pasa por UseCounter)
    readonly property bool wantWeather: has("clima")
    property bool _w: false
    function _syncWeather(): void { if (wantWeather !== _w) { Weather.users = Math.max(0, Weather.users + (wantWeather ? 1 : -1)); _w = wantWeather; } }
    onWantWeatherChanged: _syncWeather()
    Component.onCompleted: _syncWeather()
    Component.onDestruction: if (_w) Weather.users = Math.max(0, Weather.users - 1)

    // ---- Fondo ----
    Rectangle { anchors.fill: parent; color: face.cBg }
    Landscape {
        anchors.fill: parent
        preset: Settings.get("lockScene", "amanecer")
        visible: face.bg === "paisaje" || ((face.bg === "fondo" || face.bg === "desenfocado") && wall.status !== Image.Ready)
        animated: !Theme.still && !face.preview
    }
    Image {
        id: wall
        anchors.fill: parent
        source: face.forceScene || (face.bg !== "fondo" && face.bg !== "desenfocado") ? "" : "file://" + (face.wallFile || Paths.state + "/current-wallpaper")
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize: Qt.size(Math.min(face.width, 1920), Math.min(face.height, 1200))
        visible: status === Image.Ready
        layer.enabled: face.bg === "desenfocado"
        layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 64; saturation: 0.1 }
    }
    // Fondo en movimiento: el mismo vídeo que en el escritorio (mpvpaper queda debajo del bloqueo)
    Loader {
        anchors.fill: parent
        active: face.video !== "" && face.wallFile === "" && face.bg === "fondo" && wall.visible && !face.preview
        source: Qt.resolvedUrl("../../components/VideoLoop.qml")
        onLoaded: item.source = Qt.binding(() => face.video)
    }
    // Velo suave para que el texto se lea sobre cualquier fondo, y el oscurecido que se elija
    Rectangle {
        anchors.fill: parent
        visible: face.onPhoto
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0, 0, 0, face.photo ? 0.28 : 0.06) }
            GradientStop { position: 0.45; color: Qt.rgba(0, 0, 0, face.photo ? 0.08 : 0) }
            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, face.photo ? 0.32 : 0.05) }
        }
    }
    Rectangle { anchors.fill: parent; color: "#000000"; opacity: face.onPhoto ? face.dim : 0; visible: opacity > 0 }

    // Al desbloquear, el contenido se desvanece
    Item {
        id: content
        anchors.fill: parent
        enabled: !face.preview
        opacity: face.ctl?.state === "ok" ? 0 : 1
        scale: face.ctl?.state === "ok" ? 1.02 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.durMedium; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
        Behavior on scale { NumberAnimation { duration: Theme.durMedium; easing.type: Easing.OutCubic } }

        // ---- Reloj, fecha y widgets ----
        ColumnLayout {
            id: info
            layer.enabled: face.photo
            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#000000"; shadowOpacity: 0.35; shadowBlur: 0.6; shadowVerticalOffset: 1 }
            readonly property real mx: 110 * Math.min(1, face.width / 1440)
            x: face.layout === "centro" ? (face.width - width) / 2 : face.layout === "derecha" ? face.width - width - mx : mx
            y: (face.layout === "centro" ? 96 : 72) * Math.min(1, face.height / 900)
            width: Math.max(implicitWidth, 1)
            spacing: 0
            Text {
                Layout.alignment: face.align
                visible: face.clockStyle !== "oculto"
                readonly property int px: face.clockStyle === "pequeno" ? 72 : face.clockStyle === "grueso" ? 120 : 132
                text: Time.hhmm
                color: face.cBig
                font.family: face.clockFont
                font.pixelSize: px
                font.weight: face.clockStyle === "grueso" ? Font.DemiBold : Font.Light
                font.letterSpacing: (face.clockStyle === "grueso" ? -0.03 : -0.04) * px
                font.features: { "tnum": 1 }
                renderType: Text.QtRendering
                Layout.leftMargin: face.align === Qt.AlignLeft ? -6 : 0
            }
            Text {
                Layout.alignment: face.align
                visible: face.has("fecha")
                Layout.topMargin: face.clockStyle === "oculto" ? 0 : face.clockStyle === "pequeno" ? -8 : -16
                text: Time.longDate
                color: face.cBig2
                font.family: Theme.font
                font.pixelSize: 20
                renderType: Text.QtRendering
            }
            Row {
                Layout.alignment: face.align
                Layout.topMargin: 30
                visible: chips.count > 0
                layoutDirection: face.layout === "derecha" ? Qt.RightToLeft : Qt.LeftToRight
                spacing: 10
                Repeater {
                    id: chips
                    model: {
                        const a = [];
                        const n = face.preview ? 2 : Notifs.count;
                        if (n > 0 && Settings.get("notifyLock", true)) a.push({ icon: "bell", text: n + (n === 1 ? " notificación" : " notificaciones") + " (contenido oculto)" });
                        if (face.has("clima") && Weather.ready) a.push({ icon: Weather.icon, text: Math.round(Weather.temp) + "° · " + Weather.desc });
                        if (face.has("bateria") && (Battery.present || face.preview))
                            a.push({ icon: Battery.percent < 0.2 && !Battery.charging ? "battery_low" : "battery",
                                     text: "Batería " + Math.round((Battery.present ? Battery.percent : 0.8) * 100) + " %" + (Battery.charging ? " · cargando" : "") });
                        if (face.has("nomolestar") && (Notifs.dnd || face.preview)) a.push({ icon: "dnd", text: "No molestar" });
                        return a;
                    }
                    Rectangle {
                        required property var modelData
                        height: 32; radius: Theme.r(6)
                        width: chipRow.implicitWidth + 28
                        color: face.cPanel
                        border.width: 1; border.color: face.cBorder
                        RowLayout {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 7
                            Icon { name: modelData.icon; size: 13; color: face.cTv }
                            Txt { text: modelData.text; size: 12.5; color: face.cT }
                        }
                    }
                }
            }
            // Lo que suena (sin abrir nada: anterior / pausa / siguiente)
            Rectangle {
                id: music
                readonly property bool show: face.has("musica") && (Media.active !== null || face.preview)
                Layout.alignment: face.align
                Layout.topMargin: chips.count > 0 ? 12 : 30
                visible: show
                implicitWidth: 360; implicitHeight: 72
                radius: Theme.r(8)
                color: face.cPanel
                border.width: 1; border.color: face.cBorder
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12
                    Rectangle {
                        implicitWidth: 52; implicitHeight: 52; radius: Theme.r(6)
                        color: face.cPc
                        clip: true
                        Icon { anchors.centerIn: parent; name: "music"; size: 18; color: face.cPcText; visible: art.status !== Image.Ready }
                        Image { id: art; anchors.fill: parent; source: Media.art; fillMode: Image.PreserveAspectCrop; asynchronous: true; visible: status === Image.Ready }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Txt { Layout.fillWidth: true; text: Media.title || (face.preview && !Media.active ? "Canción de ejemplo" : "Sin título"); weight: Font.DemiBold; color: face.cT; elide: Text.ElideRight }
                        Txt { Layout.fillWidth: true; text: Media.artist || (face.preview && !Media.active ? "Artista" : ""); size: 11.5; color: face.cTv; elide: Text.ElideRight; visible: text !== "" }
                    }
                    Repeater {
                        model: [{ icon: "prev", act: () => Media.previous() }, { icon: Media.playing ? "pause" : "play", act: () => Media.toggle() }, { icon: "next", act: () => Media.next() }]
                        Rectangle {
                            required property var modelData
                            implicitWidth: 34; implicitHeight: 34; radius: 17
                            color: mMa.containsMouse ? Qt.alpha(face.cT, 0.10) : "transparent"
                            Icon { anchors.centerIn: parent; name: modelData.icon; size: 15; color: face.cT }
                            MouseArea { id: mMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: modelData.act() }
                        }
                    }
                }
            }
        }

        // ---- Contraseña (abajo, centrada) ----
        ColumnLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 70
            spacing: 12

            Rectangle {
                id: field
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 360; implicitHeight: 48
                radius: Theme.r(7)
                color: face.cPanel
                border.width: 1
                border.color: face.ctl?.state === "error" ? Qt.alpha(face.cTer, 0.8) : input.activeFocus ? Qt.alpha(face.cP, 0.55) : face.cBorder
                Behavior on border.color { ColorAnimation { duration: Theme.durShort; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
                transform: Translate { id: shakeT }
                SequentialAnimation {
                    id: shakeAnim
                    NumberAnimation { target: shakeT; property: "x"; to: -9; duration: 50 }
                    NumberAnimation { target: shakeT; property: "x"; to: 8; duration: 70 }
                    NumberAnimation { target: shakeT; property: "x"; to: -6; duration: 70 }
                    NumberAnimation { target: shakeT; property: "x"; to: 4; duration: 60 }
                    NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 60 }
                }
                Connections {
                    target: face.ctl
                    ignoreUnknownSignals: true
                    function onShake() { if (!Theme.still) shakeAnim.restart(); }
                    function onClearInput() { input.text = ""; }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 5; anchors.rightMargin: 5
                    spacing: 12
                    Rectangle {
                        implicitWidth: 38; implicitHeight: 38; radius: Theme.r(6)
                        color: face.cPc
                        clip: true
                        Icon { anchors.centerIn: parent; name: face.ctl?.hasFprint ? "fingerprint" : "user"; size: 17; color: face.cPcText; visible: avatar.status !== Image.Ready }
                        Image {
                            id: avatar
                            anchors.fill: parent
                            source: face.ctl?.hasFace ? "file://" + Paths.home + "/.face" : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready
                            asynchronous: true
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: input.text === ""
                            text: face.ctl?.state === "checking" ? "Comprobando…" : face.ctl?.hasFprint ? "Contraseña o huella" : "Contraseña"
                            size: 14
                            color: face.cT
                            opacity: 0.85
                        }
                        TextInput {
                            id: input
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            echoMode: TextInput.Password
                            passwordCharacter: "●"
                            color: face.cT
                            font.family: Theme.font
                            font.pixelSize: 14
                            font.letterSpacing: 2
                            selectionColor: face.cP
                            clip: true
                            focus: !face.preview
                            enabled: !face.preview && face.ctl?.state !== "checking" && face.ctl?.state !== "ok"
                            cursorVisible: activeFocus
                            onTextChanged: { if (!face.ctl || face.preview) return; face.ctl.password = text; if (face.ctl.state === "error" && text !== "") { face.ctl.state = ""; face.ctl.message = ""; } }
                            onAccepted: face.ctl.submit()
                            Keys.onPressed: event => { face.ctl.checkCaps(); if (event.key === Qt.Key_Escape) { text = ""; event.accepted = true; } }
                            Component.onCompleted: if (!face.preview) forceActiveFocus()
                        }
                    }
                    Rectangle {
                        implicitWidth: 38; implicitHeight: 38; radius: Theme.r(6)
                        color: goMa.containsMouse ? Qt.lighter(face.cP, 1.08) : face.cP
                        Icon { anchors.centerIn: parent; name: "arrow_right"; size: 16; color: face.cPText; visible: face.ctl?.state !== "checking" }
                        // Indicador de comprobación
                        Rectangle {
                            anchors.centerIn: parent
                            width: 16; height: 16; radius: 8
                            color: "transparent"
                            border.width: 2; border.color: face.cPText
                            visible: face.ctl?.state === "checking"
                            Rectangle { width: 6; height: 6; radius: 3; color: face.cP; x: 8; y: -2 }
                            RotationAnimation on rotation { running: face.ctl?.state === "checking"; from: 0; to: 360; duration: 800; loops: Animation.Infinite }
                        }
                        MouseArea { id: goMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: face.ctl.submit() }
                    }
                }
            }
            Txt {
                layer.enabled: face.photo
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#000000"; shadowOpacity: 0.5; shadowBlur: 0.5 }
                Layout.alignment: Qt.AlignHCenter
                size: 11.5
                color: face.ctl?.state === "error" ? face.cTer : face.cTv
                textFormat: Text.PlainText
                text: {
                    const c = face.ctl;
                    if (!c) return "";
                    const who = c.realName || c.userName;
                    if (c.message) return c.message;
                    if (c.caps) return who + " · Bloq Mayús activado";
                    return who + " · Bloqueado desde las " + Time.fmt(c.lockedAt);
                }
            }
        }
    }
    // Clic en cualquier parte → foco al campo
    MouseArea { anchors.fill: parent; z: -1; enabled: !face.preview; onClicked: input.forceActiveFocus() }
}
