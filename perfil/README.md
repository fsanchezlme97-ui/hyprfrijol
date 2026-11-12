# Perfil del proyecto

`perfil.json` es el equipo de referencia de HyprFrijol **sin datos personales**: paquetes y apps, servicios,
acceso remoto (SSH, cortafuegos, Tailscale, RustDesk), voz de Helpert, modelos de dictado y de Ollama, login y los
ajustes de aspecto y comportamiento. Se rehace con `hf-perfil publicar` en cada versión.

Para dejar un equipo nuevo igual: `./install.sh --perfil` (o `hf-perfil aplicar perfil/perfil.json`; con
`--dry-run` solo enseña las órdenes). Los ajustes se suman a los tuyos, con copia de los de antes.

No lleva (y nunca debe llevar): tu foto, el nombre del equipo, la ciudad del tiempo, rutas, la personalidad de la
IA, claves ni contraseñas. Eso va en tu perfil privado, `~/.config/hyprfrijol/perfil.json` (`hf-perfil guardar`),
que guardas tú fuera del repo.
