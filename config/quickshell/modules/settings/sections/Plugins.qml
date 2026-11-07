// Ajustes › Plugins — gestor de plugins de Hyprland con hyprpm.
// Catálogo: config/tools/plugins.json (compatibilidad con 0.57/Lua y opciones). Estado: «hyprpm list».
// Instalar y «Actualizar todos» van en una terminal (compilan y pueden pedir la contraseña); activar,
// desactivar y recargar se hacen aquí (hyprpm enable/disable + hyprpm reload) con los errores en español.
// Las opciones se guardan en Settings «plugins» { id: { on, …opciones } } y las aplica config/apply/70-plugins.py
// (solo para los activados: «on» se sincroniza con hyprpm list). Al iniciar: autostart.lua (pluginsAutoload).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../.."
import "../../../components"
import "../../../services"
import "../ui"

ColumnLayout {
    id: root
    spacing: 12
    property string tab: "todos"
    property string cat: "todo"
    property bool hasHyprpm: true
    property bool listed: false            // «hyprpm list» ya respondió
    property var pstate: ({})              // plugin de hyprpm → "on" | "off" | "fail"
    property var repos: []                 // repositorios añadidos
    property var catalog: []
    property string retired: ""
    property string sel: ""                // id con el panel de opciones abierto
    property string busyId: ""
    property string msg: ""
    property bool msgBad: false
    property int polls: 0                  // tras abrir una terminal: vuelve a leer el estado un rato
    readonly property var conf: Settings.get("plugins", ({})) ?? ({})
    readonly property var cats: [["todo", "Todo"], ["ventanas", "Ventanas"], ["visual", "Visual"], ["entrada", "Entrada"], ["juegos", "Juegos"]]
    // Del catálogo + los instalados con hyprpm que no están en él
    readonly property var all: catalog.concat(Object.keys(pstate).filter(n => !catalog.some(c => c.plugin === n)).map(n => ({
        id: n, name: n, plugin: n, by: "", cat: "otros", install: "hyprpm", compat: "", repo: "", url: "",
        desc: "Instalado con hyprpm (no está en el catálogo de HyprFrijol).", compatNote: "", options: []
    })))
    readonly property var shown: all.filter(p => (cat === "todo" || p.cat === cat)
        && (tab === "todos" || (tab === "instalados") === (pstate[p.plugin] !== undefined))
        && (!search.text || (p.name + " " + p.desc + " " + (p.by ?? "")).toLowerCase().includes(search.text.toLowerCase())))
    readonly property var selP: all.find(p => p.id === sel) ?? null
    readonly property int nOn: Object.keys(pstate).filter(k => pstate[k] === "on").length
    readonly property int nInst: Object.keys(pstate).length
    function st(p): string { return pstate[p.plugin] ?? ""; }
    function isOn(id: string): bool { const p = all.find(x => x.id === id); return !!p && st(p) === "on"; }

    function refresh(): void { lister.running = false; lister.running = true; }
    function say(t: string, bad: bool): void { msg = t; msgBad = bad; }

    // ---------- catálogo ----------
    FileView {
        path: Paths.root + "/config/tools/plugins.json"
        printErrors: false
        onLoaded: {
            try { const j = JSON.parse(text()); root.catalog = j.plugins ?? []; root.retired = j.retired ?? ""; }
            catch (e) { root.say("No se pudo leer el catálogo de plugins (config/tools/plugins.json)", true); }
            root.sync();
        }
    }

    // ---------- estado: hyprpm list ----------
    Process {
        id: lister
        running: true
        command: ["sh", "-c", "command -v hyprpm >/dev/null || { echo NOHYPRPM; exit; }; hyprpm list 2>&1 | sed 's/\\x1b\\[[0-9;]*m//g'"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.includes("NOHYPRPM")) { root.hasHyprpm = false; root.listed = true; return; }
                root.hasHyprpm = true;
                const st = {}, rp = [];
                let cur = "";
                text.split("\n").forEach(l => {
                    const r = l.match(/Repository\s+(\S+)/); if (r) rp.push(r[1]);
                    const m = l.match(/^\s*│?\s*Plugin\s+(\S+)\s*$/); if (m) cur = m[1];
                    const e = l.match(/enabled:\s*(.+)$/);
                    if (e && cur) st[cur] = /failed/i.test(e[1]) ? "fail" : /^\s*(true|yes)/.test(e[1]) ? "on" : "off";
                });
                root.pstate = st;
                root.repos = rp;
                root.listed = true;
                root.sync();
            }
        }
    }
    // «on» de cada plugin en Settings = activado en hyprpm (70-plugins.py solo genera Lua para esos)
    function sync(): void {
        if (!listed || !hasHyprpm || !catalog.length || !Settings.loaded) return;
        const c = Object.assign({}, conf);
        let changed = false;
        for (const p of catalog) {
            if (p.install !== "hyprpm") continue;
            const on = pstate[p.plugin] === "on";
            if (!!(c[p.id]?.on) !== on && (on || c[p.id])) { c[p.id] = Object.assign({}, c[p.id] ?? {}, { on: on }); changed = true; }
        }
        if (changed) Settings.set("plugins", c);
    }
    function setOpt(id: string, key: string, v): void {
        const c = Object.assign({}, conf);
        const o = Object.assign({}, c[id] ?? {});
        o[key] = v;
        c[id] = o;
        Settings.set("plugins", c);
    }
    function opt(id: string, key: string, def): var { const v = conf[id]?.[key]; return v === undefined ? def : v; }

    // ---------- acciones ----------
    // Errores de hyprpm → español
    function explain(out: string, name: string): var {
        const o = out.replace(/\x1b\[[0-9;]*m/g, "");
        if (/headers? (are )?(not up-to-date|outdated)|Headers (missing|corrupted|version mismatch)|ABI (is )?mismatched|ABI changed|Cannot find headers/i.test(o))
            return [true, "Las cabeceras de Hyprland no coinciden con la versión que usas. Pulsa «Actualizar todos» (hyprpm update) y vuelve a intentarlo."];
        if (/Couldn.t (enable|disable) plugin/i.test(o)) return [true, "hyprpm no encuentra «" + name + "»: instálalo primero."];
        if (/differs from plugin state|please restart Hyprland/i.test(o))
            return [true, "Hyprland se actualizó y los plugins son de la versión anterior: pulsa «Actualizar todos» o reinicia la sesión."];
        if (/Not loading .*not built|failed to build/i.test(o))
            return [true, "«" + name + "» no se pudo compilar para tu versión de Hyprland. Prueba «Actualizar todos»; si sigue igual, aún no es compatible."];
        if (/running (on )?hyprland|HYPRLAND_INSTANCE_SIGNATURE/i.test(o)) return [true, "hyprpm necesita una sesión de Hyprland en marcha."];
        if (/Dependencies not satisfied/i.test(o)) return [true, "Faltan herramientas para compilar (cmake, cpio, pkg-config, git, g++): instálalas y repite."];
        if (/will be (un)?loaded after restarting/i.test(o)) return [false, "Se aplicará al reiniciar Hyprland."];
        const f = o.split("\n").find(l => l.includes("✖"));
        if (f) return [true, "hyprpm: " + f.replace(/^.*✖\s*/, "").trim()];
        return null;
    }
    Process {
        id: runner
        property string what: ""
        property string label: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const ok = /RC=0\s*$/.test(text);
                const e = root.explain(text, runner.label);
                if (e) root.say(e[1], e[0] || !ok);
                else if (!ok) root.say("hyprpm no pudo " + (runner.what === "disable" ? "desactivar" : runner.what === "enable" ? "activar" : "recargar") + " «" + runner.label + "».", true);
                else root.say(runner.what === "enable" ? "«" + runner.label + "» activado." : runner.what === "disable" ? "«" + runner.label + "» desactivado." : "Plugins recargados.", false);
                root.busyId = "";
                root.refresh();
            }
        }
    }
    function hyprpm(what: string, p): void {
        if (runner.running) return;
        runner.what = what;
        runner.label = p ? p.name : "";
        busyId = p ? p.id : "*";
        msg = "";
        runner.command = what === "reload"
            ? ["sh", "-c", "hyprpm reload 2>&1; echo \"RC=$?\""]
            : ["sh", "-c", "hyprpm \"$1\" \"$2\" 2>&1 && hyprpm reload 2>&1; echo \"RC=$?\"", "sh", what, p.plugin];
        runner.running = true;
    }
    function install(p): void {
        const fail = st(p) === "fail";
        const cmd = (fail ? "hyprpm update -f && " : !repos.length ? "hyprpm update && " : "")
            + (repos.includes(p.repoName) || fail ? "" : "hyprpm add " + p.repo + " && ")
            + "hyprpm enable " + p.plugin + " && hyprpm reload -n";
        Pkg.runInTerminal(cmd, (fail ? "Recompilar " : "Instalar ") + p.name);
        say("Se abrió una terminal para " + (fail ? "recompilar" : "compilar e instalar") + " «" + p.name + "». Puede tardar unos minutos.", false);
        polls = 36;
    }
    function updateAll(): void {
        Pkg.runInTerminal("hyprpm update && hyprpm reload -n", "Actualizar plugins");
        say("Se abrió una terminal con «hyprpm update»: recompila los plugins para tu versión de Hyprland.", false);
        polls = 36;
    }
    Timer { interval: 5000; repeat: true; running: root.polls > 0; onTriggered: { root.polls--; root.refresh(); } }

    // ---------- avisos de cada plugin ----------
    readonly property var gestureKeys: ({ "4:up": ["gesture4Up", "spotlight"], "4:down": ["gesture4Down", "notificaciones"], "3:up": ["gesture3Up", "vista"] })
    readonly property var gestureNames: ({ vista: "Vista general", escritorio: "Mostrar el escritorio", spotlight: "Spotlight", ia: "Asistente de IA", notificaciones: "Notificaciones", ajustes: "Ajustes", bloquear: "Bloquear" })
    function keyTaken(k: string): bool {
        const n = s => String(s ?? "").split("+").map(x => x.trim().toUpperCase()).filter(x => x).join(" + ");
        const kb = Settings.get("keybinds", ({})) ?? {};
        return Object.keys(kb).some(d => n(kb[d]?.to) === n(k));
    }
    function hints(p): var {
        const h = [];
        if (!p) return h;
        if (p.id === "hyprbars")
            h.push(["Con Hyprbars activado, las ventanas flotantes llevan barra de título con botones para cerrar, maximizar y minimizar (el modo flotante se elige en Ajustes › Escritorio). Doble clic en la barra: maximizar.", false]);
        if (p.id === "hyprexpo" || p.id === "Hyprspace") {
            const b = opt(p.id, "bind", (p.options ?? []).find(o => o.key === "bind")?.def ?? "");
            if (b === "SUPER + TAB") h.push(["Super + Tab abrirá " + p.name + " en lugar de la «Vista general» del shell mientras esté activado.", false]);
            if (b && keyTaken(b)) h.push([b.replace("SUPER", "Super").replace("SHIFT", "Mayús").replace("TAB", "Tab") + " ya lo usa un atajo tuyo (Ajustes › Teclado): no se asignará.", true]);
            const other = p.id === "hyprexpo" ? "Hyprspace" : "hyprexpo";
            if (b && isOn(other) && opt(other, "bind", other === "hyprexpo" ? "SUPER + SHIFT + TAB" : "") === b)
                h.push(["El otro plugin de vista general usa el mismo atajo: solo se asigna a HyprExpo.", true]);
        }
        if (p.id === "hyprexpo") {
            const g = gestureKeys[opt("hyprexpo", "gesture", "")];
            if (g) {
                const a = Settings.get(g[0], g[1]);
                if (a && a !== "ninguna") h.push(["Ese gesto ya abre «" + (gestureNames[a] ?? a) + "» (Ajustes › Escritorio y gestos): no se asignará a HyprExpo hasta que lo pongas en «Nada» allí.", true]);
            }
        }
        if (p.id === "hyprglass") h.push(["Se suma al desenfoque del estilo «Cristal» del shell: con ventanas opacas apenas se nota.", false]);
        if (p.id === "Hypr-DarkWindow" || p.id === "hyprwinwrap")
            h.push(["No tiene opciones aquí: sus reglas por ventana van en ~/.config/hyprfrijol/local.lua (mira su README).", false]);
        return h;
    }

    // ---------- interfaz ----------
    Rectangle {
        visible: !root.hasHyprpm
        Layout.fillWidth: true
        implicitHeight: noPm.implicitHeight + 20
        radius: Theme.r(6)
        color: Theme.pc
        RowLayout {
            id: noPm
            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 8
            Txt { Layout.fillWidth: true; color: Theme.pcText; wrapMode: Text.WordWrap; text: "hyprpm no está instalado. Desde Hyprland 0.57 va en su propio paquete «hyprpm» (y para compilar plugins necesita cmake, meson y cpio)." }
            Button { text: "Instalar hyprpm"; onClicked: { Pkg.runInTerminal(Pkg.family === "arch" ? "sudo pacman -S --needed hyprpm hyprland-protocols cmake meson cpio pkgconf git gcc && hyprpm update" : Pkg.family === "fedora" ? "sudo dnf install -y hyprpm cmake meson cpio gcc-c++ git && hyprpm update" : "echo 'Instala el paquete hyprpm (o hyprland-devel) con tu gestor de paquetes'", "hyprpm"); root.polls = 36; } }
        }
    }
    Rectangle {
        visible: root.msg !== ""
        Layout.fillWidth: true
        implicitHeight: msgRow.implicitHeight + 16
        radius: Theme.r(6)
        color: root.msgBad ? Qt.alpha(Theme.danger, 0.14) : Theme.selBg
        RowLayout {
            id: msgRow
            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 8
            Txt { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.msg; color: root.msgBad ? Theme.danger : Theme.selText; weight: Font.Medium }
            Button { visible: root.msgBad && /Actualizar todos/.test(root.msg); h: 26; kind: "primary"; text: "Actualizar todos"; onClicked: root.updateAll() }
            Button { h: 26; kind: "link"; text: "✕"; onClicked: root.msg = "" }
        }
    }

    Section {
        Layout.fillWidth: true
        title: "Gestor de plugins"
        headerRight: [
            Button { h: 28; text: "Recargar"; enabled: root.hasHyprpm && !runner.running; onClicked: root.hyprpm("reload", null) },
            Button { h: 28; kind: "primary"; text: "Actualizar todos"; enabled: root.hasHyprpm && root.nInst > 0; onClicked: root.updateAll() }
        ]
        Txt {
            Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
            text: !root.listed ? "Leyendo hyprpm…" : !root.hasHyprpm ? "Sin hyprpm no se pueden instalar plugins." : root.nInst === 0
                ? "Aún no hay plugins instalados. Se compilan para tu versión de Hyprland con hyprpm; la primera vez descarga las cabeceras de Hyprland (unos minutos)."
                : root.nOn + (root.nOn === 1 ? " activado" : " activados") + " de " + root.nInst + (root.nInst === 1 ? " instalado" : " instalados")
                  + ". Tras actualizar Hyprland, pulsa «Actualizar todos» para recompilarlos."
        }
        SwRow {
            label: "Cargar al iniciar"
            sub: "hyprpm reload -n al iniciar sesión: carga los plugins activados y avisa si alguno falla"
            key: "pluginsAutoload"; def: true
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Seg { model: [["todos", "Todos"], ["instalados", "Instalados"], ["disponibles", "Disponibles"]]; current: root.tab; fill: false; pill: true; onPicked: k => root.tab = k }
        Repeater {
            model: root.cats
            Chip { required property var modelData; mark: false; text: modelData[1]; on: root.cat === modelData[0]; onClicked: root.cat = modelData[0] }
        }
        Item { Layout.fillWidth: true }
        Field { id: search; Layout.preferredWidth: 200; placeholder: "Buscar plugin…"; h: 30 }
    }

    // Opciones del plugin elegido
    Section {
        visible: root.selP !== null
        Layout.fillWidth: true
        title: root.selP ? (root.selP.install === "manual" ? root.selP.name + ": cómo instalarlo" : "Opciones de " + root.selP.name) : ""
        headerRight: [ Button { h: 26; kind: "link"; text: "Cerrar"; onClicked: root.sel = "" } ]
        Txt {
            Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
            text: root.selP ? (root.selP.compatNote || "") : ""
            visible: text !== ""
        }
        Txt {
            Layout.fillWidth: true; size: 11.5; wrapMode: Text.WordWrap; color: Theme.tv
            visible: root.selP !== null && root.selP.install !== "manual" && root.st(root.selP) !== "on" && (root.selP.options ?? []).length > 0
            text: "Se aplicarán cuando el plugin esté instalado y activado."
        }
        Repeater {
            model: root.hints(root.selP)
            RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 8
                Rectangle { Layout.alignment: Qt.AlignTop; Layout.topMargin: 5; implicitWidth: 6; implicitHeight: 6; radius: 3; color: modelData[1] ? Theme.danger : Theme.p }
                Txt { Layout.fillWidth: true; wrapMode: Text.WordWrap; size: 11.5; text: modelData[0]; color: modelData[1] ? Theme.danger : Theme.t }
            }
        }
        Repeater {
            model: root.selP ? (root.selP.options ?? []) : []
            PluginOption {
                required property var modelData
                required property int index
                opt: modelData
                value: root.conf[root.selP?.id]?.[modelData.key]
                onPicked: v => root.setOpt(root.selP.id, modelData.key, v)
            }
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: root.width > 980 ? 3 : 2
        columnSpacing: 10; rowSpacing: 10
        Repeater {
            model: root.shown
            PluginCard {
                required property var modelData
                p: modelData
                st: root.st(modelData)
                busy: root.busyId === modelData.id || (root.busyId === "*" && st !== "")
                selected: root.sel === modelData.id
                canRun: root.hasHyprpm && !runner.running
                onInstall: root.install(modelData)
                onToggle: root.hyprpm(st === "on" ? "disable" : "enable", modelData)
                onConfigure: root.sel = root.sel === modelData.id ? "" : modelData.id
                onWeb: if (modelData.url || modelData.repo) Quickshell.execDetached(["xdg-open", modelData.url || modelData.repo])
            }
        }
    }
    Txt {
        visible: root.shown.length === 0
        Layout.fillWidth: true; Layout.topMargin: 8
        horizontalAlignment: Text.AlignHCenter
        muted: true
        text: root.tab === "instalados" ? "No hay plugins instalados con estos filtros." : "Ningún plugin coincide."
    }
    Txt {
        Layout.fillWidth: true
        muted: true; size: 11.5; wrapMode: Text.WordWrap
        text: "Los plugins se compilan en tu equipo y dependen de la versión exacta de Hyprland: tras cada actualización, «Actualizar todos». Sus opciones se generan en Lua solo para los activados. "
            + root.retired
    }
}
