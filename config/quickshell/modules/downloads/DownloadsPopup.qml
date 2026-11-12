// Ventana de descargas (vista "w-descargas", clic en el indicador de la barra; también Spotlight «descargar …»):
// pegar una o varias direcciones (Auto / Vídeo / Audio / Imágenes / Archivo), la cola con progreso, velocidad y lo
// que queda, y por elemento pausar / reanudar, cancelar, reintentar y abrir la carpeta. Lo hace scripts/hf-download
// (services/Downloads vigila su queue.json).
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../.."
import "../../components"
import "../../services"
import "../widgets"
import "../devices"

ChipPopup {
    id: pop
    view: "w-descargas"
    panelWidth: 400
    panelHeight: Math.min(card.implicitHeight, 620)
    property string kind: "auto"
    onShownChanged: if (shown) Qt.callLater(() => urlField.focusInput())

    // Activas primero (en el orden de la cola), luego las demás de la más nueva a la más vieja
    readonly property var rows: {
        const act = Downloads.items.filter(x => ["queued", "running", "pausing", "canceling", "paused"].includes(x.status));
        const rest = Downloads.items.filter(x => !act.includes(x)).sort((a, b) => (b.finished || b.added) - (a.finished || a.added));
        return act.concat(rest).slice(0, 40);
    }
    function submit(): void {
        const u = urlField.text.split(/\s+/).filter(x => /^https?:\/\//.test(x));
        if (!u.length) return;
        Downloads.add(u, pop.kind, pop.kind === "audio" ? Settings.get("downloadsAudioFormat", "mp3") : "");
        urlField.text = "";
    }

    Glass {
        id: card
        anchors.fill: parent
        kind: "popup"
        implicitHeight: col.implicitHeight + 28

        ColumnLayout {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Icon { name: "download"; size: 16; color: Theme.t }
                Txt { text: "Descargas"; size: 14; weight: Font.DemiBold; Layout.fillWidth: true }
                Txt {
                    text: Downloads.active.length ? Downloads.active.length + (Downloads.active.length === 1 ? " activa" : " activas")
                        + (Downloads.progress >= 0 && Downloads.running.length ? " · " + Math.round(Downloads.progress * 100) + " %" : "") : ""
                    muted: true; size: 11.5; tabular: true
                }
            }

            Field {
                id: urlField
                Layout.fillWidth: true
                icon: "download"
                placeholder: "Pega una o varias direcciones…"
                onAccepted: pop.submit()
                input.Keys.onEscapePressed: Shell.close()
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Segmented {
                    Layout.fillWidth: true
                    h: 28
                    model: [{ key: "auto", label: "Auto" }, { key: "video", label: "Vídeo" }, { key: "audio", label: "Audio" },
                            { key: "image", label: "Imágenes" }, { key: "file", label: "Archivo" }]
                    current: pop.kind
                    onPicked: k => pop.kind = k
                }
                DevBtn { Layout.fillWidth: false; primary: true; text: "Descargar"; enabled: /https?:\/\//.test(urlField.text); onClicked: pop.submit() }
            }

            Txt {
                visible: pop.rows.length === 0
                Layout.fillWidth: true
                text: "No hay descargas. Pega aquí un enlace de vídeo, música, una galería o un archivo; también desde Spotlight: «descargar <dirección>»."
                muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
            }

            Flickable {
                visible: pop.rows.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(list.implicitHeight, 400)
                contentHeight: list.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height
                ColumnLayout {
                    id: list
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: pop.rows
                        Rectangle {
                            id: row
                            required property var modelData
                            readonly property var it: modelData
                            readonly property bool live: ["running", "pausing", "canceling"].includes(it.status)
                            Layout.fillWidth: true
                            implicitHeight: rc.implicitHeight + 16
                            radius: Theme.r(9)
                            color: Theme.fill2
                            ColumnLayout {
                                id: rc
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8; leftMargin: 10 }
                                spacing: 5
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Icon { name: Downloads.typeIcon(row.it.type); size: 14; color: row.it.status === "error" ? Theme.danger : Theme.tv }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Txt { Layout.fillWidth: true; text: row.it.title || row.it.name; weight: Font.DemiBold; size: 12 }
                                        Txt {
                                            Layout.fillWidth: true
                                            text: row.it.status === "error" ? row.it.error
                                                : row.live ? [row.it.progress >= 0 && row.it.total ? Math.round(row.it.progress * 100) + " %" : "",
                                                              row.it.total ? Downloads.human(row.it.done) + " de " + Downloads.human(row.it.total) : row.it.count ? row.it.count + " archivos" : "",
                                                              row.it.speed ? Downloads.human(row.it.speed) + "/s" : "",
                                                              row.it.eta > 0 ? "quedan " + Downloads.eta(row.it.eta) : ""].filter(Boolean).join(" · ") || Downloads.statusText(row.it)
                                                : Downloads.statusText(row.it) + (row.it.status === "done" && (row.it.files ?? []).length > 1 ? " · " + row.it.files.length + " archivos" : "")
                                                  + " · " + row.it.tool
                                            color: row.it.status === "error" ? Theme.danger : Theme.tv
                                            size: 11; tabular: true
                                            wrapMode: row.it.status === "error" ? Text.WordWrap : Text.NoWrap
                                            maximumLineCount: 2
                                        }
                                    }
                                    IconBtn {
                                        visible: row.it.status === "running" || row.it.status === "queued"
                                        icon: "pause"; iconSize: 12; fg: Theme.tv; tooltip: "Pausar"
                                        onClicked: Downloads.pause(row.it.id)
                                    }
                                    IconBtn {
                                        visible: row.it.status === "paused"
                                        icon: "play"; iconSize: 12; fg: Theme.tv; tooltip: "Reanudar"
                                        onClicked: Downloads.resume(row.it.id)
                                    }
                                    IconBtn {
                                        visible: row.it.status === "error" || row.it.status === "canceled"
                                        icon: "refresh"; iconSize: 12; fg: Theme.tv; tooltip: "Reintentar"
                                        onClicked: Downloads.retry(row.it.id)
                                    }
                                    IconBtn {
                                        visible: row.it.status === "done" || row.live
                                        icon: "folder"; iconSize: 12; fg: Theme.tv; tooltip: "Abrir la carpeta"
                                        onClicked: { Downloads.open(row.it.id); Shell.close(); }
                                    }
                                    IconBtn {
                                        icon: "x"; iconSize: 11; fg: Theme.tv
                                        tooltip: ["queued", "running", "paused"].includes(row.it.status) ? "Cancelar" : "Quitar de la lista"
                                        onClicked: ["queued", "running", "paused"].includes(row.it.status) ? Downloads.cancel(row.it.id) : Downloads.remove(row.it.id)
                                    }
                                }
                                // la cola se lee cada 1,5 s (services/Downloads.qml): el relleno avanza ese rato sin pararse
                                Progress {
                                    visible: row.live || row.it.status === "paused" || row.it.status === "queued"
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 4
                                    value: !(row.it.progress > 0) && row.live ? -1 : Math.max(0, row.it.progress || 0)
                                    period: 1500
                                    busy: row.live
                                    color: row.it.status === "paused" ? Theme.ter : Theme.p
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                DevBtn {
                    visible: Downloads.active.length > 1
                    icon: "pause"; text: "Pausar todas"
                    onClicked: Downloads.pause("all")
                }
                DevBtn {
                    visible: Downloads.items.some(x => ["done", "error", "canceled"].includes(x.status))
                    icon: "trash"; text: "Limpiar terminadas"
                    onClicked: Downloads.clear()
                }
                DevBtn { icon: "settings"; text: "Ajustes"; onClicked: Shell.open("ajustesapp", "almacenamiento") }
            }
        }
    }
}
