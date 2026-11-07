pragma Singleton
// Batería y modo de energía (UPower + power-profiles-daemon)
import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    readonly property var dev: UPower.displayDevice
    readonly property bool present: dev?.isLaptopBattery ?? false
    readonly property real percent: (dev?.percentage ?? 0)          // 0–1
    readonly property bool charging: dev?.state === UPowerDeviceState.Charging || dev?.state === UPowerDeviceState.FullyCharged
    readonly property bool onBattery: UPower.onBattery
    readonly property real secondsLeft: charging ? (dev?.timeToFull ?? 0) : (dev?.timeToEmpty ?? 0)
    readonly property string timeText: {
        const s = secondsLeft;
        if (!present || s <= 0) return "";
        const h = Math.floor(s / 3600), m = Math.round((s % 3600) / 60);
        return (h > 0 ? h + " h " : "") + m + " min";
    }
    // "ahorro" | "equilibrado" | "rendimiento"
    readonly property string profile: PowerProfiles.profile === PowerProfile.PowerSaver ? "ahorro"
                                    : PowerProfiles.profile === PowerProfile.Performance ? "rendimiento" : "equilibrado"
    readonly property bool hasPerformance: PowerProfiles.hasPerformanceProfile
    function setProfile(k: string): void {
        PowerProfiles.profile = k === "ahorro" ? PowerProfile.PowerSaver : k === "rendimiento" ? PowerProfile.Performance : PowerProfile.Balanced;
    }
}
