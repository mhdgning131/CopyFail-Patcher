#!/usr/bin/env bash

# Usage:
#   sudo bash patch-CVE-2026-31431.sh
#   sudo bash patch-CVE-2026-31431.sh --check  # Check status only, patch noting
#
set -euo pipefail

CVE="CVE-2026-31431"
MODULE="algif_aead"
CONF_FILE="/etc/modprobe.d/disable-${MODULE}.conf"
CHECK_ONLY=false
LOG_FILE="/var/log/cve-patch-${CVE}.log"

for arg in "$@"; do
  case "$arg" in
    --check) CHECK_ONLY=true ;;
    --help|-h)
      echo "Usage: sudo bash $0 [--check]"
      echo "  (no flags)  Apply the CVE-2026-31431 mitigation"
      echo "  --check     Report current status without making changes"
      exit 0 ;;
    *)
      echo "Unknown argument: $arg  (use --help for usage)"
      exit 1 ;;
  esac
done

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info() { echo -e "${CYAN}[INFO]${RESET}  $*"; }
ok()   { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn() { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
err()  { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
die()  { err "$*"; exit 1; }

separator() { echo -e "${BOLD}────────────────────────────────────────${RESET}"; }

separator
echo -e "${BOLD}  ${CVE} Mitigation Script${RESET}"
echo -e "           by @mhdgning131               "
separator

[[ $EUID -ne 0 ]] && die "This script must be run as root (use sudo)"

OS=$(grep -oP '(?<=^ID=).+' /etc/os-release 2>/dev/null || echo "unknown")
KERNEL=$(uname -r)
HOSTNAME=$(hostname)

info "Host    : ${HOSTNAME}"
info "OS      : ${OS}"
info "Kernel  : ${KERNEL}"
separator

check_status() {
  local module_loaded conf_exists
  lsmod | grep -q "^${MODULE}" && module_loaded=true || module_loaded=false
  [[ -f "$CONF_FILE" ]] && conf_exists=true || conf_exists=false

  echo ""
  echo -e "${BOLD}Current Status:${RESET}"
  if $conf_exists; then
     ok  "modprobe block file exists  → ${CONF_FILE}"
  else
    warn "modprobe block file missing → module can be loaded on reboot"
  fi

  if $module_loaded; then
    warn "Module '${MODULE}' LOADE in the kernel! Your System is Vulnerable !!!"
  else
    ok  "Module '${MODULE}' is NOT loaded :)"
  fi

  echo ""
  if $conf_exists && ! $module_loaded; then
    echo -e "${GREEN}${BOLD} ✓ Patch is fully applied and active.${RESET}"
  elif $conf_exists && $module_loaded; then
    echo -e "${YELLOW}${BOLD}✕  Block file exists but module is still loaded.${RESET}"
    echo    "   Run this script again without --check to unload the module."
  else
    echo -e "${RED}${BOLD}✘  Patch is NOT applied.${RESET}"
  fi
  echo ""
}

if $CHECK_ONLY; then
  check_status
  exit 0
fi

echo ""
info "Applying mitigation for ${CVE}..."
echo ""

if [[ -f "$CONF_FILE" ]]; then
  info "Block file already exists. Verifying contents..."
  grep -q "install ${MODULE} /bin/false" "$CONF_FILE" \
    && ok "Contents verified no changes needed" \
    || { warn "File exists but the content is unknown, we overwriting..."; 
         echo "install ${MODULE} /bin/false" > "$CONF_FILE"; }
else
  info "Creating modprobe block file at ${CONF_FILE}..."
  echo "install ${MODULE} /bin/false" > "$CONF_FILE"
  chmod 644 "$CONF_FILE"
  ok "Block file created"
fi

if lsmod | grep -q "^${MODULE}"; then
  info "Module '${MODULE}' is loaded, unloading..."
  if rmmod "$MODULE" 2>/dev/null; then
    ok "Module '${MODULE}' unloaded (^o^) "
  else
    warn "Couldn't unload '${MODULE}' it may be in use by another process"
    warn "Reboot your device to fully complete the mitigation !"
  fi
else
  ok "Module '${MODULE}' was not loaded, so, there is nothing to unload"
fi

info "Updating initramfs to persist the block across reboots..."
if command -v update-initramfs &>/dev/null; then
  update-initramfs -u &>>"$LOG_FILE" && ok "initramfs updated (Debian/Ubuntu)" || warn "initramfs update failed, check the $LOG_FILE"
elif command -v dracut &>/dev/null; then
  dracut --force &>>"$LOG_FILE" && ok "initramfs rebuilt (RHEL/Fedora)" || warn "dracut rebuild failed, check the $LOG_FILE"
else
  warn "Could not find update-initramfs or dracut, the patch will not persist on reboot "
fi

separator
check_status
echo -e "${GREEN}${BOLD}Mitigation for ${CVE} applied successfully hehe (^-^)${RESET}"
echo    "Reboot confirm the module cannot be reloaded !"
separator
