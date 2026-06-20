#!/usr/bin/env bash
set -Eeuo pipefail

REPO="Tweakl/xboard-node-userdiff-fix"
RELEASE="v1.13-userdiff-fix-1"
ASSET="xboard-node-linux-amd64"
EXPECTED_SHA256="7bf4c248c70dc303919e88d7a4050dd093d2efd2a8b7f8ba44404051275874e0"
SERVICE="xboard-node.service"
TARGET="/usr/local/bin/xboard-node"

log() {
    printf '[xboard-node-fix] %s\n' "$*"
}

fail() {
    printf '[xboard-node-fix] ERROR: %s\n' "$*" >&2
    exit 1
}

[[ ${EUID:-$(id -u)} -eq 0 ]] || fail "run this installer as root"

case "$(uname -m)" in
    x86_64|amd64) ;;
    *) fail "this release currently supports Linux amd64 only" ;;
esac

command -v curl >/dev/null || fail "curl is required"
command -v sha256sum >/dev/null || fail "sha256sum is required"
command -v systemctl >/dev/null || fail "systemd is required"
[[ -x "$TARGET" ]] || fail "$TARGET was not found"
systemctl cat "$SERVICE" >/dev/null 2>&1 || fail "$SERVICE was not found"

tmp_dir=$(mktemp -d)
download="$tmp_dir/$ASSET"
cleanup() {
    rm -rf "$tmp_dir"
}
trap cleanup EXIT

url="https://github.com/$REPO/releases/download/$RELEASE/$ASSET"
log "downloading patched binary"
curl -fL --retry 3 --connect-timeout 15 "$url" -o "$download"

actual_sha256=$(sha256sum "$download" | awk '{print $1}')
[[ "$actual_sha256" == "$EXPECTED_SHA256" ]] || fail "SHA-256 verification failed"
chmod 755 "$download"
"$download" -v | grep -q 'v1.13-userdiff-fix' || fail "unexpected binary version"

stamp=$(date +%Y%m%d-%H%M%S)
backup="${TARGET}.before-userdiff-${stamp}"
cp -a "$TARGET" "$backup"

log "installing patch; existing connections may pause briefly"
systemctl stop "$SERVICE"
install -o root -g root -m 755 "$download" "$TARGET"

if systemctl start "$SERVICE" && sleep 5 && systemctl is-active --quiet "$SERVICE"; then
    log "installation successful"
    log "backup: $backup"
    "$TARGET" -v
    exit 0
fi

log "startup failed; restoring $backup"
install -o root -g root -m 755 "$backup" "$TARGET"
systemctl start "$SERVICE" || true
fail "patched binary failed to start and was rolled back"
