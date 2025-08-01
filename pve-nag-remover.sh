#!/bin/bash
#
# ┌───────────────────────────────────────────────────────────────┐
# │             Proxmox VE No-Subscription Nag Remover            │
# │                                                               │
# │ 📌 Author   : Jordan Hillis                                   │
# │ 📬 Contact  : jordan@hillis.email                             │
# │ 🌐 GitHub   : https://github.com/jordanhillis/pve-nag-remover │
# │ 📄 License  : MIT                                             │
# │ 📦 Version  : 1.0.0                                           │
# └───────────────────────────────────────────────────────────────┘
# test
# This script safely removes the "No valid subscription" popup 
# from the Proxmox VE web interface without affecting system stability.
#
# ➤ Compatible with Proxmox VE 5.1 and newer
#
# ⚠ Use at your own risk. Review source before running.
#
# ##############################################################################
#
# MIT License
# 
# Copyright (c) 2025 Jordan Hillis
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# ##############################################################################

# ====== CONFIG ======
TARGET="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"
BACKUP="${TARGET}.bak"
TAG_START="// --- PVE NO-SUB PATCH START ---"
TAG_END="// --- PVE NO-SUB PATCH END ---"

# ====== VERSIONING ======
VERSION="1.0.0"
DISABLE_VERSION_CHECK=false  # Set to true to skip update checks
VERSION_CACHE_FILE="/tmp/pve-nag-remover.versioncheck"
VERSION_CACHE_TTL_SECONDS=3600  # 1 hour
VERSION_URL="https://raw.githubusercontent.com/jordanhillis/pve-nag-remover/main/latest_version.txt"
SCRIPT_URL="https://raw.githubusercontent.com/jordanhillis/pve-nag-remover/main/pve-nag-remover.sh"
RELEASE_PAGE="https://github.com/jordanhillis/pve-nag-remover"
AUTO_UPDATE=false
[[ ! -t 0 ]] && NONINTERACTIVE=true || NONINTERACTIVE=false

# ====== MISC ======
SCRIPT_NAME="PVE Nag Remover"
AUTHOR_NAME="Jordan Hillis"
AUTHOR_EMAIL="jordan@hillis.email"

# ====== COLORS & ICONS ======
BOLD="\e[1m"
GREEN="\e[1;32m"
YELLOW="\e[1;33m"
RED="\e[1;31m"
BLUE="\e[1;34m"
RESET="\e[0m"
CHECK="${GREEN}✔${RESET}"
WARN="${YELLOW}⚠${RESET}"
FAIL="${RED}✖${RESET}"
INFO="${BLUE}ℹ${RESET}"

# ====== FUNCTIONS ======
log() { echo -e "${INFO} ${BOLD}$1${RESET}"; }
success() { echo -e "${CHECK} ${BOLD}$1${RESET}"; }
warn() { echo -e "${WARN} ${BOLD}$1${RESET}"; }
fail() { echo -e "${FAIL} ${BOLD}$1${RESET}"; exit 1; }

