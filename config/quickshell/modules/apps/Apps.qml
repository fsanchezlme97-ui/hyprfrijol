// Apps sueltas que antes vivían dentro de Ajustes (Ajustes es para ajustes): cada una reutiliza su sección con
// «app: true», que enseña la parte de uso diario y esconde las preferencias (estas siguen en Ajustes, con un botón
// para abrir la app). Ventanas diferidas: no existen hasta abrirlas.
//   remoto     «Conexiones remotas»   — conexiones guardadas (RDP, VNC, SSH, SPICE): conectar, añadir, editar
//   maquinas   «Máquinas virtuales»   — tus máquinas (virsh) y contenedores (Distrobox): encender, apagar, crear
//   impresion  «Cola de impresión»    — trabajos pendientes: cancelar uno o todos
//   restauracion «Puntos de restauración» — los de snapper: crear uno, ver qué cambió, restaurar archivos
import QtQuick
import Quickshell
import "../.."
import "../../components"
import "../settings/sections"

Scope {
    AppWindow {
        view: "remoto"; title: "Conexiones remotas"
        subtitle: "Escritorios de otros equipos por RDP, VNC, SSH o SPICE · los clientes y compartir este escritorio, en Ajustes › Escritorio remoto"
        prefW: 760
        content: Component { Remoto { app: true } }
    }
    AppWindow {
        view: "maquinas"; title: "Máquinas virtuales"
        subtitle: "Tus máquinas y contenedores · lo que hay que instalar y Cockpit, en Ajustes › Máquinas virtuales"
        content: Component { Virtualizacion { app: true } }
    }
    AppWindow {
        view: "impresion"; title: "Cola de impresión"
        subtitle: "Lo que está esperando para imprimirse · las impresoras, en Ajustes › Impresoras y escáneres"
        prefW: 640; prefH: 520
        content: Component { Impresoras { app: true } }
    }
    AppWindow {
        view: "restauracion"; title: "Puntos de restauración"
        subtitle: "Snapper guarda el sistema antes y después de cada actualización · las actualizaciones y los kernels, en Ajustes › Sistema"
        prefW: 720; prefH: 560
        content: Component { Sistema { app: true } }
    }
}
