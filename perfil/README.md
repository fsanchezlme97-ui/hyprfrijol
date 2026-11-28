# Perfil del proyecto

`perfil.json` es el equipo de referencia de HyprFrijol **sin datos personales**: paquetes y apps, servicios,
acceso remoto (SSH, cortafuegos, Tailscale, RustDesk), voz de Emma, modelos de dictado y de Ollama, login y los
ajustes de aspecto y comportamiento. Se rehace con `hf-perfil publicar` en cada versión.

Para dejar un equipo nuevo igual: `./install.sh --perfil` (o `hf-perfil aplicar perfil/perfil.json`; con
`--dry-run` solo enseña las órdenes). Los ajustes se suman a los tuyos, con copia de los de antes. El acceso remoto
(SSH, Tailscale, RustDesk) se pregunta antes de abrirlo; sin terminal, solo con `--acceso-remoto`.

No lleva (y nunca debe llevar): tu foto, el nombre del equipo, la ciudad del tiempo, rutas, la personalidad de la
IA, claves ni contraseñas. Eso va en tu perfil privado, `~/.config/hyprfrijol/perfil.json` (`hf-perfil guardar`),
que guardas tú fuera del repo.

## Perfiles por equipo

`equipo-gpu.json`, `equipo-cpu.json` y `equipo-cpu-poca-ram.json` solo tocan el asistente (Emma) y el dictado; los
aplica `./install.sh --equipo=gpu|cpu` (sin la opción, detecta la gráfica y pregunta). Con gráfica dedicada de 6 GB o
más: gemma4:e4b en la gráfica y dictado híbrido con whisper turbo. Sin ella: Parakeet en la CPU y gemma4:e4b, o
gemma4:e2b con menos de 16 GB de RAM. Medidas en `docs/IA.md`.