check_for_update() {
  if [[ "$DISABLE_VERSION_CHECK" == true ]]; then
    log "Version checking is disabled by user."
    return
  fi

  local now last_check_age latest_version
  now=$(date +%s)

  if [[ -f "$VERSION_CACHE_FILE" ]]; then
    local last_check
    last_check=$(stat -c %Y "$VERSION_CACHE_FILE")
    last_check_age=$(( now - last_check ))
    if (( last_check_age < VERSION_CACHE_TTL_SECONDS )); then
      latest_version=$(cat "$VERSION_CACHE_FILE")
      log "Using cached version check: $latest_version (checked $((last_check_age / 60)) minutes ago)"
    fi
  fi

  if [[ -z "$latest_version" ]]; then
    latest_version=$(curl -fsSL "$VERSION_URL" 2>/dev/null) || {
      warn "Could not check for updates."
      return
    }
    echo "$latest_version" > "$VERSION_CACHE_FILE"
    log "Fetched latest version: $latest_version"
  fi

  if [[ "$latest_version" != "$VERSION" ]]; then
    echo -e "${YELLOW}⚠ Update available: $latest_version (you have $VERSION)${RESET}"
    echo -e "🔗 View release notes: ${BLUE}${RELEASE_PAGE}${RESET}"

    if [[ "$AUTO_UPDATE" == true ]]; then
      log "Auto-update enabled. Proceeding with update..."
      answer="y"
    elif [[ "$NONINTERACTIVE" == true ]]; then
      warn "Non-interactive mode: skipping update prompt."
      return
    else
      read -rp "Do you want to update to the latest version? [y/N] " answer
    fi

    case "$answer" in
      [Yy]*)
        TMP_SCRIPT="$0.tmp"
        TMP_CHECKSUM="$0.tmp.sha256"

        curl -fsSL "$SCRIPT_URL" -o "$TMP_SCRIPT" || fail "Failed to download script."
        curl -fsSL "${SCRIPT_URL}.sha256" -o "$TMP_CHECKSUM" || fail "Failed to download checksum."

        EXPECTED_HASH=$(awk '{print $1}' "$TMP_CHECKSUM")
        ACTUAL_HASH=$(sha256sum "$TMP_SCRIPT" | awk '{print $1}')
        if [[ "$EXPECTED_HASH" == "$ACTUAL_HASH" ]]; then
          mv "$TMP_SCRIPT" "$0" && chmod +x "$0"
          success "Updated to version $latest_version. Please rerun the script."
          rm -f "$TMP_CHECKSUM"
          exit 0
        else
          rm -f "$TMP_SCRIPT" "$TMP_CHECKSUM"
          fail "Checksum verification failed! Update aborted."
        fi
        ;;
      *)
        log "Continuing with current version $VERSION"
        ;;
    esac
  else
    log "You are running the latest version: $VERSION"
  fi
}

show_banner() {
  local name="PVE NAG REMOVER"
  local version="Version $VERSION"
  local author="Author: $AUTHOR_NAME"
  local contact="Contact: $AUTHOR_EMAIL"
  local width=40
  local inner_width=$((width - 2)) 
  local ORANGE="\e[38;5;208m"
  local border_top="┌$(printf '─%.0s' $(seq 1 $width))┐"
  local border_bottom="└$(printf '─%.0s' $(seq 1 $width))┘"
  echo -e "${ORANGE}${BOLD}${border_top}"
  printf "│ %-*s │\n" "$inner_width" "            $name"
  printf "│ %s │\n" "$(printf '%*s' "$inner_width" '' | tr ' ' '-')"
  printf "│ %-*s │\n" "$inner_width" "$version"
  printf "│ %-*s │\n" "$inner_width" "$author"
  printf "│ %-*s │\n" "$inner_width" "$contact"
  echo -e "${border_bottom}${RESET}"
}

check_root() {
  [[ $EUID -ne 0 ]] && fail "Please run this script as root."
}

check_file() {
  [[ ! -f "$TARGET" ]] && fail "Target file not found: $TARGET"
}

backup() {
  if [[ -f "$BACKUP" ]]; then
    local TS
    TS=$(date +%Y%m%d-%H%M%S)
    local TIMED_BACKUP="${TARGET}.${TS}.bak"
    cp "$TARGET" "$TIMED_BACKUP"
    warn "Backup already exists. Created timestamped backup: $TIMED_BACKUP"

    # Keep only the 3 most recent backups
    local backups
    backups=($(ls -t "${TARGET}".*.bak 2>/dev/null))
    if (( ${#backups[@]} > 3 )); then
      for b in "${backups[@]:3}"; do
        rm -f "$b"
        warn "Old backup removed: $b"
      done
    fi
  else
    cp "$TARGET" "$BACKUP"
    success "Backup created: $BACKUP"
  fi
}

already_patched() {
  grep -q "$TAG_START" "$TARGET"
}

apply_patch() {
  if already_patched; then
    warn "Patch already applied. Skipping."
    return
  fi

  backup

  sed -i "/Ext.Msg.show/,/});/c\\
$TAG_START\\
void 0;\\
$TAG_END" "$TARGET" || fail "Failed to apply patch."

  success "Proxmox subscription nag successfully removed."
  restart_pveproxy
}

revert_patch() {
  if ! already_patched; then
    warn "No patch found. Nothing to revert."
    return
  fi

  # Get the most recent .bak file (timestamped or default)
  local latest_backup
  latest_backup=$(ls -t "${TARGET}".*.bak "$BACKUP" 2>/dev/null | head -n 1)

  if [[ -f "$latest_backup" ]]; then
    cp "$latest_backup" "$TARGET"
    success "Patch reverted using backup: $latest_backup"
    restart_pveproxy
  else
    fail "No backup found. Cannot safely revert."
  fi
}

restart_pveproxy() {
  if systemctl restart pveproxy.service; then
    success "Restarted pveproxy.service"
  else
    warn "Failed to restart pveproxy.service. You may need to do it manually."
  fi
}

cron_comment="# Remove Proxmox subscription nag at boot"

cron_add() {
  echo "Choose how often to run the patch:"
  echo "  1) At boot (@reboot)"
  echo "  2) Hourly"
  echo "  3) Daily"
  echo "  4) Custom crontab expression"
  read -rp "Enter choice [1-4]: " choice

  local cron_schedule
  case "$choice" in
    1) cron_schedule="@reboot" ;;
    2) cron_schedule="0 * * * *" ;;
    3) cron_schedule="0 0 * * *" ;;
    4)
      read -rp "Enter custom cron expression: " cron_schedule
      ;;
    *)
      warn "Invalid choice. Aborting."
      return
      ;;
  esac

  # Build cron line
  cron_line="$cron_schedule $(readlink -f "$0") apply"

  # Load existing crontab
  local tmp current_cron
  tmp=$(mktemp)
  crontab -l 2>/dev/null > "$tmp" || touch "$tmp"

  # Check for existing identical entry
  if grep -Fq "$cron_line" "$tmp"; then
    warn "Cron entry already exists."
    rm -f "$tmp"
    return
  fi

  # Append newline only if last line isn't blank
  if [[ -s "$tmp" && -n $(tail -n 1 "$tmp") ]]; then
    echo "" >> "$tmp"
  fi

  {
    echo "$cron_comment"
    echo "$cron_line"
  } >> "$tmp"

  crontab "$tmp"
  rm -f "$tmp"

  success "Cron entry added with schedule: $cron_schedule"
}

