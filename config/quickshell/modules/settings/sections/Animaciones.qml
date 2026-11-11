// Ajustes › Animaciones y efectos — movimiento (preset, velocidad, cambio de espacio), ventanas (sombras, resaltado,
// atenuado de las inactivas) y desenfoque y rendimiento de los efectos (antes en Apariencia y en Energía).
// Ajustes: animPreset, animado, animSpeed, workspaceAnim, shadows, activeBorder, dimInactive, blurQuality,
// blurOnBattery, gameNoFx, blurAuto. Lo aplica scripts/hf-apply (y config/apply/10-look.py el desenfoque y las sombras).
// El modo juego (Super + Mayús + G) es Shell.setGameMode.
import QtQuick
import QtQuick.Layouts
import "../../.."
import "../../../components"
import "../../../services"
import "../ui"

ColumnLayout {
    id: root
    spacing: 12

    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        Section {
            id: mov
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            Layout.fillHeight: true
            title: "Movimiento"
            readonly property string preset: Settings.get("animado", true) === false ? "ninguno" : Settings.get("animPreset", "fluido")
            headerRight: Mono { text: "hl.animation · hl.curve" }
            MotionDemo { Layout.fillWidth: true }
            LabeledRow {
                label: "Animaciones"; labelWidth: 80
                Seg {
                    model: [["fluido", "Fluido"], ["equilibrado", "Equilibrado"], ["rapido", "Rápido"], ["minimo", "Mínimo"], ["ninguno", "Ninguna"]]
                    current: mov.preset
                    textSize: 11.5
                    onPicked: k => Settings.setMany({ animPreset: k, animado: k !== "ninguno" })
                }
            }
            Txt {
                Layout.fillWidth: true
                Layout.leftMargin: 90
                muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
                text: ({
                    fluido: "Movimiento elástico y suave, algo más largo, como en iOS o macOS: las ventanas aparecen con un leve rebote y los espacios se deslizan.",
                    equilibrado: "El de siempre: entrada rápida que frena al final y un rebote corto al abrir ventanas.",
                    rapido: "Ágil y sin rebotes: casi la mitad de largo. Para quien quiere que todo responda ya.",
                    minimo: "Solo fundidos: nada se desplaza ni cambia de tamaño.",
                    ninguno: "Sin animaciones en ventanas, espacios ni paneles."
                })[mov.preset] ?? ""
            }
            LabeledRow {
                label: "Velocidad"; labelWidth: 80
                enabled: mov.preset !== "ninguno" && !Theme.reduceMotion
                opacity: enabled ? 1 : 0.5
                Pills {
                    Layout.fillWidth: true
                    model: [[0.7, "Lenta"], [0.85, "Pausada"], [1, "Normal"], [1.25, "Ágil"], [1.5, "Rápida"]]
                    current: Settings.get("animSpeed", 1)
                    onPicked: v => Settings.set("animSpeed", v)
                }
            }
            LabeledRow {
                label: "Espacios"; labelWidth: 80
                enabled: mov.preset !== "ninguno" && !Theme.reduceMotion
                opacity: enabled ? 1 : 0.5
                Seg {
                    model: [["auto", "Según preset"], ["slide", "Deslizar"], ["slidefade", "Con fundido"], ["fade", "Fundido"], ["slidevert", "Vertical"]]
                    current: Settings.get("workspaceAnim", "auto")
                    textSize: 11.5
                    onPicked: k => Settings.set("workspaceAnim", k)
                }
            }
            SwRow { label: "Onda al pulsar"; sub: "botones y mosaicos dibujan una onda desde el punto pulsado"; key: "ripple"; def: true; enabled: !Theme.reduceMotion }
            LinkRow {
                visible: Theme.reduceMotion
                label: "Reducir movimiento está activado"; value: "Sin animaciones"
                section: "accesibilidad"; sectionLabel: "Accesibilidad"
            }
        }
        Section {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            Layout.fillHeight: true
            title: "Ventanas"
            headerRight: Mono { text: "decoration.shadow · col.active_border" }
            WindowLookPreview { Layout.fillWidth: true }
            LabeledRow {
                label: "Sombras"; labelWidth: 80
                Seg {
                    model: [["ninguna", "Ninguna"], ["suaves", "Suaves"], ["marcadas", "Marcadas"]]
                    current: Settings.get("shadows", "suaves")
                    onPicked: k => Settings.set("shadows", k)
                }
            }
            LabeledRow {
                label: "Resaltado"; labelWidth: 80
                Seg {
                    model: [["sutil", "Sutil"], ["color", "Color"], ["brillo", "Brillo"], ["ninguno", "Ninguno"]]
                    current: Settings.get("activeBorder", "sutil")
                    onPicked: k => Settings.set("activeBorder", k)
                }
            }
            Txt {
                Layout.fillWidth: true
                Layout.leftMargin: 90
                muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
                text: "Resaltado de la ventana activa: " + ({
                    sutil: "borde fino con un toque del color de acento; las demás ventanas, casi sin borde.",
                    color: "borde de 2 px con un degradado del color de acento.",
                    brillo: "borde fino y un halo suave del color de acento alrededor.",
                    ninguno: "sin borde; las sombras separan las ventanas."
                })[Settings.get("activeBorder", "sutil")] ?? ""
            }
            SwRow { label: "Atenuar ventanas inactivas"; sub: "oscurece un poco las que no tienen el foco · decoration.dim_inactive"; key: "dimInactive" }
            LabeledRow {
                label: "Sin foco"; labelWidth: 80
                hint: "opacidad de las ventanas inactivas"
                Seg {
                    model: [[0, "Automática"], [1, "Opacas"], [0.92, "92 %"], [0.85, "85 %"]]
                    current: Settings.get("inactiveOpacity", 0)
                    onPicked: k => Settings.set("inactiveOpacity", k)
                }
            }
        }
    }

    // Apps que no se transparentan sin foco (inactiveOpacityExclude → hf-apply: regla hf-opaque-apps)
    Section {
        Layout.fillWidth: true
        visible: Settings.get("inactiveOpacity", 0) !== 1
        title: "Siempre opacas"
        headerRight: Mono { text: "opacity override" }
        FloatApps {
            Layout.fillWidth: true
            settingKey: "inactiveOpacityExclude"
            intro: "Estas apps no se vuelven translúcidas al perder el foco: vídeos y videollamadas se siguen viendo bien mientras trabajas en otra ventana. "
                + "«Automática» deja el resto un 3 % translúcido solo con desenfoque."
            groups: [
                { key: "video", label: "Vídeo", sub: "mpv, Celluloid, Showtime, Totem, VLC", classes: ["mpv", "io.github.celluloid_player.Celluloid", "org.gnome.Showtime", "org.gnome.Totem", "vlc"] },
                { key: "llamadas", label: "Videollamadas", sub: "Zoom, Teams, Discord, Vesktop", classes: ["zoom", "teams-for-linux", "discord", "vesktop"] },
                { key: "grabar", label: "Grabación", sub: "OBS Studio", classes: ["com.obsproject.Studio", "obs"] }
            ]
            onApply: l => Settings.set("inactiveOpacityExclude", l)
        }
    }

    Section {
        id: glass
        Layout.fillWidth: true
        title: "Desenfoque y rendimiento"
        readonly property string q: Settings.get("blurQuality", "equilibrada")
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Card { title: "Alta"; sub: "Máximo detalle"; selected: glass.q === "alta"; onClicked: Settings.set("blurQuality", "alta") }
            Card { title: "Equilibrada"; sub: "Menos GPU"; selected: glass.q === "equilibrada"; onClicked: Settings.set("blurQuality", "equilibrada") }
            Card { title: "Ahorro"; sub: "Sin desenfoque"; selected: glass.q === "ahorro"; onClicked: Settings.set("blurQuality", "ahorro") }
        }
        Mono {
            Layout.fillWidth: true
            text: glass.q === "alta" ? "decoration:blur → size 10 · passes 3 · vibrancy 0.25"
                : glass.q === "equilibrada" ? "decoration:blur → size 7 · passes 2 · vibrancy 0.17"
                : "decoration:blur → enabled = false"
        }
        SwRow { label: "Bajar calidad con batería"; sub: "Quita el desenfoque al desconectar el cargador"; key: "blurOnBattery"; def: true }
        SwRow { label: "Quitar efectos en juegos"; sub: "pantalla completa sin desenfoque ni sombras"; key: "gameNoFx"; def: true }
        SwRow { label: "Ajustar según la GPU"; sub: "Detecta equipos modestos y elige solo"; key: "blurAuto"; def: true }
        Txt {
            Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
            text: "Modo juego: Super + Mayús + G quita al momento animaciones, desenfoque, sombras, redondeo y huecos; otra vez, y vuelven."
        }
    }
}
