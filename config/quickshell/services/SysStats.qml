pragma Singleton
// CPU / GPU / RAM / disco desde /proc y /sys (sin dependencias). Solo mide mientras alguien lo usa:
//   SysStats.users++ al mostrarse, SysStats.users-- al ocultarse.
//   cpu (0–100), cpuTemp (°C o -1), gpu (0–100 o -1), gpuTemp, memUsed/memTotal (bytes), diskUsed/diskTotal
//   cores [%…], swapUsed/swapTotal, netRx/netTx (bytes/s), load ("0,52 0,61 0,70"), uptime (s)
//   cpuHist / memHist / gpuHist / rxHist / txHist: últimas 40 medidas (cada 2 s) para las gráficas
//   diskRead/diskWrite (bytes/s de los discos físicos) · diskHist (lectura + escritura)
//   gpus [{ card, driver, vendor: amd|nvidia|intel|otro, name, busy (0–100 o -1), temp (°C o -1),
//          memUsed/memTotal (bytes o -1), freq (0–100 o -1: Intel no da el % de uso; se usa la frecuencia) }]
//     AMD: sysfs gpu_busy_percent + mem_info_vram_* · NVIDIA: nvidia-smi (si está) · Intel (i915/xe): frecuencia
//     gpu / gpuTemp = la gráfica principal (la primera que da % de uso); hasGpu = hay alguna con datos
// Detalle (ventana «Sistema» de la barra): SysStats.detailUsers++ añade procesos (procs: top 6 por CPU
//   [{ pid, name, cpu, mem }]) y discos (disks: [{ mount, used, size }]).
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root
    property int users: 0
    property real cpu: 0
    property real cpuTemp: -1
    property real gpu: -1
    property real gpuTemp: -1
    property real memUsed: 0
    property real memTotal: 0
    property real diskUsed: 0
    property real diskTotal: 0
    property real diskRead: 0
    property real diskWrite: 0
    property var diskHist: []
    property var prevDio: null
    property var gpus: []
    readonly property bool hasGpu: gpus.some(g => g.busy >= 0 || g.freq >= 0 || g.temp > 0)
    property var gpuNames: ({})          // ranura PCI → nombre (lspci, una vez)
    property var prev: null
    property int detailUsers: 0
    property var cores: []
    property real swapUsed: 0
    property real swapTotal: 0
    property real netRx: 0
    property real netTx: 0
    property string load: ""
    property real uptime: 0
    property var procs: []
    property var disks: []
    property var cpuHist: []
    property var memHist: []
    property var gpuHist: []
    property var rxHist: []
    property var txHist: []
    property var prevCores: []
    property var prevNet: null
    property var prevProcs: null
    readonly property int histLen: 40
    function push(a, v): var { const r = a.concat([v]); return r.length > histLen ? r.slice(r.length - histLen) : r; }
    // 1,2 MB/s · 340 kB/s
    function rate(b: real): string {
        if (b >= 1e6) return (b / 1e6).toFixed(b >= 1e7 ? 0 : 1).replace(".", ",") + " MB/s";
        if (b >= 1e3) return Math.round(b / 1e3) + " kB/s";
        return Math.round(b) + " B/s";
    }

    function gb(b: real): string {
        const v = b / 1073741824;
        return (v >= 100 ? Math.round(v) : v.toFixed(1)).toString().replace(".", ",");
    }

    // Nombres de las gráficas (lspci -vmm): «Radeon RX 6600/6600 XT/6600M», «GeForce GT 710»
    Process {
        running: root.users > 0 && Object.keys(root.gpuNames).length === 0
        command: ["sh", "-c", `for d in /sys/class/drm/card[0-9]*; do case "\${d##*/}" in *-*) continue;; esac
            s=$(sed -n 's/^PCI_SLOT_NAME=//p' "$d/device/uevent" 2>/dev/null); [ -n "$s" ] || continue
            n=$(lspci -vmm -s "$s" 2>/dev/null | sed -n 's/^Device:[[:space:]]*//p'); echo "$s|$n"; done; echo end`]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = { _: true };
                for (const l of text.split("\n")) {
                    const i = l.indexOf("|");
                    if (i < 0) continue;
                    const n = l.slice(i + 1).trim(), b = n.match(/\[([^\]]+)\]/);
                    m[l.slice(0, i).toLowerCase()] = b ? b[1] : n;
                }
                root.gpuNames = m;
            }
        }
    }

    // Al abrir o cerrar el monitor del sistema (detalle por proceso) se relanza con el otro modo
    readonly property bool detailOn: detailUsers > 0
    onDetailOnChanged: if (proc.running) { proc.running = false; proc.running = Qt.binding(() => root.users > 0); }

    Process {
        id: proc
        running: root.users > 0
        command: Paths.reaper.concat(["bash", "-c", `
            # Un solo bash en marcha (antes un sh nuevo cada 2 s): escribe un bloque por vuelta terminado en «end» y espera con
            # \`read -t\` (sin sleep). Casi todo con builtins; los drivers de cada gráfica se leen una vez; df cada 30 s.
            detail=$1; exec 3<> <(:); i=0
            cards=(); drvs=()
            for d in /sys/class/drm/card[0-9]*; do
              case "\${d##*/}" in *-*) continue;; esac
              [ -e "$d/device/driver" ] || continue
              drv=$(readlink "$d/device/driver"); cards+=("$d"); drvs+=("\${drv##*/}")
            done
            nv=0; command -v nvidia-smi >/dev/null && nv=1
            while :; do
              while read -r l; do case "$l" in cpu*) echo "$l";; *) break;; esac; done < /proc/stat
              while read -r k v _; do case "$k" in MemTotal:|MemAvailable:|SwapTotal:|SwapFree:) echo "$k $v kB";; esac; done < /proc/meminfo
              read -r l1 l2 l3 _ < /proc/loadavg; echo "load $l1 $l2 $l3"
              read -r up _ < /proc/uptime; echo "uptime $up"
              rx=0; tx=0; n=0
              while read -r l; do
                n=$((n + 1)); [ "$n" -le 2 ] && continue
                l=\${l/:/ }; read -r ifc a _ _ _ _ _ _ _ t _ <<< "$l"
                case "$ifc" in lo|docker*|veth*|br-*|virbr*|tun*|wg*) continue;; esac
                rx=$((rx + a)); tx=$((tx + t))
              done < /proc/net/dev
              echo "net $rx $tx"
              for h in /sys/class/hwmon/hwmon*; do
                n=; read -r n 2>/dev/null < "$h/name"
                case "$n" in k10temp|coretemp|zenpower|cpu_thermal|acpitz) v=; read -r v 2>/dev/null < "$h/temp1_input"; echo "cputemp $n $v";; esac
              done
              for j in "\${!cards[@]}"; do
                d=\${cards[$j]}; dev=$d/device
                busy=-; read -r busy 2>/dev/null < "$dev/gpu_busy_percent"
                t=-; for h in "$dev"/hwmon/hwmon*/temp1_input; do [ -r "$h" ] && { read -r t < "$h"; break; }; done
                mu=-; mt=-; read -r mu 2>/dev/null < "$dev/mem_info_vram_used"; read -r mt 2>/dev/null < "$dev/mem_info_vram_total"
                fa=-; fm=-
                if [ -r "$d/gt_act_freq_mhz" ]; then read -r fa < "$d/gt_act_freq_mhz"; read -r fm 2>/dev/null < "$d/gt_max_freq_mhz"
                elif [ -r "$dev/tile0/gt0/freq0/act_freq" ]; then read -r fa < "$dev/tile0/gt0/freq0/act_freq"; read -r fm 2>/dev/null < "$dev/tile0/gt0/freq0/max_freq"; fi
                slot=; while IFS== read -r k v; do [ "$k" = PCI_SLOT_NAME ] && { slot=$v; break; }; done < "$dev/uevent"
                echo "gpu \${d##*/} \${drvs[$j]} \${slot:--} $busy $t $mu $mt $fa $fm"
              done
              [ "$nv" = 1 ] && nvidia-smi --query-gpu=pci.bus_id,utilization.gpu,temperature.gpu,memory.used,memory.total,name --format=csv,noheader,nounits 2>/dev/null | while read -r l; do echo "nvidia $l"; done
              r=0; w=0
              while read -r _ _ dn _ _ a _ _ _ b _; do
                [[ "$dn" =~ ^(nvme[0-9]+n[0-9]+|sd[a-z]+|vd[a-z]+|xvd[a-z]+|mmcblk[0-9]+)$ ]] && { r=$((r + a)); w=$((w + b)); }
              done < /proc/diskstats
              echo "dio $((r * 512)) $((w * 512))"
              [ $((i % 15)) = 0 ] && df -B1 --output=used,size / | { read -r _; read -r u s; echo "disk $u $s"; }
              if [ "$detail" = 1 ]; then
                # tiempo de CPU de cada proceso (el % se calcula entre dos medidas, como top)
                awk 'match($0, /\\) [A-Za-z] /) { n = substr($0, index($0, "(") + 1, RSTART - index($0, "(") - 1); split(substr($0, RSTART + 2), a, " "); print "proc", FILENAME, a[12] + a[13], a[22], n }' /proc/[0-9]*/stat 2>/dev/null
                df -B1 --output=source,target,used,size -x tmpfs -x devtmpfs -x efivarfs -x overlay -x squashfs 2>/dev/null | tail -n +2 | awk '$4 > 1e9 && !seen[$1]++' | sed 's/^/mnt /'
              fi
              echo end
              i=$((i + 1))
              read -t 2 -u 3
            done
        `, "bash", root.detailOn ? "1" : "0"])
        property string buf: ""
        stdout: SplitParser {
            onRead: line => {
                if (line !== "end") { proc.buf += line + "\n"; return; }
                const text = proc.buf;
                proc.buf = "";
                root.parse(text);
            }
        }
    }
    function parse(text: string): void {
            {
                let cpuT = -1, cpuPri = 9;
                const gpus = [], nv = {};
                const cores = [], prevCores = [], procs = [], disks = [];
                let swT = 0, swF = 0;
                const detail = root.detailUsers > 0;
                for (const l of text.split("\n")) {
                    const f = l.trim().split(/[\s,]+/);
                    if (f[0] === "cpu") {
                        const v = f.slice(1).map(Number), idle = v[3] + (v[4] || 0), tot = v.reduce((a, b) => a + b, 0);
                        if (root.prev) {
                            const dt = tot - root.prev.tot, di = idle - root.prev.idle;
                            if (dt > 0) root.cpu = Math.max(0, Math.min(100, 100 * (1 - di / dt)));
                        }
                        root.prev = { tot: tot, idle: idle };
                    } else if (/^cpu\d+$/.test(f[0])) {
                        const v = f.slice(1).map(Number), idle = v[3] + (v[4] || 0), tot = v.reduce((a, b) => a + b, 0);
                        const p = root.prevCores[cores.length];
                        cores.push(p && tot - p.tot > 0 ? Math.max(0, Math.min(100, 100 * (1 - (idle - p.idle) / (tot - p.tot)))) : 0);
                        prevCores.push({ tot: tot, idle: idle });
                    } else if (f[0] === "SwapTotal:") swT = Number(f[1]) * 1024;
                    else if (f[0] === "SwapFree:") swF = Number(f[1]) * 1024;
                    else if (f[0] === "load") root.load = f.slice(1, 4).join("  ").replace(/\./g, ",");
                    else if (f[0] === "uptime") root.uptime = Number(f[1]);
                    else if (f[0] === "net") {
                        const rx = Number(f[1]), tx = Number(f[2]), t = Date.now(), pn = root.prevNet;
                        if (pn && t > pn.t && rx >= pn.rx && tx >= pn.tx) {
                            root.netRx = (rx - pn.rx) * 1000 / (t - pn.t);
                            root.netTx = (tx - pn.tx) * 1000 / (t - pn.t);
                        }
                        root.prevNet = { rx: rx, tx: tx, t: t };
                    } else if (f[0] === "proc") {
                        const m = l.trim().match(/^proc\s+\/proc\/(\d+)\/stat\s+(\d+)\s+(\d+)\s+(.*)$/);
                        if (m) procs.push({ pid: +m[1], ticks: +m[2], rss: +m[3], name: m[4] });
                    } else if (f[0] === "mnt") {
                        const m = l.trim().match(/^mnt\s+\S+\s+(.+?)\s+(\d+)\s+(\d+)$/);
                        if (m) disks.push({ mount: m[1], used: +m[2], size: +m[3] });
                    } else if (f[0] === "MemTotal:") root.memTotal = Number(f[1]) * 1024;
                    else if (f[0] === "MemAvailable:") root.memUsed = root.memTotal - Number(f[1]) * 1024;
                    else if (f[0] === "cputemp" && f[2]) {
                        const pri = ["k10temp", "coretemp", "zenpower", "cpu_thermal", "acpitz"].indexOf(f[1]);
                        if (pri < cpuPri) { cpuPri = pri; cpuT = Number(f[2]) / 1000; }
                    } else if (f[0] === "gpu") {
                        const g = f.map(x => x === "-" ? "" : x), num = x => x === "" || isNaN(Number(x)) ? -1 : Number(x);
                        const drv = g[2], fa = num(g[9]), fm = num(g[10]);
                        gpus.push({
                            card: g[1], driver: drv, slot: (g[3] || "").toLowerCase(),
                            vendor: /amdgpu|radeon/.test(drv) ? "amd" : /nvidia|nouveau/.test(drv) ? "nvidia" : /i915|xe/.test(drv) ? "intel" : "otro",
                            busy: num(g[4]), temp: num(g[5]) > 0 ? num(g[5]) / 1000 : -1,
                            memUsed: num(g[6]), memTotal: num(g[7]),
                            freq: fa >= 0 && fm > 0 ? Math.min(100, 100 * fa / fm) : -1, freqMhz: fa
                        });
                    } else if (f[0] === "nvidia") {
                        // 00000000:08:00.0, 37, 45, 512, 2002, NVIDIA GeForce GT 710  ([N/A] si no lo da)
                        const c = l.trim().slice(7).split(/\s*,\s*/), num = x => isNaN(Number(x)) || x === "" ? -1 : Number(x);
                        if (c.length >= 5) nv[c[0].toLowerCase().slice(-7)] = { busy: num(c[1]), temp: num(c[2]), memUsed: num(c[3]) * 1048576, memTotal: num(c[4]) * 1048576, name: (c[5] || "").replace(/^NVIDIA\s+/, "") };
                    } else if (f[0] === "dio") {
                        const r = Number(f[1]), w = Number(f[2]), t = Date.now(), pd = root.prevDio;
                        if (pd && t > pd.t && r >= pd.r && w >= pd.w) {
                            root.diskRead = (r - pd.r) * 1000 / (t - pd.t);
                            root.diskWrite = (w - pd.w) * 1000 / (t - pd.t);
                        }
                        root.prevDio = { r: r, w: w, t: t };
                    } else if (f[0] === "disk") { root.diskUsed = Number(f[1]); root.diskTotal = Number(f[2]); }
                }
                // NVIDIA: los datos de nvidia-smi van a su tarjeta (por la ranura PCI)
                for (const g of gpus) {
                    const n = nv[g.slot.slice(-7)];
                    if (n) {
                        if (n.busy >= 0) g.busy = n.busy;
                        if (n.temp > 0) g.temp = n.temp;
                        if (n.memTotal > 0) { g.memUsed = n.memUsed; g.memTotal = n.memTotal; }
                        if (n.name) g.name = n.name;
                    }
                    if (!g.name) g.name = root.gpuNames[g.slot] || (g.vendor === "amd" ? "AMD Radeon" : g.vendor === "nvidia" ? "NVIDIA" : g.vendor === "intel" ? "Intel" : g.card);
                }
                // La principal: la que da % de uso (Intel: la frecuencia); con varias, la de más VRAM (la dedicada)
                const main = gpus.filter(g => g.busy >= 0).sort((a, b) => b.memTotal - a.memTotal)[0] ?? gpus.find(g => g.freq >= 0);
                root.gpus = gpus.sort((a, b) => (b === main) - (a === main));
                root.cpuTemp = cpuT;
                root.gpu = main ? (main.busy >= 0 ? main.busy : main.freq) : -1;
                root.gpuTemp = main ? main.temp : (gpus.find(g => g.temp > 0)?.temp ?? -1);
                root.cores = cores; root.prevCores = prevCores;
                root.swapTotal = swT; root.swapUsed = swT - swF;
                if (detail) {
                    // % de CPU (100 = un núcleo) entre esta medida y la anterior; ticks de 1/100 s
                    const t = Date.now(), pp = root.prevProcs, dt = pp ? (t - pp.t) / 1000 : 0, cur = {};
                    for (const p of procs) cur[p.pid] = p.ticks;
                    if (pp && dt > 0) {
                        root.procs = procs.filter(p => pp.m[p.pid] !== undefined)
                            .map(p => ({ pid: p.pid, name: p.name, cpu: (p.ticks - pp.m[p.pid]) / dt, mem: root.memTotal ? 100 * p.rss * 4096 / root.memTotal : 0 }))
                            .sort((a, b) => b.cpu - a.cpu || b.mem - a.mem).slice(0, 6);
                    }
                    root.prevProcs = { t: t, m: cur };
                    root.disks = disks.slice(0, 5);
                } else root.prevProcs = null;
                root.cpuHist = root.push(root.cpuHist, root.cpu);
                root.memHist = root.push(root.memHist, root.memTotal ? 100 * root.memUsed / root.memTotal : 0);
                root.gpuHist = root.push(root.gpuHist, Math.max(0, root.gpu));
                root.rxHist = root.push(root.rxHist, root.netRx);
                root.txHist = root.push(root.txHist, root.netTx);
                root.diskHist = root.push(root.diskHist, root.diskRead + root.diskWrite);
            }
    }
}