cron_remove() {
  local tmp
  tmp=$(mktemp)
  crontab -l 2>/dev/null > "$tmp" || touch "$tmp"
  if grep -qF "$cron_comment" "$tmp"; then
    # Remove the comment and the line after it
    sed -i "/$(printf '%q' "$cron_comment")/{
      N
      d
    }" "$tmp"
    crontab "$tmp"
    success "Cron entry and comment removed"
  else
    warn "No matching cron entry found"
  fi
  rm -f "$tmp"
}

cron_status() {
  if crontab -l 2>/dev/null | grep -qF "$cron_comment"; then
    success "Cron entry is present"
  else
    warn "Cron entry is NOT present"
  fi
}

detect_version() {
  if command -v pveversion &>/dev/null; then
    local version=$(pveversion | head -n1)
    log "Detected Proxmox version: $version"
  fi
}

show_status() {
  echo -e "${BOLD}📊 Patch Status:${RESET}"
  if already_patched; then
    echo -e "${GREEN}✔ Patch is currently applied${RESET}"
  else
    echo -e "${YELLOW}⚠ Patch is NOT applied${RESET}"
  fi
  # Show latest backup
  local latest_backup
  latest_backup=$(ls -t "${TARGET}".*.bak "$BACKUP" 2>/dev/null | head -n 1)
  if [[ -n "$latest_backup" ]]; then
    echo -e "${INFO} Latest backup: $latest_backup"
    echo -e "${INFO} Last modified: $(stat -c '%y' "$latest_backup")"
  else
    echo -e "${WARN} No backups found."
  fi
}

# ====== MAIN ======
show_banner
check_root
check_for_update
check_file
detect_version

case "$1" in
  apply)
    log "Applying patch..."
    apply_patch
    ;;
  revert)
    log "Reverting patch..."
    revert_patch
    ;;
  status)
    show_status
    ;;
  cron-add)
    log "Adding script to @reboot crontab..."
    cron_add
    ;;
  cron-remove)
    log "Removing script from crontab..."
    cron_remove
    ;;
  cron-status)
    log "Checking if script is in crontab..."
    cron_status
    ;;
  --auto-update)
    AUTO_UPDATE=true
    shift
    "$0" "$@"
    exit $?
    ;;
  --version|-v)
    printf "  - ${RESET}📦 Version : %-32s\n" "$VERSION"
    printf "  - ${RESET}🔗 GitHub  : %-32s\n" "$RELEASE_PAGE"
    exit 0
    ;;
  *)
    echo -e "${YELLOW}Usage:${RESET} $0 {apply|revert|status|cron-add|cron-remove|cron-status}"
    ;;
esac
