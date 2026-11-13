// Ajustes › Privacidad y seguridad — qué apps usan ahora el micrófono, la cámara o la pantalla (pw-dump +
// /dev/video*), bloqueo de pantalla (idleLock, lockOnSuspend → config/apply/85-idle.py, notifyLock → 
// Lock.qml), historial (archivos recientes, portapapeles cliphist, uso de la búsqueda spotlight-usage.json,
// papelera, miniaturas), ubicación (gsettings org.gnome.system.location + geoclue; weatherIpLocation →
// services/Weather.qml) y estado de seguridad del equipo (arranque seguro, cifrado, TPM, cortafuegos → Red).
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
    property var use: ({ mic: [], cam: [], screen: [], sys: [] })
    property var sec: ({})
    property string done: ""            // última limpieza hecha (aviso breve)

    readonly property string usePy: "import json,subprocess,os,glob\n"
        + "try: d=json.loads(subprocess.run(['pw-dump'],capture_output=True,text=True,timeout=4).stdout or '[]')\n"
        + "except Exception: d=[]\n"
        + "nodes={o['id']:o.get('info',{}).get('props',{}) for o in d if o.get('type','').endswith(':Node')}\n"
        + "out={'mic':[],'cam':[],'screen':[],'sys':[]}\n"
        + "def app(p): return p.get('application.name') or p.get('application.process.binary') or p.get('node.name') or '?'\n"
        + "def add(k,n):\n"
        + "  if n not in out[k]: out[k].append(n)\n"
        + "for o in d:\n"
        + "  if not o.get('type','').endswith(':Link'): continue\n"
        + "  i=o.get('info',{}); a=nodes.get(i.get('output-node-id'),{}); b=nodes.get(i.get('input-node-id'),{})\n"
        + "  mb=b.get('media.class',''); ma=a.get('media.class','')\n"
        + "  if mb=='Stream/Input/Audio':\n"
        + "    if b.get('stream.monitor')=='true' or 'quickshell' in app(b).lower(): continue\n"
        + "    add('sys' if ma=='Audio/Sink' or b.get('stream.capture.sink')=='true' else 'mic', app(b))\n"
        + "  elif mb=='Stream/Input/Video':\n"
        + "    add('cam' if a.get('device.api') in ('v4l2','libcamera') else 'screen', app(b))\n"
        + "for f in glob.glob('/proc/[0-9]*/fd/*'):\n"
        + "  try:\n"
        + "    if os.readlink(f).startswith('/dev/video'):\n"
        + "      c=open(f.split('/fd/')[0]+'/comm').read().strip()\n"
        + "      if c not in ('pipewire','wireplumber'): add('cam',c)\n"
        + "  except Exception: pass\n"
        + "print(json.dumps(out))\n"
    Process {
        id: useProc
        running: true
        command: ["python3", "-c", root.usePy]
        stdout: StdioCollector { onStreamFinished: { try { root.use = JSON.parse(text); } catch (e) {} } }
    }
    Timer { interval: 3000; running: Shell.settingsSeen; repeat: true; onRunningChanged: if (running) triggered(); onTriggered: if (!useProc.running) useProc.running = true }

    function probe() { secProc.running = false; secProc.running = true; }
    Process {
        id: secProc
        running: true
        command: ["sh", "-c", "[ -d /sys/firmware/efi ] && echo efi:yes; echo sb:$(od -An -t u1 /sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c 2>/dev/null | awk '{print $NF}'); "
            + "lsblk -rno TYPE 2>/dev/null | grep -q '^crypt$' && echo crypt:yes; [ -e /sys/class/tpm/tpm0 ] && echo tpm:yes; "
            + "systemctl is-active -q ufw 2>/dev/null && echo fw:ufw; systemctl is-active -q firewalld 2>/dev/null && echo fw:firewalld; "
            + "(command -v ufw || command -v firewall-cmd) >/dev/null && echo fwinst:yes; "
            + "[ -x /usr/lib/geoclue ] || [ -x /usr/libexec/geoclue ] && echo geoclue:yes; "
            + "echo loc:$(gsettings get org.gnome.system.location enabled 2>/dev/null); echo recent:$(gsettings get org.gnome.desktop.privacy remember-recent-files 2>/dev/null); "
            + "command -v cliphist >/dev/null && echo cliphist:yes; "
            + "echo trash:$(find \"$HOME/.local/share/Trash/files\" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l); "
            + "echo thumbs:$(du -sh \"$HOME/.cache/thumbnails\" 2>/dev/null | cut -f1); "
            + "echo rec:$(grep -c '<bookmark ' \"$HOME/.local/share/recently-used.xbel\" 2>/dev/null)"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n"), g = p => (l.find(x => x.startsWith(p)) ?? p).slice(p.length).trim();
                root.sec = {
                    efi: l.includes("efi:yes"), sb: g("sb:") === "1", crypt: l.includes("crypt:yes"), tpm: l.includes("tpm:yes"),
                    fw: g("fw:"), fwInst: l.includes("fwinst:yes"), geoclue: l.includes("geoclue:yes"),
                    loc: g("loc:"), recent: g("recent:"), cliphist: l.includes("cliphist:yes"),
                    trash: Number(g("trash:") || 0), thumbs: g("thumbs:"), rec: Number(g("rec:") || 0)
                };
            }
        }
    }
    Timer { id: later; interval: 900; onTriggered: root.probe() }
    Timer { id: doneClear; interval: 3500; onTriggered: root.done = "" }
    function clean(what, cmd) {
        Quickshell.execDetached(["sh", "-c", cmd]);
        done = what; doneClear.restart(); later.restart();
    }
    function gset(schema, key, v) { Quickshell.execDetached(["gsettings", "set", schema, key, v ? "true" : "false"]); later.restart(); }

    component UseRow: RowLayout {
        id: ur
        property string icon: ""
        property string label: ""
        property var apps: []
        property string idle: ""
        Layout.fillWidth: true
        spacing: 12
        Rectangle {
            implicitWidth: 34; implicitHeight: 34; radius: Theme.ctl(34)
            color: ur.apps.length ? Qt.alpha(Theme.ter, 0.18) : Theme.s4
            Icon { anchors.centerIn: parent; name: ur.icon; size: 16; color: ur.apps.length ? Theme.ter : Theme.tv }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Txt { Layout.fillWidth: true; text: ur.label; weight: Font.DemiBold }
            Txt { Layout.fillWidth: true; muted: !ur.apps.length; size: 11.5; text: ur.apps.length ? "En uso por " + ur.apps.join(", ") : ur.idle }
        }
        Rectangle { visible: ur.apps.length > 0; width: 8; height: 8; radius: 4; color: Theme.ter }
    }

    component CleanRow: RowLayout {
        id: cr
        property string label: ""
        property string sub: ""
        property string button: "Borrar"
        // enabled: el de Item (antes se redeclaraba y tapaba al de Qt; mismo valor por defecto)
        signal go()
        Layout.fillWidth: true
        Layout.topMargin: 2
        spacing: 12
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Txt { Layout.fillWidth: true; text: cr.label; weight: Font.DemiBold }
            Txt { Layout.fillWidth: true; visible: cr.sub !== ""; text: cr.sub; muted: true; size: 11.5 }
        }
        ConfirmButton { text: cr.button; confirmText: "¿Seguro? Sí"; enabled: cr.enabled; onConfirmed: cr.go() }
    }
    component SecRow: RowLayout {
        id: sr
        property string label: ""
        property string value: ""
        property bool good: true
        Layout.fillWidth: true
        spacing: 12
        Rectangle { width: 8; height: 8; radius: 4; color: sr.good ? Theme.p : Theme.ter }
        Txt { text: sr.label; muted: true }
        Txt { Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; text: sr.value; weight: Font.DemiBold }
    }

    // ---------- izquierda ----------
    ColumnLayout {
        id: left
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        spacing: 12
        Section {
            Layout.fillWidth: true
            title: "Ahora mismo"
            headerRight: Mono { tech: true; text: "PipeWire · se actualiza solo" }
            UseRow { icon: "mic"; label: "Micrófono"; apps: root.use.mic ?? []; idle: "Ninguna app lo está usando" }
            UseRow { icon: "camera"; label: "Cámara"; apps: root.use.cam ?? []; idle: "Ninguna app la está usando" }
            UseRow { icon: "monitor"; label: "Compartir pantalla"; apps: root.use.screen ?? []; idle: "No se está compartiendo ni grabando la pantalla" }
            UseRow { visible: (root.use.sys ?? []).length > 0; icon: "volume"; label: "Sonido del equipo"; apps: root.use.sys ?? []; idle: "" }
            RowLayout {
                spacing: 8
                Button { text: Audio.micMuted ? "Activar micrófono" : "Silenciar micrófono"; onClicked: Audio.toggleMic() }
                Button { kind: "link"; text: "Sonido"; onClicked: Shell.open("ajustesapp", "sonido") }
            }
            Txt {
                Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
                text: "Cuando una app usa el micrófono aparece un aviso en la barra. Las apps Flatpak piden permiso para la cámara, la pantalla y la ubicación a través del portal."
            }
        }
        Section {
            Layout.fillWidth: true
            title: "Bloqueo de pantalla"
            headerRight: Button { text: "Bloquear ahora"; onClicked: Quickshell.execDetached(["loginctl", "lock-session"]) }
            LabeledRow {
                label: "Bloquear tras"; labelWidth: 120
                hint: "sin actividad"
                Seg { model: [[2, "2 min"], [5, "5 min"], [10, "10 min"], [0, "Nunca"]]; current: Settings.get("idleLock", 5); onPicked: k => Settings.set("idleLock", k) }
            }
            SwRow { label: "Bloquear al suspender"; sub: "pide la contraseña al volver de la suspensión"; key: "lockOnSuspend"; def: true }
            LinkRow { label: "Tema, fondo y widgets"; target: "Pantalla de bloqueo"; section: "bloqueo"; sectionLabel: "Bloqueo e inicio de sesión" }
            LinkRow { label: "Aviso de notificaciones al bloquear"; target: "En la pantalla de bloqueo"; value: Settings.get("notifyLock", true) ? "Activado" : "Desactivado"; section: "notificaciones"; sectionLabel: "Notificaciones" }
        }
        Section {
            Layout.fillWidth: true
            title: "Ubicación"
            SwRow {
                separator: false
                label: "Servicios de ubicación"
                sub: !root.sec.geoclue ? "geoclue no está instalado · las apps no pueden pedir tu ubicación" : "las apps pueden pedirla (portal y geoclue)"
                enabled: !!root.sec.geoclue && root.sec.loc !== ""
                checked: root.sec.loc === "true"
                onToggled: v => root.gset("org.gnome.system.location", "enabled", v)
            }
            SwRow {
                label: "Ubicación aproximada por IP para el tiempo"
                sub: Settings.get("weatherLat", "") !== "" ? "no hace falta: tienes una ciudad fija en Escritorio" : "consulta ipapi.co / ipinfo.io una vez"
                key: "weatherIpLocation"; def: true
                enabled: Settings.get("weatherLat", "") === ""     // con ciudad fija no se usa
            }
            Button {
                visible: !root.sec.geoclue
                kind: "link"; text: "Instalar geoclue"
                onClicked: Pkg.runInTerminal(Pkg.commands([{ src: "Repos", pkg: "geoclue" }], { snapshot: false }).join(" && "), "Ubicación")
            }
        }
    }

    // ---------- derecha ----------
    ColumnLayout {
        id: right
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        spacing: 12
        Section {
            Layout.fillWidth: true
            title: "Historial"
            headerRight: Txt { visible: root.done !== ""; text: "✓ " + root.done; size: 11.5; color: Theme.p }
            SwRow {
                separator: false
                label: "Recordar archivos recientes"
                sub: root.sec.rec ? root.sec.rec + " archivos en ~/.local/share/recently-used.xbel" : "las apps GTK guardan lo que abres"
                enabled: root.sec.recent !== ""
                checked: root.sec.recent !== "false"
                onToggled: v => root.gset("org.gnome.desktop.privacy", "remember-recent-files", v)
            }
            CleanRow {
                label: "Archivos recientes"; sub: "la lista de «Recientes» de las apps y del selector de archivos"
                enabled: root.sec.rec > 0
                onGo: root.clean("Recientes borrados", "f=\"$HOME/.local/share/recently-used.xbel\"; [ -f \"$f\" ] && printf '<?xml version=\"1.0\" encoding=\"UTF-8\"?>\\n<xbel version=\"1.0\"/>\\n' > \"$f\"")
            }
            CleanRow {
                label: "Historial del portapapeles"; sub: root.sec.cliphist ? "cliphist wipe · los fijados se conservan" : "cliphist no está instalado"
                enabled: !!root.sec.cliphist
                onGo: root.clean("Portapapeles vaciado", "cliphist wipe")
            }
            CleanRow {
                label: "Uso de la búsqueda"; sub: "lo que Spotlight aprendió · los fijados se quedan"
                onGo: root.clean("Búsqueda reiniciada", "f=\"" + Paths.state + "/spotlight-usage.json\"; [ -f \"$f\" ] || exit 0; python3 -c 'import json,sys; p=sys.argv[1]; d=json.load(open(p)); json.dump({\"counts\":{},\"pinned\":d.get(\"pinned\",[])},open(p,\"w\"))' \"$f\" 2>/dev/null || rm -f \"$f\"")
            }
            CleanRow {
                label: "Papelera"; sub: root.sec.trash ? root.sec.trash + " elementos" : "vacía"
                button: "Vaciar"
                enabled: root.sec.trash > 0
                onGo: root.clean("Papelera vaciada", "gio trash --empty || rm -rf \"$HOME/.local/share/Trash/files\"/* \"$HOME/.local/share/Trash/info\"/*")
            }
            CleanRow {
                label: "Miniaturas"; sub: root.sec.thumbs ? root.sec.thumbs + " en ~/.cache/thumbnails · se vuelven a crear" : "no hay"
                enabled: !!root.sec.thumbs && root.sec.thumbs !== "0"
                onGo: root.clean("Miniaturas borradas", "rm -rf \"$HOME/.cache/thumbnails\"")
            }
            LinkRow { label: "Asistente de IA: datos sensibles, apps privadas y conversaciones"; section: "iaprivacidad"; sectionLabel: "Asistente de IA"; target: "Ocultar datos sensibles" }
        }
        Section {
            Layout.fillWidth: true
            title: "Seguridad del equipo"
            headerRight: Button { kind: "outline"; h: 26; text: "Actualizar"; onClicked: root.probe() }
            SecRow { label: "Cortafuegos"; value: root.sec.fw ? root.sec.fw + " · activo" : root.sec.fwInst ? "desactivado" : "no instalado"; good: !!root.sec.fw }
            SecRow { label: "Cifrado del disco"; value: root.sec.crypt ? "LUKS · activo" : "sin cifrar"; good: !!root.sec.crypt }
            SecRow { label: "Arranque seguro"; value: !root.sec.efi ? "BIOS antigua (sin UEFI)" : root.sec.sb ? "activado" : "desactivado"; good: !!root.sec.sb }
            SecRow { label: "Chip de seguridad (TPM)"; value: root.sec.tpm ? "presente" : "no detectado"; good: !!root.sec.tpm }
            RowLayout {
                spacing: 4
                Button { kind: "link"; text: "Cortafuegos (Red)"; onClicked: Shell.open("ajustesapp", "red") }
                Txt { text: "·"; color: Theme.p }
                Button { kind: "link"; text: "Actualizaciones (Sistema)"; onClicked: Shell.open("ajustesapp", "sistema") }
            }
            Txt {
                Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
                text: "El cifrado y el arranque seguro se eligen al instalar el sistema o en la BIOS; aquí solo se muestra su estado."
            }
        }
    }
}
