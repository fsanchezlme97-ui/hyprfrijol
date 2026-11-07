# hyprfrijol — detección de la distro, compartida por install.sh y scripts/hf-apps (se carga con «.»).
#   load_os_release   → OS_ID OS_LIKE OS_VER OS_CODENAME OS_UCODENAME OS_PRETTY SIMULATED (HF_DISTRO la simula)
#   family_of <id>    → arch | fedora | rhel | suse | suse-leap | debian | ubuntu | void | gentoo | nixos (1 si no la conoce)
#   hf_family         → imprime la familia de esta distro (mirando también ID_LIKE)
OS_ID="" OS_LIKE="" OS_VER="" OS_CODENAME="" OS_UCODENAME="" OS_PRETTY="" SIMULATED=0
load_os_release() {
  local f=/etc/os-release; [ -r "$f" ] || f=/usr/lib/os-release
  if [ -r "$f" ]; then
    eval "$( . "$f" >/dev/null 2>&1
      printf 'OS_ID=%q OS_LIKE=%q OS_VER=%q OS_CODENAME=%q OS_UCODENAME=%q OS_PRETTY=%q\n' \
        "${ID:-}" "${ID_LIKE:-}" "${VERSION_ID:-}" "${VERSION_CODENAME:-}" "${UBUNTU_CODENAME:-}" "${PRETTY_NAME:-}" )"
  fi
  if [ -n "${HF_DISTRO:-}" ]; then
    SIMULATED=1 OS_ID="$HF_DISTRO" OS_LIKE="" OS_CODENAME="" OS_UCODENAME="" OS_VER="${HF_DISTRO_VERSION:-}"
    case "$OS_VER" in *[a-z]*) OS_CODENAME="$OS_VER" OS_UCODENAME="$OS_VER" OS_VER="" ;; esac
    # Valores típicos si no se da versión
    case "$OS_ID" in
      fedora)    : "${OS_VER:=44}" ;;
      rocky|almalinux|rhel|centos) : "${OS_VER:=10}" ;;
      debian)    [ -n "$OS_CODENAME$OS_VER" ] || OS_CODENAME=forky ;;
      ubuntu)    [ -n "$OS_UCODENAME$OS_VER" ] || OS_VER=26.04 ;;
      pop)       [ -n "$OS_UCODENAME$OS_VER" ] || OS_UCODENAME=noble ;;
      linuxmint) [ -n "$OS_UCODENAME$OS_VER" ] || OS_UCODENAME=noble ;;
      opensuse-leap) : "${OS_VER:=16.0}" ;;
    esac
    OS_PRETTY="$OS_ID${OS_VER:+ $OS_VER}${OS_CODENAME:+ ($OS_CODENAME)} — simulada con HF_DISTRO"
  fi
  return 0
}
family_of() {
  case "$1" in
    arch|archarm|cachyos|endeavouros|manjaro|manjaro-arm|garuda|artix|arcolinux|archcraft|rebornos) echo arch ;;
    fedora|nobara|ultramarine) echo fedora ;;
    rhel|centos|rocky|almalinux|ol|eurolinux|circle) echo rhel ;;
    opensuse-tumbleweed|opensuse-slowroll|opensuse-microos|opensuse-aeon|opensuse-kalpa|opensuse|suse) echo suse ;;
    opensuse-leap|sles|sled) echo suse-leap ;;
    debian|raspbian|devuan|kali|parrot) echo debian ;;
    ubuntu|pop|linuxmint|elementary|zorin|neon|tuxedo) echo ubuntu ;;
    void) echo void ;;
    gentoo|funtoo) echo gentoo ;;
    nixos) echo nixos ;;
    *) return 1 ;;
  esac
}
hf_family() {
  load_os_release
  local f w
  if f="$(family_of "$OS_ID")"; then echo "$f"; return 0; fi
  for w in $OS_LIKE; do f="$(family_of "$w")" && { echo "$f"; return 0; }; done
  echo unknown
}
