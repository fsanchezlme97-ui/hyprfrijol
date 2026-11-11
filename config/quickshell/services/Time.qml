pragma Singleton
// Reloj compartido (fecha en español como el diseño: "vie 6 nov", "10:11")
// Ajuste clock24 (Ajustes › Fecha, hora e idioma): false → hhmm "03:45" + ampm "p. m." (hhmm siempre son 5
// caracteres, la barra vertical lo parte en dos). fmt(d) da la hora de cualquier fecha con el mismo formato.
import QtQuick
import Quickshell
import ".."

Singleton {
    id: root
    property date now: new Date()
    readonly property bool h24: Settings.get("clock24", true) !== false
    readonly property string hhmm: h24 ? Qt.formatDateTime(now, "HH:mm") : String(now.getHours() % 12 || 12).padStart(2, "0") + Qt.formatDateTime(now, ":mm")
    readonly property string ampm: h24 ? "" : (now.getHours() < 12 ? "a. m." : "p. m.")
    readonly property string shortDate: Qt.locale("es_ES").toString(now, "ddd d MMM").replace(/\./g, "")
    readonly property string longDate: Qt.locale("es_ES").toString(now, "dddd, d 'de' MMMM")
    function fmt(d): string { return h24 ? Qt.formatDateTime(d, "HH:mm") : (d.getHours() % 12 || 12) + Qt.formatDateTime(d, ":mm") + (d.getHours() < 12 ? " a. m." : " p. m."); }
    function fmtHM(s: string): string {   // "13:05" (de date +%H:%M) → formato elegido
        const m = /^(\d{1,2}):(\d{2})/.exec(s ?? ""); if (!m || h24) return s ?? "";
        const h = Number(m[1]); return (h % 12 || 12) + ":" + m[2] + (h < 12 ? " a. m." : " p. m.");
    }
    // Minutos: nada muestra segundos, y con Seconds todo lo que depende de «now» (el «hace X min» de cada aviso…)
    // se recalculaba cada segundo con el shell en reposo. Salta justo al cambiar de minuto.
    SystemClock { id: clock; precision: SystemClock.Minutes; onDateChanged: if (date) root.now = date }
}
