// Ajustes › Energía y rendimiento — perfil (power-profiles-daemon), suspensión por inactividad (hypridle, 85-idle.py),
// GPU (supergfxctl/envycontrol), límite de carga 80/90/100 (chargeLimit: charge_control_end_threshold con pkexec
// y regla udev /etc/udev/rules.d/99-hyprfrijol-charge.rules para que dure tras reiniciar), brillo automático,
// ahorro con poca batería, calidad del desenfoque del cristal (config/apply/10-look.py) y salud de la batería con su
// historial (modules/settings/BatteryLog.qml → battery-history.json). $HF_POWER_SUPPLY sustituye a
// /sys/class/power_supply para probar con datos falsos.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../.."
import "../../../components"
import "../../../services"
import "../ui"

RowLayout {
    id: root
    spacing: 12
    implicitHeight: Math.max(left.implicitHeight, right.implicitHeight)
    property string gfxTool: ""
    property string battery: ""      // ruta de charge_control_end_threshold
    property int threshold: 100
    property bool lightSensor: false
    property bool hasPkexec: true
    Timer { id: thrLater; interval: 4000; onTriggered: { detect.running = false; detect.running = true; } }
    // Límite de carga: lo escribe ahora (pkexec, pide tu contraseña) y deja una regla udev para los siguientes
    // arranques (100 % la quita). Si el umbral de inicio (ThinkPad…) es mayor, lo baja a n − 5.
    function setChargeLimit(n) {
        if (!battery) return;
        const dev = battery.split("/").slice(-2)[0];
        const rule = n < 100 ? 'SUBSYSTEM=="power_supply", KERNEL=="' + dev + '", ATTR{charge_control_end_threshold}="' + n + '"' : "";
        const cmd = 's="${2%end_threshold}start_threshold"; [ -f "$s" ] && [ "$(cat "$s")" -ge "$1" ] && echo $(($1 - 5)) > "$s"; '
            + 'echo "$1" > "$2" && rm -f /etc/udev/rules.d/99-hypr-liquid-charge.rules && r=/etc/udev/rules.d/99-hyprfrijol-charge.rules && '
            + 'if [ -n "$3" ]; then printf "# hyprfrijol · Ajustes › Energía (límite de carga)\n%s\n" "$3" > "$r"; else rm -f "$r"; fi';
        if (hasPkexec) Quickshell.execDetached(["pkexec", "sh", "-c", cmd, "sh", String(n), battery, rule]);
        else Pkg.runInTerminal("sudo sh -c '" + cmd.replace(/'/g, "'\\''") + "' sh " + n + " '" + battery + "' '" + rule.replace(/'/g, "'\\''") + "'", "Límite de carga");
        threshold = n;
        Settings.set("chargeLimit", n);
        thrLater.restart();
    }
    Process {
        id: detect
        running: true
        command: ["sh", "-c", "command -v supergfxctl >/dev/null && echo gfx:supergfxctl || { command -v envycontrol >/dev/null && echo gfx:envycontrol; }; "
            + "for f in ${HF_POWER_SUPPLY:-/sys/class/power_supply}/BAT*/charge_control_end_threshold; do [ -f \"$f\" ] && echo \"bat:$f:$(cat $f)\" && break; done; "
            + "command -v pkexec >/dev/null || echo nopkexec; "
            + "ls /sys/bus/iio/devices/*/in_illuminance_raw >/dev/null 2>&1 && echo light"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                root.gfxTool = (l.find(x => x.startsWith("gfx:")) ?? "gfx:").slice(4);
                const b = (l.find(x => x.startsWith("bat:")) ?? "").split(":");
                root.battery = b[1] ?? ""; root.threshold = parseInt(b[2] ?? "100") || 100;
                root.lightSensor = l.includes("light");
                root.hasPkexec = !l.includes("nopkexec");
            }
        }
    }
    // logind (tapa y botón de encendido) y batería
    property var login: ({})            // { lid, lidAC, power }
    property bool canHibernate: false
    property bool swapZram: false
    property bool lid: false
    property var bat: ({})
    // Historial de salud (últimos 180 días con dato)
    property var history: []
    readonly property var healthHist: history.filter(e => e && e.health > 0).slice(-180)
    readonly property string histSpan: {
        if (healthHist.length < 2) return "";
        const d = Math.round((new Date(healthHist[healthHist.length - 1].d) - new Date(healthHist[0].d)) / 86400000);
        return d >= 60 ? Math.round(d / 30) + " meses" : d + " días";
    }
    FileView {
        path: Paths.state + "/battery-history.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { const v = JSON.parse(text()); root.history = Array.isArray(v) ? v : []; } catch (e) { root.history = []; } }
    }
    readonly property var lidActions: [["suspend", "Suspender"], ["lock", "Solo bloquear"], ["ignore", "No hacer nada"], ["poweroff", "Apagar"]].concat(canHibernate ? [["hibernate", "Hibernar"], ["suspend-then-hibernate", "Suspender y luego hibernar"]] : [])
    function loadLogin() { loginProc.running = false; loginProc.running = true; }
    Process {
        id: loginProc
        running: true
        command: ["sh", "-c", "g() { busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager \"$1\" 2>/dev/null | sed 's/^s //; s/\"//g'; }; "
            + "echo lid:$(g HandleLidSwitch); echo lidac:$(g HandleLidSwitchExternalPower); echo power:$(g HandlePowerKey); "
            + "echo hib:$(busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager CanHibernate 2>/dev/null | sed 's/^s //; s/\"//g'); "
            + "swapon --show=NAME --noheadings 2>/dev/null | grep -q zram && echo zram; "
            + "{ ls /proc/acpi/button/lid/*/state >/dev/null 2>&1 || grep -qi 'SW_LID\\|Lid Switch' /proc/bus/input/devices 2>/dev/null; } && echo haslid; "
            + "b=$(ls -d ${HF_POWER_SUPPLY:-/sys/class/power_supply}/BAT* 2>/dev/null | head -1); [ -n \"$b\" ] && { echo bat:$(basename $b); "
            + "if [ -f $b/energy_full ]; then echo unit:energy; echo full:$(cat $b/energy_full); echo design:$(cat $b/energy_full_design 2>/dev/null); "
            + "else echo unit:charge; echo full:$(cat $b/charge_full 2>/dev/null); echo design:$(cat $b/charge_full_design 2>/dev/null); fi; "
            + "echo cycles:$(cat $b/cycle_count 2>/dev/null); echo vendor:$(cat $b/manufacturer 2>/dev/null); echo model:$(cat $b/model_name 2>/dev/null); }"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n"), g = p => (l.find(x => x.startsWith(p)) ?? p).slice(p.length).trim();
                root.login = { lid: g("lid:"), lidAC: g("lidac:"), power: g("power:") };
                root.canHibernate = g("hib:") === "yes";
                root.swapZram = l.includes("zram");
                root.lid = l.includes("haslid");
                const full = Number(g("full:")), design = Number(g("design:"));
                root.bat = g("bat:") ? { present: true, name: g("bat:"), unit: g("unit:"), full: full, design: design, health: design > 0 ? full / design * 100 : 0,
                                        cycles: Number(g("cycles:")) || 0, vendor: g("vendor:"), model: g("model:") } : { present: false };
            }
        }
    }
    Timer { id: loginLater; interval: 2500; onTriggered: root.loadLogin() }
    function setLogin(patch) {
        const c = Object.assign({}, login, patch);
        Quickshell.execDetached(["pkexec", "sh", "-c", "mkdir -p /etc/systemd/logind.conf.d && rm -f /etc/systemd/logind.conf.d/hypr-liquid.conf && printf '# hyprfrijol · Ajustes › Energía\\n[Login]\\nHandleLidSwitch=%s\\nHandlePowerKey=%s\\n' \"$1\" \"$3\" > /etc/systemd/logind.conf.d/hyprfrijol.conf && "
            + "{ [ -z \"$2\" ] || printf 'HandleLidSwitchExternalPower=%s\\n' \"$2\" >> /etc/systemd/logind.conf.d/hyprfrijol.conf; } && systemctl kill -s HUP systemd-logind",
            "sh", c.lid || "suspend", c.lidAC ?? "", c.power || "poweroff"]);
        login = c;
        loginLater.restart();
    }
    function setGfx(k) {
        Settings.set("gpuMode", k);
        if (gfxTool === "supergfxctl") Quickshell.execDetached(["supergfxctl", "-m", k === "integrada" ? "Integrated" : k === "dedicada" ? "AsusMuxDgpu" : "Hybrid"]);
        else if (gfxTool === "envycontrol") Pkg.runInTerminal("sudo envycontrol -s " + (k === "integrada" ? "integrated" : k === "dedicada" ? "nvidia" : "hybrid") + " && echo 'Reinicia para aplicar'", "Gráficos");
    }

    ColumnLayout {
        id: left
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        spacing: 12
        Section {
            Layout.fillWidth: true
            title: "Modo de energía"
            headerRight: Txt { visible: Battery.present; muted: true; size: 11.5; text: Math.round(Battery.percent * 100) + " %" + (Battery.charging ? " · cargando" : Battery.timeText ? " · " + Battery.timeText : "") }
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Card { title: "Ahorro"; sub: "Más batería"; selected: Battery.profile === "ahorro"; onClicked: Battery.setProfile("ahorro") }
                Card { title: "Equilibrado"; sub: "Recomendado"; selected: Battery.profile === "equilibrado"; onClicked: Battery.setProfile("equilibrado") }
                Card { title: "Rendimiento"; sub: Battery.hasPerformance ? "Máxima potencia" : "No disponible"; selected: Battery.profile === "rendimiento"; opacity: Battery.hasPerformance ? 1 : 0.5; onClicked: if (Battery.hasPerformance) Battery.setProfile("rendimiento") }
            }
            LabeledRow {
                label: "Atenuar tras"; labelWidth: 120
                Seg { model: [[1, "1 min"], [2, "2 min"], [4, "4 min"], [0, "Nunca"]]; current: Settings.get("idleDim", 0); onPicked: k => Settings.set("idleDim", k) }
            }
            LabeledRow {
                // el bloqueo por inactividad se elige en Privacidad › Bloqueo de pantalla
                label: "Bloquear tras"; labelWidth: 120
                RowLayout {
                    Button {
                        kind: "link"
                        readonly property int m: Settings.get("idleLock", 5)
                        text: (m > 0 ? m + " min" : "Nunca") + " · Se configura en Privacidad ›"
                        onClicked: Shell.open("ajustesapp", "privacidad#Bloquear tras")
                    }
                    Item { Layout.fillWidth: true }
                }
            }
            LabeledRow {
                label: "Apagar pantalla"; labelWidth: 120
                Seg { model: [[5, "5 min"], [10, "10 min"], [20, "20 min"], [0, "Nunca"]]; current: Settings.get("idleScreenOff", 10); onPicked: k => Settings.set("idleScreenOff", k) }
            }
            LabeledRow {
                label: "Suspender tras"; labelWidth: 120
                Seg { model: [[15, "15 min"], [30, "30 min"], [60, "1 h"], [0, "Nunca"]]; current: Settings.get("idleSuspend", 15); onPicked: k => Settings.set("idleSuspend", k) }
            }
            LabeledRow {
                label: "Gráficos"; labelWidth: 120
                hint: root.gfxTool || "no disponible"
                Seg { opacity: root.gfxTool ? 1 : 0.5; model: [["auto", "Automático"], ["integrada", "Integrada"], ["dedicada", "Dedicada"]]; current: Settings.get("gpuMode", "auto"); onPicked: k => { if (root.gfxTool) root.setGfx(k); } }
            }
        }
        Section {
            Layout.fillWidth: true
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                opacity: root.battery ? 1 : 0.5
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Txt { Layout.fillWidth: true; text: "Limitar la carga"; weight: Font.Medium }
                    Txt {
                        Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
                        text: !root.battery ? "Tu batería no permite limitar la carga"
                            : root.threshold < 100 ? "Se detiene al " + root.threshold + " % · alarga la vida de la batería"
                            : "Carga completa · 80 % es lo mejor si sueles estar enchufado"
                    }
                }
                Seg {
                    fill: false
                    model: [[80, "80 %"], [90, "90 %"], [100, "100 %"]]
                    current: root.threshold <= 80 ? 80 : root.threshold <= 90 ? 90 : 100
                    onPicked: k => { if (root.battery && k !== root.threshold) root.setChargeLimit(k); }
                }
            }
            Txt {
                visible: root.battery !== ""
                Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
                text: "Pide tu contraseña. Escribe " + root.battery.replace(/^.*\/(BAT[^/]*)\//, "$1/") + " y deja una regla udev para que se mantenga al reiniciar."
            }
            SwRow { label: "Brillo automático"; sub: root.lightSensor ? "Usa el sensor de luz" : "Este equipo no tiene sensor de luz"; key: "autoBrightness"; enabled: root.lightSensor }
            SwRow { label: "Ahorro automático con poca batería"; sub: "Por debajo del 20 %"; key: "lowBatterySaver"; def: true }
            // Perfil al enchufar y al desenchufar el cargador (Daemons.profileOnPlug)
            Repeater {
                model: [["powerProfileAC", "Con el cargador"], ["powerProfileBattery", "Con batería"]]
                LabeledRow {
                    required property var modelData
                    visible: Battery.present
                    label: modelData[1]; labelWidth: 130
                    Seg {
                        model: [["", "No cambiar"], ["ahorro", "Ahorro"], ["equilibrado", "Equilibrado"]].concat(Battery.hasPerformance ? [["rendimiento", "Rendimiento"]] : [])
                        current: Settings.get(modelData[0], "")
                        // (claves literales: así las encuentra «Restaurar valores por defecto»)
                        onPicked: k => modelData[0] === "powerProfileAC" ? Settings.set("powerProfileAC", k) : Settings.set("powerProfileBattery", k)
                    }
                }
            }
        }
    }
    ColumnLayout {
    id: right
    Layout.fillWidth: true
    Layout.preferredWidth: 1
    Layout.alignment: Qt.AlignTop
    spacing: 12
    Section {
        Layout.fillWidth: true
        title: "Efectos y rendimiento"
        LinkRow { label: "Calidad del desenfoque, efectos en juegos y con batería"; section: "animaciones"; sectionLabel: "Animaciones y efectos"; target: "Desenfoque y rendimiento" }
        SwRow { label: "Pantalla de carga al entrar"; sub: "el frijolito y una barrita si el fondo y la barra tardan en cargar"; key: "startSplash"; def: true }
    }
    Section {
        Layout.fillWidth: true
        title: "Memoria del escritorio"
        headerRight: Mono { text: "components/LazyView" }
        SwRow {
            label: "Cargar los paneles al abrirlos"
            sub: "Spotlight, centro de control, vista general… solo ocupan memoria mientras se usan. Apágalo solo para depurar"
            key: "lazyModules"; def: true
        }
    }
    Section {
        Layout.fillWidth: true
        title: "Tapa y botón de encendido"
        headerRight: Mono { text: "logind.conf.d" }
        LabeledRow {
            label: "Al cerrar la tapa"; labelWidth: 150
            hint: root.lid ? "con batería" : "sin tapa"
            Dropdown {
                enabled: root.lid
                opacity: root.lid ? 1 : 0.5
                model: root.lidActions
                current: root.login.lid || "suspend"
                onPicked: k => root.setLogin({ lid: k })
            }
        }
        LabeledRow {
            visible: root.lid
            label: "…con el cargador"; labelWidth: 150
            Dropdown {
                model: [["", "Igual que con batería"]].concat(root.lidActions)
                current: root.login.lidAC ?? ""
                onPicked: k => root.setLogin({ lidAC: k })
            }
        }
        LabeledRow {
            label: "Botón de encendido"; labelWidth: 150
            Dropdown {
                model: [["menu", "Mostrar el menú de apagado"], ["poweroff", "Apagar"], ["suspend", "Suspender"]].concat(root.canHibernate ? [["hibernate", "Hibernar"]] : []).concat([["ignore", "No hacer nada"]])
                current: root.login.power === "ignore" && Settings.get("powerKey", "") === "menu" ? "menu" : (root.login.power || "poweroff")
                onPicked: k => { Settings.set("powerKey", k); root.setLogin({ power: k === "menu" ? "ignore" : k }); }
            }
        }
        SwRow {
            label: "Hibernar"
            sub: root.canHibernate ? "disponible · guarda la sesión en el disco y apaga" : "no disponible: falta swap en disco" + (root.swapZram ? " (solo hay zram)" : "")
            enabled: false
            checked: root.canHibernate
        }
        Txt {
            Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
            text: "Se guarda en /etc/systemd/logind.conf.d/hyprfrijol.conf (pide tu contraseña). Con un monitor externo conectado, cerrar la tapa no suspende."
        }
    }
    Section {
        visible: root.bat.present === true
        Layout.fillWidth: true
        title: "Estado de la batería"
        headerRight: Mono { text: root.bat.name ?? "" }
        Kv { k: "Salud"; v: root.bat.health > 0 ? Math.round(root.bat.health) + " % de la capacidad original" : "—" }
        Kv { k: "Ciclos de carga"; v: root.bat.cycles > 0 ? String(root.bat.cycles) : "—" }
        Kv { k: "Capacidad"; v: root.bat.full > 0 ? (root.bat.full / 1e6).toFixed(1) + " / " + (root.bat.design / 1e6).toFixed(1) + (root.bat.unit === "energy" ? " Wh" : " Ah") : "—" }
        Kv { k: "Fabricante y modelo"; v: [root.bat.vendor, root.bat.model].filter(Boolean).join(" ") || "—"; bold: false }
        // Historial diario de la salud (BatteryLog.qml)
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            Txt { Layout.fillWidth: true; text: "Salud en el tiempo"; weight: Font.Medium }
            Txt {
                visible: root.healthHist.length > 1
                muted: true; size: 11.5; tabular: true
                text: root.healthHist.length > 1 ? Math.round(root.healthHist[0].health) + " % → " + Math.round(root.healthHist[root.healthHist.length - 1].health) + " % · " + root.histSpan : ""
            }
        }
        Sparkline {
            visible: root.healthHist.length > 1
            Layout.fillWidth: true
            implicitHeight: 56
            values: root.healthHist.map(e => e.health)
            min: Math.max(0, Math.floor(Math.min(...values) / 5) * 5 - 5)
            max: Math.min(105, Math.ceil(Math.max(...values) / 5) * 5 + 1)
        }
        Txt {
            Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
            text: root.healthHist.length > 1 ? "Un dato al día · ~/.local/state/hyprfrijol/battery-history.json"
                : "El historial se irá llenando: se guarda un dato al día mientras el shell está abierto."
        }
    }
    }
}
