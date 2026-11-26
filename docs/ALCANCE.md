# Alcance

> Borrador para revisar: resume decisiones ya tomadas y propone el resto. Cámbialo a tu gusto.

Qué acepta HyprFrijol y qué no, para que una idea tenga una respuesta previsible. Complementa a
[PENDIENTES.md](PENDIENTES.md) (lo que falta) y a `AGENTS.md` (cómo trabajar en el código).

## Qué es

Un rice con su propio shell para **Hyprland** (configuración en Lua) y **Quickshell**, en español, que corre como
sesión aparte sin tocar tu configuración de siempre.

## Dentro

- Fallos y regresiones de cualquier cosa que ya hace.
- Pulir lo que ya existe: barra, paneles, vistas, modos de ventanas, temas, Ajustes.
- Poner a mano lo que Hyprland ya ofrece y HyprFrijol no enseña.
- Que cada función tenga su orden `hf-*` y funcione sin el shell cuando tenga sentido.
- Que el instalador traiga lo que haga falta, en todas las distribuciones admitidas.
- Documentación, empaquetado y pruebas de lo anterior.

## Fuera

- **Otros compositores** (niri, Sway, Umbriel…): descartado el 2026-11-13; HyprFrijol es para Hyprland.
- **Rehacer lo que hace Hyprland**: efectos o disposiciones que necesiten parchearlo. Para eso están sus plugins.
- **Plugins propios con permisos y registro** (los de Omarchy sí se cargan).
- Opciones que nadie ha pedido ni va a probar; compatibilidad con otros rices más allá de la migración documentada.
- Lo que no se pueda probar en un equipo de verdad se publica diciendo que no está probado, o no se publica.

## Cómo se decide

1. ¿Lo puede hacer ya Hyprland, un script o una aplicación? Entonces basta con enseñarlo.
2. ¿Amplía algo que existe o abre un frente nuevo? Mejor lo primero.
3. ¿Añade una dependencia? Tiene que valer la pena en todas las distribuciones.
4. ¿Quién lo mantiene y lo vuelve a probar con cada versión de Hyprland?

Un «no» es sobre el momento, no sobre la idea: si cambia, se mueve a PENDIENTES.
