pragma Singleton
// Amanecer y atardecer de hoy, una sola fuente para la luz nocturna («Del atardecer al amanecer») y el tema
// claro/oscuro «Según la salida y puesta del sol» (themeSchedule = "sol").
//  · sunAuto (por defecto true): se calculan con la ecuación de NOAA a partir de la ubicación del clima
//    (Weather.where: ciudad fija weatherLat/weatherLon o la última por IP, si weatherIpLocation lo permite).
//  · Sin ubicación (o sunAuto = false): las horas a mano sunrise / sunset de Ajustes › Pantallas.
// scripts/hf-apply hace el mismo cálculo (sun_times) para elegir la paleta clara u oscura.
//   Sun.sunrise / Sun.sunset ("HH:MM"), Sun.riseMin / Sun.setMin (minutos desde las 0:00), Sun.computed,
//   Sun.isDay(minutos), Sun.where (texto de la ubicación)
import QtQuick
import Quickshell
import ".."

Singleton {
    id: root
    readonly property bool auto: Settings.get("sunAuto", true) !== false
    readonly property var loc: Weather.where
    readonly property bool computed: auto && !!loc && !isNaN(Number(loc.lat)) && !isNaN(Number(loc.lon))
    property int day: new Date().getDate()          // se renueva cada 10 min para recalcular al cambiar el día
    readonly property var times: computed ? calc(new Date(), Number(loc.lat), Number(loc.lon), day) : null
    readonly property int riseMin: times ? times.rise : hm(Settings.get("sunrise", "07:00"))
    readonly property int setMin: times ? times.set : hm(Settings.get("sunset", "19:00"))
    readonly property string sunrise: fmt(riseMin)
    readonly property string sunset: fmt(setMin)
    readonly property string polar: times ? times.polar : ""       // "" · "dia" (sol de medianoche) · "noche"
    readonly property string where: computed ? (loc.city || (Number(loc.lat).toFixed(2) + ", " + Number(loc.lon).toFixed(2))) : ""

    function hm(s): int { const p = String(s || "0:0").split(":"); return (parseInt(p[0]) || 0) * 60 + (parseInt(p[1]) || 0); }
    function fmt(m: int): string { m = ((m % 1440) + 1440) % 1440; return String(Math.floor(m / 60)).padStart(2, "0") + ":" + String(m % 60).padStart(2, "0"); }
    // ¿Es de día a esa hora (minutos desde las 0:00)?
    function isDay(now: int): bool {
        if (polar === "dia") return true;
        if (polar === "noche") return false;
        return riseMin <= setMin ? (now >= riseMin && now < setMin) : (now >= riseMin || now < setMin);
    }

    // Ecuación de NOAA (General Solar Position, precisión ~1 min). Devuelve minutos locales redondeados.
    // Igual que sun_times() de scripts/hf-apply: cambiar los dos a la vez.
    function calc(d, lat: real, lon: real, _day: int): var {
        const start = new Date(d.getFullYear(), 0, 1);
        const n = Math.floor((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - start) / 86400000) + 1;
        const g = 2 * Math.PI / 365 * (n - 1);
        const eq = 229.18 * (0.000075 + 0.001868 * Math.cos(g) - 0.032077 * Math.sin(g) - 0.014615 * Math.cos(2 * g) - 0.040849 * Math.sin(2 * g));
        const decl = 0.006918 - 0.399912 * Math.cos(g) + 0.070257 * Math.sin(g) - 0.006758 * Math.cos(2 * g)
            + 0.000907 * Math.sin(2 * g) - 0.002697 * Math.cos(3 * g) + 0.00148 * Math.sin(3 * g);
        const rad = Math.PI / 180, phi = lat * rad;
        const cosH = Math.cos(90.833 * rad) / (Math.cos(phi) * Math.cos(decl)) - Math.tan(phi) * Math.tan(decl);
        if (cosH > 1) return { rise: 720, set: 720, polar: "noche" };
        if (cosH < -1) return { rise: 0, set: 1440, polar: "dia" };
        const ha = Math.acos(cosH) / rad;
        const tz = -new Date(d.getFullYear(), d.getMonth(), d.getDate(), 12).getTimezoneOffset();
        const r = Math.round(720 - 4 * (lon + ha) - eq + tz), s = Math.round(720 - 4 * (lon - ha) - eq + tz);
        return { rise: ((r % 1440) + 1440) % 1440, set: ((s % 1440) + 1440) % 1440, polar: "" };
    }

    Timer { interval: 600000; running: true; repeat: true; onTriggered: root.day = new Date().getDate() }
    // Si hace falta y aún no hay ubicación, pedirla (después de que Weather lea su caché)
    Timer { interval: 6000; running: root.auto && !root.loc; onTriggered: Weather.locate() }
}
