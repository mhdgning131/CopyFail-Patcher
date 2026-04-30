#!/usr/bin/env bash

set -euo pipefail

CVE="CVE-2026-31431"
MODULE="algif_aead"
CONF_FILE="/etc/modprobe.d/disable-${MODULE}.conf"
LOG_FILE="/var/log/cve-patch-${CVE}-removal.log"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log()  { local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"; echo "$msg" | tee -a "$LOG_FILE"; }
info() { echo -e "${CYAN}[INFO]${RESET}  $*"; log "INFO  $*"; }
ok()   { echo -e "${GREEN}[OK]${RESET}    $*"; log "OK    $*"; }
warn() { echo -e "${YELLOW}[WARN]${RESET}  $*"; log "WARN  $*"; }
die()  { echo -e "${RED}[ERROR]${RESET} $*" >&2; log "ERROR $*"; exit 1; }
separator() { echo -e "${BOLD}────────────────────────────────────────${RESET}"; }


separator
echo -e "${RED}${BOLD}=> CVE-2026-31431 PATCH REMOVE{RESET}"
echo -e "               by @mhdgning131                    "
separator

echo ""
echo -e "This will ${BOLD}REMOVE${RESET} the mitigation and re-enable the ${MODULE} module."
echo -e "${RED}The system will be vulnerable until the patch is re-applied.${RESET}"
echo ""
read -r -p "Type YES to confirm removal: " CONFIRM
[[ "$CONFIRM" == "YES" ]] || { echo "Aborted."; exit 0; }

[[ $EUID -ne 0 ]] && die "Must be run as root (sudo)."

echo ""
separator
info "Removing mitigation for ${CVE}..."
separator
echo ""

# Step 1: Remove modprobe block file
if [[ -f "$CONF_FILE" ]]; then
  rm -f "$CONF_FILE"
  ok "Removed block file: ${CONF_FILE}"
else
  warn "Block file not found ! It's already removed or never applied."
fi

# Step 2: Reload the module to confirm it loads again
info "Attempting to load '${MODULE}' module..."
if modprobe "$MODULE" 2>/dev/null; then
  ok "Module '${MODULE}' loaded successfully. ← Patch is confirmed removed."
else
  warn "Module could not be loaded :)."
fi

# Step 3: Update initramfs
info "Rebuilding initramfs to remove the block..."
if command -v update-initramfs &>/dev/null; then
  update-initramfs -u &>>"$LOG_FILE" && ok "initramfs updated (Debian/Ubuntu)."
elif command -v dracut &>/dev/null; then
  dracut --force &>>"$LOG_FILE" && ok "initramfs rebuilt (RHEL/Fedora)."
else
  warn "Could not rebuild initramfs automatically."
fi

echo ""
separator
echo -e "${RED}${BOLD}=> System is now UNPATCHED. ${RESET}"
separator
