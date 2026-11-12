// Ajustes › Sistema — «que no se rompa»: Diagnóstico (hf-doctor), Actualizaciones de HyprFrijol (hf-update,
// por versiones etiquetadas; distinto de hf-updates, que son los paquetes del sistema) y Modo seguro (hf-safe).
// La lógica está en los scripts; aquí solo se muestra su JSON y se abren en una terminal las acciones interactivas.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../.."
import "../../../components"
import "../../../services"

ColumnLayout {
    id: root
    spacing: 12
    function sh(name: string): string { return Paths.script(name); }

    // ───────── Diagnóstico ─────────
    property var doc: null
    property string docMsg: ""
    readonly property var docIssues: (doc?.checks ?? []).filter(c => c.status === "error" || c.status === "warn")
    Process {
        id: docProc
        command: [root.sh("hf-doctor"), "--json"]
        stdout: StdioCollector { onStreamFinished: { try { root.doc = JSON.parse(text); root.docMsg = ""; } catch (e) { root.docMsg = "No se pudo leer el diagnóstico"; } } }
    }
    Process {   // el último diagnóstico guardado (hf-doctor --json lo deja en la caché)
        running: true
        command: ["cat", Paths.cache + "/doctor.json"]
        stdout: StdioCollector { onStreamFinished: { try { if (!root.doc) root.doc = JSON.parse(text); } catch (e) {} } }
    }
    Process {
        id: docSave
        stderr: StdioCollector { onStreamFinished: root.docMsg = text.trim() }
    }

    Section {
        Layout.fillWidth: true
        title: "Diagnóstico"
        headerRight: Button { kind: "primary"; text: docProc.running ? "Analizando…" : "Diagnóstico"; enabled: !docProc.running; onClicked: { root.docMsg = ""; docProc.running = true; } }
        Txt {
            Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
            visible: !root.doc
            text: "Revisa versiones, gráficos, dependencias, servicios, la configuración y los últimos errores. El informe no incluye claves, tokens, correos ni tu carpeta personal."
        }
        RowLayout {
            visible: !!root.doc
            Layout.fillWidth: true
            spacing: 14
            Repeater {
                model: [["ok", "bien", Theme.p], ["warn", "avisos", Theme.tv], ["error", "errores", Theme.danger]]
                RowLayout {
                    required property var modelData
                    spacing: 5
                    Txt { text: String(root.doc?.summary?.[modelData[0]] ?? 0); size: 17; weight: Font.DemiBold; tabular: true; color: modelData[2] }
                    Txt { text: modelData[1]; muted: true; size: 11.5 }
                }
            }
            Item { Layout.fillWidth: true }
            Txt { text: root.doc ? Qt.formatDateTime(new Date(root.doc.generated), "dd/MM HH:mm") : ""; muted: true; size: 11.5; tabular: true }
        }
        Repeater {
            model: root.docIssues.slice(0, 6)
            RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 8
                Txt { text: modelData.status === "error" ? "✗" : "!"; weight: Font.Bold; color: modelData.status === "error" ? Theme.danger : Theme.tv; Layout.alignment: Qt.AlignTop }
                Txt { Layout.fillWidth: true; wrapMode: Text.WordWrap; elide: Text.ElideNone; size: 12; text: "<b>" + modelData.name + "</b> · " + modelData.detail; textFormat: Text.StyledText }
            }
        }
        Txt { visible: !!root.doc && root.docIssues.length === 0; text: "Todo en orden ✓"; color: Theme.p }
        RowLayout {
            spacing: 8
            Button { text: "Copiar informe"; onClicked: { Quickshell.execDetached(["sh", "-c", "\"$0\" --copy >/dev/null", root.sh("hf-doctor")]); root.docMsg = "Copiado al portapapeles ✓"; } }
            Button { text: "Guardar…"; onClicked: { docSave.command = [root.sh("hf-doctor"), "--save"]; docSave.running = true; } }
            Button { kind: "link"; text: "Ver completo"; onClicked: Pkg.runInTerminal(root.sh("hf-doctor") + " | less -R", "Diagnóstico") }
        }
        Txt { visible: root.docMsg !== ""; Layout.fillWidth: true; text: root.docMsg; muted: true; size: 11.5; wrapMode: Text.WordWrap }
    }

    // ───────── Actualizaciones de HyprFrijol ─────────
    property var upd: null
    property string updErr: ""
    function loadUpd(net: bool): void { updProc.command = [root.sh("hf-update"), net ? "check" : "status", "--json"]; updProc.running = false; updProc.running = true; }
    Process {
        id: updProc
        running: true
        command: [root.sh("hf-update"), "status", "--json"]
        stdout: StdioCollector { onStreamFinished: { try { root.upd = JSON.parse(text); root.updErr = ""; } catch (e) {} } }
        stderr: StdioCollector { onStreamFinished: { const t = text.replace(/\x1b\[[0-9;]*m/g, "").trim(); if (t) root.updErr = t.split("\n").pop().replace(/^[✗!] /, ""); } }
    }
    Section {
        Layout.fillWidth: true
        title: "Actualizaciones de HyprFrijol"
        headerRight: Mono { text: root.upd ? (root.upd.current ?? root.upd.base ?? root.upd.rev) : "hf-update" }
        Txt {
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            visible: !!root.upd
            text: !root.upd ? "" : root.upd.packaged ? "Instalado con el paquete " + root.upd.package + ": se actualiza con tu ayudante del AUR (paru -Syu o yay -Syu)"
                : root.upd.update ? "Hay una versión nueva: <b>" + root.upd.latest + "</b>"
                : root.upd.latest ? "Estás en la última versión (" + root.upd.latest + ")" : "Aún no hay versiones publicadas"
            textFormat: Text.StyledText
            color: root.upd?.update ? Theme.p : Theme.t
        }
        Txt {
            visible: (root.upd?.notes ?? "") !== ""
            Layout.fillWidth: true; Layout.maximumHeight: 120; clip: true
            text: (root.upd?.notes ?? "").replace(/^── /gm, "").trim()
            size: 11.5; muted: true; wrapMode: Text.WordWrap; elide: Text.ElideNone
        }
        Txt { visible: !!root.upd?.dirty; Layout.fillWidth: true; wrapMode: Text.WordWrap; size: 11.5; color: Theme.danger; text: "El repo tiene cambios locales: al actualizar se te ofrecerá guardarlos (git stash)." }
        Txt { visible: root.updErr !== ""; Layout.fillWidth: true; wrapMode: Text.WordWrap; size: 11.5; muted: true; text: root.updErr }
        RowLayout {
            spacing: 8
            Button { text: updProc.running ? "Buscando…" : "Buscar"; enabled: !updProc.running; onClicked: root.loadUpd(true) }
            Button { visible: !!root.upd?.update; kind: "primary"; text: "Actualizar a " + (root.upd?.latest ?? ""); onClicked: { Pkg.runInTerminal(root.sh("hf-update") + " apply " + root.upd.latest, "Actualizar HyprFrijol"); recheck.restart(); } }
            Button { visible: !!root.upd?.rollback; text: "Volver a " + (root.upd?.rollback ?? ""); onClicked: { Pkg.runInTerminal(root.sh("hf-update") + " rollback", "Volver a la versión anterior"); recheck.restart(); } }
        }
        Timer { id: recheck; interval: 20000; onTriggered: root.loadUpd(false) }
        LabeledRow {
            label: "Buscar solo"; labelWidth: 90
            Seg {
                model: [["weekly", "Cada semana"], ["daily", "Cada día"], ["never", "Nunca"]]
                current: Settings.get("hfUpdateCheck", "weekly")
                onPicked: k => Settings.set("hfUpdateCheck", k)
            }
        }
        Txt { Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap; text: "Actualiza esta copia de HyprFrijol por versiones (git tags) y la deja como estaba si algo falla. Los paquetes del sistema van aparte, en «Actualizaciones»." }
    }

    // ───────── Modo seguro ─────────
    property var safe: null
    Process {
        id: safeProc
        running: true
        command: [root.sh("hf-safe"), "status", "--json"]
        stdout: StdioCollector { onStreamFinished: { try { root.safe = JSON.parse(text); } catch (e) {} } }
    }
    Section {
        Layout.fillWidth: true
        title: "Modo seguro y recuperación"
        Txt {
            Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
            text: "Si el escritorio no arranca, elige «HyprFrijol (modo seguro)» en el inicio de sesión: Hyprland mínimo, sin shell ni plugins, con una terminal para restaurar tus ajustes."
        }
        InfoRow {
            separator: false
            label: "Restaurar ajustes"; icon: "shield"
            sub: root.safe ? (root.safe.lastGood ? "última copia buena: " + root.safe.lastGood.replace(/^(\d{4})(\d\d)(\d\d)-(\d\d)(\d\d).*/, "$3/$2/$1 $4:$5") : "aún sin copia buena") + " · " + root.safe.snapshots + " copias" : "…"
            Button { text: "Guardar copia"; onClicked: { Quickshell.execDetached([root.sh("hf-safe"), "snapshot", "manual desde Ajustes"]); safeT.restart(); } }
            Button { text: "Abrir…"; onClicked: Pkg.runInTerminal(root.sh("hf-safe") + " menu", "Restaurar ajustes") }
        }
        Timer { id: safeT; interval: 1500; onTriggered: { safeProc.running = false; safeProc.running = true; } }
        LabeledRow {
            label: "Ofrecer el modo seguro si el shell se cae al arrancar"; labelWidth: 190
            Seg {
                model: [["0", "Nunca"], ["2", "2 veces"], ["3", "3 veces"], ["5", "5 veces"]]
                current: String(Settings.get("safeModeCrashLimit", 3))
                onPicked: k => Settings.set("safeModeCrashLimit", parseInt(k))
            }
        }
    }
}
